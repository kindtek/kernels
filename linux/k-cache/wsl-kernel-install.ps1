$argString = $args -join " "
$argArray = $argString.Split(" ")
$bashArgs = ""
for ($i = 0; $i -lt $argArray.Length; $i += 1) {
    $paramValue = $argArray[$i]
    $bashArgs += " `'"
    $bashArgs += ${paramValue}
    $bashArgs += "`' "
}
Write-Output wsl.exe -- $bashArgs


# wsl.exe -u agl -- $("$("/hal/dvlw/dvlp/docker/kali/make-kernel.sh $bashArgs")")
wsl.exe --cd /hal/dvlw/dvlp/kernels/linux exec bash -c ./install-kernel.sh $argArray[0] $argArray[1] $argArray[2]
