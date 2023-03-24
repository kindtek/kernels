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
config_file_default=/home/dvl/dvl-works/dvlp/kernels/ubuntu/$cpu_arch/$cpu_vendor/$save_version/.config_wsl-zfs0
if ! [ -f $config_file_default ]; then config_file_default=/home/dvl/dvl-works/dvlp/kernels/ubuntu/$cpu_arch/generic/$save_version/.config_wsl0; fi
if ! [ -f $config_file_default ]; then config_file_default=wsl2/Microsoft/config-wsl; fi
if ! [ -f ${config_file} ]; then cp -fv $config_file_default wsl2/.config; config_file=$config_file_default; else cp -fv ${config_file} wsl2/.config; fi

config_file=${1:-$config_file_default}

printf '\n======= Kernel Build Info =========================================================================\n\n\tCPU Architecture:\t%s\n\n\tCPU Vendor:\t\t%s\n\n\tConfiguration File:\n\t\t%s\n\n\tSave Locations:\n\t\t%s\n\t\t%s\n\n===================================================================================================\n' $cpu_arch $cpu_vendor $config_file $save_location1 $save_location2


wget https://github.com/openzfs/zfs/releases/download/zfs-2.1.9/zfs-2.1.9.tar.gz
tar -xvf zfs-2.1.9.tar.gz
mv zfs-2.1.9 zfs
cd /home/${_AGL}/dls && sudo rm -rf linux-6.2.7
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.2.7.tar.xz
tar -xvf linux-6.2.7.tar.xz
mv linux-6.2.7 linux
cd linux
kernel_tag=b

sudo apt install build-essential flex bison libssl-dev libelf-dev git dwarves
git clone https://github.com/microsoft/WSL2-Linux-Kernel.git
mv WSL2-Linux-Kernel wsl2
cd wsl2
# cp Microsoft/config-wsl .config
# make -j $(expr $(nproc) - 1)
wsl_username=$(wslvar USERNAME)
sudo cp /home/dvl/dvl-works/dvpg/kernels/ubuntu/x86/amd/5_1519/.config_wsl-zfs0 .config && \
sudo chown $LOGNAME:$(id -gn) .config && \

yes "" | sudo make prepare scripts && \
cd ../zfs && sudo sh autogen.sh && \
sudo sh configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=/halo/dls/wsl2 --with-linux-obj=/halo/dls/wsl2 && \
sudo sh copy-builtin ../wsl2 && \
yes "" | sudo make install  && \
cd ../wsl2/ && sudo sed -i 's/\# CONFIG_ZFS is not set/CONFIG_ZFS=y/g' .config && echo grep ZFS .config && \
yes "" | sudo make -j16 && sudo make modules_install && \
sudo mkdir -p ../../../${_AGL}/kernels && sudo cp -f arch/x86/boot/bzImage ../../../${_AGL}/kernels/ubuntu/x86/amd/5_1519/linux-5_1519_wz$kernel_tag && \
sudo mkdir -p ../../../dvl/kernels && sudo cp -f arch/x86/boot/bzImage ../../../dvl/kernels/ubuntu/x86/amd/5_1519/linux-51519_wsl-zfs0 && \
sudo cp -f arch/x86/boot/bzImage ../../../dvl/kernels/ubuntu/x86/amd/5_1519/linux-51519_wsl0 && \
sudo cp arch/x86/boot/bzImage /mnt/c/users/$wsl_username/ubuntu/x86/amd/5_1519/linux-5_1519_wz$kernel_tag
 
# RUN sudo systemctl unmask snapd.service && sudo systemctl enable snapd.service && sudo systemctl start snapd.service && \
#     sudo snap install lxd 


