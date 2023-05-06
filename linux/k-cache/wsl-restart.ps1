# source of the below self-elevating script: https://blog.expta.com/2017/03/how-to-self-elevate-powershell-script.html#:~:text=If%20User%20Account%20Control%20(UAC,select%20%22Run%20with%20PowerShell%22.
# Self-elevate the script if required
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    if ((Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = '-File "{0}" {1}' -f $MyInvocation.MyCommand.Path, $MyInvocation.UnboundArguments
        Start-Process -FilePath powershell.exe -Verb Runas -WindowStyle Maximized -ArgumentList $CommandLine
        Exit
    }
}

write-host "
attempting restart ..."


if ($IsLinux) {
    write-host "... from within WSL Linux distro
"
    Write-Output "stopping docker ..."
    Start-Process -FilePath cmd.exe -ArgumentList '/c net stop com.docker.service'
    Start-Process -FilePath cmd.exe -ArgumentList '/c taskkill /IM "Docker Desktop.exe" /F'
    Write-Output "restarting wsl ..."
    Start-Process -FilePath wsl.exe -ArgumentList '--shutdown'; pwsh Start-Process -FilePath wsl.exe -ArgumentList '--exec echo "wsl restarted"';
    Write-Output "starting docker ..."
    Start-Process -FilePath cmd.exe -ArgumentList '/c net start com.docker.service'
    Start-Process -FilePath wsl.exe -ArgumentList  '--exec echo "docker restarted"';
}
else {
    if ($IsWindows) {
        write-host "... from within native Windows
"

    } 
    else {
        write-host "... from within unlabeled environment
"
    }

    Write-Output "stopping docker ..."
    powershell.exe -Command cmd.exe /c net stop com.docker.service
    powershell.exe -Command cmd.exe /c taskkill /IM "'Docker Desktop.exe'" /F
    Write-Output "restarting wsl ..."
    powershell.exe -Command wsl.exe --shutdown; powershell.exe -Command wsl.exe --exec echo 'wsl restarted';
    Write-Output "starting docker ..."
    powershell.exe -Command cmd.exe /c net start com.docker.service
    powershell.exe -Command wsl.exe --exec echo 'docker restarted';
}

Read-Host "
(done)
"
