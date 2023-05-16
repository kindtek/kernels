#!/bin/bash
kernel_type="$1"
config_source="$2"
zfs="$3"
win_user="${4}"
quick_wsl_install=${4:+1}
timestamp_id="${5:-${DOCKER_BUILD_TIMESTAMP:-$(date -d "today" +"%Y%m%d%H%M%S")}}"
kernel_file_suffix="W"
linux_build_dir=linux-build

if [ "$zfs" = "zfs" ];  then
    zfs_build_dir="zfs-build"
    zfs_repo=https://github.com/openzfs/zfs.git
    zfs_version_tag=$(git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $zfs_repo | tail --lines=1 | cut --delimiter='/' --fields=3)
    zfs_version=${zfs_version_tag#"zfs-"}
    linux_kernel_type_tag=$linux_kernel_type_tag-ZFS
    kernel_file_suffix+="Z"
fi
if [ "$kernel_type" = "" ]; then
    kernel_type="stable"
fi
if [ "$kernel_type" = "latest" ]; then
    # zfs not supported atm
    # zfs=False; linux_kernel_type_tag=;
    if [ "$zfs" = "zfs" ]; then
        zfs_version=2.1.12
        zfs_version_tag=zfs-$zfs_version-staging
    fi
    linux_build_dir=linux-build-torvalds
    linux_repo=https://github.com/torvalds/linux.git
    linux_kernel_version_tag=$(git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $linux_repo | cut --delimiter='/' --fields=3 | grep '^v[0-9a-zA-Z\.]*$' | tail --lines=1) 
    linux_kernel_type_tag="LATEST-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
    kernel_file_suffix+="L"
    # config_file_suffix+="_latest"
elif [ "$kernel_type" = "latest-rc" ]; then
    # zfs not supported atm
    # zfs=False; linux_kernel_type_tag=;
    # if [ "$zfs" = "zfs" ]; then
    #     zfs_version=2.1.12
    #     zfs_version_tag=zfs-$zfs_version-staging
    # fi
    linux_build_dir=linux-build-torvalds
    kernel_file_suffix+="R"
    # config_file_suffix+="_rc"
    linux_repo=https://github.com/torvalds/linux.git
    linux_kernel_version_tag=$(git ls-remote --refs --sort=version:refname --tags $linux_repo | cut --delimiter='/' --fields=3 | grep '^v[0-9a-zA-Z\.]*-rc.*$' | tail --lines=1) 
    linux_kernel_type_tag="LATEST_RC-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
elif [ "$kernel_type" = "stable" ]; then
    # latest tag doesn't work properly with zfs so manually update for zfs version possibly compatible with 6.2.9+
    # update: it did not work
    # zfs_version=2.1.11
    # zfs_version_tag=zfs-$zfs_version
    # if [ "$zfs" = "zfs" ]; then
    #     zfs_version=2.1.12
    #     zfs_version_tag=zfs-$zfs_version-staging
    # fi
    zfs=False; linux_kernel_type_tag=;
    linux_build_dir=linux-build-gregkh
    kernel_file_suffix+="S"
    # config_file_suffix+="_stable"
    linux_repo=https://github.com/gregkh/linux.git
    # linux_version_query="git ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$(git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $linux_repo | tail --lines=1 | cut --delimiter='/' --fields=3)
    linux_kernel_type_tag="STABLE-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
# elif [ "$kernel_type"="basic" ]; then
else 
    # (BASIC)
    # latest tag doesn't work properly with zfs so manually update for zfs version compatible with 5.5.3+
    zfs_version=2.1.11
    zfs_version_tag=zfs-$zfs_version
    kernel_file_suffix+="B"
    # config_file_suffix+="_basic"
    linux_build_dir=linux-build-msft
    linux_repo=https://github.com/microsoft/WSL2-Linux-Kernel.git
    linux_kernel_version_tag=$(git -c versionsort.suffix=+ ls-remote --refs --sort=version:refname --tags $linux_repo  | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="BASIC-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"linux-msft-wsl"}
    linux_kernel_version=${linux_kernel_version_tag%".y"}
    # manually set version due to known bug that breaks 5.15 build with werror: pointer may be used after 'realloc' [-Werror=use-after-free] https://gcc.gnu.org/bugzilla/show_bug.cgi?id=104069
    linux_kernel_version_tag=linux-msft-wsl-6.1.y
    linux_kernel_version=6.1

fi

package_full_name_id=Linux-$linux_kernel_version-${linux_kernel_type_tag}_${timestamp_id}

if [ "$2" = "get-version" ]; then
    if [ "$zfs" = "zfs" ];  then
        echo -n "$zfs_version"
        exit
    else
        echo -n "$linux_kernel_version"
        exit
    fi
fi
if [ "$2" = "get-package" ]; then
    echo -n "$package_full_name_id"
    exit
fi


# deduce architecture of this machine
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"
# shorten common vendor names
if [ "$cpu_vendor" = AuthenticAMD ]; then cpu_vendor=amd; fi
if [ "$cpu_vendor" = GenuineIntel ]; then cpu_vendor=intel; fi
linux_kernel_version_mask=${linux_kernel_version/\./_}
linux_kernel_header_version="${linux_kernel_version:0:3}"
linux_kernel_kali_header_pattern="linux-headers-${linux_kernel_header_version}*"
kernel_alias_no_timestamp=${linux_kernel_version/\./L}
linux_kernel_version_mask=${linux_kernel_version_mask//[\.-]/}
kernel_alias_no_timestamp=${kernel_alias_no_timestamp//[\.-]/}${kernel_file_suffix}
kernel_alias=${kernel_alias_no_timestamp}_${timestamp_id}
config_alias=.config_${kernel_alias}
config_alias_no_timestamp=.config_${kernel_alias_no_timestamp}
git_save_path=$cpu_arch/$cpu_vendor/$linux_kernel_version_mask
nix_k_cache=/kache

# check that the user supplied source exists if not try to pick the best .config file available
# user choice is best if it exists
if [ "$config_source" != "" ] && [ -r "$config_source" ] && [ -s "$config_source" ]; then
    echo "config: $config_source
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    "
# try alternates if user config doesn't work 
    # download reliable .config
elif [ ! -r "$git_save_path/$config_alias_no_timestamp" ]; then
        generic_config_source=https://raw.githubusercontent.com/microsoft/WSL2-Linux-Kernel/linux-msft-wsl-5.15.y/Microsoft/config-wsl
    echo "

No saved .config files match this kernel version $linux_kernel_version_tag and $cpu_arch/$cpu_vendor"
    if [ ! -r "config-wsl" ]; then
        wget $generic_config_source
    fi
    if [ ! -r "config-wsl" ]; then
        echo "Oooops. Failed to download generic .config file.

Exiting ...

"
        exit
    fi
echo "

Press ENTER to continue and use the generic Microsoft .config downloaded from:
    $generic_config_source

        -- OR --

Enter the url of a config file to use

    pro tip: to use a file on Github make sure to use a raw file url starting with https://raw.githubusercontent.com
"
[ "$win_user" != "" ] || read -r -p "($generic_config_source)
" config_source
echo "
# checking if input is a url ..."
    if [ "$config_source" != "" ]; then
        if [[ "$config_source" =~ https?://.* ]]; then 
            echo "yes"
            echo "attempting to download $config_source ...
            "
            wget -O .config "$config_source" && \
            config_source=".config"
        else 
            echo "not a url"
        fi
    fi
fi
if [ -r "$config_source" ]; then 
    # config_source=$generic_config_source
    echo "config $config_source appears to be valid"
else    
    echo "config source is invalid (${config_source:-blank})
choosing an alternative ..."
    # reliable but the least desirable .. keep looking
    if [ -r "config-wsl" ]; then 
        config_source=config-wsl
    fi
    # generic - slightly better
    if [ -r "$cpu_arch/generic/$linux_kernel_version_mask/$config_alias" ]; then 
        config_source=$cpu_arch/generic/$linux_kernel_version_mask/$config_alias
    fi
    # specific arch - best alternate 
    if [ -r "$git_save_path/$config_alias_no_timestamp" ]; then
        config_source=$git_save_path/$config_alias_no_timestamp
    fi

    echo "picked $config_source"
fi

padding="----------"
printf "













==================================================================
========================   Linux Kernel   ========================
======------------------%s%s------------------======
------------------------------------------------------------------
====-------------------     Source Info    -------------------====
------------------------------------------------------------------

  CPU Architecture: 
    $cpu_arch

  CPU Vendor:  
    $cpu_vendor

  Configuration File:
    $config_source


==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}"
orig_win_user=$win_user
orig_pwd=$(pwd)
[ ! -d "/mnt/c/users" ] || cd "/mnt/c/users" || exit
while [ ! -d "$win_user" ]; do
    if [ ! -d "/mnt/c/users" ]; then
        if [ ! -d "/mnt/c/users/$win_user" ]; then
            echo "skipping prompt for home directory"
        fi
        break;
    fi
    echo " 


save kernel build to which Windows home directory?

    choose from:
    " 
    ls -da /mnt/c/users/*/ | tail -n +4 | sed -r -e 's/^\/mnt\/c\/users\/([ A-Za-z0-9]*)*\/+$/\t\1/g'

    read -r -p "

(skip)  C:\\users\\" win_user
    if [ "$win_user" = "" ]; then
        win_user=$orig_win_user
        break
    fi
    if [ ! -d "/mnt/c/users/$win_user" ]; then
        echo "

        
        
        







C:\\users\\$win_user is not a home directory"
    fi
done
cd "$orig_pwd" || exit

kernel_source=arch/$cpu_arch/boot/bzImage
kernel_target_git=$git_save_path/$kernel_alias_no_timestamp
config_target_git=$git_save_path/$config_alias_no_timestamp
tarball_filename=$package_full_name_id.tar.gz
tarball_target_nix=$nix_k_cache/$package_full_name_id.tar.gz
win_user_home=/mnt/c/users/$win_user
win_k_cache=$win_user_home/kache
tarball_target_win=$win_k_cache/$package_full_name_id.tar.gz
wsl_kernel=$win_k_cache/$kernel_alias
wsl_config=$win_user_home/.wslconfig
kindtek_kernel_version="kindtek-kernel-$kernel_alias_no_timestamp"
sed -i "s/[# ]*CONFIG_LOCALVERSION[ =].*/CONFIG_LOCALVERSION=\"\-${kindtek_kernel_version}\"/g" "$config_source"
# if win timestamp was manually set or win_user not set then clear win install paths
if [ "${5}" != "" ] || [ "$win_user" = "" ]; then
    tarball_target_win=""
    win_user_home=""
    win_k_cache=""
fi

if [ "$linux_kernel_version" = "" ]; then
echo "

    couuld not get Linux kernel version ... 
    cannot continue.

    Error: LINUX_KERNEL_VERSION_NOT_FOUND

    "
fi


printf "



==================================================================
========================   Linux Kernel   ========================
======------------------%s%s------------------======
------------------------------------------------------------------
====-------------------     Output Info    -------------------====
------------------------------------------------------------------

  Kernel:
    $kernel_target_git

  Config:
    $config_target_git
    
  Kernel/Config/Installation/.tar.gz files:
    $nix_k_cache
    %s     

==================================================================
==================================================================
==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}" "${win_k_cache:-'
'}"  | tr -d "'"

[ "$win_user" != "" ] || echo "
build kernel or exit?
" && \
read -r -p "(build)
" build
if [ "$build" != "" ]; then
    exit
fi
if [ -d "$linux_build_dir/.git" ]; then
    cd "$linux_build_dir" || exit
    if ! (( quick_wsl_install )); then
        git reset --hard
        git clean -fxd
    fi
    echo "checking out $linux_kernel_version_tag ..."
    # git checkout "tags/$linux_kernel_version_tag" -b "$kernel_alias" --progress
    git checkout "tags/$linux_kernel_version_tag" --progress
    cd ..
else
    echo "cloning $linux_kernel_version_tag ..."
    git clone $linux_repo --single-branch --branch "$linux_kernel_version_tag" --depth=1 --progress -- $linux_build_dir
fi
if [ "$zfs" = "zfs" ];  then
#     echo "zfs == True
# LINENO: ${LINENO}"
    if [ -d "$zfs_build_dir/.git" ]; then
        cd "$zfs_build_dir" || exit
        if ! (( quick_wsl_install )); then 
            git reset --hard
            git clean -fxd
        fi
        echo "checking out $zfs_version_tag ..."

        # git checkout "tags/$zfs_version_tag" -b "$kernel_alias" --progress
        git checkout "tags/$zfs_version_tag" --progress
        cd ..
    else
        echo "cloning $zfs_version_tag ..."
        git clone "$zfs_repo" --single-branch --branch "$zfs_version_tag" --progress -- "$zfs_build_dir" 
    fi
fi


# replace kernel source .config with the config generated from a custom config
cp -fv "$config_source" $linux_build_dir/.config

cd $linux_build_dir || exit
if (( quick_wsl_install )); then
    # prompt bypass
    yes "" | make oldconfig
    yes "" | make prepare scripts 
else
    make oldconfig
    make prepare scripts 
fi
if [ "$zfs" = "zfs" ];  then
#     echo "zfs == True
# LINENO: ${LINENO}"
    cd ../"$zfs_build_dir" || exit 
    bash autogen.sh && \
    bash configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=../$linux_build_dir --with-linux-obj=../$linux_build_dir && \
    bash copy-builtin ../$linux_build_dir && \
    yes "" | make install 
fi

cd ../$linux_build_dir || exit
if [ "$zfs" = "zfs" ];  then
    # create config variable if it does not exist
    if [ "$(grep '[# ]*CONFIG_ZFS[ =].*' .config)" = "" ]; then
        echo "CONFIG_ZFS=y" | tee --append  .config >/dev/null
    fi
#     echo "zfs == True
# LINENO: ${LINENO}"
    sed -i 's/\[# ]*CONFIG_ZFS[ =].*/CONFIG_ZFS=y/g' .config
fi
if (( quick_wsl_install )); then
    yes "" | make -j$(($(nproc) - 1))
else
    make -j$(($(nproc) - 1))
fi

echo "searching for headers matching $linux_kernel_kali_header_pattern"
echo "apt -qq search \"$linux_kernel_kali_header_pattern\" 2>/dev/null | grep -o \"^$linux_kernel_kali_header_pattern[^/]*\" | head -n 1"
linux_kernel_kali_header=$(apt -qq search "$linux_kernel_kali_header_pattern" 2>/dev/null | grep -o "^$linux_kernel_kali_header_pattern[^/]*" | head -n 1)
linux_kernel_generic_header=$(apt-cache search linux-headers-generic | grep -o "^linux-headers-[a-zA-Z0-9]*[^ -]*" | head -n 1 )
echo "linux kali header: $linux_kernel_kali_header"
echo "linux generic header: $linux_kernel_generic_header"
yes 'y' | apt -y install "$linux_kernel_kali_header" 2>/dev/null
yes 'y' | apt -y install "$linux_kernel_generic_header" 2>/dev/null

# reset kache
rm -rfv kache/boot | grep '/$' | tail -n 5
rm -rfv kache/usr | grep '/$' | tail -n 5
mkdir -pv kache/boot 2>/dev/null
mkdir -pv kache/usr/src 2>/dev/null
mkdir -pv kache/usr/include 2>/dev/null
mkdir -pv kache/usr/lib/modules 2>/dev/null
# not sure if renaming header will work so copying just to be safe for now
# mv "/usr/src/$linux_kernel_kali_header_pattern" "/usr/src/$kindtek_kernel_version"
# the following requires linux headers to be installed first in the wsl install script
kindtek_kernel_suffix="$(ls -tx1 /boot/vmlinuz-*-${kindtek_kernel_version}* | sed -r -e "s/^(.*)$kindtek_kernel_version\-?(.*)*$/\2/g"  | head -n 1)"
echo "kindtek_kernel_suffix: $kindtek_kernel_suffix"
kindtek_kernel_suffix="${kindtek_kernel_suffix%%.old}"
echo "kindtek_kernel_suffix: $kindtek_kernel_suffix"
kindtek_kernel_suffix="${kindtek_kernel_suffix:-$(echo -$kindtek_kernel_suffix)}"
echo "kindtek_kernel_suffix: $kindtek_kernel_suffix"
linux_kernel_kali_header_type=${linux_kernel_kali_header##*-}
echo "kindtek_kernel_suffix: $kindtek_kernel_suffix"
echo "linux_kernel_kali_header_type: $linux_kernel_kali_header_type"
# echo \'"$(ls -txr1 /usr/src/${linux_kernel_kali_header} | sed -r -e "s/^\/usr\/src\/$linux_kernel_kali_header(.*)$/\1/g"  | head -n 1)"\'
linux_kernel_kali="${linux_kernel_kali_header%%-$linux_kernel_kali_header_type}"
linux_kernel_kali="${linux_kernel_kali#linux-headers-}"
echo "linux_kernel_kali: $linux_kernel_kali"
cp -rfv "/usr/src/${kindtek_kernel_version}-common" "kache/usr/src/${kindtek_kernel_version}${kindtek_kernel_suffix}common" | grep '/$' | tail -n 5
cp -rfv "/usr/src/${kindtek_kernel_version}-${linux_kernel_kali_header_type}" "kache/usr/src/${kindtek_kernel_version}${kindtek_kernel_suffix}${linux_kernel_kali_header_type}" | grep '/$' | tail -n 5
orig_working_dir="$(pwd)"
rm "/usr/lib/modules/${linux_kernel_kali}-common/source"
rm "/usr/lib/modules/${linux_kernel_kali}-${linux_kernel_kali_header_type}/build"
ln -sv "/usr/lib/modules/${linux_kernel_kali}-common" "kache/usr/lib/modules/${linux_kernel_kali}-common/source" && \
ln -sv "/usr/lib/modules/${linux_kernel_kali}-${linux_kernel_kali_header_type}" "kache/usr/lib/modules/${linux_kernel_kali}-${linux_kernel_kali_header_type}/build" && \
cd "$orig_working_dir" || exit
make headers_install
make modules install
find /usr/include -type d -mmin -1 -exec cp -rfv {} kache/usr/include \; | grep '/$' | tail -n 5;


if [ ! -f "$kernel_source" ]; then
    echo "
    
Ooops. The kernel did not build. Exiting ..."
exit
fi
ps_wsl_install_kernel_id=wsl-kernel-install_$kernel_alias.ps1

cd ..
# kernel is baked - time to distribute the goods
# move back to base dir  folder with github (relative) path
mkdir -pv "$git_save_path" 2>/dev/null
# queue files to be saved to repo
# if (( $user_config_flag )); then
cp -fv --backup=numbered $linux_build_dir/.config "$config_target_git"
# fi
cp -fv --backup=numbered $linux_build_dir/"$kernel_source" "$kernel_target_git"


# remove config
rm -rfv kache/.config_*
# remove kernel
# match optional A-Z0-9, optional "rc", A-Z0-9_*
rm -rfv kache/[A-Z0-9]*(rc)*[A-Z0-9]_*
# remove empty file tag
rm -rfv kache/Linux-*
# remove install script
rm -rfv kache/wsl-kernel-install_*
# remove tar.gz file
rm -rfv kache/*.tar.gz

# copy relevant sources
cp -rfv "/boot" "kache" | tail -n 5
rm -rfv  kache/boot/*.old | tail -n 5
# cp -r -fv "/boot/*$kindtek_kernel_version*" "kache"
# cp -r -f "/usr/src" "kache"
cp -rfv /usr/src/${kindtek_kernel_version}-${kindtek_kernel_suffix}-common* "kache/usr/src" | tail -n 5
cp -rfv /usr/src/${kindtek_kernel_version}-${kindtek_kernel_suffix}-${linux_kernel_kali_header_type}* "kache/usr/src" | tail -n 5

# cp -rf /usr/lib/modules/${linux_kernel_header_version}* "kache/usr/lib/modules"
# win
# package a known working wslconfig file along with the kernel and config file
mkdir -p "$win_k_cache" 2>/dev/null
# rm -fv "$win_k_cache/wsl-kernel-install.ps1"
# rm -rfv "$win_k_cache/wsl-kernel-install_${kernel_alias_no_timestamp}*"
sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\kache\\\\\\\\${kernel_alias}/g" ../../../dvlp/mnt/HOME_WIN/head.wslconfig
cp -fv --backup=numbered ../../../dvlp/mnt/HOME_WIN/head.wslconfig kache/.wslconfig


tee "kache/$ps_wsl_install_kernel_id" >/dev/null <<EOF

#############################################################################
# ________________ WSL KERNEL INSTALLATION INSTRUCTIONS ____________________#
# --------------------- FOR CURRENT WINDOWS ACCOUNT ------------------------#
#############################################################################

#############################################################################
#####   OPTION A  ###########################################################
#####                   (works as long as files are in kache)         #####
#############################################################################
####    copy/pasta this into any windows terminal (WIN + x, i):         #####
####                                                                    #####
####    copy/pasta without '#>>' to navigate to this                    #####
####    directory and run the script from option A                      #####                                              
#                                                                       ##### 
#
# navigate to kache and execute option B script saved in this file
#>> cd kache
#>> ./$ps_wsl_install_kernel_id


####-------------------------    OR    ----------------------------------#### 


#############################################################################
#####   OPTION B  #####                                                 #####
#############################################################################
#####   copy/pasta this into any Windows terminal (WIN + x, i):         #####
#####                                                                   #####
#####   copy without '#>>' to replace (delete/move) .wslconfig          #####

    \$kernel_alias="$kernel_alias"

    if (\$IsLinux -eq \$false) {

        cd "\$env:USERPROFILE/kache"

    }

    \$win_user=\$env:USERNAME

    if ("\$(\$args[0])" -ne ""){
        \$win_user=\$args[0]
    }

#
#   # delete
#>> del ..\\.wslconfig -Force -verbose;
#
    echo "backing up old .wslconfig"
    # move file out of the way   
    move ..\\.wslconfig ..\\.wslconfig.old -Force -verbose;
    
    echo "extracting $package_full_name_id.tar.gz ..."
    # extract
    tar -xzf $package_full_name_id.tar.gz

    echo "appending tail.wslconfig to .wslconfig"
    # append tail.wslconfig to .wslconfig
    Add-Content "" -Path "tail.wslconfig" -NoNewLine
    if (Test-Path -Path tail.wslconfig -PathType Leaf) {
        Get-Content "tail.wslconfig" | Add-Content -Path ".wslconfig"
    }
    # copy file
    echo "installing new .wslconfig and kernel \$kernel_alias"
    copy .wslconfig ..\\.wslconfig -verbose;
    copy boot\\vmlinuz* \$kernel_alias -verbose
    # restart wsl
    if ("\$(\$args[1])" -ne ""){
        if ("\$(\$args[1])" -ne "restart"){
            echo "installing kernel to \$(\$args[1]) distro ..."
            wsl.exe -d "\$(\$args[1])" --exec sudo cp -rfv "/mnt/c/users/\$env:USERNAME/kache/boot" / | tail -n 5
            echo "installing kernel modules to \$(\$args[1]) distro ..."
            wsl.exe --exec sudo cp -rfv "/mnt/c/users/\$env:USERNAME/kache/usr/src/${kindtek_kernel_version}${kindtek_kernel_suffix}*" / | tail -n 5
            wsl.exe -d "\$(\$args[1])" --exec sudo cp -rfv "/mnt/c/users/\$env:USERNAME/kache/usr/src/includes" / | tail -n 5
            wsl.exe -d "\$(\$args[1])" --exec sudo cp -rfv "/mnt/c/users/\$env:USERNAME/kache/usr/lib/modules*" / | tail -n 5
            # order is important here for installing kernel headers
            wsl.exe -d "\$(\$args[1])" --exec sudo yes 'y' | apt -y install "$linux_kernel_generic_header" 2>/dev/null
            wsl.exe -d "\$(\$args[1])" --exec sudo yes 'y' | apt -y install "$linux_kernel_kali_header" 2>/dev/null
        } elseif ("\$(\$args[1])" -eq "restart"){
            # restart wsl
            # pwsh -Command .\\wsl-restart.ps1;
            # Start-Process -FilePath powershell.exe -ArgumentList "-Command .\\wsl-restart.ps1"
            .\\wsl-restart.ps1;
            exit
        } 
        if ("\$(\$args[2])" -eq "restart"){
            # pwsh -Command .\\wsl-restart.ps1;
            # Start-Process -FilePath powershell.exe -ArgumentList "-Command .\\wsl-restart.ps1"
            .\\wsl-restart.ps1;
            exit
        }
    } else {
            echo "installing kernel to default distro ..."
            wsl.exe --exec sudo cp -rfv "/mnt/c/users/\$env:USERNAME/kache/boot" / | tail -n 5
            echo "installing kernel modules to default distro ..."
            wsl.exe --exec sudo cp -rfv "/mnt/c/users/\$env:USERNAME/kache/usr/src/${kindtek_kernel_version}${kindtek_kernel_suffix}*" / | tail -n 5
            wsl.exe --exec sudo cp -rfv "/mnt/c/users/\$env:USERNAME/kache/usr/src/includes" / | tail -n 5
            wsl.exe --exec sudo cp -rfv "/mnt/c/users/\$env:USERNAME/kache/usr/lib/modules*" / | tail -n 5
            # order is important here for installing kernel headers
            wsl.exe -d "\$(\$args[1])" --exec sudo yes 'y' | apt -y install "$linux_kernel_generic_header" 2>/dev/null
            wsl.exe -d "\$(\$args[1])" --exec sudo yes 'y' | apt -y install "$linux_kernel_kali_header" 2>/dev/null
            exit
    }




#############################################################################

EOF

tar -czvf "$tarball_filename" -C kache . | tail -n 5
mv -fv "$tarball_filename" "kache/$tarball_filename" | tail -n 5
# cp "kache/$tarball_filename" kache/latest.tar.gz
# work on *nix first
mkdir -pv "$nix_k_cache" 2>/dev/null

if [ -w "$nix_k_cache" ]; then
    # tar -czvf "kache/$tarball_filename" -C kache kache
    cp -fv "kache/$tarball_filename" "$tarball_target_nix" 
else
    echo "unable to save kernel package to Linux home directory"
fi
# now win
mkdir -pv "$win_k_cache" 2>/dev/null
# if win_k_cache is writable and no timestamp was given in args
if [ -w "$win_k_cache" ] && [ "$5" = "" ]; then
    echo "copying kernel to WSL install location"
    cp -fv "kache/$ps_wsl_install_kernel_id" "$win_k_cache/$ps_wsl_install_kernel_id"
    if [ "$tarball_target_win" != "" ]; then
        echo "copying tarball to WSL kache"
        # cp -fv --backup=numbered "$tarball_filename" "$tarball_target_win.bak"
        cp -fv "kache/$tarball_filename" "$tarball_target_win"
    else 
        echo "win tarball empty: $tarball_target_win"
    fi
else 
    echo "not saving to windows home directory"
fi


echo "

KERNEL BUILD COMPLETE

"


[ "$win_k_cache" = "" ] && printf "



==================================================================
========================   Linux Kernel   ========================
======------------------%s%s------------------======
------------------------------------------------------------------
====-------------------     Output Info    -------------------====
------------------------------------------------------------------

  Kernel:
    $kernel_target_git

  Config:
    $config_target_git
    
  Kernel/Config/Installation/.tar.gz files:
    $nix_k_cache
    %s     

==================================================================
==================================================================
==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}" "${win_k_cache:-'
'}"  | tr -d "'" || printf "



==================================================================
========================   Linux Kernel   ========================
======------------------%s%s------------------======
------------------------------------------------------------------
====-----------------    Install Locations    ----------------====
------------------------------------------------------------------

.wslconfig:
    $wsl_config

kernel:
    $wsl_kernel     

==================================================================
==================================================================
==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}"
