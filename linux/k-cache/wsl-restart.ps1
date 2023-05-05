# source of the below self-elevating script: https://blog.expta.com/2017/03/how-to-self-elevate-powershell-script.html#:~:text=If%20User%20Account%20Control%20(UAC,select%20%22Run%20with%20PowerShell%22.
# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -WindowStyle "Maximized" -ArgumentList $CommandLine
        Exit
    }
}
powershell.exe -Command wsl.exe --shutdown; 
Write-Output "restarting docker ..."
cmd.exe /c net stop docker
cmd.exe /c net stop com.docker.service
cmd.exe /c taskkill /IM "dockerd.exe" /F
cmd.exe /c taskkill /IM "Docker Desktop.exe" /F
cmd.exe /c net start docker
cmd.exe /c net start com.docker.service
wsl.exe --exec echo 'Docker restarted';

# $docker_process = Get-Process "com.docker.service"
# if ($docker_process.Count -gt 0) {
#     $docker_process[0].Kill()
#     Stop-Service -Name $docker_process
#     $docker_process[0].WaitForExit()
# }
# $docker_process = Get-Process "com.docker.proxy"
# if ($docker_process.Count -gt 0) {
#     $docker_process[0].Kill()
#     Stop-Service -Name $docker_process
#     $docker_process[0].WaitForExit()
# }
# $docker_process = Get-Process "docker"
# if ($docker_process.Count -gt 0) {
#     $docker_process[0].Kill()
#     Stop-Service -Name $docker_process
#     $docker_process[0].WaitForExit()
# }
# $docker_process = Get-Process "com.dockerd.service"
# if ($docker_process.Count -gt 0) {
#     $docker_process[0].Kill()
#     Stop-Service -Name $docker_process
#     $docker_process[0].WaitForExit()
# }
# $docker_process = Get-Process "com.dockerd.proxy"
# if ($docker_process.Count -gt 0) {
#     $docker_process[0].Kill()
#     Stop-Service -Name $docker_process
#     $docker_process[0].WaitForExit()
# }
# $docker_process = Get-Process "dockerd"
# if ($docker_process.Count -gt 0) {
#     $docker_process[0].Kill()
#     Stop-Service -Name $docker_process
#     $docker_process[0].WaitForExit()
# }
# wsl.exe --exec echo 'WSL successfully restarted';
# Start-Process "com.docker.service"
# Start-Process "com.docker.proxy"
# Start-Process "docker"
# Start-Service "com.docker.service"
# Start-Service "com.docker.proxy"
# Start-Service "docker"