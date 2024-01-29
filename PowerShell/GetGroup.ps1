param($DisplayName)
Write-Host
Write-Host -ForegroundColor yellow "Getting groups..."
Get-SCOMGroup -DisplayName "*$DisplayName*" | sort DisplayName | ft DisplayName, FullName, Id -au