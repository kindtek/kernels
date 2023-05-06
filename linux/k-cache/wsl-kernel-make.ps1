# usage : ./make-kernel username # (will build basic kernel)
#         ./make-kernel username basic zfs nocache
#         ./make-kernel username latest 
#         ./make-kernel username stable "" path/to/config/file 


$argString = $args -join " "
$argArray = $argString.Split(" ")

for ($i = 0; $i -lt $argArray.Count; $i++) {
    if ($argArray[$i] -eq "") {
        $argArray[$i] = "`"`""
    }
}

$commandArgs = $argArray -join " "

wsl.exe --cd /hal/dvlw/dvlp/docker/kali exec ./make-kernel.sh $commandArgs
