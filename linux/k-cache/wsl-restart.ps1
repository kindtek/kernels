$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

try {
    # Self-elevate the privileges
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
            $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
            Start-Process -FilePath PowerShell.exe -Verb Runas -WindowStyle "Maximized" -ArgumentList $CommandLine
            Exit
        }
    }
}
catch {
    write-host "
Oooops... unable to gain access required to completely restart WSL

recommendation:
    use WIN + x, a to open a *windows* terminal with *admin* priveleges
    to your home directory and copy/pasta this:
    
        .\k-cache\wsl-restart

"
    $confirm_reboot = read-host -Prompt "
(reboot WSL anyways)
" 
    if ( "$confirm_reboot" -ne "" ) {
        exit
    }

}
Write-Host "

"
write-host -n "attempting to restart wsl"


if ($IsLinux) {
    write-host -n " from within WSL Linux distro"
}
else {
    if ($IsWindows) {
        write-host -n " from within native Windows
"    
    }
    else {
        write-host -n " from within unlabeled environment
"    
    }
}

$procs_kill = @(
    powershell.exe -Command { Get-Process docker* -ErrorAction SilentlyContinue | sort-object path -unique | ForEach-Object { $($_) } | Where-Object { $_.Path -imatch '^C:\\.*\.exe$' } }
    powershell.exe -Command { Get-Process wsl* -ErrorAction SilentlyContinue | sort-object path -unique | ForEach-Object { $($_) } | Where-Object { $_.Path -imatch '^C:\\.*\.exe$' } } 
)
$procs_start = @(
    powershell.exe -Command { Get-Process wsl* -ErrorAction SilentlyContinue | sort-object path -unique | ForEach-Object { $($_) } | Where-Object { $_.Path -imatch '^C:\\.*\.exe$' } }
    powershell.exe -Command { Get-Process docker* -ErrorAction SilentlyContinue | sort-object path -unique | ForEach-Object { $($_) } |  Where-Object { $_.Path -imatch '^C:\\.*\.exe$' } } 
)


# arrange services in proper startup/shutdown sequence
# only add services that are running to kill queue
$servs_kill = @(
    # kill docker first
    powershell.exe -Command { Get-Service -Name docker* -ErrorAction SilentlyContinue | Where-Object { $_.Status -ieq 'running' } }
    # kill wsl second
    powershell.exe -Command { Get-Service -Name wsl* -ErrorAction SilentlyContinue | Where-Object { $_.Status -ieq 'running' } }
)

# add all related services to start queue (reverse order)
$servs_start = @(
    # start wsl first
    powershell.exe -Command { Get-Service -Name wsl* -ErrorAction SilentlyContinue }
    powershell.exe -Command { Get-Service -Name docker* -ErrorAction SilentlyContinue }
)

$servs_kill | ForEach-Object { powershell.exe -Command "& {Stop-Service -Name "$($_)" -verbose}" }; $servs_start | ForEach-Object { powershell.exe -Command "& {Start-Service -Name "$($_)" -verbose}" }; powershell.exe -Command wsl.exe --exec echo 'docker and wsl were successfully restarted';

# $procs_kill |  ForEach-Object { powershell.exe -Command "& {Stop-Process -Force -PassThru -Id "$($_.Id)" -Verbose}" }; `
# $servs_start | ForEach-Object {  powershell.exe -Command "& {Start-Service -Name "$($_)" -verbose}" }; `
# $procs_start |  ForEach-Object { powershell.exe -Command "& {Start-Process -FilePath "$($_.Path)" -ArgumentList '-verbose -verb RunAsUser -NoNewWindow -PassThru'}" }; 

# $servs_kill | ForEach-Object { [void]( (write-host "killing service: $($_.Name)") -or (powershell.exe -Command { "& {Stop-Service -Name $_ -verbose}" } ) ) };
# $procs_kill |  ForEach-Object { [void]( (write-host "killing process: $($_.Name)") -or (powershell.exe -Command { "& {Stop-Process -Force -PassThru -Id $_.Id -Verbose}" } ) ) }; 
# $servs_start | ForEach-Object { [void]( (write-host "starting service: $($_.Name)") -or (powershell.exe -Command { "& {Start-Service -Name $_ -verbose}" } ) ) };
# $procs_start |  ForEach-Object { [void]( (write-host "starting process: $($_.Name)") -or (powershell.exe -Command { "& {Start-Process -FilePath $_.Path -ArgumentList '-verbose -verb RunAsUser -NoNewWindow -PassThru'}" } )) }; 


# run this for testing
# $servs_kill | ForEach-Object { powershell.exe -Command "& {Stop-Service $_ -whatif }" }; $servs_start | ForEach-Object { powershell.exe -Command "& {Start-Service $_ -whatif }" }; 


Write-Host "









"
Write-Host "(done)
" -NoNewline
Read-Host