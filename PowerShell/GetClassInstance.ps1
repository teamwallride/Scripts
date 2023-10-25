param($Type, $Class)
Write-Host
Write-Host -ForegroundColor yellow "Looking for instances:" $Class
Write-Host
if ($Type -eq "n")
{
$a = get-scomclass -name "$Class" | get-scomclassinstance | sort displayname
}
elseif ($Type -eq "d")
{
$a = get-scomclass -displayname "$Class" | get-scomclassinstance | sort displayname
}
foreach ($i in $a) {write-host $i.displayname","$i.path","$i.id}
write-host
write-host "Count: " $a.count