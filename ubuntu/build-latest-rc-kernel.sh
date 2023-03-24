############################# Latest Release Candidate #######################################
_AGL=${_AGL:-agl}
cd /home/${_AGL}/dls && sudo rm -rf linux linux-6.3-rc3 && \
wget https://git.kernel.org/torvalds/t/linux-6.3-rc3.tar.gz && \
tar -xvf linux-6.3-rc3.tar.gz && \
mv linux-6.3-rc3 linux && \
cd linux && \
kernel_tag=c

# wsl_username=$(wslvar USERNAME)
sudo cp /hel/dvl-works/dvpg/kernels/ubuntu/x86/amd/6_3-rc/.config_wsl-zfs0 .config && \
sudo chown $LOGNAME:$(id -gn) .config && \
yes "" | sudo make prepare scripts && \
sudo make -j16 && sudo make modules_install && \
sudo mkdir -p ../../../${_AGL}/kernels/ubuntu/x86/amd/6_3-rc && sudo cp -f arch/x86/boot/bzImage ../../../${_AGL}/kernels/ubuntu/x86/amd/6_3-rc/linux-6_3rc_wz$kernel_tag && \
sudo mkdir -p ../../../dvl/kernels/ubuntu/x86/amd/6_3-rc && sudo cp -f arch/x86/boot/bzImage ../../../dvl/dvl-works/dvpg/kernels/ubuntu/x86/amd/6_3-rc/amd/linux-6_3rc_0 && \
sudo cp -f arch/x86/boot/bzImage ../../../dvl/kernels/ubuntu/x86/amd/6_3-rc/linux-6_3rc_0 && \
sudo cp arch/x86/boot/bzImage /mnt/c/users/$wsl_username/linux-6_3rc_wz$kernel_tag
