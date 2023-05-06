# usage : ./make-kernel username # (will build basic kernel)
#         ./make-kernel username basic zfs nocache
#         ./make-kernel username latest 
#         ./make-kernel username stable "" path/to/config/file 


try {
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
            $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
            Start-Process -FilePath powershell.exe -Verb Runas -WindowStyle "Maximized" -ArgumentList $CommandLine
            Exit
        }
    }
}
catch {
    $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
    try {
        Start-Process -FilePath powershell.exe -ArgumentList $CommandLine
    }
    catch {}
}

$argString = $args -join " "
$argArray = $argString.Split(" ")
for ($i = 0; $i -lt $argArray.Length; $i += 1) {
    $paramValue = $argArray[$i]
    if ( "$paramValue" -eq "" ) {
        $argArray[$i] = "`"`""
    }
    # write-host "param ${i}: $($argArray[$i])"
}


wsl.exe --cd /hal/dvlw/dvlp/docker/kali exec ./make-kernel.sh "$($argArray[0])" "$($argArray[1])" "$($argArray[2])" "$($argArray[3])"