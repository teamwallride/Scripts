param ($MpName)
$AllManagementPacks = Get-SCOMManagementPack
$MPToFind = $AllManagementPacks | where{$_.Name -eq $MpName}
$DependentMPs = @()
foreach($MP in $AllManagementPacks) {
$Dependent = $false
$MP.References | foreach{
if($_.Value.Name -eq $MPToFind.Name) { $Dependent = $true }
}
if($Dependent -eq $true) {
$DependentMPs+= $MP
}}
$DependentMPs | sort name | ft Name

