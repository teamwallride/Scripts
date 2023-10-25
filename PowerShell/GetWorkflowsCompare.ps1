<#
The intention of the script is to see what has changed in new mgmt packs that you want to import to production.
It assumes you have 2 mgmt groups: Test mgmt group (new mgmt packs imported), Prod mgmt group (old mgmt packs imported).
It extracts required fields from all discoveries, monitors and rules from a mgmt group and dumps to a csv.
You then use Excel to filter on mp name and compare columns to see changes.
==========
CHANGE LOG
==========
2023.7.27.0
-Initial release.
#>
Function GetWorkflows ($WorkflowType) {
$WorkflowType
Switch ($WorkflowType) {
"Discovery" {$Workflows=Get-SCOMDiscovery; BREAK}
"Monitor" {$Workflows=Get-SCOMMonitor; BREAK}
"Rule" {$Workflows=Get-SCOMRule; BREAK}
}
foreach ($Workflow in $Workflows) {
$obj=New-Object -TypeName psobject
$MPName=$Workflow.GetManagementPack().Name
$Name=$Workflow.Name
$Enabled=$Workflow.Enabled
$NonCategoryOverride=$Workflow.HasNonCategoryOverride
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_NAME" -Value $MPName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_NAME" -Value "$WorkflowType`_$Name`_$Enabled`_$NonCategoryOverride"
$Script:Output+=$obj
}
}
$OutDir="C:\temp"
IF (!(Test-Path $OutDir))
{
Write-Host "Output folder not found.  Creating folder..." -ForegroundColor Magenta
md $OutDir
}
Write-Host
Write-Host "Output path is $OutDir"
$Output=@()
# Connect to SCOM
Write-Host "Connecting to local SCOM Management Server..."
$MG=Get-SCOMManagementGroup
$MGName=$MG.Name
$Script:Output=@()
GetWorkflows -WorkflowType "Discovery"
GetWorkflows -WorkflowType "Monitor"
GetWorkflows -WorkflowType "Rule"
$Output | Export-Csv $OutDir\SCOM_Workflows_Compare_$MGName.csv -NotypeInformation
