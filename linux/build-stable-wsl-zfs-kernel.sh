#!/bin/bash
config_file=${1:-$config_file_default}
user_name=${2:-dvl}
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"
config_suffix=_wsl-zfs${user_name:-$(wslvar USERNAME)}

linux_version_name=6.2.8
# replace first . with _ and then remove the rest of the .'s
linux_version_mask=${linux_version_name/./_}
linux_version_mask=${linux_version_mask//[.-]/}
linux_mask=linux-$linux_version_mask

zfs_version_name=2.1.9
# replace first . with _ and then remove the rest of the .'s
zfs_version_mask=${zfs_version_name/./_}
zfs_version_mask=${zfs_version_mask//[.-]/}
zfs_mask=zfs-$zfs_version_mask

if ! [ -d /home/$user_name ]; then $user_name=/home/dvl; fi
if [ $cpu_vendor = AuthenticAMD ]; then cpu_vendor=amd; fi
if [ $cpu_vendor = GenuineIntel ]; then cpu_vendor=intel; fi

if ! [ $user_name=agl ]; then save_name=$linux_mask\_wz${user_name:-$(wslvar USERNAME)}; else save_name=$linux_mask; fi
save_location1=$cpu_arch/$cpu_vendor/$linux_version_mask/$save_name
save_location2=/home/$user_name/built-kernels/$save_name

wsl_username=$(wslvar USERNAME) > /dev/null
if [ -d /mnt/c/users/$wsl_username ]; then save_location4=/mnt/c/users/$wsl_username/$save_name; fi

# try to pick the best .config file and default to the one provided by microsoft
default_config_file=$cpu_arch/$cpu_vendor/$linux_version_mask/.config_wsl-zfs0
config_file=${1:-$default_config_file}
if ! [ -f $config_file ]; then config_file=$cpu_arch/generic/$linux_version_mask/.config_wsl-zfs0; fi
# if ! [ -f $config_file ]; then config_file=wsl2/Microsoft/config-wsl; fi
if ! [ -f ${config_file} ]; then config_file=$default_config_file; else mkdir -pv $cpu_arch/$cpu_vendor/$linux_version_mask; cp -bv $config_file $cpu_arch/$cpu_vendor/$linux_version_mask/.config$config_suffix; fi

wget https://github.com/openzfs/zfs/releases/download/zfs-$zfs_version_name/zfs-$zfs_version_name.tar.gz

wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$linux_version_name.tar.xz

printf '\n======= Kernel Build Info =========================================================================\n\n\tCPU Architecture:\t%s\n\n\tCPU Vendor:\t\t%s\n\n\tConfiguration File:\n\t\t%s\n\n\tSave Locations:\n\t\t%s\n\t\t%s\n\t\t%s\n\n===================================================================================================\n' $cpu_arch $cpu_vendor $config_file $save_location1 $save_location2 $save_location4
tar -xf linux-$linux_version_name.tar.xz
tar -xf zfs-$zfs_version_name.tar.gz
mv -v zfs-$zfs_version_name $zfs_mask
mv -v linux-$linux_version_name $linux_mask

cp -fv ${config_file} $linux_mask/.config;

cd $linux_mask

sleep 7

yes "" | make prepare scripts
cd ../$zfs_mask && sh autogen.sh
sh configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=../$linux_mask --with-linux-obj=../$linux_mask
sh copy-builtin ../$linux_mask
yes "" | make install 

cd ../$linux_mask/
sed -i 's/\# CONFIG_ZFS is not set/CONFIG_ZFS=y/g' .config
yes "" | make -j $(expr $(nproc) - 1)
make modules_install

mkdir -pv ../$cpu_arch/$cpu_vendor/$linux_version_mask
mkdir -pv /home/$user_name/built-kernels
cp -fv --backup=numbered arch/$cpu_arch/boot/bzImage ../$save_location1 
cp -fv --backup=numbered arch/$cpu_arch/boot/bzImage $save_location2
cp -fv --backup=numbered .config ../$cpu_arch/$cpu_vendor/$linux_version_mask/.config$config_suffix
cp -fv --backup=numbered .config /home/$user_name/built-kernels/.config$config_suffix
cp -fv --backup=numbered ../../../../dvlp/mnt/home/sample.wslconfig /home/$user_name/built-kernels
if [ -d "/mnt/c/users/$wsl_username" ]; then cp -fv --backup=numbered  arch/$cpu_arch/boot/bzImage /mnt/c/users/$wsl_username/$save_name; fi
if [ -d "/mnt/c/users/$wsl_username" ]; then cp -fv --backup=numbered  arch/$cpu_arch/boot/bzImage /mnt/c/users/$wsl_username/$save_name; fi


cd ..
rm -rf $linux_mask
rm -rf linux-$linux_version_name.tar.xz
rm -rf zfs-$zfs_version_name.tar.gz
rm -rf zfs-$zfs_mask

cd /
zip -qr built-kernel /home/$user_name/built-kernels/*