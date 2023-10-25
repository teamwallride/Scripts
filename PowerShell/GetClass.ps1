param($Type, $Class)
Write-Host
Write-Host -ForegroundColor yellow "Searching for class:" $Class "(sorted by 1st column)"
if ($Type -eq "n")
{
Get-SCOMClass -Name "*$Class*" | sort Name | ft Name, DisplayName, ManagementPackName, Abstract, Hosted, Id -au
}
elseif ($Type -eq "d")
{
Get-SCOMClass -DisplayName "*$Class*" | sort DisplayName | ft DisplayName, Name, ManagementPackName, Abstract, Hosted, Id -au
}
elseif ($Type -eq "i")
{
Get-SCOMClass -id "$Class" | sort DisplayName | ft DisplayName, Name, ManagementPackName, Abstract, Hosted, Id -au
}

