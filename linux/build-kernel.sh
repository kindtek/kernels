#!/bin/bash
user_config_flag=False
user_entry_flag=False
kernel_type=$1
config_source=$2
zfs=${3:+True:-False}
win_user=${4:-'user'}
quick_install=${4:+True}
# interact=False
# interact=${5:+True}
# kernel_file_suffix=''
# config_file_suffix=''
# linux_kernel_version="5.15.90.1"
# zfs_version="2.1.11"
kernel_file_suffix="W"
config_file_suffix="_wsl"
linux_build_dir=linux-build
if [ $zfs = True ]; then
    echo "zfs == True
LINENO: ${LINENO}"
elif [ $zfs = False ]; then
    echo "zfs == False
LINENO: ${LINENO}"
else 
    echo "zfs === $zfs
LINENO: ${LINENO}"
fi

if [ $zfs ]; then
    zfs_build_dir=zfs-build
    zfs_repo=https://github.com/openzfs/zfs.git
    zfs_version_query="git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $zfs_repo"
    zfs_version_tag=$($zfs_version_query | tail --lines=1 | cut --delimiter='/' --fields=3)
    zfs_version=${zfs_version_tag#"zfs-"}
    linux_kernel_type_tag=$linux_kernel_type_tag-ZFS
    echo "zfs version tag:$zfs_version_tag"
    echo "zfs version:$zfs_version"
fi
if [ "$kernel_type" = "" ]; then
    kernel_type="stable"
fi
if [ "$kernel_type" = "latest" ]; then
    # zfs not supported atm
    zfs=False
    linux_build_dir=linux-build-torvalds
    linux_repo=https://github.com/torvalds/linux.git
    linux_version_query="git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="LATEST-WSL"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
    kernel_file_suffix+="L"
    config_file_suffix+="_latest"
    echo "linux version tag:$linux_kernel_version_tag"
    echo "linux version:$linux_kernel_version"
    echo "linux version tag:$linux_kernel_type_tag"
elif [ "$kernel_type" = "latest-rc" ]; then
    # zfs not supported atm
    zfs=False
    linux_build_dir=linux-build-torvalds
    kernel_file_suffix+="R"
    config_file_suffix+="_rc"
    linux_repo=https://github.com/torvalds/linux.git
    linux_version_query="git ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="LATEST_RC-WSL"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
    echo "linux version tag:$linux_kernel_version_tag"
    echo "linux version:$linux_kernel_version"
    echo "linux version tag:$linux_kernel_type_tag"
elif [ "$kernel_type" = "stable" ]; then
    # latest tag doesn't work properly with zfs so manually update for zfs version possibly compatible with 6.2.9+
    # update: it did not work
    # zfs_version=2.1.11
    # zfs_version_tag=zfs-$zfs_version
    zfs=False
    linux_build_dir=linux-build-gregkh
    kernel_file_suffix+="S"
    config_file_suffix+="_stable"
    linux_repo=https://github.com/gregkh/linux.git
    # linux_version_query="git ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_version_query="git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | grep -v -e "-rc[0-9]\+$" | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="STABLE-WSL"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
    echo "linux version query: $linux_version_query"
    echo "linux version tag:$linux_kernel_version_tag"
    echo "linux version:$linux_kernel_version"
    echo "linux kernel type:$linux_kernel_type_tag"
# elif [ "$kernel_type"="basic" ]; then
else 
    # latest tag doesn't work properly with zfs so manually update for zfs version compatible with 5.5.3+
    zfs_version=2.1.11
    zfs_version_tag=zfs-$zfs_version
    kernel_file_suffix+="B"
    config_file_suffix+="_basic"
    linux_build_dir=linux-build-msft
    linux_repo=https://github.com/microsoft/WSL2-Linux-Kernel.git
    linux_version_query="git -c versionsort.suffix=+ ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | grep -v -e "-rc[0-9]\+$" | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="BASIC-WSL"
    linux_kernel_version=${linux_kernel_version_tag#"linux-msft-wsl"}
    linux_kernel_version=${linux_kernel_version_tag%".y"}
    echo "linux version tag:$linux_kernel_version_tag"
    echo "linux version:$linux_kernel_version"
    echo "linux version type:$linux_kernel_type_tag"
fi
if [ $zfs ]; then
    echo "zfs == True
LINENO: ${LINENO}"
    echo "zfs version tag:$zfs_version_tag"
    echo "zfs version:$zfs_version"
    kernel_file_suffix+="Z"
    config_file_suffix+="-zfs"
fi
config_file_suffix+="0"
kernel_file_suffix+="0"
timestamp_id=$(date -d "today" +"%Y%m%d%H%M%S")
# deduce architecture of this machine
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"
# shorten common vendor names
if [ "$cpu_vendor" = AuthenticAMD ]; then cpu_vendor=amd; fi
if [ "$cpu_vendor" = GenuineIntel ]; then cpu_vendor=intel; fi
linux_kernel_version_mask=${linux_kernel_version/\./_}
kernel_alias=${linux_kernel_version/\./L}
linux_kernel_version_mask=${linux_kernel_version_mask//[\.-]/}
kernel_alias=${kernel_alias//[\.-]/}${kernel_file_suffix}
package_alias=linux-$linux_kernel_version_mask
package_full_name=Linux-$linux_kernel_version-$linux_kernel_type_tag
config_alias=.config_${kernel_alias}${config_file_suffix}
git_save_path=$cpu_arch/$cpu_vendor/$linux_kernel_version_mask
nix_save_path=$HOME/k-cache

# check that the user supplied source exists if not try to pick the best .config file available
# user choice is best if it exists
if [ ! "$config_source" = "" ] && [ -r "$config_source" ] && [ -s "$config_source" ]; then
    echo "config: $config_source"
    user_config_flag=True
else
# try alternates if user config doesn't work 
    if [ ! -r "config-wsl" ]; then
        wget https://raw.githubusercontent.com/microsoft/WSL2-Linux-Kernel/linux-msft-wsl-5.15.y/Microsoft/config-wsl
    fi
    # reliable but the least desirable .. keep looking
    if [ -r "config-wsl" ]; then 
        config_source=config-wsl
    fi
    # generic - slightly better
    if [ -r "$cpu_arch/generic/$linux_kernel_version_mask/$config_alias" ]; then 
        config_source=$cpu_arch/generic/$linux_kernel_version_mask/$config_alias
    fi
    # specific arch - best alternate 
    if [ -r "$git_save_path/$config_alias" ]; then
        config_source=$git_save_path/$config_alias
    fi
fi

padding="----------"
# display info while waiting on repo to clone
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

======================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}"

if [ $quick_install ]; then
    echo " press ENTER to install kernel when finished
"
    read install
    if [ "$install" = "" ]; then
        install="y"
        quick_install=True
    else
        quick_install=False
    fi    
else
    echo "
install kernel when finished?
y/(n)"
    read install
    if [ "$install" != "" ] && ( [ "$install" = "y" ] || [ "$install" = "Y" ]  ) ; then
        install="y" && \
        echo "
enter the name of your windows home directory 
                    
                    - OR -

press ENTER to confirm save location as C:\\\\users\\$win_user" && \
        win_user_orig=$win_user && \
        read win_user
        if [ "$win_user" = "" ]; then
            win_user=$win_user_orig
        # else 
        #     # if the user tries inputting a path name take everything to the right of the last \
        #     # win_user=$(echo $win_user | sed -E 's/^\s*([A-Za-z0-9]:?\\*)([A-Za-z0-9]*\\)*([A-Za-z0-9]+)+$/\3/g')        
        #     # win_user=$(echo $win_user | sed -E 's/^\s*([A-Za-z0-9]:?\\*)([A-Za-z0-9]*\\?\\?)*([A-Za-z0-9]+)+$/\3/g')
        fi
    fi
fi

win_save_path=/mnt/c/users/$win_user/k-cache
kernel_source=arch/$cpu_arch/boot/bzImage
kernel_target_git=$git_save_path/$kernel_alias
config_target_git=$git_save_path/$config_alias
kernel_target_nix=$nix_save_path/$kernel_alias
config_target_nix=$nix_save_path/$config_alias
kernel_target_win=$win_save_path/$kernel_alias
config_target_win=$win_save_path/$config_alias
tarball_target_nix=$nix_save_path/$package_full_name.tar.gz
tarball_target_win=$win_save_path/$package_full_name.tar.gz
tarball_source_nix=$package_full_name.tar.gz
tarball_source_win=$package_full_name.tar.gz

if [ "$linux_kernel_version" = "" ]; then
    echo "

    Sorry. Cannot continue. Exiting ...

    Error: LINUX_KERNEL_VERSION_NOT_FOUND

    "
fi
padding="----------"
# display info while waiting on repo to clone
printf "
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
    $tarball_target_win      

==================================================================
==================================================================
==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}"

echo "
press ENTER to confirm details and continue"
read confirm
if [ -d "$linux_build_dir/.git" ]; then
    cd $linux_build_dir
    if [ ! $quick_install ]; then
        git reset --hard
        git clean -fxd
    fi
    git checkout $linux_kernel_version_tag --progress
    cd ..
else
    git clone $linux_repo --single-branch --branch $linux_kernel_version_tag --progress -- $linux_build_dir
fi
if [ $zfs ]; then
    echo "zfs == True
LINENO: ${LINENO}"
    if [ -d "$zfs_build_dir/.git" ]; then
        cd $zfs_build_dir
        if [ ! $quick_install ]; then 
            git reset --hard
            git clean -fxd
        fi
        git checkout $zfs_version_tag --progress
        cd ..
    else
        git clone $zfs_repo --single-branch --branch $zfs_version_tag --progress -- $zfs_build_dir 
    fi
fi

if [ $user_config_flag ]; then
    # replace kernel source .config with the config generated from a custom config
    cp -fv $config_source $linux_build_dir/.config
fi


cd $linux_build_dir
yes "" | make oldconfig
yes "" | make prepare scripts 
if [ $zfs ]; then
    echo "zfs == True
LINENO: ${LINENO}"
    cd ../$zfs_build_dir && \
    bash autogen.sh && \
    bash configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=../$linux_build_dir --with-linux-obj=../$linux_build_dir && \
    bash copy-builtin ../$linux_build_dir && \
    yes "" | make install 
fi

cd ../$linux_build_dir
if [ $zfs ]; then
    echo "zfs == True
LINENO: ${LINENO}"
    sed -i 's/\# CONFIG_ZFS is not set/CONFIG_ZFS=y/g' .config
fi
yes "" | make -j $(expr $(nproc) - 1)
make modules_install
# kernel is baked - time to distribute fresh copies
if [ ! -f "$kernel_source" ]; then
    echo "
    
Ooops. The kernel did not build. Exiting ..."
exit
fi

cd ..
# move back to base dir  folder with github (relative) path
mkdir -pv $git_save_path 2>/dev/null
# queue files to be saved to repo
if [ "$user_config_flag" ]; then
    cp -fv --backup=numbered $linux_build_dir/.config $config_target_git
fi
cp -fv --backup=numbered $linux_build_dir/$kernel_source $kernel_target_git


# build/move tar with version control if [tar]get directory is writeable
# save copies in timestamped dir to keep organized
mkdir -pv k-cache 2>/dev/null
rm -rfv k-cache/*
rm -rfv k-cache/.*
cp -fv --backup=numbered  $config_source k-cache/$config_alias
cp -fv --backup=numbered  $linux_build_dir/$kernel_source k-cache/$kernel_alias
touch k-cache/$package_full_name
# work on *nix first
mkdir -pv $nix_save_path 2>/dev/null
if [ -w "$nix_save_path" ]; then
    tar -czvf $tarball_source_nix -C k-cache .
    cp -fv --backup=numbered $tarball_source_nix $tarball_target_nix.bak
    cp -fv $tarball_source_nix $tarball_target_nix 
else
    echo "unable to save kernel package to home directory"
fi

# win
# package a known working wslconfig file along with the kernel and config file
mkdir -p $win_save_path 2>/dev/null
sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\${kernel_alias}_$timestamp_id/g" ../../../dvlp/mnt/home/sample.wslconfig
cp -fv --backup=numbered ../../../dvlp/mnt/home/sample.wslconfig k-cache/sample.wslconfig
if [ -w "$win_save_path" ]; then
    tar -czvf $tarball_source_win -C k-cache .
    cp -fv --backup=numbered $tarball_source_win $tarball_target_win.bak
    cp -fv $tarball_source_win $tarball_target_win
else
    echo "
unable to save kernel package to home directory"
fi
win_user_home=/mnt/c/users/$win_user
wslconfig=$win_user_home/.wslconfig
if [ $quick_install ]; then
    # copy kernel and wsl config right away
    cp -vf k-cache/$kernel_alias "${win_user_home}/${kernel_alias}_$timestamp_id" 
    mv -vf --backup=numbered $wslconfig $wslconfig.old
    sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\${kernel_alias}_$timestamp_id/g" k-cache/sample.wslconfig           
    cp -vf k-cache/sample.wslconfig $wslconfig  
else
    echo "
    
install $package_full_name kernel ($kernel_alias) to WSL? y/(n)"
    read install_kernel
    if [ "$install_kernel" = "y" ] || [ "$install_kernel" = "Y" ]; then
        quick_install=True && \
        win_user_home=/mnt/c/users/$win_user && \
        cp -vf k-cache/$kernel_alias "${win_user_home}/${kernel_alias}_$timestamp_id"
        if [ -f "$wslconfig" ]; then
            echo "
            
.wslconfig found in $win_user_home

replacing this with a pre-configured .wslconfig is *HIGHLY* recommended
a backup of the original file will be saved as:

    $wslconfig.old

continue with .wslconfig replacement?
(y)/n"
            read replace_wslconfig
            if [ "$replace_wslconfig" = "n" ] || [ "$replace_wslconfig" = "N" ]; then
                if grep -q '^\s?\#?\skernel=.*' "$wslconfig"; then
                    sed -i "s/\s*\#*\s*kernel=C.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\$kernel_alias_/g" $wslconfig
                else
                    wslconfig_old="$(cat $wslconfig)"
                    wslconfig_new="
[wsl2]

kernel=C\:\\\\users\\\\$win_user\\\\${kernel_alias}_$timestamp_id
$(cat $wslconfig_old)"
                    echo "$wslconfig_new" > $wslconfig
                fi
            else
                mv -vf --backup=numbered $wslconfig $wslconfig.old
                sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\${kernel_alias}_$timestamp_id/g" k-cache/sample.wslconfig           
                cp -vf k-cache/sample.wslconfig $wslconfig  
            fi
        else
            mv -vf --backup=numbered $wslconfig $wslconfig.old
            sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\${kernel_alias}_$timestamp_id/g" k-cache/sample.wslconfig           
            cp -vf k-cache/sample.wslconfig $wslconfig          
        fi
    fi
fi

if [ $quick_install ]; then
            echo "
        
restarting wsl is required to boot into the kernel 

try to automatically restart?

Press ENTER to reboot now
type any other key and then press ENTER to manually reboot at a later time"

read restart

    if [ "$restart" != "" ]; then
        echo "

    enter 'reboot' into a linux terminal 

                - OR - 

    copy/pasta this into a windows terminal:

        wsl.exe --shutdown
        wsl.exe -d $WSL_DISTRO_NAME


        "
    else
        su r00t
        reboot
    fi
fi
# cp -fv --backup=numbered $kernel_source $kernel_target_nix
# cp -fv --backup=numbered .config $nix_save_path/$config_alias

# if [ -d "$win_save_path" ]; then cp -fv --backup=numbered  $kernel_source $win_save_path/$config_alias; fi
# if [ -d "$win_save_path" ]; then cp -fv --backup=numbered  $kernel_source $win_save_path/$kernel_alias; fi


# cleanup
# rm -rf k-cache/*
# rm -rf $linux_build_dir
# rm -rf $temp_dir


