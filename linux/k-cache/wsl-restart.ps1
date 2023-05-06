# source of the below self-elevating script: https://blog.expta.com/2017/03/how-to-self-elevate-powershell-script.html#:~:text=If%20User%20Account%20Control%20(UAC,select%20%22Run%20with%20PowerShell%22.
# Self-elevate the script if required
try {
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
            $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
            Start-Process -FilePath PowerShell.exe -Verb Runas -WindowStyle "Maximized" -ArgumentList $CommandLine
            Exit
        }
    }
}
catch {
    Start-Process -FilePath PowerShell.exe -ArgumentList $CommandLine
}

write-host "
attempting restart ..."

if ($IsWindows) {
    write-host "... from within native Windows
"
    Write-Output "stopping docker ..."
    powershell.exe -Command cmd.exe /c net stop com.docker.service
    powershell.exe -Command cmd.exe /c taskkill /IM "'Docker Desktop.exe'" /F
    Write-Output "restarting wsl ..."
    powershell.exe -Command wsl.exe --shutdown; powershell.exe -Command wsl.exe --exec echo 'wsl restarted';
    Write-Output "starting docker ..."
    powershell.exe -Command cmd.exe /c net start com.docker.service
    powershell.exe -Command wsl.exe --exec echo 'docker restarted';
}
elseif ($IsLinux) {
    write-host "... from within WSL Linux distro
"
    Write-Output "stopping docker ..."
    pwsh Start-Process -FilePath cmd.exe -ArgumentList '/c net stop com.docker.service'
    pwsh Start-Process -FilePath cmd.exe -ArgumentList '/c taskkill /IM "Docker Desktop.exe" /F'
    Write-Output "restarting wsl ..."
    pwsh Start-Process -FilePath wsl.exe -ArgumentList '--shutdown'; pwsh Start-Process -FilePath wsl.exe -ArgumentList '--exec echo "wsl restarted"';
    Write-Output "starting docker ..."
    pwsh Start-Process -FilePath cmd.exe -ArgumentList '/c net start com.docker.service'
    pwsh Start-Process -FilePath wsl.exe -ArgumentList  '--exec echo "docker restarted"';
}
else {
    write-host "... from within unlabeled environment
"

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
