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
manual WSL restart may be required
.. or restart your computer


to manually restart WSL only:

1)  open a windows shell *WITH* ADMIN privileges
        
        shortcut: 
            - [WIN + X] then [a]    (opens admin window)
            - [<-] then [ENTER]     (confirm elevated access privileges)


2)  copypasta this:
    
    .\wsl-restart



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
        write-host -n " from within a new environment
"    
    }
}
$procs_start = @(
    # powershell.exe -Command { Get-Process wsl* -ErrorAction SilentlyContinue | sort-object path -unique | ForEach-Object { $($_) } };
    powershell.exe -Command { Get-Process docker* -ErrorAction SilentlyContinue | sort-object path -unique | ForEach-Object { $($_) } };
);
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
    );
    wsl.exe --shutdown;
    $servs_kill | ForEach-Object {
        powershell.exe -Command `"& Set-Service -Name $($_) -Status Stopped -Force -ErrorAction SilentlyContinue `" | Out-Null;powershell.exe -Command `"& Set-Service -Name $($_) -Status Stopped -ErrorAction SilentlyContinue `";powershell.exe -Command `"& Set-Service -Name $($_) -StartupType Automatic -Force -ErrorAction SilentlyContinue `" | Out-Null;powershell.exe -Command `"& Set-Service -Name $($_) -StartupType Automatic -ErrorAction SilentlyContinue `" ;powershell.exe -Command `"& Stop-Service -Name $($_) -Verbose `"; 
    };
    # powershell.exe -Command \"& { Start-Sleep -Seconds 8 } \" ;
    $procs_kill | ForEach-Object {
        powershell.exe -Command `"& Stop-Process -PassThru -Id $($_.Id) -ErrorAction SilentlyContinue  -Verbose `";
    };
    powershell.exe -Command { Start-Sleep -Seconds 8 };
    $servs_start = @(
        # queue wsl to start first
        powershell.exe -Command { Get-Service -Name wsl* -ErrorAction SilentlyContinue };
        powershell.exe -Command { Get-Service -Name docker* -ErrorAction SilentlyContinue };
    );
    $servs_start | ForEach-Object {
        powershell.exe -Command \"& { Start-Service -Name `\"$($_)`\" -ErrorAction SilentlyContinue  -Verbose } \";
    };
    $procs_start | ForEach-Object { 
        powershell.exe -Command { Start-Process -FilePath \"$($_.Path)\" -ArgumentList \"-ErrorAction SilentlyContinue -Verbose -Wait\" };
    };  
    powershell.exe -Command \"& { Start-Service -Name `\"com.docker.service`\" -ErrorAction SilentlyContinue  -Verbose } \";
    powershell.exe -Command wsl.exe --exec echo \"docker and WSL were successfully restarted\"; 
}"' -Wait -ErrorAction SilentlyContinue 


wsl.exe --exec echo "waiting for docker and WSL to fully come back online ...";
powershell.exe -Command { Start-Sleep -Seconds 8 };
wsl.exe --exec echo "attempting to restart processes ...";

powershell.exe -Command {
    $procs_start | ForEach-Object { 
        Start-Process -FilePath "$($_.Path)" -ArgumentList "-Verbose -Wait" ;
    };
};
# powershell.exe -Command {
#     $procs_start | ForEach-Object { 
#         powershell.exe -Command "& { 
#             Start-Process -FilePath `"$($_.Path)`" -ArgumentList `"-ErrorAction SilentlyContinue -Verbose`"
#         }";
#     };
# };
# powershell.exe -Command '{
#     $procs_start | ForEach-Object { 
#         powershell.exe -Command \"& { 
#             Start-Process -FilePath `\"$($_.Path)`\" -ArgumentList `\"-ErrorAction SilentlyContinue -Verbose`\"
#         }\"
#     };
# }';
# powershell.exe -Command {
# $procs_start | ForEach-Object { 
#     powershell.exe -Command \"& { 
#         Start-Process -FilePath `\"$($_.Path)`\" -ArgumentList `\"-ErrorAction SilentlyContinue -Verbose`\"
#     }\"
# };
# };
# $servs_start | ForEach-Object {  powershell.exe -Command "& {Start-Service -Name "$($_)" -verbose}" }; `

# $servs_kill | ForEach-Object { [void]( (write-host "killing service: $($_.Name)") -or (powershell.exe -Command { "& {Stop-Service -Name $_ -verbose}" } ) ) };
# $procs_kill |  F
# forEach-Object { [void]( (write-host "killing process: $($_.Name)") -or (powershell.exe -Command { "& {Stop-Process -Force -PassThru -Id $_.Id -Verbose}" } ) ) }; 
# $servs_start | ForEach-Object { [void]( (write-host "starting service: $($_.Name)") -or (powershell.exe -Command { "& {Start-Service -Name $_ -verbose}" } ) ) };
# $procs_start |  ForEach-Object { [void]( (write-host "starting process: $($_.Name)") -or (powershell.exe -Command { "& {Start-Process -FilePath $_.Path -ArgumentList '-verbose -verb RunAsUser -NoNewWindow -PassThru'}" } )) }; 


# run this for testing
# $servs_kill | ForEach-Object { powershell.exe -Command "& {Stop-Service $_ -whatif }" }; $servs_start | ForEach-Object { powershell.exe -Command "& {Start-Service $_ -whatif }" }; 


Write-Host "









"
if ($IsLinux) {
    Write-Host "(done)
" -NoNewline
    Read-Host
}