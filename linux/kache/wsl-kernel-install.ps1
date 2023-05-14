# usage : ./wsl-kernel-install          # (will prompt for username and list available kernels to install)
#         ./wsl-kernel-install latest
#         ./wsl-kernel-install 6L1 
#         ./wsl-kernel-install 6L 2023


Write-Host "wsl-kernel-install path: $($pwd)"

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
