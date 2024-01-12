# This only shows DisplayName, Path and Id to fit on screen.
param($Type, $Class)
Write-Host
Write-Host -ForegroundColor yellow "Getting class instances... "
Write-Host
Write-Host -ForegroundColor yellow "DISPLAY_NAME^PATH^ID"
if ($Type -eq "n") {
    $a=get-scomclass -name "$Class" | get-scomclassinstance | sort DisplayName
}
elseif ($Type -eq "d") {
    $a=get-scomclass -displayname "$Class" | get-scomclassinstance | sort DisplayName
}
foreach ($i in $a) {
	$d=$i.displayname
	$p=$i.path
	$i=$i.id
	write-host $d"^"$p"^"$i
	}
Write-Host
Write-Host "Count: " $a.count