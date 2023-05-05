#!/bin/bash
win_user=${1:-'no-user-selectedlkadjfasdf'}
orig_pwd=$(pwd)

while [ ! -d "/mnt/c/users/$win_user" ]; do
    echo " 


    install to which Windows home directory?

        C:\\users\\__________ 

        choose from:
    " 
    ls -da /mnt/c/users/*/ | tail -n +4 | sed -r -e 's/^\/mnt\/c\/users\/([ A-Za-z0-9]*)*\/+$/\t\1/g'
    read -r -p "
" win_user
done

win_k_cache="/mnt/c/users/$win_user/k-cache"
mkdir -p "$win_k_cache"
cd "$win_k_cache" || exit

if [ ! -f "wsl-kernel-install_${2}_${3}.ps1" ] && [ "$2" != "latest" ]; then

    while [ ! -f "$selected_kernel_install_file" ]; do
        latest_kernel_install_file="$(exec find . -maxdepth 1 -name "wsl-kernel-install_${2}_*" | head -n 1)"
        if [ -f "$latest_kernel_install_file" ]; then
            latest_kernel=$( echo "$latest_kernel_install_file" | sed -r -e "s/^\.\/wsl-kernel-install_(.*)_(.*)\.ps1$/\t\1_\2/g")
            echo "

install latest ${2}:
    $latest_kernel"
            latest_kernel_install_file="$latest_kernel"
            read -r -p "
(confirm)
" selected_kernel_install_file
        else
            echo "
kernels available to install:


        name_timestamp
        --------------------"
            ls -t1 wsl-kernel-install_* | sed -r -e "s/^wsl-kernel-install_(.*)_(.*)\.ps1$/\t\1_\2/g"
            echo "

enter a kernel name to install:
"
            latest_kernel_install_file="$(ls -t1 wsl-kernel-install_* )"
            read -r -p "
($(echo "$latest_kernel_install_file" | sed -r -e "s/^wsl-kernel-install_(.*)_(.*)\.ps1$/\1_\2/g"))
" selected_kernel_install_file
            if [ "${selected_kernel_install_file}" != "" ] && [ ! -f "$selected_kernel_install_file" ]; then
                exit
            elif [ -f "$selected_kernel_install_file" ]; then
                echo "user entered ${selected_kernel_install_file} ..."
            fi
        fi
        if [ "${selected_kernel_install_file}" = "" ]; then
            echo "using $latest_kernel_install_file ..."
            selected_kernel_install_file=$latest_kernel_install_file
        fi
    done
elif [ "$2" = "latest" ]; then
    selected_kernel_install_file="$(ls -t1 wsl-kernel-install_* | head -n 1 )"
    latest_kernel=$( echo "$selected_kernel_install_file" | sed -nr "s/^wsl-kernel-install_(.*)_(.*)\.ps1$/\1_\2/p")

    echo "






    
install $latest_kernel kernel into WSL or exit?"
    read -r -p "
(install $latest_kernel)
" install_latest
    if [ "$install_latest" != "" ]; then
        echo "
build completed and no install requested.
exiting..."
        exit
    # else
    #     selected_kernel_install_file=$latest_kernel
    fi
fi

if [ ! -f "$selected_kernel_install_file" ]; then
    echo "could not find $selected_kernel_install_file
exiting ..."
else 
    wsl_config=../.wslconfig 
    new_kernel=$( echo "$selected_kernel_install_file" | sed -nr "s/^wsl-kernel-install_(.*)_(.*)\.ps1$/\1_\2/p")
    old_kernel=$(sed -nr "s/^\s*\#*\s*kernel=(.*)\\\\\\\\([A-Za-z0-9_-]+)$/\2/p" "$wsl_config")
    # make sure there actually was an old kernel before deleting
    if [ "$old_kernel" != "" ]; then
        rm -fv "$old_kernel" 
        cp -v "wsl-kernel-install_$old_kernel.ps1"  "wsl-kernel-rollback.ps1"
        rm -v ".config_$old_kernel"
    else    
        echo "
move .wslconfig.old .wslconfig.new
move .wslconfig .wslconfig.old
move .wslconfig.new .wslconfig" | tee "wsl-kernel-rollback.ps1"
    fi
    echo "running:  $selected_kernel_install_file"
    pwsh -file "$selected_kernel_install_file"
    # installation happens here
    cp -fv .wslconfig $wsl_config
        
    if [ "$old_kernel" != "" ]; then
        echo "


WSL ROLLBACK INSTRUCTIONS
-------------------------

open a windows terminal to home directory (WIN + x, i) and copy/pasta:

    ./k-cache/wsl-install-$old_kernel
    "
    else 
        echo "


WSL ROLLBACK INSTRUCTIONS
-------------------------

open a windows terminal to home directory (WIN + x, i) and copy/pasta:

    move .wslconfig.old .wslconfig.new
    move .wslconfig .wslconfig.old
    move .wslconfig.new .wslconfig

    "    
    fi
    echo "


WSL KERNEL INSTALL
-------------------------

open a windows terminal to home directory (WIN + x, i) and copy/pasta:

    ./k-cache/wsl-install-$new_kernel


WSL REBOOT INSTRUCTIONS
-----------------------

open a windows terminal to home directory (WIN + x, i) and copy/pasta:

    ./k-cache/wsl-restart
"
# rm latest.tar.gz
    ./wsl-restart

fi


cd "$orig_pwd" || exit

wsl.exe || pwsh -Command wsl