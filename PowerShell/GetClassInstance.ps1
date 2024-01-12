# This only shows DisplayName, Path and Id to fit on screen.
param($Type, $Class)
Write-Host
Write-Host -ForegroundColor yellow "Getting class instances..."
if ($Type -eq "n") {
    get-scomclass -name "$Class" | get-scomclassinstance | sort Name | ft DisplayName, Path, Id -au
}
elseif ($Type -eq "d") {
    get-scomclass -displayname "$Class" | get-scomclassinstance | sort Name | ft DisplayName, Path, Id -au
}
foreach ($i in $a) { write-host $i.displayname"^"$i.path"^"$i.id }
write-host
write-host "Count: " $a.count