#!/bin/bash
config_source=$1
wsl_build_dir=wsl2
user_config_flag=false
kernel_version="5.15.90.1"
kernel_version=${2:-$kernel_version}
win_user=${3:-'user'}
linux_kernel_type="basic-wsl-kernel"
timestamp_id=$(date -d "today" +"%Y%m%d%H%M%S")
# deduce architecture of this machine
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"
# shorten common vendor names
if [ $cpu_vendor = AuthenticAMD ]; then cpu_vendor=amd; fi
if [ $cpu_vendor = GenuineIntel ]; then cpu_vendor=intel; fi
# replace first . with _ and then remove the rest of the .'s
kernel_version_mask=${kernel_version/\./_}
kernel_alias=${kernel_version/\./L}
kernel_version_mask=${kernel_version_mask//[\.-]/}
kernel_alias=${kernel_alias//[\.-]/}W0
package_alias=linux-$kernel_version_mask
package_full_name=Linux-$kernel_version-WSL
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
tarfile_target_nix=$nix_save_path/$package_full_name.tar.gz
tarfile_target_win=$win_save_path/$package_full_name.tar.gz

# check that the user supplied source exists if not try to pick the best .config file available
# user choice is best if it exists
if [ -r "$config_source" -a -s "$config_source" ]; then
    user_config_flag=true
else
# try alternates if user config doesn't work 
    # reliable but the least desirable .. keep looking
    if [ -r "$wsl_build_dir/Microsoft/config-wsl" ]; then 
        config_source=$wsl_build_dir/Microsoft/config-wsl
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
    $tarfile_target_nix
    $tarfile_target_win      


===========================================================
===========================================================
===========================================================
"

msft_wsl_repo=https://github.com/microsoft/WSL2-Linux-Kernel.git
msft_wsl_repo_branch=linux-msft-wsl-$kernel_version 
( ( git clone $msft_wsl_repo $wsl_build_dir --progress --depth=1 --single-branch --branch $msft_wsl_repo_branch  ) || ( git pull $msft_wsl_repo --squash --progress ) ) 
# replace kernel source .config with user's
cp -fv $config_source $wsl_build_dir/.config
cd $wsl_build_dir
# make/build
yes "" | make oldconfig && yes "" | make prepare
yes "" | make -j $(expr $(nproc) - 1)
make modules_install 
cd ..
# kernel is baked - time to distribute fresh copies

# move back to base dir  folder with github (relative) path
mkdir -pv $git_save_path
# queue files to be saved to repo
if [ $user_config_flag ]; then
    cp -fv --backup=numbered $wsl_build_dir/.config $config_target_git
fi
cp -fv --backup=numbered linux/$kernel_source $kernel_target_git


# build/move tar with version control if [tar]get directory is writeable
# save copies in timestamped dir to keep organized
mkdir -pv k-cache
cp -fv --backup=numbered  linux/$config_source k-cache/$config_alias
cp -fv --backup=numbered  linux/$kernel_source k-cache/$kernel_alias
touch k-cache/$kernel_version_mask
# work on *nix first
mkdir -pv $nix_save_path
if [ -w "$nix_save_path" ]; then
    tar -czvf $package_full_name.tar.gz k-cache/*
    cp -fv --backup=numbered $nix_save_path/$package_full_name.tar.gz 
else
    echo "unable to save kernel package to home directory"
fi

# win
# package a known working wslconfig file along with the kernel and config file
mkdir -p $win_save_path
cp -fv --backup=numbered ../../../dvlp/mnt/home/sample.wslconfig $win_save_path/sample.wslconfig
if [ -w "$win_save_path" ]; then
    tar -czvf $package_full_name.tar.gz k-cache/*
    cp -fv --backup=numbered $win_save_path/$package_full_name.tar.gz;
else
    echo "unable to save kernel package to home directory"
fi

# cp -fv --backup=numbered $kernel_source $kernel_target_nix
# cp -fv --backup=numbered .config $nix_save_path/$config_alias

if [ -d "$win_save_path" ]; then cp -fv --backup=numbered  $kernel_source $win_save_path/$config_alias; fi
if [ -d "$win_save_path" ]; then cp -fv --backup=numbered  $kernel_source $win_save_path/$kernel_alias; fi


# cleanup
# rm -rf $wsl_build_dir
# rm -rf $temp_dir
cd ..
git submodule update deinit -- kernels

