# usage : ./wsl-kernel-install          # (will prompt for username and list available kernels to install)
#         ./wsl-kernel-install latest
#         ./wsl-kernel-install 6L1 
#         ./wsl-kernel-install 6L 2023

$argString = $args -join " "
$argArray = $argString.Split(" ")
$win_user = ""
if (!$IsLinux ) {
    # get the user home dir info
    $win_user = $Env:USERNAME
    # write-host "win user is: `"$win_user`""
}
else {
    write-host "could not find windows user"
}
# if it exists, prepend win_user info to front of array
$args = @( "$win_user" ) + $args

$args -split ' ' | ForEach-Object {
    if ([string]::IsNullOrEmpty($_)) {
        '""'
    }
    else {
        $_
    }
} | ForEach-Object {
    $_ = '"{0}"' -f $_
}

$argString = $args -join ' '
$argArray = $argString.Split(' ')

wsl.exe --cd /hal/dvlw/dvlp/kernels/linux exec ./install-kernel.sh $($argArray)
