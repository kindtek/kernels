#!/bin/bash
if [ "$1" = "" ]; then
    exit
fi
kernel_type="$1"
config_source="$2"
zfs="$3"
quick_wsl_install=${4:+1}
timestamp_id="${5:-${DOCKER_BUILD_TIMESTAMP:-$(date -d "today" +"%Y%m%d%H%M%S")}}"
kernel_file_suffix="W"
linux_build_dir=linux-build

if [ "${zfs,,}" = "zfs" ];  then
# set -x
    zfs_build_dir="zfs-build"
    zfs_repo=https://github.com/openzfs/zfs.git
    zfs_version_tag=$(git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $zfs_repo | tail --lines=1 | cut --delimiter='/' --fields=3)
    zfs_version=${zfs_version_tag#"zfs-"}
    linux_kernel_type_tag=$linux_kernel_type_tag-ZFS
    kernel_file_suffix+="Z"
# set +x
fi
if [ "$kernel_type" = "" ]; then
    kernel_type="stable"
fi
if [ "$kernel_type" = "latest" ]; then
# set -x
    # zfs not supported atm
    # zfs=False; linux_kernel_type_tag=;
    # if [ "$zfs" = "zfs" ]; then
    #     zfs_version=2.1.12
    #     zfs_version_tag=zfs-$zfs_version-staging
    # fi
    linux_build_dir=linux-build-torvalds
    linux_repo=https://github.com/torvalds/linux.git
    linux_kernel_version_tag=$(git ls-remote --refs --sort=version:refname --tags $linux_repo | cut --delimiter='/' --fields=3 | grep '^v[0-9a-zA-Z\.]*$' | tail --lines=1) 
    linux_kernel_type_tag="LATEST-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
    kernel_file_suffix+="L"
# set +x
    # config_file_suffix+="_latest"
elif [ "$kernel_type" = "latest-rc" ]; then
# set -x
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
# set +x
elif [ "$kernel_type" = "stable" ]; then
# set -x
    # latest tag doesn't work properly with zfs so manually update for zfs version possibly compatible with 6.2.9+
    # update: it did not work
    # zfs_version=2.1.11
    # zfs_version_tag=zfs-$zfs_version
    # if [ "$zfs" = "zfs" ]; then
    #     zfs_version=2.1.12
    #     zfs_version_tag=zfs-$zfs_version-staging
    # fi
    # zfs=False; linux_kernel_type_tag=;
    linux_build_dir=linux-build-gregkh
    kernel_file_suffix+="S"
    # config_file_suffix+="_stable"
    linux_repo=https://github.com/gregkh/linux.git
    # linux_version_query="git ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$(git ls-remote --refs --sort=version:refname --tags $linux_repo | cut --delimiter='/' --fields=3 | grep '^v[0-9a-zA-Z\.]*$' | tail --lines=1) 
    # linux_kernel_version_tag='v6.3.13'
    linux_kernel_type_tag="STABLE-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
# set +x
# elif [ "$kernel_type"="basic" ]; then
else 
# set -x
    # (BASIC)
    # latest tag doesn't work properly with zfs so manually update for zfs version compatible with 5.5.3+
    # zfs_version=2.1.11
    # zfs_version_tag=zfs-$zfs_version
    kernel_file_suffix+="B"
    # config_file_suffix+="_basic"
    linux_build_dir=linux-build-msft
    linux_repo=https://github.com/microsoft/WSL2-Linux-Kernel.git
    linux_kernel_version_tag=$(git -c versionsort.suffix=+ ls-remote --refs --sort=version:refname --tags $linux_repo | cut --delimiter='/' --fields=3 | grep '^linux-msft-wsl-[0-9a-zA-Z\.]*$' | tail --lines=1 ) 
    linux_kernel_type_tag="BASIC-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"linux-msft-wsl"}
    linux_kernel_version=${linux_kernel_version_tag%".y"}
    # manually set version due to known bug that breaks 5.15 build with werror: pointer may be used after 'realloc' [-Werror=use-after-free] https://gcc.gnu.org/bugzilla/show_bug.cgi?id=104069
    linux_kernel_version_tag=linux-msft-wsl-6.1.y
    linux_kernel_version=6.1
# set +x
fi

# docker/cli output and exit
package_full_name_id=Linux-$linux_kernel_version-${linux_kernel_type_tag}_${timestamp_id}
# echo "kernel_file_suffix: $kernel_file_suffix"
# echo "package_full_name_id: $package_full_name_id"
# sleep 15

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

# deduce architecture of this machine and shorten to amd/intel or print whatever was found
cpu_vendor="$(echo "$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo | grep -Eio 'intel|amd' || grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)" | tr '[:upper:]' '[:lower:]')"
# cpu_vendor="$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo | tr '[:upper:]' '[:lower:]' | grep -Eio --color=never 'intel|amd' || grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo --color=never)"
cpu_arch="$(uname -m | grep -o '^[^_]*')"
# shorten common vendor names
linux_kernel_version_mask=${linux_kernel_version/\./_}
kernel_alias_no_timestamp=${linux_kernel_version/\./L}
linux_kernel_version_mask=${linux_kernel_version_mask//[\.-]/}
kernel_alias_no_timestamp=${kernel_alias_no_timestamp//[\.-]/}${kernel_file_suffix}
kernel_alias=${kernel_alias_no_timestamp}_${timestamp_id}
config_alias=.config_${kernel_alias}
config_alias_no_timestamp=.config_${kernel_alias_no_timestamp}
git_save_path=$cpu_arch/$cpu_vendor/$linux_kernel_version_mask
nix_user_kache=/kache
if [ "$2" = "get-alias" ]; then
    echo -n "$kernel_alias"
    exit
fi
mkdir -pv $nix_user_kache 2>/dev/null


./clean.sh k
./clean.sh r

# check that the user supplied source exists if not try to pick the best .config file available
# user choice is best if it exists
if [ "$config_source" != "" ] && [ -r "$config_source" ] && [ -s "$config_source" ]; then
    echo "config: $config_source
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    "
# try alternates if user config doesn't work 
    # download reliable .config
elif [ ! -r "$git_save_path/$config_alias_no_timestamp" ] || [ "$config_source" != "" ]; then
        generic_config_source=https://raw.githubusercontent.com/kindtek/kernels/497ad943dff2766c3ed8e087f2d8cec980fcbde9/linux/x86/generic/6_1/.config_6L1WZB
#     echo "

# No saved .config files match this kernel version $linux_kernel_version_tag and $cpu_arch/$cpu_vendor"
    if [ ! -r "config-wsl" ]; then
        wget -O "config-wsl" $generic_config_source
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
default_config_source=$generic_config_source
if [[ "$config_source" =~ https?://.* ]]; then
    default_config_source="$config_source"
fi
[ "${5}" != "" ] || [[ "$config_source" =~ https?://.* ]] || read -r -p "($default_config_source)
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
====-------------------     Source Info    -------------------====
  CPU Architecture: 
    $cpu_arch
  CPU Vendor:  
    $cpu_vendor
  Configuration File:
    $config_source
==================================================================
" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}"
[ "${5}" != "" ] || sleep 10


kernel_source=arch/$cpu_arch/boot/bzImage
kernel_target_git=$git_save_path/$kernel_alias_no_timestamp
config_target_git=$git_save_path/$config_alias_no_timestamp
tarball_filename=$package_full_name_id.tar.gz
tarball_target_nix=$nix_user_kache/$package_full_name_id.tar.gz
kindtek_kernel_version="kindtek-kernel-$kernel_alias_no_timestamp"
sed -i "s/[# ]*CONFIG_LOCALVERSION[ =].*/CONFIG_LOCALVERSION=\"\-${kindtek_kernel_version}\"/g" "$config_source"

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
====-------------------     Output Info    -------------------====
  Kernel:
    version:    $kindtek_kernel_version
    path:       $kernel_target_git
    config:     $config_target_git
  Kernel/Config/Installation/.tar.gz files:
    $nix_user_kache
==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}" | tr -d "'"
[ -d "/mnt/c/users" ] || sleep 10
[ "${5}" != "" ] || echo "
build kernel or exit?
" && \
read -r -p "(build)
" build
if [ "$build" != "" ]; then
    exit
fi

# sudo apt-get -y remove dkms
# sudo apt-get -y remove --auto-remove dkms
# sudo apt-get -y purge dkms
# sudo apt-get -y purge --auto-remove dkms
# sudo rm -rf /usr/lib/modules /usr/src /boot/*
# sudo apt-get -y remove virtualbox
# sudo apt-get -y remove --auto-remove virtualbox
# sudo apt-get -y purge virtualbox
# sudo apt-get -y purge --auto-remove virtualbox
# sudo apt-get autoremove --purge "*virtual*box*"
# sudo apt-get autoremove --purge "*dkms*"
# sudo apt-get -y /var/lib/dkms
# sudo apt-get -y autoremove --purge
# sudo apt-get -y install --install-suggests dkms
# sudo apt-get -y install --install-suggests virtualbox;
git config --global http.postBuffer 1048576000
git config --global https.postBuffer 1048576000
if [ -d "$linux_build_dir/.git" ]; then
    # sudo chown -R "$(id -un):$(id -Gn | grep -o --color=never '^\w*\b')" $linux_build_dir
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
    git clone $linux_repo --single-branch --branch "$linux_kernel_version_tag" --depth=1 --progress -- "$linux_build_dir"
fi

if [ "$zfs" = "zfs" ];  then
#     echo "zfs == True
# LINENO: ${LINENO}"
    if [ -d "$zfs_build_dir/.git" ]; then
        # sudo chown -R "$(id -un):$(id -Gn | grep -o --color=never '^\w*\b')" $zfs_build_dir
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

set +h
umask 022
LFS="$(pwd)/$linux_build_dir"
echo "LFS:
$LFS"
LC_ALL=POSIX
PATH_ORIG=$PATH
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
echo "PATH: 
$PATH"
[ ! -e "/etc/bash.bashrc" ] || sudo mv -v "/etc/bash.bashrc" "/etc/bash.bashrc.NOUSE"

# replace kernel source .config with the config generated from a custom config
cp -fv "$config_source" $linux_build_dir/.config


cd $linux_build_dir || exit
    rm -rf build && \
    mkdir -v build
if (( quick_wsl_install )); then
    # prompt bypass
    echo "starting make oldconfig ..." && \
    yes "" | make oldconfig && \
    echo "starting make prepare scripts ..." && \
    yes "" | make prepare scripts 
else
    echo "starting make oldconfig ..." && \
    make oldconfig && \
    echo "starting make prepare scripts ..." && \
    make prepare scripts 
fi

echo "starting autoreconf ..." && \
bash autoreconf --force --verbose -- install
echo "starting configure ..." && \
bash configure \
    --prefix="$LFS/tools" \
    --with-sysroot="$LFS" \
    --target="$LFS_TGT"   \
    --disable-nls       \
    --enable-gprofng=no \
    --disable-werror
if [ "$zfs" = "zfs" ];  then
#     echo "zfs == True
# LINENO: ${LINENO}"
    cd ../"$zfs_build_dir" || exit 
    bash autoreconf --force --verbose -- install
    bash autogen.sh && \
    bash configure \
        --prefix=/ \
        --libdir=/lib \
        --includedir=/usr/include \
        --datarootdir=/usr/share \
        --enable-linux-builtin=yes \
        --with-linux=../$linux_build_dir \
    --with-linux-obj=../$linux_build_dir && \
    bash copy-builtin ../$linux_build_dir && \
    yes "" | make install 
    sleep 10
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
echo "starting make ..."
if (( quick_wsl_install )); then
    yes "" | make -j$(($(nproc) - 1))
    # yes "" | make deb-pkg
else
    make -j$(($(nproc) - 1))
    # make deb-pkg
fi

make_kernel_version="$(make kernelversion)"
make_kernel_release=$(make kernelrelease)
make_kernel_release_suffix="-g$(git describe --first-parent --abbrev=12 --long --dirty --always)"
LFS_TGT=$make_kernel_release
case "$(echo $make_kernel_release)" in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac

cd .. || exit
# reset kache
rm -rf kache/boot 
rm -rf kache/usr 
mkdir -pv /kache 2>/dev/null
mkdir -pv kache/boot 2>/dev/null
mkdir -pv kache/usr 2>/dev/null
mkdir -pv kache/lib/modules 2>/dev/null
# remove config
rm -rfv kache/.config_*
# remove kernel
# match optional A-Z0-9, optional "rc", A-Z0-9_*
rm -rfv kache/[A-Z0-9]*[-rc]*[A-Z0-9]_*
# remove empty file tag
rm -rfv kache/Linux-*
# remove install script
rm -rfv kache/wsl-kernel-install_*
# remove tar.gz file
rm -rfv kache/*.tar.gz
# remove symlink and anything else in /lib/modules
rm -rfv kache/lib/modules/*

cd $linux_build_dir || exit
sudo cp -fv "arch/$cpu_arch/boot/bzImage" "/boot/vmlinuz-$make_kernel_release"
cp -fv "arch/$cpu_arch/boot/bzImage" "../kache/boot/vmlinuz-$make_kernel_release"
sudo cp -fv System.map "/boot/System.map-$make_kernel_version"
cp -fv System.map "../kache/boot/System.map-$make_kernel_version"
sudo cp -fv .config "/boot/config-$make_kernel_version"
cp -fv .config "../kache/boot/config-$make_kernel_version"
cd .. || exit

cat > /etc/inittab << "EOF"
# Begin /etc/inittab

id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S06:once:/sbin/sulogin
s1:1:respawn:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600

# End /etc/inittab
EOF
sudo mkdir -pv /etc/sysconfig
cat > /etc/sysconfig/clock << "EOF"
# Begin /etc/sysconfig/clock

UTC=1

# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=

# End /etc/sysconfig/clock
EOF

cd $linux_build_dir || exit
find usr/include -type f ! -name '*.h' -delete
sudo make headers_install
sudo make modules_install
make headers_install INSTALL_HDR_PATH=../kache/usr
make modules_install INSTALL_MOD_PATH=../kache/usr
sudo ln -sfv "/lib/modules/$make_kernel_release" "/lib/modules/${make_kernel_release%%-g$(git describe --first-parent --abbrev=12 --long --dirty --always)}"
cd .. || exit
sudo cp -fv "/lib/modules/$make_kernel_release" "kache/lib/modules/$make_kernel_release"

sudo install -v -m755 -d /etc/modprobe.d
cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF

ps_wsl_install_kernel_id="wsl-kernel-install_${kernel_alias}.ps1"
# kernel is baked - time to distribute the goods
# move back to base dir  folder with github (relative) path
mkdir -pv "$git_save_path" 2>/dev/null
# queue files to be saved to repo
cp -fv --backup=numbered "${linux_build_dir}/.config" "${config_target_git}"
cp -fv "${linux_build_dir}/.config" "${config_target_git}"
cp -fv --backup=numbered "${linux_build_dir}/${kernel_source}" "${kernel_target_git}"
cp -fv "${linux_build_dir}/${kernel_source}" "kache/${kernel_alias}"

echo "ps_wsl_install_kernel_id: $ps_wsl_install_kernel_id"
tee "kache/${ps_wsl_install_kernel_id}" >/dev/null <<EOF

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
#>> cd \$env:USERPROFILE/kache
#>> ./${ps_wsl_install_kernel_id}


####-------------------------    OR    ----------------------------------#### 


#############################################################################
#####   OPTION B  #####                                                 #####
#############################################################################
#####   copy/pasta this into any Windows terminal (WIN + x, i):         #####
#####                                                                   #####
#####   copy without '#>>' to replace (delete/move) .wslconfig          #####

    if ([string]::isnullorempty(\$env:USERPROFILE)){
        \$win_user="\$(\$args[0])"
        \$wsl_distro="\$(\$args[1])"
        \$win_user_dir="/mnt/c/users/\$win_user"
    } else {
        # username is optional when calling from windows
        \$win_user="\$env:USERNAME"
        \$win_user_dir="\$env:USERPROFILE" 

        if ([string]::isnullorempty(\$args[1])) {
            \$wsl_distro="\$(\$args[0])"
        } else {
            \$wsl_distro="\$(\$args[1])"
        }
    }

    echo "
    win_user is \$win_user
    win_user_dir is \$win_user_dir
    wsl_distro is \$wsl_distro"

    cd \$win_user_dir\\kache
    
#
#   # delete
#>> del \$win_user_dir\\.wslconfig -Force -verbose;
#
    
    echo "extracting ${package_full_name_id}.tar.gz ..."
    # extract
    tar -xzvf "${package_full_name_id}.tar.gz"


    # append tail.wslconfig to .wslconfig
    if (Test-Path -Path tail.wslconfig -PathType Leaf) {
        echo "appending tail.wslconfig to .wslconfig"
        Add-Content "\$win_user_dir\\kache\\tail.wslconfig" "\$win_user_dir\\kache\\.wslconfig" 
    } else {
        echo "appending blank tail to .wslconfig"
        Write-Host -NoNewline '' | Out-File "\$win_user_dir\\kache\\.wslconfig"
    }

    # backup old wslconfig
    echo "backing up old .wslconfig"
    # move file out of the way   
   
    if (Test-Path -Path "\$win_user_dir\\.wslconfig" -PathType Leaf) {
         move \$win_user_dir\\.wslconfig \$win_user_dir\\.wslconfig.old -Force -verbose;
    } else {
        echo "no .wslconfig found - creating blank file"
        Write-Host -NoNewline '' | Out-File "\$win_user_dir\\.wslconfig.old"
    }

    # install wsl-restart script
    echo "installing wsl-restart script"
    copy \$win_user_dir\\kache\\wsl-restart.ps1 \$win_user_dir\\wsl-restart.ps1 -Force -verbose;

    # copy wslconfig to home dir
    echo "installing new .wslconfig, ${kernel_alias} kernel and ${ps_wsl_install_kernel_id}"
    try {
        \$ErrorActionPreference = "Stop"
        sed -i "s/\\s*\\#*\\s*kernel=.*/kernel=C:\\\\\\\\\\\\\\\\users\\\\\\\\\\\\\\\\\$win_user\\\\\\\\\\\\\\\\kache\\\\\\\\\\\\\\\\${kernel_alias}/g" "/mnt/c/users\$win_user/kache/.wslconfig"
    } catch {
        try {
            sed -i '' "s/\\s*\\#*\\s*kernel=.*/kernel=C:\\\\\\\\\\\\\\\\users\\\\\\\\\\\\\\\\\$win_user\\\\\\\\\\\\\\\\kache\\\\\\\\\\\\\\\\${kernel_alias}/g" "/mnt/c/users\$win_user/kache/.wslconfig"
        } catch {
            try {
                Set-Alias -Name sed -Value 'C:\Program Files\Git\usr\bin\sed.exe'
                sed -i "s/\\s*\\#*\\s*kernel=.*/kernel=C:\\\\\\\\\\\\\\\\users\\\\\\\\\\\\\\\\\$win_user\\\\\\\\\\\\\\\\kache\\\\\\\\\\\\\\\\${kernel_alias}/g" "C:\\users\\\$win_user\\kache\\.wslconfig"
            } catch {
                try {
                    sed -i '' "s/\\s*\\#*\\s*kernel=.*/kernel=C:\\\\\\\\\\\\\\\\users\\\\\\\\\\\\\\\\\$win_user\\\\\\\\\\\\\\\\kache\\\\\\\\\\\\\\\\${kernel_alias}/g" "C:\\users\\\$win_user\\kache\\.wslconfig"
                } catch {
                    try {
                        write-host "
                        could not add update path to kernel in .wslconfig
                        "
                        write-host "
                        please edit line in C:\\users\\\$win_user\\kache\\.wslconfig starting with 'kernel=' to match the following:
                        
                        kernel=C:\\\\users\\\\\$win_user\\\\kache\\\\${kernel_alias}
                        "
                        Start-Process notepad.exe -Wait C:\\users\\\$win_user\\kache\\.wslconfig
                    } catch {
                        Set-Alias -Name notepad.exe -value 'C:\\windows\\system32\\notepad.exe'
                        Start-Process notepad.exe -Wait C:\\users\\\$win_user\\kache\\.wslconfig
                    }
                }
            }
        }
    } finally {
        \$ErrorActionPreference = "Continue"
    }
    copy \$win_user_dir\\kache\\.wslconfig \$win_user_dir\\.wslconfig -force -verbose;

    copy \$win_user_dir\\kache\\${kernel_alias} \$win_user_dir\\kache\\${kernel_alias} -force -verbose
    copy \$win_user_dir\\kache\\${ps_wsl_install_kernel_id} \$win_user_dir\\kache\\${ps_wsl_install_kernel_id} -force -verbose

    # install kernel/modules
    if ([string]::isnullorempty(\$wsl_distro)){
        echo "installing kernel to default distro ..."
        wsl.exe -- sudo apt-get -y update; 
        wsl.exe -- sudo apt-get -y upgrade;        
        wsl.exe --cd \$win_user_dir/kache -- cp -fv ${package_full_name_id}.tar.gz /kache/${package_full_name_id}.tar.gz;
    } else {
        echo "installing kernel to \$wsl_distro distro ..."
        wsl.exe -d \$wsl_distro -- sudo apt-get -y update; 
        wsl.exe -d \$wsl_distro -- sudo apt-get -y upgrade;
        wsl.exe -d \$wsl_distro --cd \$win_user_dir/kache -- cp -fv ${package_full_name_id}.tar.gz /kache/${package_full_name_id}.tar.gz; 
    }




#############################################################################

EOF

chmod +x kache
echo "saving to compressed tarball ..."
tar -czvf "${tarball_filename}" -C kache .
mv -fv "${tarball_filename}" "kache/${tarball_filename}"
# cp "kache/$tarball_filename" kache/latest.tar.gz
# work on *nix first
mkdir -pv "$nix_user_kache" 2>/dev/null

if [ -w "$nix_user_kache" ]; then
    # tar -czvf "kache/$tarball_filename" -C kache kache
    cp -fv "kache/${tarball_filename}" "${tarball_target_nix}" 
else
    echo "unable to save kernel package to Linux home directory"
fi

# restore path and /etc/bash.bashrc
PATH=$PATH_ORIG
sudo bash dkms autoinstall --modprobe-on-install --kernelsourcedir "$LFS"
[ -e "/etc/bash.bashrc.NOUSE" ] && sudo mv -v "/etc/bash.bashrc.NOUSE" "/etc/bash.bashrc"
sudo chmod +rx /etc/bash.bashrc
echo "

KERNEL BUILD COMPLETE

"


printf "


==================================================================
========================   Linux Kernel   ========================
======------------------%s%s------------------======
------------------------------------------------------------------
====-------------------     Output Info    -------------------====
------------------------------------------------------------------

  Kernel:
    ${kernel_target_git}

  Config:
    ${config_target_git}
    
  Kernel/Config/Installation/.tar.gz files:
    ${nix_user_kache}

==================================================================
==================================================================
==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}"

