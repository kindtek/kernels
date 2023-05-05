$argString = $args -join " "
$argArray = $argString.Split(" ")
for ($i = 0; $i -lt $argArray.Length; $i += 1) {
    $paramValue = $argArray[$i]
    if ( "$paramValue" -eq "" ) {
        $argArray[$i] = "`"`""
    }
    # write-host "param ${i}: $($argArray[$i])"
}


# wsl.exe -u agl -- $("$("/hal/dvlw/dvlp/docker/kali/make-kernel.sh $bashArgs")")
wsl.exe --cd /hal/dvlw/dvlp/kernels/linux exec ./install-kernel.sh "$($argArray[0])" "$($argArray[1])" "$($argArray[2])"
