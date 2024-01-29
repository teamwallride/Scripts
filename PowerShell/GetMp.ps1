# This only shows Name, DisplayName and Sealed to fit on screen.
param($Type, $Mp)
Write-Host
Write-Host -ForegroundColor yellow "Getting management packs..."
if ($Type -eq "n") {
    Get-SCOMManagementPack -Name "*$Mp*" | sort Name | ft Name, DisplayName, Version, Sealed -au
}
elseif ($Type -eq "d") {
    Get-SCOMManagementPack -DisplayName "*$Mp*" | sort DisplayName | ft DisplayName, Name, Version, Sealed -au
}