#!/bin/bash
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
user_name=${2:-dvl}
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"

if ! [ -d /home/$user_name ]; then $user_name=/home/dvl; fi
if [ $cpu_vendor = AuthenticAMD ]; then cpu_vendor=amd; fi
if [ $cpu_vendor = GenuineIntel ]; then cpu_vendor=intel; fi

save_version=5_1519
save_name=linux-kernel-$save_version\_w0
save_location1=/home/dvl/dvl-works/dvlp/kernels/ubuntu/$cpu_arch/$cpu_vendor/$save_version/$save_name
save_location2=/home/$user_name/$save_name


# try to pick the best .config file and default to the one provided by microsoft
config_file_default=/home/dvl/dvl-works/dvlp/kernels/ubuntu/$cpu_arch/$cpu_vendor/$save_version/.config_wsl0
if ! [ -f $config_file_default ]; then config_file_default=/home/dvl/dvl-works/dvlp/kernels/ubuntu/$cpu_arch/generic/$save_version/.config_wsl0; fi
if ! [ -f $config_file_default ]; then config_file_default=wsl2/Microsoft/config-wsl; fi
if ! [ -f ${config_file} ]; then cp -fv $config_file_default wsl2/.config; config_file=$config_file_default; else cp -fv ${config_file} wsl2/.config; fi

config_file=${1:-$config_file_default}

printf '\n======= Kernel Build Info =========================================================================\n\n\tCPU Architecture:\t%s\n\n\tCPU Vendor:\t\t%s\n\n\tConfiguration File:\n\t\t%s\n\n\tSave Locations:\n\t\t%s\n\t\t%s\n\n===================================================================================================\n' $cpu_arch $cpu_vendor $config_file $save_location1 $save_location2


git clone https://github.com/microsoft/WSL2-Linux-Kernel.git --progress --depth=1 --single-branch 
mv -uv WSL2-Linux-Kernel wsl2

cd wsl2

yes "" | make -j $(expr $(nproc) - 1)
make modules_install 
mkdir -pv /home/$user_name/kernels
mkdir -pv ../../../dvl/dvl-works/dvlp/kernels/ubuntu/$cpu_arch/$cpu_vendor/$save_name
cp -fv --backup=numbered arch/x86/boot/bzImage /home/$user_name/$save_name
cp -fv --backup=numbered arch/x86/boot/bzImage /home/dvl/$save_name
cp -fv --backup=numbered arch/x86/boot/bzImage /home/dvl/dvl-works/dvlp/kernels/ubuntu/$cpu_arch/$cpu_vendor/$save_version/$save_name 
cp -fv --backup=numbered .config /home/dvl/dvl-works/dvlp/kernels/ubuntu/$cpu_arch/$cpu_vendor/$save_version/.config_wsl0

rm -rf wsl2
