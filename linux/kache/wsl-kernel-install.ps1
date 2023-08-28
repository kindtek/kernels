# usage : ./wsl-kernel-install          # (will prompt for username and list available kernels to install)
#         ./wsl-kernel-install latest
#         ./wsl-kernel-install 6L1 
#         ./wsl-kernel-install 6L 2023
$distro_name = $args[2]

$arg_str = $args -join " "
$arg_arr = $arg_str.Split(" ")
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

$arg_str = $args -join ' '
$arg_arr = $arg_str.Split(' ')

if ([string]::isNullOrEmpty($distro_name)){
    wsl.exe --user r00t cd `$HOME `&`& bash `$HOME/dvlw/dvlp/kernels/linux/install-kernel.sh $($arg_arr)
} else {
    wsl.exe --user r00t --distribution $distro_name cd `$HOME `&`& bash `$HOME/dvlw/dvlp/kernels/linux/install-kernel.sh $($arg_arr)

}
