# This only shows Name, DisplayName and Id to fit on screen.
param($Type, $Class)
Write-Host
Write-Host -ForegroundColor yellow "Getting classes..."
if ($Type -eq "n") {
    Get-SCOMClass -Name "*$Class*" | sort Name | ft Name, DisplayName, Id -a
}
elseif ($Type -eq "d") {
    Get-SCOMClass -DisplayName "*$Class*" | sort DisplayName | ft DisplayName, Name, Id -au
}
elseif ($Type -eq "i") {
    Get-SCOMClass -id "$Class" | sort DisplayName | ft DisplayName, Name, Id -au
}

