if [ "$1" != "" ]; then
    clean_target=""
    arg1=$1
fi

while [ "$clean_target" = "" ]; do

if [ "$arg1" = "" ]; then
        echo "

    press ENTER to exit or choose something to clean
"
    if [ -d "linux-build-msft/.git" ]; then
        echo "        basic"
    fi
    if [ -d "linux-build-gregkh/.git" ]; then
        echo "        stable"
    fi
    if [ -d "linux-build-torvalds/.git" ]; then
        echo "        latest"
        echo "        latest-rc"

    fi
    if [ -d "zfs-build/.git" ]; then
        echo "        zfs"
    fi
        echo "        k-cache"
echo "        
    build type: "
        read clean_target
else
    clean_target=$arg1
fi

    if [ "$clean_target" = "basic" ]; then
        cd linux-build-msft
        git reset --hard
        git clean -fxd
    fi
    if [ "$clean_target" = "stable" ]; then
        cd linux-build-gregkh
        git reset --hard
        git clean -fxd
        cd ..
    fi
    if [ "$clean_target" = "latest" ]; then
        cd linux-build-torvalds
        git reset --hard
        git clean -fxd
        cd ..
    fi
    if [ "$clean_target" = "latest-rc" ]; then
        cd linux-build-torvalds
        git reset --hard
        git clean -fxd
        cd ..
    fi
    if [ "$clean_target" = "zfs" ]; then
        cd zfs-build
        git reset --hard
        git clean -fxd
        cd ..
    fi
if [ "$clean_target" = "k-cache" ]; then
        rm -rfv k-cache/*
        rm -rfv k-cache/.*
    fi
    if [ $clean_target = "" ]; then
        exit
    fi
    clean_target=""
    arg1=""
done
