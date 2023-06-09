#!/bin/bash
win_user=${1}
echo "win_user is: $1"
kernel_code=${2}
timestamp_id=${3}
orig_pwd=$(pwd)

echo "





"
while [ "$win_user" = "" ]; do
            echo " 


install to which Windows home directory?"
    cd /mnt/c/users || exit
    while [ ! -d "$win_user" ]; do
        if [ "$win_user" != "" ]; then
            echo "could not find C:\\users\\$win_user"
        fi
echo "

    choose from:
    " 
        ls -da /mnt/c/users/*/ | tail -n +4 | sed -r -e 's/^\/mnt\/c\/users\/([ A-Za-z0-9]*)*\/+$/\t\1/g'

        read -r -p "
    C:\\users\\" win_user
        if [ ! -d "$win_user" ]; then
            echo "

        
        
        










C:\\users\\$win_user is not a home directory"
        fi
    done
    cd "$orig_pwd" || exit
done

win_k_cache="/mnt/c/users/$win_user/kache"
mkdir -p "$win_k_cache"
cd "$win_k_cache" || exit
# if [ -f "wsl-kernel-install_${kernel_code}*_${3}*.ps1" ]; then
if [ "${kernel_code}" = "latest" ]; then
    selected_kernel_install_file="$(ls -tx1 wsl-kernel-install_*.ps1 | sed -nr "s/^wsl-kernel-install_(.*)_(.*)\.ps1$/wsl-kernel-install_\1_\2\.ps1/p" | head -n 1)"
    latest_kernel="$(ls -tx1 wsl-kernel-install_*.ps1 | sed -nr "s/^wsl-kernel-install_(.*)_(.*)\.ps1$/\1_\2/p" | head -n 1)"
    if [ "$latest_kernel" = "" ]; then
        echo "there are no kernels available to install
" 
        read -r -p "
(exit)
"
        exit
    fi
    echo "




the most recently built kernel is: $latest_kernel




    
install kernel into WSL?"
    read -r -p "
(install $latest_kernel)
" install_latest
    if [ "$install_latest" != "" ]; then
        echo "
        
no kernel install requested. exiting ...

"
        exit
    else
        selected_kernel=$latest_kernel
        selected_kernel_install_file="wsl-kernel-install_${selected_kernel}.ps1"
    fi 
elif [ "${kernel_code}" != "" ] && [ "${timestamp_id}" != "" ]; then
    latest_kernel="$(ls -txr1 wsl-kernel-install_*${kernel_code}*_*${timestamp_id}*.ps1 | sed -r -e "s/^wsl-kernel-install_(.*)_(.*)\.ps1$/\1_\2/g"  | head -n 1)"
    latest_kernel_install_file="wsl-kernel-install_${latest_kernel}.ps1"
    if [ "$latest_kernel" = "" ]; then
        echo "there are no kernels available to install
exiting ..."
        exit
    fi
    selected_kernel_install_file=$latest_kernel_install_file
    selected_kernel=$latest_kernel 
    read -r -p "
(install $latest_kernel)
" install_latest
    if [ "$install_latest" != "" ]; then
        echo "
exiting ..."
        exit
    fi
else
    # focus only on 2nd arg
    while [ ! -f "$selected_kernel_install_file" ]; do
        # only focus on single match if $kernel_code has matches
        
        if [ "${kernel_code}" != "" ]; then
            latest_kernel="$(find . -maxdepth 1 -name "wsl-kernel-install_*${kernel_code}*_*" 2>/dev/null | sed -r -e "s/^\.\/wsl-kernel-install_(.*)_(.*)\.ps1$/\1_\2/g" | sort -r  | head -n 1)"
            latest_kernel_install_file="wsl-kernel-install_${latest_kernel}.ps1"
            output_msg="kernels available to install matching *${kernel_code}*:"
        else
            latest_kernel="$(find . -maxdepth 1 -name 'wsl-kernel-install_*' 2>/dev/null | sed -r -e "s/^\.\/wsl-kernel-install_(.*)_(.*)\.ps1$/\1_\2/g" | sort -r  | head -n 1)"
            latest_kernel_install_file="wsl-kernel-install_${latest_kernel}.ps1"
            output_msg="kernels available to install:"
        fi
        if [ -f "$latest_kernel_install_file" ] && [ "$latest_kernel" != "" ]; then
            echo "
$output_msg


        name_timestamp
        --------------------"
            find . -maxdepth 1 -name 'wsl-kernel-install_*' 2>/dev/null | sed -r -e "s/^\.\/wsl-kernel-install_(.*)_(.*)\.ps1$/\t\1_\2/g" | sort -r 
            echo "

enter a kernel name to install:
"
            read -r -p "
($latest_kernel)
 " selected_kernel
            if [ "${selected_kernel}" != "" ] && [ ! -f "wsl-kernel-install_$selected_kernel.ps1" ] && [ ! -f "$latest_kernel_install_file" ]; then
                exit
            elif [ "$selected_kernel" != "" ] && [ -f "wsl-kernel-install_$selected_kernel.ps1" ]; then
                selected_kernel_install_file="wsl-kernel-install_$selected_kernel.ps1"
                echo "user picked ${selected_kernel} ..."
            elif [ "$selected_kernel" = "" ] && [ -f "$latest_kernel_install_file" ]; then
                echo "user confirmed ${latest_kernel_install_file} ..."
                selected_kernel=$latest_kernel
                selected_kernel_install_file=$latest_kernel_install_file
            fi
        elif [ "${kernel_code}" != "" ]; then
            echo "

no kernels like ${kernel_code} found.

enter a different kernel code to search or exit?
            "
            read -r -p "
(exit)
 " selected_kernel

            if [ "$selected_kernel" = "" ]; then
                exit
            else
                kernel_code="$selected_kernel"
                selected_kernel_install_file="wsl-kernel-install_$selected_kernel.ps1"
            fi
        fi
    done
fi


if [ ! -f "$selected_kernel_install_file" ] || [ "$latest_kernel" = "" ]; then
    echo "could not find $selected_kernel_install_file
exiting ..."
    exit
fi
if [ -f "$selected_kernel_install_file" ]; then
    echo "



    
restart WSL when kernel installation is complete?"
    read -r -p "
(install $selected_kernel and restart WSL)
" restart_wsl
    wsl_config=../.wslconfig 
    new_kernel=$(echo "$selected_kernel_install_file" | sed -nr "s/^\.?\/?wsl-kernel-install_(.*)_(.*)\.ps1$/\1_\2/p")
    old_kernel=$(sed -nr "s/^\s*\#*\s*kernel=(.*)\\\\\\\\([A-Za-z0-9_-]+)$/\2/p" "$wsl_config")
    # make sure there actually was an old kernel before deleting
    if [ "$old_kernel" != "" ]; then
        rm -fv "$old_kernel" 
        cp -fv "wsl-kernel-install_$old_kernel.ps1"  "wsl-kernel-rollback.ps1"
        # rm -v ".config_$old_kernel"
    elif [ "$old_kernel" = "$new_kernel" ]; then
        echo "there is nothing to install
current kernel is also $new_kernel

exiting ..."
        exit
    else    
        echo "
move .wslconfig.old .wslconfig.new
move .wslconfig .wslconfig.old
move .wslconfig.new .wslconfig" 2>/dev/null | tee "wsl-kernel-rollback.ps1"
    fi
    if [ "$restart_wsl" = "" ]; then
        echo "running: $selected_kernel_install_file $win_user restart"
        pwsh -file "$selected_kernel_install_file" "$win_user" restart
    else
        echo "running: $selected_kernel_install_file $win_user"
        pwsh -file "$selected_kernel_install_file" "$win_user"
    fi
    # # installation happens here
    # cp -fv .wslconfig $wsl_config
        
    if [ "$old_kernel" != "" ]; then
        echo "


_______________________________________________________________________
        WSL ROLLBACK INSTRUCTIONS
-----------------------------------------------------------------------

from this directory copy/pasta:

    ./wsl-kernel-install_${old_kernel}
    "
    else 
        echo "


_______________________________________________________________________
        WSL ROLLBACK INSTRUCTIONS
-------------------------------------------

from this directory copy/pasta:

    move .wslconfig.old .wslconfig.new
    move .wslconfig .wslconfig.old
    move .wslconfig.new .wslconfig
"    
    fi
    echo "
_______________________________________________________________________
        WSL KERNEL INSTALL INSTRUCTIONS
-----------------------------------------------------------------------

from this directory copy/pasta:

    ./wsl-kernel-install_${new_kernel:-err}


_______________________________________________________________________
        WSL REBOOT INSTRUCTIONS
-----------------------------------------------------------------------

from this directory copy/pasta:

    ./wsl-restart



"

fi


cd "$orig_pwd" || exit

# good for debugging - bad for noninteractive
# read -r -p "
# (exit)
# "
