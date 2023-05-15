# usage : ./make-kernel username # (will build basic kernel)
#         ./make-kernel username basic zfs nocache
#         ./make-kernel username latest 
#         ./make-kernel username stable "" path/to/config/file 

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

wsl.exe --cd /hal/dvlw/dvlp/docker/kali exec ./make-kernel.sh $($argArray)