#!/bin/bash
timestamp_id=$(date -d "today" +"%Y%m%d%H%M%S")
user_config_flag=False
kernel_type=$1
config_source=$2
zfs=$3
win_user=${4:-'user'}
quick_wsl_install=${4:+True}
# interact=False
# interact=${5:+True}
# kernel_file_suffix=''
# config_file_suffix=''
# linux_kernel_version="5.15.90.1"
# zfs_version="2.1.11"
kernel_file_suffix="W"
# config_file_suffix="_wsl"
linux_build_dir=linux-build
# if [ "$zfs" = "zfs" ];  then
#     echo "zfs == True
# LINENO: ${LINENO}"
# elif ! (( $zfs )); then
#     echo "zfs == False
# LINENO: ${LINENO}"
# else 
#     echo "zfs === $zfs
# LINENO: ${LINENO}"
# fi

if [ "$zfs" = "zfs" ];  then
    zfs_build_dir="zfs-build"
    zfs_repo=https://github.com/openzfs/zfs.git
    zfs_version_query="git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $zfs_repo"
    zfs_version_tag=$($zfs_version_query | tail --lines=1 | cut --delimiter='/' --fields=3)
    zfs_version=${zfs_version_tag#"zfs-"}
    linux_kernel_type_tag=$linux_kernel_type_tag-ZFS
    kernel_file_suffix+="Z"
fi
if [ "$kernel_type" = "" ]; then
    kernel_type="stable"
fi
if [ "$kernel_type" = "latest" ]; then
    # zfs not supported atm
    zfs=False; linux_kernel_type_tag=;
    linux_build_dir=linux-build-torvalds
    linux_repo=https://github.com/torvalds/linux.git
    linux_version_query="git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="LATEST-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
    kernel_file_suffix+="L"
    # config_file_suffix+="_latest"
elif [ "$kernel_type" = "latest-rc" ]; then
    # zfs not supported atm
    zfs=False; linux_kernel_type_tag=;
    linux_build_dir=linux-build-torvalds
    kernel_file_suffix+="R"
    # config_file_suffix+="_rc"
    linux_repo=https://github.com/torvalds/linux.git
    linux_version_query="git ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="LATEST_RC-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
elif [ "$kernel_type" = "stable" ]; then
    # latest tag doesn't work properly with zfs so manually update for zfs version possibly compatible with 6.2.9+
    # update: it did not work
    # zfs_version=2.1.11
    # zfs_version_tag=zfs-$zfs_version
    zfs=False; linux_kernel_type_tag=;
    linux_build_dir=linux-build-gregkh
    kernel_file_suffix+="S"
    # config_file_suffix+="_stable"
    linux_repo=https://github.com/gregkh/linux.git
    # linux_version_query="git ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_version_query="git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | grep -v -e "-rc[0-9]\+$" | tail --lines=1 | cut --delimiter='/' --fields=3) 
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
    linux_version_query="git -c versionsort.suffix=+ ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | grep -v -e "-rc[0-9]\+$" | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="BASIC-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"linux-msft-wsl"}
    linux_kernel_version=${linux_kernel_version_tag%".y"}
    # manually set version due to known bug that breaks 5.15 build with werror: pointer may be used after 'realloc' [-Werror=use-after-free] https://gcc.gnu.org/bugzilla/show_bug.cgi?id=104069
    linux_kernel_version_tag=linux-msft-wsl-6.1.y
    linux_kernel_version=6.1

fi
# if [ "$zfs" = "zfs" ];  then
# #     echo "zfs == True
# # LINENO: ${LINENO}"
#     # config_file_suffix+="-zfs"
# fi

package_full_name=Linux-$linux_kernel_version-$linux_kernel_type_tag
package_full_name_id=Linux-$linux_kernel_version-$linux_kernel_type_tag-$timestamp_id

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
    echo -n "$package_full_name"
    exit
fi
    echo "home: $HOME"
    echo "zfs version tag:$zfs_version_tag"
    echo "zfs version:$zfs_version"
    echo "linux version query: $linux_version_query"
    echo "linux version tag:$linux_kernel_version_tag"
    echo "linux version:$linux_kernel_version"
    echo "linux version type:$linux_kernel_type_tag"

# deduce architecture of this machine
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"
# shorten common vendor names
if [ "$cpu_vendor" = AuthenticAMD ]; then cpu_vendor=amd; fi
if [ "$cpu_vendor" = GenuineIntel ]; then cpu_vendor=intel; fi
linux_kernel_version_mask=${linux_kernel_version/\./_}
kernel_alias_no_timestamp=${linux_kernel_version/\./L}
linux_kernel_version_mask=${linux_kernel_version_mask//[\.-]/}
kernel_alias_no_timestamp=${kernel_alias_no_timestamp//[\.-]/}${kernel_file_suffix}
kernel_alias=${kernel_alias_no_timestamp}_${timestamp_id}
config_alias=.config_${kernel_alias}
config_alias_no_timestamp=.config_${kernel_alias_no_timestamp}
git_save_path=$cpu_arch/$cpu_vendor/$linux_kernel_version_mask
nix_k_cache=$HOME/k-cache

# check that the user supplied source exists if not try to pick the best .config file available
# user choice is best if it exists
if [ "$config_source" != "" ] && [ -r "$config_source" ] && [ -s "$config_source" ]; then
    echo "config: $config_source
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    "
    user_config_flag=True
else
# try alternates if user config doesn't work 
    # download reliable .config
echo "
searching for a saved config file at $git_save_path/$config_alias_no_timestamp
"
    if ! [ -r "$git_save_path/$config_alias_no_timestamp" ]; then
        generic_config_source=https://raw.githubusercontent.com/microsoft/WSL2-Linux-Kernel/linux-msft-wsl-5.15.y/Microsoft/config-wsl
echo "

























No saved .config files match this kernel version and platform"
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

    Hint: to use a file on Github make sure to use a raw file url starting with https://raw.githubusercontent.com
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
                wget "$config_source"
                config_source=$( echo "$config_source" | cut --delimiter='/' --fields=1 )
                # config_source=${pwd}/$( echo $config_source | sed -r -e 's/^([A-Za-z0-9-_/:])*\/([A-Za-z0-9-_/])+$/\2/g' )
            else 
                echo "not a url"
            fi
        else
            echo "not a url"
        fi
    fi
    if [ -r "$config_source" ]; then 
        # config_source=$generic_config_source
        echo "config $config_source appears to be valid"
    else    
        echo "could not read $config_source
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

if (( quick_wsl_install )); then
    echo "install kernel when finished?
"
[ "$win_user" != "" ] || read -r -p "(y)
" wsl_install
    if [ "$wsl_install" = "" ]; then
        wsl_install="y"
    fi
    if [ "${wsl_install,,}" = "y" ] || [ "${wsl_install,,}" = "yes" ]; then
        wsl_install="y"
        quick_wsl_install=True
    else
        quick_wsl_install=False
    fi    
else
[ "$win_user" != "" ] || echo "
install the kernel into WSL when build is finished?
"
[ "$win_user" != "" ] || read -r -p "(n)
" wsl_install
    if [ "${wsl_install,,}" = "y" ] || [ "${wsl_install,,}" = "yes" ]; then
        wsl_install="y"
        save_or_wsl_install_mask=install
        if [ "$4" = "" ]; then win_user=""; fi
        wsl_install="y" && \
echo "










    "
echo " 


install to which Windows home directory?

    choose from:
" 
        ls -da /mnt/c/users/*/ | tail -n +4 | sed -r -e 's/^\/mnt\/c\/users\/([ A-Za-z0-9]*)*\/+$/\t\1/g'

        if [ "$win_user" != "" ]; then
            win_user_orig=$win_user
echo "
    C:\\users\\__________ 

install kernel in C:\\users\\$win_user ?
            "
[ "$win_user" != "" ] || read -r -p "(continue)
" win_user 
        else
echo "
    C:\\users\\__________ 
"
[ "$win_user" != "" ] || read -r -p "(skip)
" win_user 
        fi
        if [ "$win_user" = "" ]; then
            win_user=${win_user_orig}
        # else 
        #     # if the user tries inputting a path name take everything to the right of the last \
        #     # win_user=$(echo $win_user | sed -E 's/^\s*([A-Za-z0-9]:?\\*)([A-Za-z0-9]*\\)*([A-Za-z0-9]+)+$/\3/g')        
        #     # win_user=$(echo $win_user | sed -E 's/^\s*([A-Za-z0-9]:?\\*)([A-Za-z0-9]*\\?\\?)*([A-Za-z0-9]+)+$/\3/g')
        else
            win_user=$(echo "$win_user" | cut --delimiter='/' --fields=1)
        fi 
    else 
        save_or_wsl_install_mask=save 
        if [ "$4" = "" ]; then 
            win_user=""
echo "










"
echo " 


save kernel package to Windows home directory C:\\users\\__________

    choose from:
" 
        ls -da /mnt/c/users/*/ | tail -n +4 | sed -r -e 's/^\/mnt\/c\/users\/([ A-Za-z0-9]*)*\/+$/\t\1/g'

        else
            [ "$win_user" != "" ] || echo "${save_or_wsl_install_mask} kernel files to C:\\users\\$win_user ?
            "
        fi
[ "$win_user" != "" ] || read -r -p "(${save_or_wsl_install_mask})
" win_user
        if [ "$4" != "" ] && [ "$4" != "docker" ] && [ -w "/mnt/c/users/$4" ]; then
            win_user=${4}
        # else 
        #     # if the user tries inputting a path name take everything to the right of the last \
        #     # win_user=$(echo $win_user | sed -E 's/^\s*([A-Za-z0-9]:?\\*)([A-Za-z0-9]*\\)*([A-Za-z0-9]+)+$/\3/g')        
        #     # win_user=$(echo $win_user | sed -E 's/^\s*([A-Za-z0-9]:?\\*)([A-Za-z0-9]*\\?\\?)*([A-Za-z0-9]+)+$/\3/g')
        else
            win_user=$(echo "$win_user" | cut --delimiter='/' --fields=1)
        fi
    fi
    # if [ "$wsl_install" = "y" ] || [ "${wsl_install,,}" = "yes" ]; then
    
    if [ "$win_user" != "" ] && [ -w "/mnt/c/users/$win_user" ] || \
    [ "$win_user" != "" ]; then
        
[ "$win_user" != "" ] || echo "
kernel package will be ${save_or_wsl_install_mask}ed to C:\\users\\$win_user
archives and recovery scripts will be saved to C:\\users\\$win_user\\k-cache
"  
[ "$win_user" != "" ] || read -r -p "
(continue)
" 
    else
echo "
Oooops - C:\\users\\$win_user is an invalid save location
package will not be saved to Windows home directory ...

        "
        sleep 2
        echo ""
        sleep 1
        echo ""
        sleep 1
        echo ""
    fi
fi

win_k_cache=/mnt/c/users/$win_user/k-cache
kernel_source=arch/$cpu_arch/boot/bzImage
kernel_target_git=$git_save_path/$kernel_alias_no_timestamp
config_target_git=$git_save_path/$config_alias_no_timestamp
# kernel_target_nix=$nix_k_cache/$kernel_alias
# config_target_nix=$nix_k_cache/$config_alias
# kernel_target_win=$win_k_cache/$kernel_alias
# config_target_win=$win_k_cache/$config_alias
tarball_target_nix=$nix_k_cache/$package_full_name.tar.gz
tarball_target_win=$win_k_cache/$package_full_name.tar.gz
tarball_filename=$package_full_name_id.tar.gz

if [ "$linux_kernel_version" = "" ]; then
echo "

    Sorry. Cannot continue. Exiting ...

    Error: LINUX_KERNEL_VERSION_NOT_FOUND

    "
fi
padding="----------"

if [ ! -w "/mnt/c/users/$win_user" ]; then
    tarball_target_win=""
fi
[ "$win_user" != "" ] || printf "



==================================================================
========================   Linux Kernel   ========================
======------------------%s%s------------------======
------------------------------------------------------------------
====-------------------     Output Info    -------------------====
------------------------------------------------------------------

  Kernel:
    $kernel_target_git

  Compressed Kernel/Config:
    $tarball_target_nix
    %s      
==================================================================
==================================================================
==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}" "$tarball_target_win
"

echo "
build kernel or exit?
"
[ "$win_user" != "" ] || read -r -p "(build)
" continue
if [ "$continue" != "" ]; then
    exit
fi
if [ -d "$linux_build_dir/.git" ]; then
    cd "$linux_build_dir" || exit
    if ! (( quick_wsl_install )); then
        git reset --hard
        git clean -fxd
    fi
    echo "checking out $linux_kernel_version_tag ..."
    git checkout "$linux_kernel_version_tag" --progress
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
        git checkout "$zfs_version_tag" --progress
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
#     echo "zfs == True
# LINENO: ${LINENO}"
    sed -i 's/\# CONFIG_ZFS is not set/CONFIG_ZFS=y/g' .config
fi
if (( quick_wsl_install )); then
    yes "" | make -j "$(expr "$(nproc)" - 1)"
else
    make -j "$(expr "$(nproc)" - 1)"
fi
make modules install
# kernel is baked - time to distribute fresh copies
if [ ! -f "$kernel_source" ]; then
    echo "
    
Ooops. The kernel did not build. Exiting ..."
exit
fi
ps_wsl_install_kernel_id=wsl-kernel-install_$kernel_alias.ps1

cd ..
# move back to base dir  folder with github (relative) path
mkdir -pv "$git_save_path" 2>/dev/null
# queue files to be saved to repo
# if (( $user_config_flag )); then
    cp -fv --backup=numbered $linux_build_dir/.config "$config_target_git"
# fi
cp -fv --backup=numbered $linux_build_dir/"$kernel_source" "$kernel_target_git"


# build/move tar with version control if [tar]get directory is writeable
# save copies in timestamped dir to keep organized
mkdir -pv k-cache 2>/dev/null
# remove config
rm -rfv k-cache/.config_*
# remove kernel
rm -rfv k-cache/*_*
# remove empty file tag
rm -rfv k-cache/Linux-*
# remove wsl install ps file
rm -rfv k-cache/wsl-kernel-install*
# remove tarball
rm -rfv k-cache/*.tar.gz
cp -fv --backup=numbered  "$config_source" "k-cache/$config_alias"
cp -fv --backup=numbered  "$linux_build_dir/$kernel_source" "k-cache/$kernel_alias"
# touch "k-cache/$package_full_name"

# win
# package a known working wslconfig file along with the kernel and config file
mkdir -p "$win_k_cache" 2>/dev/null
# rm -fv "$win_k_cache/wsl-kernel-install.ps1"
# rm -rfv "$win_k_cache/wsl-kernel-install_${kernel_alias_no_timestamp}*"
sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\${kernel_alias}/g" ../../../dvlp/mnt/%HOME%/sample.wslconfig
cp -fv --backup=numbered ../../../dvlp/mnt/%HOME%/sample.wslconfig k-cache/.wslconfig

echo "
try {
    # first check OS to use relevant powershell/wsl calls later
    switch (Get-PSPlatform) {
        'Win32NT' { 
            New-Variable -Option Constant -Name win_os -Value \$True -ErrorAction SilentlyContinue
            New-Variable -Option Constant -Name nix_os  -Value \$False -ErrorAction SilentlyContinue
            New-Variable -Option Constant -Name mac_os  -Value \$False -ErrorAction SilentlyContinue
        }
    }
} catch {}

#############################################################################
# ________________ WSL KERNEL INSTALLATION INSTRUCTIONS ____________________#
# --------------------- FOR CURRENT WINDOWS ACCOUNT ------------------------#
#############################################################################

#############################################################################
#####   OPTION A  #####                                                 #####
#############################################################################
#####   copy/pasta this into any Windows terminal (WIN + x, i):         #####
####                                                                    #####
#####   copy without '#>>' to replace (delete/move) .wslconfig          #####

if (\$win_os) {

#
#   # delete
#>> powershell.exe -Command del ..\\.wslconfig -Force -verbose;
#
#   # move file out of the way   
    powershell.exe -Command move ..\\.wslconfig ..\\.wslconfig.old -Force -verbose;
    
    # extract
    wsl.exe exec tar -xvzf $package_full_name_id.tar.gz

    # copy file
    powershell.exe -Command copy .wslconfig ..\\.wslconfig -verbose;
    # restart wsl
    powershell.exe -Command .\\wsl-restart.ps1;

}
elseif (\$nix_os) {

#
#   # delete
#>> pwsh -Command del ..\\.wslconfig -Force -verbose;
#
#   # move file out of the way   
    pwsh -Command move ..\\.wslconfig ..\\.wslconfig.old -Force -verbose;
    
    # extract
    wsl exec tar -xvzf $package_full_name_id.tar.gz

    # copy file
    pwsh -Command copy .wslconfig ..\\.wslconfig -verbose;
    # restart wsl
    pwsh -Command .\\wsl-restart.ps1;

}

#############################################################################

####-------------------------    OR    ----------------------------------#### 

#############################################################################
#####   OPTION B  #####                                                 #####
#############################################################################
####    copy/pasta this into any windows terminal (WIN + x, i):         #####
####                                                                    #####
####    copy/pasta without '#>>' to navigate to this                    #####
####    directory and run the script from option A                      #####                                              ##### 
#
#
#   # execute option A script saved in this file
#>> ./$ps_wsl_install_kernel_id

#############################################################################
" | tee "k-cache/$ps_wsl_install_kernel_id"
# rm "k-cache/$tarball_filename"
tar -czvf "k-cache/$tarball_filename" -C k-cache .
cp "k-cache/$tarball_filename" k-cache/latest.tar.gz
# work on *nix first
mkdir -pv "$nix_k_cache" 2>/dev/null
if [ -w "$nix_k_cache" ]; then
    # tar -czvf "k-cache/$tarball_filename" -C k-cache k-cache
    cp -fv "k-cache/$tarball_filename" "$tarball_target_nix" 
else
    echo "unable to save kernel package to Linux home directory"
fi
# now win
mkdir -pv "$win_k_cache" 2>/dev/null
if [ "$win_user" != "docker" ] && [ -w "$win_k_cache" ]; then
    cp "k-cache/$ps_wsl_install_kernel_id" "$win_k_cache/$ps_wsl_install_kernel_id"
    if [ "$tarball_target_win" != "" ]; then
        # cp -fv --backup=numbered "$tarball_filename" "$tarball_target_win.bak"
        cp -fv "$tarball_filename" "$tarball_target_win"
    fi
elif [ "$win_user" != "docker" ]; then
    echo "
unable to save kernel package to Windows home directory"
fi
win_user_home=/mnt/c/users/$win_user
wsl_kernel=${win_user_home}/${kernel_alias}
wsl_config=${win_user_home}/.wslconfig
if (( quick_wsl_install )); then
    # copy kernel and wsl config right away
    cp -vf "k-cache/$kernel_alias" "$wsl_kernel" 
    mv -vf --backup=numbered "$wsl_config" "$wsl_config.old"
    sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\k-cache\\\\\\\\${kernel_alias}/g" k-cache/.wslconfig           
    cp -vf k-cache/.wslconfig "$wsl_config"  
elif [ "$wsl_install" = "y" ] || [ "$wsl_install" = "yes" ]; then

printf "



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
echo "
install or exit?
"
[ "$win_user" != "" ] || read -r -p "(install $package_full_name into $WSL_DISTRO_NAME WSL)
" install_wsl_kernel
    if [ "$install_wsl_kernel" = "" ]; then
        win_user_home=/mnt/c/users/$win_user && \
        cp -vf "k-cache/${kernel_alias}" "$wsl_kernel"
        quick_wsl_install=True
        if [ -f "$wsl_config" ]; then
echo "









            
.wslconfig found in $win_user_home

replacing this with a pre-configured .wslconfig is *HIGHLY* recommended
a backup of the original file will be saved as:

    $wsl_config.old

continue with .wslconfig replacement?
"
[ "$win_user" != "" ] || read -r -p "(y)
" replace_wslconfig
            if [ "${replace_wslconfig,,}" = "n" ] || [ "${replace_wslconfig,,}" = "no" ]; then
                if grep -q '^\s?\#?\skernel=.*' "$wsl_config"; then
                    sed -i "s/\s*\#*\s*kernel=C.*/kernel=C\\\\\\\\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\k-cache\\\\\\\\${kernel_alias}/g" "$wsl_config"
                else
                    wslconfig_old="$(cat "$wsl_config")"
                    wslconfig_new="
[wsl2]

kernel=C\:\\\\users\\\\$win_user\\\\${kernel_alias}
$(cat "$wslconfig_old")"
                    echo "$wslconfig_new" > "$wsl_config"
                fi
            else
                mv -vf --backup=numbered "$wsl_config" "$wsl_config.old"
                sed -i "s/\s*\#*\s*kernel=.*/kernel=C\\\\\\\\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\k-cache\\\\\\\\${kernel_alias}/g" k-cache/.wslconfig           
                cp -vf k-cache/.wslconfig "$wsl_config"  
            fi
        else
            mv -vf --backup=numbered "$wsl_config" "$wsl_config.old"
            sed -i "s/\s*\#*\s*kernel=.*/kernel=C\\\\\\\\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\k-cache\\\\\\\\${kernel_alias}/g" k-cache/.wslconfig           
            cp -vf k-cache/.wslconfig "$wsl_config"          
        fi
    fi
fi

echo "





KERNEL BUILD COMPLETE

"

if (( quick_wsl_install )) || [ "${wsl_install,,}" = "y" ] || [ "${wsl_install,,}" = "yes" ]; then
[ "$win_user" != "" ] || read -r -p "(see kernel install instructions)
"
echo "


WSL KERNEL INSTALL
-------------------------

open a windows terminal to home directory (WIN + x, i) and copy/pasta:

    ./k-cache/wsl-install-$kernel_alias
"
[ "$win_user" != "" ] || read -r -p "(see WSL recovery instructions)
"
old_kernel=$(sed -nr "s/^\s*\#*\s*kernel=(.*)\\\\\\\\([A-Za-z0-9_-]+)$/\2/p" "$wsl_config")
if [ "$old_kernel" != "" ]; then
    echo "


WSL ROLLBACK INSTRUCTIONS
-------------------------

open a windows terminal to home directory (WIN + x, i) and copy/pasta:

    ./k-cache/wsl-install-$old_kernel
"
else 
    echo "


WSL ROLLBACK INSTRUCTIONS
-------------------------

open a windows terminal to home directory (WIN + x, i) and copy/pasta:

    move .wslconfig.old .wslconfig.new
    move .wslconfig .wslconfig.old
    move .wslconfig.new .wslconfig

"    
fi
[ "$win_user" != "" ] || read -r -p "(see WSL reboot instructions)
"
echo "


WSL REBOOT INSTRUCTIONS
-----------------------

open a windows terminal to home directory (WIN + x, i) and copy/pasta:

    ./k-cache/wsl-restart
"


[ "$win_user" != "" ] || echo "
install kernel $kernel_alias?
"
[ "$win_user" != "" ] || read -r -p "
(open install tool)" install_kernel

[ "$win_user" != "" ] || if [ "$install_kernel" = "" ]; then
    bash install-kernel.sh "$win_user" "$kernel_alias_no_timestamp" "$timestamp_id"
fi


    
fi

# else
#     echo "quick_wsl_install == $quick_install"
# fi
# cp -fv --backup=numbered $kernel_source $kernel_target_nix
# cp -fv --backup=numbered .config $nix_k_cache/$config_alias

# if [ -d "$win_k_cache" ]; then cp -fv --backup=numbered  $kernel_source $win_k_cache/$config_alias; fi
# if [ -d "$win_k_cache" ]; then cp -fv --backup=numbered  $kernel_source $win_k_cache/$kernel_alias; fi


# cleanup
# rm -rf k-cache/*
# rm -rf $linux_build_dir
# rm -rf $temp_dir

