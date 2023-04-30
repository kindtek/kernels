#!/bin/bash
user_config_flag=False
user_entry_flag=False
kernel_type=$1
config_source=$2
zfs=$3
win_user=${4:-'user'}
quick_install=${4:+True}
# interact=False
# interact=${5:+True}
# kernel_file_suffix=''
# config_file_suffix=''
# linux_kernel_version="5.15.90.1"
# zfs_version="2.1.11"
kernel_file_suffix="W"
# config_file_suffix="_wsl"
linux_build_dir=linux-build
# if [ "$zfs" = "zfs" ];  then
#     echo "zfs == True
# LINENO: ${LINENO}"
# elif ! (( $zfs )); then
#     echo "zfs == False
# LINENO: ${LINENO}"
# else 
#     echo "zfs === $zfs
# LINENO: ${LINENO}"
# fi

if [ "$zfs" = "zfs" ];  then
    zfs_build_dir=zfs-build
    zfs_repo=https://github.com/openzfs/zfs.git
    zfs_version_query="git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $zfs_repo"
    zfs_version_tag=$($zfs_version_query | tail --lines=1 | cut --delimiter='/' --fields=3)
    zfs_version=${zfs_version_tag#"zfs-"}
    linux_kernel_type_tag=$linux_kernel_type_tag-ZFS
    echo "zfs version tag:$zfs_version_tag"
    echo "zfs version:$zfs_version"
fi
if [ "$kernel_type" = "" ]; then
    kernel_type="stable"
fi
if [ "$kernel_type" = "latest" ]; then
    # zfs not supported atm
    zfs=False; linux_kernel_type_tag=;
    linux_build_dir=linux-build-torvalds
    linux_repo=https://github.com/torvalds/linux.git
    linux_version_query="git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="LATEST-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
    kernel_file_suffix+="L"
    # config_file_suffix+="_latest"
    echo "linux version tag:$linux_kernel_version_tag"
    echo "linux version:$linux_kernel_version"
    echo "linux version tag:$linux_kernel_type_tag"
elif [ "$kernel_type" = "latest-rc" ]; then
    # zfs not supported atm
    zfs=False; linux_kernel_type_tag=;
    linux_build_dir=linux-build-torvalds
    kernel_file_suffix+="R"
    # config_file_suffix+="_rc"
    linux_repo=https://github.com/torvalds/linux.git
    linux_version_query="git ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="LATEST_RC-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
    echo "linux version tag:$linux_kernel_version_tag"
    echo "linux version:$linux_kernel_version"
    echo "linux version tag:$linux_kernel_type_tag"
elif [ "$kernel_type" = "stable" ]; then
    # latest tag doesn't work properly with zfs so manually update for zfs version possibly compatible with 6.2.9+
    # update: it did not work
    # zfs_version=2.1.11
    # zfs_version_tag=zfs-$zfs_version
    zfs=False; linux_kernel_type_tag=;
    linux_build_dir=linux-build-gregkh
    kernel_file_suffix+="S"
    # config_file_suffix+="_stable"
    linux_repo=https://github.com/gregkh/linux.git
    # linux_version_query="git ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_version_query="git -c versionsort.suffix=- ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | grep -v -e "-rc[0-9]\+$" | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="STABLE-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"v"}
    echo "linux version query: $linux_version_query"
    echo "linux version tag:$linux_kernel_version_tag"
    echo "linux version:$linux_kernel_version"
    echo "linux kernel type:$linux_kernel_type_tag"
# elif [ "$kernel_type"="basic" ]; then
else 
    # (BASIC)
    # latest tag doesn't work properly with zfs so manually update for zfs version compatible with 5.5.3+
    zfs_version=2.1.11
    zfs_version_tag=zfs-$zfs_version
    kernel_file_suffix+="B"
    # config_file_suffix+="_basic"
    linux_build_dir=linux-build-msft
    linux_repo=https://github.com/microsoft/WSL2-Linux-Kernel.git
    linux_version_query="git -c versionsort.suffix=+ ls-remote --refs --sort=version:refname --tags $linux_repo "
    linux_kernel_version_tag=$($linux_version_query | grep -v -e "-rc[0-9]\+$" | tail --lines=1 | cut --delimiter='/' --fields=3) 
    linux_kernel_type_tag="BASIC-WSL${linux_kernel_type_tag}"
    linux_kernel_version=${linux_kernel_version_tag#"linux-msft-wsl"}
    linux_kernel_version=${linux_kernel_version_tag%".y"}
    # manually set version due to known bug that breaks 5.15 build with werror: pointer may be used after 'realloc' [-Werror=use-after-free] https://gcc.gnu.org/bugzilla/show_bug.cgi?id=104069
    linux_kernel_version_tag=linux-msft-wsl-6.1.y
    linux_kernel_version=6.1
    echo "linux version tag:$linux_kernel_version_tag"
    echo "linux version:$linux_kernel_version"
    echo "linux version type:$linux_kernel_type_tag"
fi
if [ "$zfs" = "zfs" ];  then
#     echo "zfs == True
# LINENO: ${LINENO}"
    echo "zfs version tag:$zfs_version_tag"
    echo "zfs version:$zfs_version"
    kernel_file_suffix+="Z"
    # config_file_suffix+="-zfs"
fi
# config_file_suffix+="0"
# kernel_file_suffix+="0"
timestamp_id=$(date -d "today" +"%Y%m%d%H%M%S")
# deduce architecture of this machine
cpu_vendor=$(grep -Pom 1 '^vendor_id\s*:\s*\K.*' /proc/cpuinfo)
cpu_arch=$(uname -m)
cpu_arch="${cpu_arch%%_*}"
# shorten common vendor names
if [ "$cpu_vendor" = AuthenticAMD ]; then cpu_vendor=amd; fi
if [ "$cpu_vendor" = GenuineIntel ]; then cpu_vendor=intel; fi
linux_kernel_version_mask=${linux_kernel_version/\./_}
kernel_alias_no_timestamp=${linux_kernel_version/\./L}
linux_kernel_version_mask=${linux_kernel_version_mask//[\.-]/}
kernel_alias_no_timestamp=${kernel_alias_no_timestamp//[\.-]/}${kernel_file_suffix}
kernel_alias=${kernel_alias_no_timestamp}_${timestamp_id}
package_full_name=Linux-$linux_kernel_version-$linux_kernel_type_tag
config_alias=.config_${kernel_alias}
config_alias_no_timestamp=.config_${kernel_alias_no_timestamp}
git_save_path=$cpu_arch/$cpu_vendor/$linux_kernel_version_mask
nix_save_path=$HOME/k-cache

# check that the user supplied source exists if not try to pick the best .config file available
# user choice is best if it exists
if [ ! "$config_source" = "" ] && [ -r "$config_source" ] && [ -s "$config_source" ]; then
    echo "config: $config_source
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    "
    user_config_flag=True
else
# try alternates if user config doesn't work 
    # download reliable .config
    echo "
searching for a saved config file at $git_save_path/$config_alias_no_timestamp
"
    if [ ! -r "$git_save_path/$config_alias_no_timestamp" ]; then
        generic_config_source=https://raw.githubusercontent.com/microsoft/WSL2-Linux-Kernel/linux-msft-wsl-5.15.y/Microsoft/config-wsl
        echo "

























No saved .config files match this kernel version and platform"
        if [ ! -r "config-wsl" ]; then
            wget $generic_config_source
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

    Hint: to use a file on Github make sure to use a raw file url starting with https://raw.githubusercontent.com
"
        read config_source
        echo "
# checking if input is a url ..."
        if [ "$config_source" != "" ]; then
            if [[ "$config_source" =~ https?://.* ]]; then 
                echo "yes"
                echo "attempting to download $config_source ...
                "
                wget "$config_source"
                config_source=${pwd}$( echo $config_source | cut --delimiter='/' --fields=1 )
                # config_source=${pwd}/$( echo $config_source | sed -r -e 's/^([A-Za-z0-9-_/:])*\/([A-Za-z0-9-_/])+$/\2/g' )
            else 
                echo "not a url"
            fi
        else
            echo "not a url"
        fi
    fi
    if [ -r "$config_source" ]; then 
        # config_source=$generic_config_source
        echo "config $config_source appears to be valid"
    else    
        echo "could not read $config_source
choosing a generic alternative instead ..."
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
    fi
fi

padding="----------"
printf "













==================================================================
========================   Linux Kernel   ========================
======------------------%s%s------------------======
------------------------------------------------------------------
====-------------------     Source Info    -------------------====
------------------------------------------------------------------

  CPU Architecture: 
    $cpu_arch

  CPU Vendor:  
    $cpu_vendor

  Configuration File:
    $config_source

==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}"

if (( $quick_install )); then
    echo " press ENTER to install kernel when finished
"
    read install
    if [ "$install" = "" ]; then
        install="y"
    fi
    if [ "$install" = "Y" ]; then
        install="y"
    fi
    if [ "$install" = "y" ]; then
        install="y"
        quick_install=True
    else
        quick_install=False
    fi    
else
    echo "
install the kernel into WSL when build is finished?

skip        - press ENTER
install     - type y; press ENTER
"
    read install
    if [ "$install" = "Y" ]; then
        install="y"
    fi
    if [ "$install" = "y" ]; then
        saved_or_installed=installed
        if [ "$4" = "" ]; then win_user=""; fi
        install="y" && \
        echo "










found these existing home directories:
    "
        ls -da /mnt/c/users/*/ | tail -n +4 | sed -r -e 's/^\/mnt\/c\/users\/([ A-Za-z0-9]*)*\/+$/\t\1/g'
        echo " 


install to Windows home directory C:\\users\\__________

        - type name of windows home directory; press ENTER" 
        if [ "$win_user" != "" ]; then
            echo "confirm     - press ENTER to install kernel in C:\\users\\$win_user
            "
        else
            echo " "
        fi
        win_user_orig=$win_user && \
        read win_user
        if [ "$win_user" = "" ]; then
            win_user=${win_user_orig}
        # else 
        #     # if the user tries inputting a path name take everything to the right of the last \
        #     # win_user=$(echo $win_user | sed -E 's/^\s*([A-Za-z0-9]:?\\*)([A-Za-z0-9]*\\)*([A-Za-z0-9]+)+$/\3/g')        
        #     # win_user=$(echo $win_user | sed -E 's/^\s*([A-Za-z0-9]:?\\*)([A-Za-z0-9]*\\?\\?)*([A-Za-z0-9]+)+$/\3/g')
        else
            win_user=$(echo $win_user | cut --delimiter='/' --fields=1)
        fi 
    else 
        saved_or_installed=saved 
        if [ "$4" = "" ]; then 
            win_user=""
            echo "










found these existing home directories:
"
        ls -da /mnt/c/users/*/ | tail -n +4 | sed -r -e 's/^\/mnt\/c\/users\/([ A-Za-z0-9]*)*\/+$/\t\1/g'
        echo " 


save kernel package to Windows home directory C:\\users\\__________

save    - type name of windows home directory; press ENTER" 
        else
            echo "confirm - press ENTER to install kernel in C:\\users\\$win_user
            "
        fi
        read win_user
        if [ "$4" != "" ] && [ -w "/mnt/c/users/$4" ]; then
            win_user=${4}
        # else 
        #     # if the user tries inputting a path name take everything to the right of the last \
        #     # win_user=$(echo $win_user | sed -E 's/^\s*([A-Za-z0-9]:?\\*)([A-Za-z0-9]*\\)*([A-Za-z0-9]+)+$/\3/g')        
        #     # win_user=$(echo $win_user | sed -E 's/^\s*([A-Za-z0-9]:?\\*)([A-Za-z0-9]*\\?\\?)*([A-Za-z0-9]+)+$/\3/g')
        else
            win_user=$(echo $win_user | cut --delimiter='/' --fields=1)
        fi
    fi
    # if [ "$install" = "y" ] || [ "$install" = "Y" ]; then
    
    if [ "$win_user" != "" ] && [ -w "/mnt/c/users/$win_user" ]; then
        
        echo "
kernel package will be $saved_or_installed to C:\\users\\$win_user ...
"   
    else
        echo "
Oooops - C:\\users\\$win_user is an invalid save location
package will not be saved to Windows home directory ...

        "
    fi
    sleep 4
fi

win_save_path=/mnt/c/users/$win_user/k-cache
kernel_source=arch/$cpu_arch/boot/bzImage
kernel_target_git=$git_save_path/$kernel_alias_no_timestamp
config_target_git=$git_save_path/$config_alias_no_timestamp
kernel_target_nix=$nix_save_path/$kernel_alias
config_target_nix=$nix_save_path/$config_alias
kernel_target_win=$win_save_path/$kernel_alias
config_target_win=$win_save_path/$config_alias
tarball_target_nix=$nix_save_path/$package_full_name.tar.gz
tarball_target_win=$win_save_path/$package_full_name.tar.gz
tarball_source_nix=$package_full_name.tar.gz
tarball_source_win=$package_full_name.tar.gz

if [ "$linux_kernel_version" = "" ]; then
    echo "

    Sorry. Cannot continue. Exiting ...

    Error: LINUX_KERNEL_VERSION_NOT_FOUND

    "
fi
padding="----------"

if [ ! -w "/mnt/c/users/$win_user" ]; then
    tarball_target_win=""
fi
printf "



==================================================================
========================   Linux Kernel   ========================
======------------------%s%s------------------======
------------------------------------------------------------------
====-------------------     Output Info    -------------------====
------------------------------------------------------------------

  Kernel:
    $kernel_target_git

  Compressed Kernel/Config:
    $tarball_target_nix
    %s      
==================================================================
==================================================================
==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}" "$tarball_target_win
"

echo "
continue    - press ENTER to confirm
exit        - type any character; press ENTER
"
read confirm
if [ "$confirm" != "" ]; then
    exit
fi
if [ -d "$linux_build_dir/.git" ]; then
    cd $linux_build_dir
    if ! (( $quick_install )); then
        git reset --hard
        git clean -fxd
    fi
    git checkout $linux_kernel_version_tag --progress
    cd ..
else
    git clone $linux_repo --single-branch --branch $linux_kernel_version_tag --progress -- $linux_build_dir
fi
if [ "$zfs" = "zfs" ];  then
#     echo "zfs == True
# LINENO: ${LINENO}"
    if [ -d "$zfs_build_dir/.git" ]; then
        cd $zfs_build_dir
        if ! (( $quick_install )); then 
            git reset --hard
            git clean -fxd
        fi
        git checkout $zfs_version_tag --progress
        cd ..
    else
        git clone $zfs_repo --single-branch --branch $zfs_version_tag --progress -- $zfs_build_dir 
    fi
fi


# replace kernel source .config with the config generated from a custom config
cp -fv $config_source $linux_build_dir/.config

cd $linux_build_dir
if (( $quick_install )); then
    # prompt bypass
    yes "" | make oldconfig
    yes "" | make prepare scripts 
else
    make oldconfig
    make prepare scripts 
fi
if [ "$zfs" = "zfs" ];  then
#     echo "zfs == True
# LINENO: ${LINENO}"
    cd ../$zfs_build_dir && \
    bash autogen.sh && \
    bash configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=../$linux_build_dir --with-linux-obj=../$linux_build_dir && \
    bash copy-builtin ../$linux_build_dir && \
    yes "" | make install 
fi

cd ../$linux_build_dir
if [ "$zfs" = "zfs" ];  then
#     echo "zfs == True
# LINENO: ${LINENO}"
    sed -i 's/\# CONFIG_ZFS is not set/CONFIG_ZFS=y/g' .config
fi
if (( $quick_install )); then
    yes "" | make -j $(expr $(nproc) - 1)
else
    make -j $(expr $(nproc) - 1)
fi
make modules_install
# kernel is baked - time to distribute fresh copies
if [ ! -f "$kernel_source" ]; then
    echo "
    
Ooops. The kernel did not build. Exiting ..."
exit
fi

cd ..
# move back to base dir  folder with github (relative) path
mkdir -pv $git_save_path 2>/dev/null
# queue files to be saved to repo
# if (( $user_config_flag )); then
    cp -fv --backup=numbered $linux_build_dir/.config $config_target_git
# fi
cp -fv --backup=numbered $linux_build_dir/$kernel_source $kernel_target_git


# build/move tar with version control if [tar]get directory is writeable
# save copies in timestamped dir to keep organized
mkdir -pv k-cache 2>/dev/null
rm -rfv k-cache/*
rm -rfv k-cache/.*
cp -fv --backup=numbered  $config_source k-cache/$config_alias
cp -fv --backup=numbered  $linux_build_dir/$kernel_source k-cache/$kernel_alias
touch k-cache/$package_full_name
# work on *nix first
mkdir -pv $nix_save_path 2>/dev/null
if [ -w "$nix_save_path" ]; then
    tar -czvf $tarball_source_nix -C k-cache .
    cp -fv --backup=numbered $tarball_source_nix $tarball_target_nix.bak
    cp -fv $tarball_source_nix $tarball_target_nix 
else
    echo "unable to save kernel package to Linux home directory"
fi

# win
# package a known working wslconfig file along with the kernel and config file
mkdir -p $win_save_path 2>/dev/null
sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\${kernel_alias}/g" ../../../dvlp/mnt/%HOME%/sample.wslconfig
cp -fv --backup=numbered ../../../dvlp/mnt/%HOME%/sample.wslconfig k-cache/.wslconfig
ps_fname=install-$package_full_name-$timestamp_id.ps1
echo "
# for executing option b outside of this directory 
# the below two lines are unnecessary to copy
\$mypath = \$MyInvocation.MyCommand.Path
cd Split-Path \$mypath -Parent
# the above two lines are unnecessary to copy

#############################################################################
# ________________ WSL KERNEL INSTALLATION INSTRUCTIONS ____________________#
# --------------------------------------------------------------------------#
# --------------------- FOR CURRENT WINDOWS ACCOUNT ------------------------#
# --------------------------------------------------------------------------#
#############################################################################
#####   OPTION A  #####                                                     #
#############################################################################
##### copy/pasta this into any Windows terminal (WIN + x, i): ###############
##### uncomment to replace/move old .wslconfig 
#
#
#   to delete   - uncomment the following line:
#   powershell.exe -Command del %HOME%\\.wslconfig;
#
#   to move     - uncomment the following line:
#   powershell.exe -Command move .wslconfig %HOME%\\.wslconfig;
    
    powershell.exe -Command copy ${kernel_alias} %HOME%\\${kernel_alias};
    powershell.exe -Command wsl.exe --shutdown; powershell.exe -Command wsl.exe;
#
#############################################################################

####-------------------------    OR    ----------------------------------#### 

#############################################################################
#####   OPTION B  #####                                                     #
#############################################################################
#### copy/pasta this into any windows terminal (WIN + x, i):      ###########
#### uncomment to replace/move old .wslconfig 
#
#### copy/pasta this into any windows terminal while in this directory  ##### 
#
#    
#   copy without '#' 
#   edit the path if you extracted the tar file to a different location
#
#   .$win_save_path/$package_full_name/$ps_fname
#
#############################################################################
" | tee k-cache/$ps_fname
if [ -w "$win_save_path" ]; then
    tar -czvf $tarball_source_win -C k-cache .
    cp -fv --backup=numbered $tarball_source_win $tarball_target_win.bak
    cp -fv $tarball_source_win $tarball_target_win
else
    echo "
unable to save kernel package to Windows home directory"
fi
win_user_home=/mnt/c/users/$win_user
wsl_kernel_install=${win_user_home}/${kernel_alias}
wsl_config_install=${win_user_home}/.wslconfig
if (( $quick_install )); then
    # copy kernel and wsl config right away
    cp -vf k-cache/$kernel_alias $wsl_kernel_install 
    mv -vf --backup=numbered $wsl_config_install $wsl_config_install.old
    sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\${kernel_alias}/g" k-cache/.wslconfig           
    cp -vf k-cache/.wslconfig $wsl_config_install  
elif [ "$install" = "y" ]; then

printf "



==================================================================
========================   Linux Kernel   ========================
======------------------%s%s------------------======
------------------------------------------------------------------
====-----------------    Install Locations    ----------------====
------------------------------------------------------------------

  .wslconfig:
    $wsl_config_install

  kernel:
    $wsl_kernel_install     

==================================================================
==================================================================
==================================================================

" "----  $linux_kernel_version  " "${padding:${#linux_kernel_version}}"
    echo "
continue    - press ENTER to confirm details and install kernel
exit        - type any character; press ENTER to exit
"
    read install_kernel
    if [ "$install_kernel" = "" ]; then
        win_user_home=/mnt/c/users/$win_user && \
        cp -vf k-cache/${kernel_alias} $wsl_kernel_install
        quick_install=True
        if [ -f "$wsl_config_install" ]; then
            echo "









            
.wslconfig found in $win_user_home

replacing this with a pre-configured .wslconfig is *HIGHLY* recommended
a backup of the original file will be saved as:

    $wsl_config_install.old

continue with .wslconfig replacement?
(y)/n"
            read replace_wslconfig
            if [ "$replace_wslconfig" = "n" ] || [ "$replace_wslconfig" = "N" ]; then
                if grep -q '^\s?\#?\skernel=.*' "$wsl_config_install"; then
                    sed -i "s/\s*\#*\s*kernel=C.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\${kernel_alias}/g" $wsl_config_install
                else
                    wslconfig_old="$(cat $wsl_config_install)"
                    wslconfig_new="
[wsl2]

kernel=C\:\\\\users\\\\$win_user\\\\${kernel_alias}
$(cat $wsl_config_install_old)"
                    echo "$wsl_config_install_new" > $wsl_config_install
                fi
            else
                mv -vf --backup=numbered $wsl_config_install $wsl_config_install.old
                sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\${kernel_alias}/g" k-cache/.wslconfig           
                cp -vf k-cache/.wslconfig $wsl_config_install  
            fi
        else
            mv -vf --backup=numbered $wsl_config_install $wsl_config_install.old
            sed -i "s/\s*\#*\s*kernel=.*/kernel=C\:\\\\\\\\users\\\\\\\\$win_user\\\\\\\\${kernel_alias}/g" k-cache/.wslconfig           
            cp -vf k-cache/.wslconfig $wsl_config_install          
        fi
    fi
fi

echo "





KERNEL BUILD COMPLETE

"

if (( $quick_install )) || [ $install = "y" ]; then
    echo "



WSL REBOOT
----------       

        
restarting WSL is required to boot into the kernel 

would you like to reboot WSL ...

now      - Press ENTER
later    - type any character; press ENTER

"
    read restart
    echo "















WSL REBOOT INSTRUCTIONS
-----------------------

use command 'reboot' in a linux terminal with root privileges

            - OR - 

copy/pasta the following line into any windows terminal (WIN + x, i):

    powershell.exe -Command wsl.exe --shutdown; powershell.exe -Command wsl.exe -d $WSL_DISTRO_NAME


WSL ROLLBACK INSTRUCTIONS
-------------------------

copy/pasta this into any windows terminal (WIN + x, i):

"
echo "
    powershell.exe -Command del c:\\users\\$win_user\\.wslconfig;
    powershell.exe -Command move c:\\users\\$win_user\\.wslconfig.old c:\\users\\$win_user\\.wslconfig;
    powershell.exe -Command wsl.exe --shutdown; powershell.exe -Command wsl.exe -d $WSL_DISTRO_NAME;    
    

" | tee $win_save_path/kindtek-kernel-rollback.cmd
cp $win_save_path/kindtek-kernel-rollback.cmd $win_save_path/kindtek-kernel-rollback.ps1
    if [ "$restart" = "" ]; then
        echo " attempting to restart WSL ... 
        "
        ( powershell.exe -Command wsl.exe --shutdown && \
        powershell.exe -Command wsl.exe -d $WSL_DISTRO_NAME --exec echo "WSL successfully restarted
        
        
        " && \
        powershell.exe -Command wsl.exe -d $WSL_DISTRO_NAME ) || \
        ( echo "unable to restart WSL. manual restart using above code required" )
        
    fi
    
    
fi

# else
#     echo "quick_install == $quick_install"
# fi
# cp -fv --backup=numbered $kernel_source $kernel_target_nix
# cp -fv --backup=numbered .config $nix_save_path/$config_alias

# if [ -d "$win_save_path" ]; then cp -fv --backup=numbered  $kernel_source $win_save_path/$config_alias; fi
# if [ -d "$win_save_path" ]; then cp -fv --backup=numbered  $kernel_source $win_save_path/$kernel_alias; fi


# cleanup
# rm -rf k-cache/*
# rm -rf $linux_build_dir
# rm -rf $temp_dir


