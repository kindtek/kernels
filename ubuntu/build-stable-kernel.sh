############################## STABLE 6.2.7 KERNEL ######################################

_AGL=${_AGL:-agl}
cd /home/${_AGL}/dls && sudo rm -rf linux-6.2.7
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.2.7.tar.xz
tar -xvf linux-6.2.7.tar.xz
mv linux-6.2.7 linux
cd linux
kernel_tag=f

wsl_username=$(wslvar USERNAME)
sudo cp /home/dvl/dvl-works/dvl-playg/kernels/ubuntu/x86/amd/6_27/.config_wsl-zfs0 .config && \
sudo chown $LOGNAME:$(id -gn) .config && \
yes "" | sudo make prepare scripts && \
sudo sed -i 's/\# CONFIG_ZFS is not set/CONFIG_ZFS=y/g' .config && echo grep ZFS .config && \
yes "" | sudo make -j16 && sudo make modules_install && \
sudo mkdir -p ../../../${_AGL}/kernels/ubuntu/x86/amd/6_27 && sudo cp -f arch/x86/boot/bzImage ../../../${_AGL}/kernels/ubuntu/x86/amd/6_27_0/linux-6_27_0wz$kernel_tag && \
sudo mkdir -p ../../../dvl/kernels/ubuntu/x86/amd/6_27 && sudo cp -f arch/x86/boot/bzImage ../../../dvl/dvl-works/dvl-playg/kernels/ubuntu/x86/amd/6_27/linux-6_27_0 && \
sudo cp -f arch/x86/boot/bzImage ../../../dvl/kernels/ubuntu/x86/amd/6_27/linux-6_27_0 && \
sudo cp arch/x86/boot/bzImage /mnt/c/users/$wsl_username/linux-6_27_0wz$kernel_tag


if ! [ ${_CONFIG_FILE} -f ]; then sudo cp -fv /home/dvl/dvl-works/dvlp/kernels/ubuntu/x86/generic/.config_wsl0 /home/${_AGL}/dls/wsl2/.config; else cp -fv ${_CONFIG_FILE} /home/${_AGL}/dls/wsl2/.config && \
    sudo chown ${_AGL}:${_HALO} .config && \
    yes "" | sudo make -j $(expr $(nproc) - 1) && sudo make modules_install && \
    sudo mkdir -pv ../../../${_AGL}/kernels && sudo mkdir -pv ../../../dvl/kernels && \
    sudo cp -fv arch/x86/boot/bzImage ../../../${_AGL}/linux-kernel-5_1519_0a && \
    sudo cp -fv arch/x86/boot/bzImage ../../../dvl/linux-kernel-5_1519_0a && \
    sudo rm -rfv /halo/dls/* && \
    echo '# sudo daemonize /usr/bin/unshare --fork --pid --mount-proc /lib/systemd/systemd --system-unit=basic.target\n# exec sudo nsenter -t $(pidof -s systemd) -a su - $LOGNAME\n# echo "exec sudo nsenter -t $(pidof -s systemd) -a su - $LOGNAME" > /dev/null && wait -n\n' >> /home/${_AGL}/.bashrc
