#!/bin/bash
config_source=$1
linux_build_dir=wsl2-build
zfs_build_dir=zfs-build
user_config_flag=false
kernel_version="5.15.90.1"
zfs_version="2.1.11"

kernel_version=${2:-$kernel_version}
zfs_version=${3:-$zfs_version}

win_user=${4:-'user'}
linux_kernel_type="basic-wsl-zfs-kernel"
linux_kernel_type_tag="LATEST_RC-WSL-ZFS"
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
kernel_version_mask=${kernel_version/\./_}
kernel_alias=${kernel_version/\./L}
kernel_version_mask=${kernel_version_mask//[\.-]/}
kernel_alias=${kernel_alias//[\.-]/}WZ0
package_alias=linux-$kernel_version_mask
package_full_name=Linux-$kernel_version-$linux_kernel_type_tag
config_alias=.config_$kernel_alias
git_save_path=$cpu_arch/$cpu_vendor/$kernel_version_mask
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
if [ ! "$config_source" -eq "" ] && [ -r "$config_source" ] && [ -s "$config_source" ]; then
    echo "config: $config_source"
    user_config_flag=true
else
# try alternates if user config doesn't work 
    # reliable but the least desirable .. keep looking
    if [ -r "$linux_build_dir/Microsoft/config-wsl" ]; then 
        config_source=$linux_build_dir/Microsoft/config-wsl
    fi
    # generic - slightly better
    if [ -r "$cpu_arch/generic/$kernel_version_mask/$config_alias" ]; then 
        config_source=$cpu_arch/generic/$kernel_version_mask/$config_alias
    fi
    # specific arch - best alternate 
    if [ -r "$git_save_path/$config_alias" ]; then
        config_source=$git_save_path/$config_alias
    fi
fi


# display info while waiting on repo to clone
printf "
===========================================================
=================   Linux Kernel   ========================
======-----------     $kernel_version    ------------------======
===========================================================
====------------     Source Info    -------------------====


  CPU Architecture: 
    $cpu_arch

  CPU Vendor:  
    $cpu_vendor

  Configuration File:
    $config_source


===========================================================
=================   Linux Kernel   ========================
======-----------     $kernel_version    ------------------======
===========================================================
====------------     Output Info     -------------------====


  Kernel:
    $kernel_target_git

  Compressed Kernel/Config:
    $tarball_target_nix
    $tarball_target_win      


===========================================================
===========================================================
===========================================================
"
# wget https://github.com/openzfs/zfs/releases/download/zfs-$zfs_version/zfs-$zfs_version.tar.gz

linux_repo=https://github.com/torvalds/linux.git
if [ -d "$linux_build_dir/.git" ]; then
    cd $linux_build_dir
    git pull $linux_repo --squash --progress
    cd ..
else
    git clone $linux_repo --progress -- $linux_build_dir
fi
cd $linux_build_dir
linux_latest_tag=$(git describe --tags $(git rev-list --tags=v[0-9\.]*-rc[0-9\.]* --max-count=1))
echo "linux latest: $zfs_latest_tag"
git checkout tags/$zfs_latest_tag
cd ..

zfs_repo=https://github.com/openzfs/zfs.git
if [ ! -d "$zfs_build_dir/.git" ]; then
    git clone $zfs_repo --progress -- $zfs_build_dir 
fi
cd $zfs_build_dir
zfs_latest_tag=$(git describe --tags $(git rev-list --tags --max-count=1))
echo "zfs latest: $zfs_latest_tag"
git checkout tags/$zfs_latest_tag
cd ..

# replace kernel source .config with user's
cp -fv $config_source $linux_build_dir/.config

cd $linux_build_dir
yes "" | make oldconfig
yes "" | make prepare scripts
cd ../$zfs_build_dir && sh autogen.sh
sh configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=../$linux_build_dir --with-linux-obj=../$linux_build_dir
sh copy-builtin ../$linux_build_dir
yes "" | make install 

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
    cp -fv --backup=numbered $tarball_source_nix $tarball_target_nix 
else
    echo "unable to save kernel package to home directory"
fi

# win
# package a known working wslconfig file along with the kernel and config file
mkdir -p $win_save_path
cp -fv --backup=numbered ../../../dvlp/mnt/home/sample.wslconfig k-cache/sample.wslconfig
if [ -w "$win_save_path" ]; then
    tar -czvf $tarball_source_win -C k-cache .
    cp -fv --backup=numbered $tarball_source_win $tarball_target_win
else
    echo "unable to save kernel package to home directory"
fi

# cp -fv --backup=numbered $kernel_source $kernel_target_nix
# cp -fv --backup=numbered .config $nix_save_path/$config_alias

# if [ -d "$win_save_path" ]; then cp -fv --backup=numbered  $kernel_source $win_save_path/$config_alias; fi
# if [ -d "$win_save_path" ]; then cp -fv --backup=numbered  $kernel_source $win_save_path/$kernel_alias; fi


# cleanup
# rm -rf k-cache/*
# rm -rf $linux_build_dir
# rm -rf $temp_dir



