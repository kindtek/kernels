# usage : ./wsl-kernel-install          # (will prompt for username and list available kernels to install)
#         ./wsl-kernel-install latest
#         ./wsl-kernel-install L6 
#         ./wsl-kernel-install L6 2023
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    if ((Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = '-File "{0}" {1}' -f $MyInvocation.MyCommand.Path, $MyInvocation.UnboundArguments
        Start-Process -FilePath powershell.exe -Verb Runas -WindowStyle Maximized -ArgumentList $CommandLine
        Exit
    }
}

Write-Host "Path: $($pwd.Path)"

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
