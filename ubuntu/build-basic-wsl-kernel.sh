#!/bin/bash
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
user_name=${2:-dvl}
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"
if ! [ -d /home/$user_name ]; then $user_name=/home/dvl; fi
if [ $cpu_vendor = AuthenticAMD ]; then cpu_vendor=amd; fi
if [ $cpu_vendor = GenuineIntel ]; then cpu_vendor=intel; fi

linux_version_name="5.15.90.1"
# replace first . with _ and then remove the rest of the .'s
linux_version_mask=${linux_version_name/\./\_}
linux_version_mask=${linux_version_mask//[\.-]/}
linux_mask=linux-$linux_version_mask

save_name=linux-$linux_version_mask\_w0
save_location1=/home/dvl/dvl-works/dvlp/kernels/ubuntu/$cpu_arch/$cpu_vendor/$linux_version_mask/$save_name
save_location2=/home/$user_name/$save_name


# try to pick the best .config file and default to the one provided by microsoft
config_file_default=$cpu_arch/$cpu_vendor/$linux_version_mask/.config_wsl0
if ! [ -f $config_file_default ]; then config_file_default=/home/dvl/dvl-works/dvlp/kernels/ubuntu/$cpu_arch/generic/$linux_version_mask/.config_wsl0; fi
if ! [ -f $config_file_default ]; then config_file_default=wsl2/Microsoft/config-wsl; fi
if ! [ -f ${config_file} ]; then cp -fv $config_file_default wsl2/.config; config_file=$config_file_default; else cp -fv ${config_file} wsl2/.config; fi

config_file=${1:-$config_file_default}

printf '\n======= Kernel Build Info =========================================================================\n\n\tCPU Architecture:\t%s\n\n\tCPU Vendor:\t\t%s\n\n\tConfiguration File:\n\t\t%s\n\n\tSave Locations:\n\t\t%s\n\t\t%s\n\n===================================================================================================\n' $cpu_arch $cpu_vendor $config_file $save_location1 $save_location2


git clone https://github.com/microsoft/WSL2-Linux-Kernel.git --progress --depth=1 --single-branch --branch linux-msft-wsl-5.15.90.1

mv -uv WSL2-Linux-Kernel wsl2

cd wsl2

yes "" | make oldconfig && yes "" | make prepare
yes "" | make -j $(expr $(nproc) - 1)
make modules_install 
mkdir -pv /home/$user_name/kernels
mkdir -pv ../$cpu_arch/$cpu_vendor/$save_name
cp -fv --backup=numbered arch/x86/boot/bzImage /home/$user_name/$save_name
cp -fv --backup=numbered arch/x86/boot/bzImage /home/dvl/$save_name
cp -fv --backup=numbered arch/x86/boot/bzImage kernels/ubuntu/$cpu_arch/$cpu_vendor/$linux_version_mask/$save_name 
cp -fv --backup=numbered .config kernels/ubuntu/$cpu_arch/$cpu_vendor/$linux_version_mask/.config_wsl0

rm -rf wsl2
