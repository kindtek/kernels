try {
    # Self-elevate the privileges if required
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
            $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
            Start-Process -FilePath PowerShell.exe -Verb Runas -WindowStyle "Maximized" -ArgumentList $CommandLine
            Exit
        }
    }
}
catch {}

write-host "
attempting to restart wsl ..."


if ($IsLinux) {
    write-host "... from within WSL Linux distro
"
    Write-Output "stopping docker ..."
    # & cmd.exe /c net stop com.docker.service
    # Start-Process -FilePath cmd.exe -ArgumentList '/c net stop com.docker.service' -NoNewWindow

    pwsh {    
        Stop-Service -Name "com.docker.service" -Force
        $process = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Id $process.Id -Force
        }
        else {
            Write-Host "The process 'Docker Desktop' was not found."
        }
        Write-Output "restarting wsl ..."
        Start-Process -FilePath wsl.exe -ArgumentList  '--shutdown'; Start-Process -FilePath wsl.exe -ArgumentList  '--exec echo "wsl restarted"';
        # powershell.exe -Command "wsl.exe --shutdown; wsl.exe --exec echo 'wsl restarted'"
        # bash -c systemctl restart systemd-shim
        Write-Output "starting docker ..."
        Start-Sleep -Seconds 5 # wait for 5 seconds to ensure that the service has stopped
        Start-Process -FilePath cmd.exe -ArgumentList '/c net start com.docker.service' -NoNewWindow
    
        Write-Output "starting docker ..."
        powershell.exe -Command cmd.exe /c net start com.docker.service
        # & net start com.docker.service
        Start-Process -FilePath wsl.exe -ArgumentList  '--exec echo "docker restarted"'

        # Find the installation path of Docker Desktop
        $dockerPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        | Where-Object { $_.DisplayName -eq "Docker Desktop" } `
        | Select-Object -ExpandProperty InstallLocation

        # Start Docker Desktop if it's installed
        if ($dockerPath) {
            & "$dockerPath\Docker Desktop.exe"
        }
        else {
            Write-Error "Docker Desktop is not installed on this machine."
        }
    }


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
    # & powershell.exe -Command "Start-Process -FilePath 'net' -ArgumentList 'stop', 'com.docker.service' -Verb RunAs"
    & net stop com.docker.service
    Stop-Process -Name "Docker Desktop" -Force
    Write-Output "restarting wsl ..."
    powershell.exe -Command wsl.exe --shutdown; powershell.exe -Command wsl.exe --exec echo 'wsl restarted'

    
    Write-Output "starting docker ..."
    powershell.exe -Command cmd.exe /c net start com.docker.service
    # & net start com.docker.service
    Start-Process -FilePath wsl.exe -ArgumentList  '--exec echo "docker restarted"'

    # Find the installation path of Docker Desktop
    $dockerPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    | Where-Object { $_.DisplayName -eq "Docker Desktop" } `
    | Select-Object -ExpandProperty InstallLocation

    # Start Docker Desktop if it's installed
    if ($dockerPath) {
        & "$dockerPath\Docker Desktop.exe"
    }
    else {
        Write-Error "Docker Desktop is not installed on this machine."
    }



}


# Write-Output "starting docker ..."
# powershell.exe -Command cmd.exe /c net start com.docker.service
# # & net start com.docker.service
# Start-Process -FilePath wsl.exe -ArgumentList  '--exec echo "docker restarted"'

# # Find the installation path of Docker Desktop
# $dockerPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" `
# | Where-Object { $_.DisplayName -eq "Docker Desktop" } `
# | Select-Object -ExpandProperty InstallLocation

# # Start Docker Desktop if it's installed
# if ($dockerPath) {
#     & "$dockerPath\Docker Desktop.exe"
# }
# else {
#     Write-Error "Docker Desktop is not installed on this machine."
# }




Write-Host "









(done)
" -NoNewline
$BookPrice = Read-Host