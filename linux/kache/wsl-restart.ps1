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
unable to gain access required to completely restart WSL
manual restart may be required
consider opening a WINDOWS terminal *WITH* ADMIN priveleges and try the below command
.. or restart your computer


pro tip: 
to open an admin terminal to your home directory 

    1) [WIN + x] 
    2) [a]
    3) [<-] 
    4) [ENTER] 


to restart WSL at any time copy/pasta this while in your home directory:
    
    .\kache\wsl-restart



"
    $confirm_reboot = read-host -Prompt "
(try to reboot WSL anyways)
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

Start-Process -FilePath powershell.exe -ArgumentList '-Command "write-host `"H3LL0 W0RLD my home directory is $HOME $USERPROFILE`";'


Start-Process -FilePath powershell.exe -ArgumentList '-Command "&{
    $procs_kill = @(
        powershell.exe -Command { Get-Process docker* -ErrorAction SilentlyContinue | sort-object path -unique | ForEach-Object { $($_) } };  
        powershell.exe -Command { Get-Process wsl* -ErrorAction SilentlyContinue | sort-object path -unique | ForEach-Object { $($_) } };
    );
    $procs_start = @(
        powershell.exe -Command { Get-Process wsl* -ErrorAction SilentlyContinue | sort-object path -unique | ForEach-Object { $($_) } };
        powershell.exe -Command { Get-Process docker* -ErrorAction SilentlyContinue | sort-object path -unique | ForEach-Object { $($_) } };
    );
    # arrange services in proper startup/shutdown sequence
    # only add services that are running to kill queue
    $servs_kill = @(
        # queue docker to be killed first
        # powershell.exe -Command \"& Get-Service -Name docker* -ErrorAction SilentlyContinue | Where-Object { $_.Status -ieq `\`"running`\`" } \";
        powershell.exe -Command { Get-Service -Name docker* -ErrorAction SilentlyContinue };
        # kill wsl second
        powershell.exe -Command { Get-Service -Name wsl* -ErrorAction SilentlyContinue };
        # powershell.exe -Command \"& Get-Service -Name wsl* -ErrorAction SilentlyContinue | Where-Object { $_.Status -ieq `\`"running`\`" } \";
    );    $servs_kill | ForEach-Object {
        powershell.exe -Command `"& Set-Service -Name $($_) -Status Stopped -Force -ErrorAction SilentlyContinue `" | Out-Null;        powershell.exe -Command `"& Set-Service -Name $($_) -Status Stopped -ErrorAction SilentlyContinue `";        powershell.exe -Command `"& Set-Service -Name $($_) -StartupType Automatic -Force -ErrorAction SilentlyContinue `" | Out-Null;        powershell.exe -Command `"& Set-Service -Name $($_) -StartupType Automatic -ErrorAction SilentlyContinue `" ;powershell.exe -Command `"& Stop-Service -Name $($_) -Verbose `"; 

    };     $procs_kill | ForEach-Object {
        powershell.exe -Command `"& Stop-Process -PassThru -Id $($_.Id) -ErrorAction SilentlyContinue  -Verbose `";
    };    $servs_start = @(
        # queue wsl to start first
        powershell.exe -Command { Get-Service -Name wsl* -ErrorAction SilentlyContinue };
        powershell.exe -Command { Get-Service -Name docker* -ErrorAction SilentlyContinue };
    );    
    $servs_start | ForEach-Object {
            powershell.exe -Command \"& { Start-Service -Name $($_) -ErrorAction SilentlyContinue  -Verbose } \" 
    };    
    powershell.exe -Command wsl.exe --exec echo \"docker and wsl were successfully restarted\" ;  
    powershell.exe -Command \"& { Start-Sleep -Seconds 8 } \" ;
    $procs_start | ForEach-Object { 
        powershell.exe -Command `"& Start-Process -FilePath \`\"$($_.Path)\`\" -Wait -ErrorAction SilentlyContinue -Verbose `" 
    };
    Read-Host 
}"' -ErrorAction SilentlyContinue 





# $servs_start | ForEach-Object {  powershell.exe -Command "& {Start-Service -Name "$($_)" -verbose}" }; `

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