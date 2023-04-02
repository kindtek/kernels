#!/bin/bash
repo_path1=dvlw
repo_path2=dvlp
kernels_linux_dir=$(pwd)

# case "$kernel_type" in

# "stable-wsl-zfs")
if [ "$1" = "stable-wsl-zfs" ]; then
    kernel_src=stable
    kernel_mod=zfs
    echo 'stable-wsl-zfs'
    cd $kernel_src
    # git submodule set-branch --branch linux-rolling-$kernel_src
    git submodule init
    git submodule update --init --remote --depth=1 --progress --single-branch --force
    git fetch
    # kernel_src_upstream=$(git ls-remote --quiet --tags --sort=committerdate $(git config --get remote.upstream.url) | tail -1)
    # # kernel_src_upstream=$( echo $kernel_src_upstream | sed 's/[\^\{\}]//g' )
    # kernel_src_upstream_sha=$kernel_src_upstream | tail -1 | cut -d $'\t' -f1
    # kernel_src_upstream_name=$kernel_src_upstream | cut -d $'/' -f3
    # kernel_src_upstream_sha=$kernel_src_upstream | git submodule update --init --remote --depth=1 --progress --cached $kernel_src
    # kernel_src_origin=$(git ls-remote --quiet --tags --sort=committerdate | tail -1)   
    # kernel_src_origin=$( echo $kernel_src_origin | sed 's/[\^\{\}]//g' ) 
    # kernel_src_origin_sha=$(cut -d $' ' -f1 <<< "$kernel_src_origin")
    # kernel_src_origin_name=$(cut -d '/' -f3 <<< "$kernel_src_origin")
    # linux_version_name=$(echo $kernel_src_origin_name | sed 's@^[^0-9]*\([0-9\.]\+\).*@\1@')
    linux_version_name="$(git rev-list --branches --date-order --header | tr -d '\0' | tr -d '\0' | grep -o 'Merge v[0-9\.]*' | sed 's/[^0-9\.]//g')"  
    linux_version_mask=$( echo $linux_version_name | sed 's/\./\_/' )
    linux_version_mask=$( echo $linux_version_mask | sed 's/\.//g' )
    echo $linux_version_mask
    # sync_fork_with_upstream() {
    # update/push origin with upstream if theres an update that has not been pushed from upstream
    # if ! [ $kernel_src_upstream_sha = $kernel_src_origin_sha ]; then
    # git fetch upstream
    # git checkout $kernel_src_upstream_sha
    # # git merge upstream/$kernel_src_upstream_sha
    # git switch -c $kernel_src_upstream_name
    # # git add -A -- /home/dvl/dvlw/dvlp/kernels/linux/msft
    # cd ../../../
    # git reset
    # git add -A -- $repo_path1
    # git commit -m "merge new branch from upstream"
    # git push
    # cd ../
    # git reset
    # git add -A -- $repo_path2
    # git commit -m "merge new branch $kernel_src_upstream_name"
    # git push
    # cd $repo_path1/$repo_path2/kernels/linux
    # echo $repo_path1/$repo_path2/kernels/linux
    # echo 'vs
    # '$(pwd)$repo_path1/$repo_path2/kernels/linux
    # else 
    #     cd ..
    # fi
    # return true
# } || { return false; }
    # ;;

elif [ "$1" = "lts-wsl-zfs" ]; then
# "lts-wsl-zfs")
    kernel_src=lts
    kernel_mod=zfs
    cd $kernel_src
    # git submodule set-branch --branch linux-rolling-$kernel_src
    git submodule init
    git submodule update --init --remote --depth=1 --progress
    git fetch

#     kernel_src_origin=$(git ls-remote --quiet --tags --sort=committerdate | tail -1)   
#     kernel_src_origin=$( echo $kernel_src_origin | sed 's/[\^\{\}]//g' ) 
#     kernel_src_origin_sha=$(cut -d $' ' -f1 <<< "$kernel_src_origin")
#     # kernel_src_origin_name=$kernel_src_origin | cut -d '/' -f3
#     kernel_src_origin_name=$(cut -d '/' -f3 <<< "$kernel_src_origin")
#     linux_version_name=$(echo $kernel_src_origin_name | sed 's@^[^0-9]*\([0-9\.]\+\).*@\1@')
#     # replace first . with _ and then remove the rest of the .'s
#     linux_version_mask=$( echo $linux_version_name | sed 's/\./\_/' )
#     linux_version_mask=$( echo $linux_version_mask | sed 's/\.//g' )
#     echo $linux_version_mask
    linux_version_name="$(git rev-list --branches --date-order --header | tr -d '\0' | tr -d '\0' | grep -o 'Merge v[0-9\.]*' | sed 's/[^0-9\.]//g')"  
    linux_version_mask=$( echo $linux_version_name | sed 's/\./\_/' )
    linux_version_mask=$( echo $linux_version_mask | sed 's/\.//g' )
# # sync_fork_with_upstream() {
#     # update/push origin with upstream if theres an update that has not been pushed from upstream
#     if ! [ $kernel_src_upstream_sha = $kernel_src_origin_sha ]; then
#     git fetch upstream
#     git checkout $kernel_src_upstream_sha
#     # git merge upstream/$kernel_src_upstream_sha
#     git switch -c $kernel_src_upstream_name
#     # git add -A -- /home/dvl/dvlw/dvlp/kernels/linux/msft
#     cd ../../../
#     git reset
#     git add -A -- $repo_path1
#     git commit -m "merge new branch from upstream"
#     git push
#     cd ../
#     git reset
#     git add -A -- $repo_path2
#     git commit -m "merge new branch $kernel_src_upstream_name"
#     git push
#     cd $repo_path1/$repo_path2/kernels/linux
#     echo $repo_path1/$repo_path2/kernels/linux
#     echo 'vs
#     '$(pwd)$repo_path1/$repo_path2/kernels/linux
    # else 
    # fi
    # return true
# } || { return false; }
    # ;;
elif [ "$1" = "latest-rc-wsl-zfs" ]; then
# "latest-rc-wsl-zfs")
    echo 'latest-rc-wsl-zfs'
    kernel_src=rc
    kernel_mod=zfs
    cd $kernel_src
    git submodule init
    git submodule update --init --remote --depth=1 --progress
    git fetch
    kernel_src_origin=$(git ls-remote --quiet --tags --sort=committerdate $(git config --get remote.origin.url) | tail -1)
    kernel_src_upstream=$(git ls-remote --quiet --tags --sort=committerdate $(git config --get remote.upstream.url) | tail -1)
    kernel_src_origin_sha=kernel_src_origin | cut -d $'\t' -f1
    # remove any letters - left with #.#-#
    linux_version_name=$(echo $kernel_src_upstream_name | sed 's@^[^0-9]*\([0-9\.-]\+\).*@\1@')
    # replace first . with _ and then remove the rest of the .'s
    linux_version_mask=$( echo $linux_version_name | sed 's/-/-rc/' )

# # sync_fork_with_upstream() {
#     # update/push origin with upstream if theres an update that has not been pushed from upstream
#     if ! [ $kernel_src_upstream_sha = $kernel_src_origin_sha ]; then
#     git fetch upstream
#     git checkout $kernel_src_upstream_sha
#     # git merge upstream/$kernel_src_upstream_sha
#     git switch -c $kernel_src_upstream_name
#     # git add -A -- /home/dvl/dvlw/dvlp/kernels/linux/msft
#     cd ../../../
#     git reset
#     git add -A -- $repo_path1
#     git commit -m "merge new branch from upstream"
#     git push
#     cd ../
#     git reset
#     git add -A -- $repo_path2
#     git commit -m "merge new branch $kernel_src_upstream_name"
#     git push
#     fi

    # return true
# } || { return false; }
    # ;;

# "basic-wsl-zfs")
elif [ "$1" = "basic-wsl-zfs" ]; then
    echo 'basic-wsl-zfs'
    kernel_src=msft
    kernel_mod=zfs
    # cd'ing after the update so if something fails the error will be caught easier
    cd $kernel_src
    git submodule init
    git submodule update --init --remote --depth=1 --progress
    git fetch

    kernel_src_origin=$(git ls-remote --quiet --tags --sort=committerdate $(git config --get remote.origin.url) | tail -1)
    kernel_src_upstream=$(git ls-remote --quiet --tags --sort=committerdate $(git config --get remote.upstream.url) | tail -1)
    kernel_src_origin_sha=kernel_src_origin | cut -d $'\t' -f1
    kernel_src_upstream_sha=$kernel_src_upstream | tail -1 | cut -d $'\t' -f1
    kernel_src_upstream_name=$kernel_src_upstream | cut -d $'/' -f3
    linux_version_name=$(echo $kernel_src_upstream_name | sed 's@^[^0-9]*\([0-9\.]\+\).*@\1@')
    # replace first . with _ and then remove the rest of the .'s
    linux_version_mask=$( echo $linux_version_name | sed 's/\./\_/' )
    linux_version_mask=$( echo $linux_version_mask | sed 's/\.//g' )
    # sync_fork_with_upstream() {
    # update/push origin with upstream if theres an update that has not been pushed from upstream
    if ! [ $kernel_src_upstream_sha = $kernel_src_origin_sha ]; then
    git fetch upstream
    git checkout $kernel_src_upstream_sha
    # git merge upstream/$kernel_src_upstream_sha
    git switch -c $kernel_src_upstream_name
    # git add -A -- /home/dvl/dvlw/dvlp/kernels/linux/msft
    cd ../../../
    git reset
    git add -A -- $repo_path1
    git commit -m "merge new branch from upstream"
    git push
    cd ../
    git reset
    git add -A -- $repo_path2
    git commit -m "merge new branch $kernel_src_upstream_name"
    git push
    fi

    # return true
# } || { return false; }
    # ;;

# *)
elif [ "$1" = "basic-wsl" ]; then
    # basic-wsl
    echo 'basic-wsl'
    kernel_src=msft
    kernel_mod=none
    cd $kernel_src
    git submodule init
    git submodule update --init --remote --depth=1 --progress
    git fetch
    # cd'ing after the update so if something fails the error will be caught easier
    kernel_src_origin=$(git ls-remote --quiet --tags --sort=committerdate | tail -1)
    # kernel_src_origin_name==$kernel_src_origin | cut -d $'/' -f3
    # kernel_src_origin_sha=$kernel_src_origin | cut -d $'\t' -f1
    kernel_src_origin_sha=$(cut -d $'\t' -f1 <<< "$kernel_src_origin")
    kernel_src_origin_name=$(cut -d '/' -f3 <<< "$kernel_src_origin")
    kernel_src_upstream=$(git ls-remote --quiet --tags --sort=committerdate $(git config --get remote.upstream.url) | tail -1)
    kernel_src_upstream_sha=$(cut -d $'\t' -f1 <<< "$kernel_src_upstream")
    kernel_src_upstream_name=$(cut -d '/' -f3 <<< "$kernel_src_upstream")
    linux_version_name=$(echo $kernel_src_origin_name | sed 's@^[^0-9]*\([0-9\.]\+\).*@\1@')
    # replace first . with _ and then remove the rest of the .'s
    linux_version_mask=$( echo $linux_version_name | sed 's/\./\_/' )
    linux_version_mask=$( echo $linux_version_mask | sed 's/\.//g' )
    echo $kernel_src_origin

# sync_fork_with_upstream() {
    # update/push origin with upstream if theres an update that has not been pushed from upstream
    if ! [ $kernel_src_upstream_sha = $kernel_src_origin_sha ]; then
    git fetch upstream
    git checkout $kernel_src_upstream_sha
    # git merge upstream/$kernel_src_upstream_sha
    git switch -c $kernel_src_upstream_name
    # git add -A -- /home/dvl/dvlw/dvlp/kernels/linux/msft
    cd ../../../
    git reset
    git add -A -- $repo_path1
    git commit -m "merge new branch from upstream"
    git push
    cd ../
    git reset
    git add -A -- $repo_path2
    git commit -m "merge new branch $kernel_src_upstream_name"
    git push
    fi

    # return true
# } || { return false; }
#     ;;
# esac
fi
echo $kernels_linux_dir
cd $kernels_linux_dir

    echo $(pwd)


if ! [ $kernel_mod = none ]; then
    git submodule init modules/$kernel_mod
    git submodule update --init --remote --depth=1 --progress --checkout --no-recommend-shallow modules/$kernel_mod
    git fetch
    # git pull --recurse-submodules
    # git submodule update --init --remote --depth=1 --progress --single-branch --force 
    cd ../../
    echo 'kernel mod != none'
fi

echo $kernel_mod
kernel_type=${1:-$kernel_type}
config_file=${2:-$config_file_default}
user_name=${3:-dvl}
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"
config_suffix=_wsl-zfs0

# linux_version_name=$(echo $kernel_src_upstream_name | sed 's@^[^0-9]*\([0-9\.]\+\).*@\1@')
# # replace first . with _ and then remove the rest of the .'s
# linux_version_mask=$(echo $( echo $linux_version_name | sed 's/\./\_/' ))
# linux_version_mask=$(echo $( echo $linux_version_mask | sed 's/\.//g' )) 
linux_mask=linux-$linux_version_mask

zfs_version_name=2.1.9
# replace first . with _ and then remove the rest of the .'s
zfs_version_mask=${zfs_version_name/./_}
zfs_version_mask=${zfs_version_mask//[.-]/}
zfs_mask=zfs-$zfs_version_mask


if ! [ -d /home/$user_name ]; then $user_name=/home/dvl; fi
if [ $cpu_vendor = AuthenticAMD ]; then cpu_vendor=amd; fi
if [ $cpu_vendor = GenuineIntel ]; then cpu_vendor=intel; fi

save_name=$linux_mask\_wz0
save_location1=$cpu_arch/$cpu_vendor/$linux_version_mask/$save_name
save_location2=/home/$user_name/built-kernels/$save_name

wsl_username=$(wslvar USERNAME) > /dev/null 2> /dev/null
if [ -d /mnt/c/users/$wsl_username ]; then save_location4=/mnt/c/users/$wsl_username/$save_name; fi


# try to pick the best .config file and default to the one provided by microsoft
default_config_file=$cpu_arch/$cpu_vendor/$linux_version_mask/.config$config_suffix
config_file=${2:-$default_config_file}
if [ $cpu_vendor = arm64 ]; then arm_suffix="-arm64"; fi
if ! [ -f $config_file ]; then config_file=$cpu_arch/generic/$linux_version_mask/.config$config_suffix; fi
if ! [ -f ${config_file} ]; then config_file=$default_config_file; else mkdir -pv $cpu_arch/$cpu_vendor/$linux_version_mask; cp -bv $config_file $cpu_arch/$cpu_vendor/$linux_version_mask/.config$config_suffix; fi
if [ -f $config_file ]; then cp -fv $config_file $kernel_src/.config; else curl https://raw.githubusercontent.com/kindtek/WSL2-Linux-Kernel/4aeb7776ebf6d022dfe49fc8abf4ece02d523e84/Microsoft/config-wsl$arm_suffix -o $kernel_src/.config; fi

# wget https://github.com/openzfs/zfs/releases/download/zfs-$zfs_version_name/zfs-$zfs_version_name.tar.gz
# wget https://git.kernel.org/torvalds/t/$linux_version_name.tar.gz

printf '\n======= Kernel Build Info =========================================================================\n\n\tCPU Architecture:\t%s\n\n\tCPU Vendor:\t\t%s\n\n\tConfiguration File:\n\t\t%s\n\n\tSave Locations:\n\t\t%s\n\t\t%s\n\t\t%s\n\n===================================================================================================\n' $cpu_arch $cpu_vendor $config_file $save_location1 $save_location2 $save_location4



# if ! [ git ls-remote --quiet --tags --sort=committerdate | tail -1 | cut -d'/' -f3 = git ls-remote --quiet --tags --sort=committerdate | tail -1 | cut -d'/' -f3 ]
# submodule set-branch --branch $(git ls-remote --quiet --tags --sort=committerdate | tail -1 | cut -d'/' -f3) .


cd $kernel_src
echo "cd $kernel_src"

yes "" | make prepare scripts
if ! [ $kernel_mod = none ]; then
# ls -al ../modules/$kernel_mod
    cd ../modules/$kernel_mod;
    sh autogen.sh;
    sh configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=../../$kernel_src --with-linux-obj=../../$kernel_src
    sh copy-builtin ../../$kernel_src
    yes "" | make install 
    cd ../../$kernel_src
    sed -i 's/\# CONFIG_ZFS is not set/CONFIG_ZFS=y/g' .config
    # sed -i "s/\# CONFIG_ZFS is not set/CONFIG_ZFS=y/g" .config
    # sed -i "s/\# CONFIG_$(echo $kernel_mod | tr '[:lower:]' '[:upper:]') is not set/CONFIG_$(echo $kernel_mod | tr '[:lower:]' '[:upper:]')=y/g" .config
fi

yes "" | make -j $(expr $(nproc) - 1)
if ! [ $kernel_mod = none ]; then make modules_install; fi

mkdir -pv ../$cpu_arch/$cpu_vendor/$linux_version_mask
mkdir -pv /home/$user_name/built-kernels
cp -fv --backup=numbered arch/$cpu_arch/boot/bzImage ../$save_location1 
cp -fv --backup=numbered arch/$cpu_arch/boot/bzImage $save_location2
cp -fv --backup=numbered .config ../$cpu_arch/$cpu_vendor/$linux_version_mask/.config$config_suffix
cp -fv --backup=numbered .config /home/$user_name/built-kernels/.config$config_suffix
cp -fv --backup=numbered ../../../../dvlp/mnt/home/sample.wslconfig /home/$user_name/built-kernels
if [ -d "/mnt/c/users/$wsl_username" ]; then cp -fv --backup=numbered  arch/$cpu_arch/boot/bzImage /mnt/c/users/$wsl_username/$save_name; fi
if [ -d "/mnt/c/users/$wsl_username" ]; then cp -fv --backup=numbered  arch/$cpu_arch/boot/bzImage /mnt/c/users/$wsl_username/$save_name; fi

cd ../
git submodule deinit --all --force
if ! [ $kernel_mod = none ]; then cd modules/$kernel_mod; git submodule deinit --all --force ; fi
cd /
tar -czvf built-kernel.tar.gz /home/$user_name/built-kernels/*