# source of the below self-elevating script: https://blog.expta.com/2017/03/how-to-self-elevate-powershell-script.html#:~:text=If%20User%20Account%20Control%20(UAC,select%20%22Run%20with%20PowerShell%22.
# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -WindowStyle "Maximized" -ArgumentList $CommandLine
        Exit
    }
}

powershell.exe -Command wsl.exe --shutdown; wsl.exe --exec echo 'WSL successfully restarted'; powershell.exe -Command wsl.exe;
Write-Output "restarting docker ..."
$docker_process = Get-Process "*docker desktop*"
if ($docker_process.Count -gt 0) {
    $docker_process[0].Kill()
    $docker_process[0].WaitForExit()
}
$docker_process = Get-Process "*dockerd*"
if ($docker_process.Count -gt 0) {
    $docker_process[0].Kill()
    $docker_process[0].WaitForExit()
}
Start-Process "Docker Desktop.exe"
Start-Process "dockerd.exe"