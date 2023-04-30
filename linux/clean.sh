basic_dir="linux-build-msft"
latest_dir="linux-build-torvalds"
stable_dir="linux-build-gregkh"
zfs_dir="zfs-build"


if [ "$1" != "" ]; then
    clean_target=""
    arg1=$1
fi

while [ "${clean_target}" = "" ]; do

if [ "$arg1" = "" ]; then
        echo "

















    press ENTER to exit or choose something to clean

"
    if [ -d "$basic_dir/.git" ]; then
        echo "      - basic"
    fi
    if [ -d "$stable_dir/.git" ]; then
        echo "      - stable"
    fi
    if [ -d "$latest_dir/.git" ]; then
        echo "      - latest"
        echo "      - latest-rc"

    fi
    if [ -d "zfs-build/.git" ]; then
        echo "      - zfs"
    fi
        echo "      - k-cache"
echo "        
    
    
    build type: "
        read clean_target
else
    clean_target=$arg1
fi

    if [ "${clean_target,,}" = "basic" ] || [ "${clean_target,,}" = "b" ]; then
        cd $basic_dir
        git reset --hard
        git clean -fxd
        cd ..
    fi
    if [ "${clean_target,,}" = "stable" ] || [ "${clean_target,,}" = "s" ]; then
        cd $stable_dir
        git reset --hard
        git clean -fxd
        cd ..
    fi
    if [ "${clean_target,,}" = "latest" ] || [ "${clean_target,,}" = "l" ]; then
        cd $latest_dir
        git reset --hard
        git clean -fxd
        cd ..
    fi
    if [ "${clean_target,,}" = "zfs" ] || [ "${clean_target,,}" = "z" ]; then
        cd $zfs_dir
        git reset --hard
        git clean -fxd
        cd ..
    fi
    if [ "${clean_target,,}" = "k-cache" ] || [ "${clean_target,,}" = "k" ] ; then
        rm -rfv k-cache/*
        rm -rfv k-cache/.*
    fi
    if [ "${clean_target,,}" = "" ] || [ "$1" != "" ]; then
        exit
    fi
    clean_target=""
    arg1=""
done
