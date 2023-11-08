param ($MpName, $OutDir)
Get-SCOMManagementPack -Name $MpName | Export-SCOMManagementPack -Path $OutDir