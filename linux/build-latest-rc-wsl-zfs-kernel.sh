#!/bin/bash
config_file=${1:-$config_file_default}
user_name=${2:-dvl}
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"
config_suffix=_wsl-zfs0

linux_version_name=6.3-rc4
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

save_name=$linux_mask\_wz0
save_location1=$cpu_arch/$cpu_vendor/$linux_version_mask/$save_name
save_location2=/home/$user_name/$save_name

# wsl_username=$(wslvar USERNAME) > /dev/null 2> /dev/null
if [ -d /mnt/c/users/$wsl_username ]; then save_location4=/mnt/c/users/$wsl_username/$save_name; fi

cd /home/$user_name/dls 

# try to pick the best .config file and default to the one provided by microsoft
default_config_file=$cpu_arch/$cpu_vendor/$linux_version_mask/.config$config_suffix
config_file=${1:-$default_config_file}
if ! [ -f $config_file ]; then config_file=$cpu_arch/generic/$linux_version_mask/.config$config_suffix; fi
if ! [ -f $config_file ]; then config_file=wsl2/Microsoft/config-wsl; fi
if ! [ -f ${config_file} ]; then config_file=$default_config_file; else mkdir -pv $cpu_arch/$cpu_vendor/$linux_version_mask; cp -bv $config_file $cpu_arch/$cpu_vendor/$linux_version_mask/.config$config_suffix; fi

wget https://github.com/openzfs/zfs/releases/download/zfs-$zfs_version_name/zfs-$zfs_version_name.tar.gz
wget https://git.kernel.org/torvalds/t/$linux_version_name.tar.gz

printf '\n======= Kernel Build Info =========================================================================\n\n\tCPU Architecture:\t%s\n\n\tCPU Vendor:\t\t%s\n\n\tConfiguration File:\n\t\t%s\n\n\tSave Locations:\n\t\t%s\n\t\t%s\n\t\t%s\n\n===================================================================================================\n' $cpu_arch $cpu_vendor $config_file $save_location1 $save_location2 $save_location4

tar -xf zfs-$zfs_version_name.tar.gz
tar -xf $linux_version_name.tar.gz
mv zfs-$zfs_version_name $zfs_mask
mv $linux_version_name $linux_mask

cp -fv ${config_file} $linux_mask/.config;
cd $linux_mask

yes "" | make prepare scripts
cd ../$zfs_mask && sh autogen.sh
sh configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=../$linux_mask --with-linux-obj=../linux-$linux_mask
sh copy-builtin ../$linux_mask
yes "" | make install 

cd ../$linux_mask
sed -i 's/\# CONFIG_ZFS is not set/CONFIG_ZFS=y/g' .config
yes "" | make -j $(expr $(nproc) - 1)
make modules_install

mkdir -pv /home/$user_name/kernels
mkdir -pv $cpu_arch/$cpu_vendor/$linux_mask
cp -fv --backup=numbered arch/$cpu_arch/boot/bzImage ../$save_location1 
cp -fv --backup=numbered arch/$cpu_arch/boot/bzImage $save_location2
cp -fv --backup=numbered .config ../$cpu_arch/$cpu_vendor/$linux_version_mask/.config$config_suffix
if ! [ -z $save_location4 ]; then cp -fv --backup=numbered  arch/$cpu_arch/boot/bzImage $save_location4; fi

cd ..

rm -rf $zfs_mask
rm zfs-$zfs_version_name.tar.gz
rm -rf $linux_mask
rm $linux_version_name.tar.gz