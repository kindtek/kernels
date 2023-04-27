#!/bin/bash
user_config_flag=false
user_entry_flag=false
kernel_type=$1
config_source=$2
zfs=$3
win_user=${4:-'user'}
# kernel_file_suffix=''
# config_file_suffix=''

# linux_kernel_version="5.15.90.1"
# zfs_version="2.1.11"
kernel_file_suffix="W"
config_file_suffix="_wsl"
if [ "$kernel_type" = "" ]; then
    kernel_type="stable"
fi
if [ "$kernel_type" = "latest" ]; then
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
    kernel_file_suffix+="B"
    config_file_suffix+="_basic"
    linux_repo=https://github.com/microsoft/WSL2-Linux-Kernel.git
    linux_version_query="git ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="BASIC-WSL"
    linux_kernel_version=${linux_kernel_version_tag#"linux-msft-wsl"}
    linux_kernel_version=${linux_kernel_version_tag%".y"}
    echo "linux version tag:$linux_kernel_version_tag"
    echo "linux version:$linux_kernel_version"
    echo "linux version type:$linux_kernel_type_tag"
fi




if [ "$zfs" != "" ]; then
    zfs_repo=https://github.com/openzfs/zfs.git
    zfs_version_query="git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $zfs_repo"
    zfs_version_tag=$($zfs_version_query | tail --lines=1 | cut --delimiter='/' --fields=3)
    zfs_version=${zfs_version_tag#"zfs-"}
    linux_kernel_type_tag=$linux_kernel_type_tag-ZFS
    echo "zfs version tag:$zfs_version_tag"
    echo "zfs version:$zfs_version"
    kernel_file_suffix+="Z"
    config_file_suffix+="-zfs"
fi

config_file_suffix+="0"
kernel_file_suffix+="0"

linux_build_dir=linux-build
# echo $linux_version_query
# echo "linux version tag:$linux_kernel_version_tag"
# echo "linux version:$linux_kernel_version"
# echo "linux version tag:$linux_kernel_type_tag"
zfs_build_dir=zfs-build
# echo $zfs_version_query
# echo "zfs version tag:$zfs_version_tag"
# echo "zfs version:$zfs_version"

linux_kernel_type="basic-wsl-zfs-kernel"
timestamp_id=$(date -d "today" +"%Y%m%d%H%M%S")
# deduce architecture of this machine
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"
# shorten common vendor names
if [ $cpu_vendor = AuthenticAMD ]; then cpu_vendor=amd; fi
if [ $cpu_vendor = GenuineIntel ]; then cpu_vendor=intel; fi
# replace first . with _ and then remove the rest of the .'s
zfs_version_mask=${zfs_version/./_}
zfs_version_mask=${zfs_version_mask//[.-]/}
zfs_mask=zfs-$zfs_version_mask
# replace first . with _ and then remove the rest of the .'s
linux_kernel_version_mask=${linux_kernel_version/\./_}
kernel_alias=${linux_kernel_version/\./L}
linux_kernel_version_mask=${linux_kernel_version_mask//[\.-]/}
kernel_alias=${kernel_alias//[\.-]/}${kernel_file_suffix}
package_alias=linux-$linux_kernel_version_mask
package_full_name=Linux-$linux_kernel_version-$linux_kernel_type_tag
config_alias=.config_${kernel_alias}${config_file_suffix}
git_save_path=$cpu_arch/$cpu_vendor/$linux_kernel_version_mask
nix_save_path=$HOME/k-cache
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


# check that the user supplied source exists if not try to pick the best .config file available
# user choice is best if it exists
if [ ! "$config_source" = "" ] && [ -r "$config_source" ] && [ -s "$config_source" ]; then
    echo "config: $config_source"
    user_config_flag=true
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

if [ $linux_kernel_version = "" ]; then
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
====-------------------     Source Info    -------------------====
------------------------------------------------------------------

  CPU Architecture: 
    $cpu_arch

  CPU Vendor:  
    $cpu_vendor

  Configuration File:
    $config_source

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

# wget https://github.com/openzfs/zfs/releases/download/zfs-$zfs_version/zfs-$zfs_version.tar.gz
if [ $5 != "" ] && [ $4 = "" ]; then
    echo "  install kernel when finished?
        y/(n)"
    read install
    if [ $install != "" ] && ( [ $install = "y" ] || [ $install = "Y" ]  ) && ( [ $win_user != "user" ]); then
        echo "enter the name your windows home directory or ..
            press ENTER to confirm as '$win_user'"
        win_user_orig=$win_user
        read win_user
        if [ $win_user = "" ]; then
            win_user = $win_user_orig
        fi
    fi
fi
echo "  press ENTER to confirm details and continue"
read install
if [ -d "$linux_build_dir/.git" ]; then
    cd $linux_build_dir
    git pull $linux_repo --squash --progress
    cd ..
else
    git clone $linux_repo --single-branch --branch $linux_kernel_version_tag --progress -- $linux_build_dir
fi


if [ ! -d "$zfs_build_dir/.git" ] &&  [ "$zfs" != "" ]; then
    git clone $zfs_repo --single-branch --branch $zfs_version_tag --progress -- $zfs_build_dir 
elif [ -d "$zfs_build_dir/.git" ] &&  [ "$zfs" != "" ]; then
    cd $zfs_build_dir
    git pull $zfs_repo --squash --progress
    cd ..
fi


# replace kernel source .config with user's
cp -fv $config_source $linux_build_dir/.config

cd $linux_build_dir
yes "" | make oldconfig
yes "" | make prepare scripts
if [ "$zfs" != "" ]; then
    cd ../$zfs_build_dir && sh autogen.sh
    sh configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=../$linux_build_dir --with-linux-obj=../$linux_build_dir
    sh copy-builtin ../$linux_build_dir
    yes "" | make install 
fi

cd ../$linux_build_dir
sed -i 's/\# CONFIG_ZFS is not set/CONFIG_ZFS=y/g' .config
yes "" | make -j $(expr $(nproc) - 1)
make modules_install
# kernel is baked - time to distribute fresh copies

cd ..
# move back to base dir  folder with github (relative) path
mkdir -pv $git_save_path
# queue files to be saved to repo
if [ "$user_config_flag" ]; then
    cp -fv --backup=numbered $linux_build_dir/.config $config_target_git
fi
cp -fv --backup=numbered $linux_build_dir/$kernel_source $kernel_target_git


# build/move tar with version control if [tar]get directory is writeable
# save copies in timestamped dir to keep organized
mkdir -pv k-cache
rm -rfv k-cache/*
rm -rfv k-cache/.*
cp -fv --backup=numbered  $config_source k-cache/$config_alias
cp -fv --backup=numbered  $linux_build_dir/$kernel_source k-cache/$kernel_alias
touch k-cache/$package_full_name
# work on *nix first
mkdir -pv $nix_save_path
if [ -w "$nix_save_path" ]; then
    tar -czvf $tarball_source_nix -C k-cache .
    cp -fv --backup=numbered $tarball_source_nix $tarball_target_nix.bak
    cp -fv $tarball_source_nix $tarball_target_nix 
else
    echo "unable to save kernel package to home directory"
fi

# win
# package a known working wslconfig file along with the kernel and config file
mkdir -p $win_save_path
sed -i "s/\# kernel=C.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\$kernel_alias/g" ../../../dvlp/mnt/home/sample.wslconfig
cp -fv --backup=numbered ../../../dvlp/mnt/home/sample.wslconfig k-cache/sample.wslconfig
if [ -w "$win_save_path" ]; then
    tar -czvf $tarball_source_win -C k-cache .
    cp -fv --backup=numbered $tarball_source_win $tarball_target_win.bak
    cp -fv $tarball_source_win $tarball_target_win
else
    echo "unable to save kernel package to home directory"
fi

if [ $5 != "" ] && ( [ $4 != "" ] || [ $win_user != "user" ] ); then
    echo "
    
    install kernel to WSL? y/(n)"
    read install_kernel
    if [ $install_kernel = "y" ] || [ $install_kernel = "Y" ]; then
        win_user_home=/mnt/c/users/$win_user
        wslconfig=$win_user_home/.wslconfig
        cp -vf k-cache/$kernel_alias "${win_user_home}/${kernel_alias}_"
        if [ -f "$wslconfig" ]; then
            echo "
            
            .wslconfig found in $win_user_home
            replacing this with the pre-configured .wslconfig is recommended

            replace it? (y)/n"
            read replace_wslconfig
            if [ $replace_wslconfig = "n" ] || [ $replace_wslconfig = "N" ]; then
                if grep -q '^\s?\#?\skernel=.*' "$wslconfig"; then
                    sed -i "s/\s?\#\s?kernel=C.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\$kernel_alias_/g" $wslconfig
                else
                    wslconfig_old=$(cat $wslconfig)
                    wslconfig_new="
                    [wsl2]

                    kernel=C\:\\\\users\\\\$win_user\\\\${kernel_alias}_
                    $(cat $wslconfig)"
                    echo $wslconfig_new > $wslconfig
                fi
            else
                mv --backup=numbered $wslconfig $wslconfig.old
                cp -vf k-cache/sample.wslconfig $wslconfig  
                sed -i "s/\#\s?kernel=C.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\$kernel_alias_/g" $wslconfig            
            fi
        else
            mv --backup=numbered $wslconfig $wslconfig.old
            cp -vf k-cache/sample.wslconfig $wslconfig  
            sed -i "s/\#\s?kernel=C.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\$kernel_alias_/g" $wslconfig            
        fi
        echo "
        
        required. copy/pasta this:
        
            wsl.exe --shutdown
            wsl.exe -d $WSL_DISTRO_NAME
            "
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


