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