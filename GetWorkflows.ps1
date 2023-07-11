<#
.SYNOPSIS
Exports all rules, monitors and discoveries to a csv file.
.DESCRIPTION
This script will export config settings for all rules, monitors and discoveries from the currently connected management group.
You will need to update these variables:
$OutDir=CSV_Folder_Path
This has been tested on the following SCOM versions:
- 2016
.NOTES
2022.4.5.0 - Initial release.
#>
# Output Directory
$OutDir="D:\Scripts"
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
Write-Host "Getting rules..."
$Rules=Get-SCOMRule
# Get GenerateAlert WriteAction module
$HealthMP=Get-SCOMManagementPack -Name "System.Health.Library"
$AlertWA=$HealthMP.GetModuleType("System.Health.GenerateAlert")
$AlertWAID=$AlertWA.Id
$Hash=""
$Hash=@{}
$Classes=Get-SCOMClass
foreach($Class in $Classes){
[string]$ClassId=$Class.Id
[string]$ClassDisplayName=$Class.DisplayName
[string]$ClassName=$Class.Name
[string]$ClassMPDisplayName=$Class.GetManagementPack().DisplayName
[string]$ClassMPName=$Class.GetManagementPack().Name
[string]$ClassMPFriendlyName=$Class.GetManagementPack().FriendlyName
[string]$ClassMPVersion=$Class.GetManagementPack().Version
[string]$ClassMPKeyToken=$Class.GetManagementPack().KeyToken
$Hash+=@{$ClassId=@($ClassDisplayName, $ClassName, $ClassMPDisplayName, $ClassMPName, $ClassMPFriendlyName, $ClassMPVersion, $ClassMPKeyToken)}
}
FOREACH ($Rule in $Rules) {
[string]$RuleName=$Rule.Name
[string]$RuleDisplayName=$Rule.DisplayName
[string]$RuleHasOverride=$Rule.HasNonCategoryOverride
[string]$RuleMPName=$Rule.GetManagementPack().Name
[string]$RuleMPDisplayName=$Rule.GetManagementPack().DisplayName
[string]$RuleMPFriendlyName=$Rule.GetManagementPack().FriendlyName
[string]$RuleMPVersion=$Rule.GetManagementPack().Version
[string]$RuleMPKeyToken=$Rule.GetManagementPack().KeyToken
[string]$RuleClassId=$Rule.Target.Id.Guid
[string]$RuleClassName=$Hash[$RuleClassId][1]
[string]$RuleClassDisplayName=$Hash[$RuleClassId][0]
[string]$RuleClassMPName=$Hash[$RuleClassId][3]
[string]$RuleClassMPDisplayName=$Hash[$RuleClassId][2]
[string]$RuleClassMPFriendlyName=$Hash[$RuleClassId][4]
[string]$RuleClassMPVersion=$Hash[$RuleClassId][5]
[string]$RuleClassMPKeyToken=$Hash[$RuleClassId][6]
[string]$Category=$Rule.Category
[string]$Enabled=$Rule.Enabled
IF ($Enabled -eq "onEssentialMonitoring") {$Enabled="TRUE"}
IF ($Enabled -eq "onStandardMonitoring") {$Enabled="TRUE"}
$MP=$Rule.GetManagementPack()
[string]$RuleDS=$Rule.DataSourceCollection.TypeID.Identifier.Path
[string]$Description=$Rule.Description
#WriteAction Section
$GenAlert=$false
$AlertDisplayName=""
$AlertPriority=""
$AlertSeverity=""
$WA=$Rule.writeactioncollection
#Inspect each WA module to see if it contains a System.Health.GenerateAlert module
FOREACH ($WAModule in $WA)
{
$WAId=$WAModule.TypeId.Id
IF ($WAId -eq $AlertWAID)
{
#this rule generates alert using System.Health.GenerateAlert module
$GenAlert=$true
#Get the module configuration
[string]$WAModuleConfig=$WAModule.Configuration
#Assign the module configuration the XML type and encapsulate it to make it easy to retrieve values
[xml]$WAModuleConfigXML="<Root>" + $WAModuleConfig + "</Root>"
$WAXMLRoot=$WAModuleConfigXML.Root
#Get the Alert Display Name from the AlertMessageID and MP
$AlertName=$WAXMLRoot.AlertMessageId.Split('"')[1]
IF (!($AlertName))
{
$AlertName=$WAXMLRoot.AlertMessageId.Split("'")[1]
}
$AlertDisplayName=$MP.GetStringResource($AlertName).DisplayName
#Get Alert Priority and Severity
$AlertPriority=$WAXMLRoot.Priority
$AlertPriority=switch($AlertPriority)
{
"0" {"Low"}
"1" {"Medium"} 
"2" {"High"}
}
$AlertSeverity=$WAXMLRoot.Severity
$AlertSeverity=switch($AlertSeverity)
{
"0" {"Information"}
"1" {"Warning"} 
"2" {"Critical"}
}
} 
ELSE 
{
#need to detect if it's using a Custom Composite WA which contains System.Health.GenerateAlert module
$WASource=$MG.GetMonitoringModuleType($WAId)
#Check each write action member modules in the customized write action module...
FOREACH ($Item in $WASource.WriteActionCollection)
{
$ItemId=$Item.TypeId.Id
IF ($ItemId -eq $AlertWAId)
{
$GenAlert=$true
#Get the module configuration
[string]$WAModuleConfig=$WAModule.Configuration
#Assign the module configuration the XML type and encapsulate it to make it easy to retrieve values
[xml]$WAModuleConfigXML="<Root>" + $WAModuleConfig + "</Root>"
$WAXMLRoot=$WAModuleConfigXML.Root
#Get the Alert Display Name from the AlertMessageID and MP
$AlertName=$WAXMLRoot.AlertMessageId.Split('"')[1]
IF (!($AlertName))
{
$AlertName=$WAXMLRoot.AlertMessageId.Split("'")[1]
}
$AlertDisplayName=$MP.GetStringResource($AlertName).DisplayName
#Get Alert Priority and Severity
$AlertPriority=$WAXMLRoot.Priority
$AlertPriority=switch($AlertPriority)
{
"0" {"Low"}
"1" {"Medium"} 
"2" {"High"}
}
$AlertSeverity=$WAXMLRoot.Severity
$AlertSeverity=switch($AlertSeverity)
{
"0" {"Information"}
"1" {"Warning"} 
"2" {"Critical"}
}
}
}
}
}
#Create generic object and assign values  
$obj=New-Object -TypeName psobject
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_NAME" -Value $RuleName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_DISPLAYNAME" -Value $RuleDisplayName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_TYPE" -Value "Rule"
$obj | Add-Member -Type NoteProperty -Name "ENABLED" -Value $Enabled
$obj | Add-Member -Type NoteProperty -Name "GENERATE_ALERT" -Value $GenAlert
$obj | Add-Member -Type NoteProperty -Name "HAS_OVERRIDE" -Value $RuleHasOverride
$obj | Add-Member -Type NoteProperty -Name "CATEGORY" -Value $Category
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_NAME" -Value $RuleMPName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_DISPLAYNAME" -Value $RuleMPDisplayName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_FRIENDLYNAME" -Value $RuleMPFriendlyName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_VERSION" -Value $RuleMPVersion
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_KEYTOKEN" -Value $RuleMPKeyToken
$obj | Add-Member -Type NoteProperty -Name "CLASS_NAME" -Value $RuleClassName
$obj | Add-Member -Type NoteProperty -Name "CLASS_DISPLAYNAME" -Value $RuleClassDisplayName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_NAME" -Value $RuleClassMPName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_DISPLAYNAME" -Value $RuleClassMPDisplayName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_FRIENDLYNAME" -Value $RuleClassMPFriendlyName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_VERSION" -Value $RuleClassMPVersion
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_KEYTOKEN" -Value $RuleClassMPKeyToken
$obj | Add-Member -Type NoteProperty -Name "DATASOURCE" -Value $RuleDS
$obj | Add-Member -Type NoteProperty -Name "CLASSIFICATION" -Value $MonitorClassification
$obj | Add-Member -Type NoteProperty -Name "ALERT_NAME" -Value $AlertDisplayName
$obj | Add-Member -Type NoteProperty -Name "ALERT_PRIORITY" -Value $AlertPriority
$obj | Add-Member -Type NoteProperty -Name "ALERT_SEVERITY" -Value $AlertSeverity
$obj | Add-Member -Type NoteProperty -Name "MONITOR_TYPE" -Value "NA"
$obj | Add-Member -Type NoteProperty -Name "DESCRIPTION" -Value $Description
$Output += $obj
}
# Get all the SCOM Monitors
Write-Host "Getting monitors..."
$Monitors= Get-SCOMMonitor
#Loop through each monitor and get properties
FOREACH ($Monitor in $Monitors)
{
[string]$MonitorName=$Monitor.Name
[string]$MonitorDisplayName=$Monitor.DisplayName
[string]$MonitorHasOverride=$Monitor.HasNonCategoryOverride
[string]$MonitorMPName=$Monitor.GetManagementPack().Name
[string]$MonitorMPDisplayName=$Monitor.GetManagementPack().DisplayName
[string]$MonitorMPFriendlyName=$Monitor.GetManagementPack().FriendlyName
[string]$MonitorMPVersion=$Monitor.GetManagementPack().Version
[string]$MonitorMPKeyToken=$Monitor.GetManagementPack().KeyToken
[string]$MonitorClassId=$Monitor.Target.Id.Guid
[string]$MonitorClassName=$Hash[$MonitorClassId][1]
[string]$MonitorClassDisplayName=$Hash[$MonitorClassId][0]
[string]$MonitorClassMPName=$Hash[$MonitorClassId][3]
[string]$MonitorClassMPDisplayName=$Hash[$MonitorClassId][2]
[string]$MonitorClassMPFriendlyName=$Hash[$MonitorClassId][4]
[string]$MonitorClassMPVersion=$Hash[$MonitorClassId][5]
[string]$MonitorClassMPKeyToken=$Hash[$MonitorClassId][6]
[string]$Category=$Monitor.Category
[string]$Enabled=$Monitor.Enabled
IF ($Enabled -eq "onEssentialMonitoring") {$Enabled="TRUE"}
IF ($Enabled -eq "onStandardMonitoring") {$Enabled="TRUE"}
$MP=$Monitor.GetManagementPack()
#[string]$MPDisplayName=$MP.DisplayName
#[string]$MPName=$MP.Name
[string]$MonitorClassification=$Monitor.XmlTag
[string]$MonitorType=$Monitor.TypeID.Identifier.Path
[string]$Description=$Monitor.Description
# Get the Alert Settings for the Monitor
$AlertSettings=$Monitor.AlertSettings
$GenAlert=""
$AlertDisplayName=""
$AlertSeverity=""
$AlertPriority=""
$AutoResolve=""
IF (!($AlertSettings))
{
$GenAlert=$false
}
ELSE
{
$GenAlert=$true
#Get the Alert Display Name from the AlertMessageID and MP
$AlertName= $AlertSettings.AlertMessage.Identifier.Path
$AlertDisplayName=$MP.GetStringResource($AlertName).DisplayName    
$AlertSeverity=$AlertSettings.AlertSeverity
IF ($AlertSeverity -eq "MatchMonitorHealth") {$AlertSeverity=$AlertSettings.AlertOnState}
IF ($AlertSeverity -eq "Error") {$AlertSeverity="Critical"}
$AlertPriority=$AlertSettings.AlertPriority
IF ($AlertPriority -eq "Normal") {$AlertPriority="Medium"}
$AutoResolve=$AlertSettings.AutoResolve
}
#Create generic object and assign values  
$obj=New-Object -TypeName psobject
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_NAME" -Value $MonitorName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_DISPLAYNAME" -Value $MonitorDisplayName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_TYPE" -Value "Monitor"
$obj | Add-Member -Type NoteProperty -Name "ENABLED" -Value $Enabled
$obj | Add-Member -Type NoteProperty -Name "GENERATE_ALERT" -Value $GenAlert
$obj | Add-Member -Type NoteProperty -Name "HAS_OVERRIDE" -Value $MonitorHasOverride
$obj | Add-Member -Type NoteProperty -Name "CATEGORY" -Value $Category
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_NAME" -Value $MonitorMPName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_DISPLAYNAME" -Value $MonitorMPDisplayName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_FRIENDLYNAME" -Value $MonitorMPFriendlyName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_VERSION" -Value $MonitorMPVersion
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_KEYTOKEN" -Value $MonitorMPKeyToken
$obj | Add-Member -Type NoteProperty -Name "CLASS_NAME" -Value $MonitorClassName
$obj | Add-Member -Type NoteProperty -Name "CLASS_DISPLAYNAME" -Value $MonitorClassDisplayName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_NAME" -Value $MonitorClassMPName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_DISPLAYNAME" -Value $MonitorClassMPDisplayName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_FRIENDLYNAME" -Value $MonitorClassMPFriendlyName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_VERSION" -Value $MonitorClassMPVersion
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_KEYTOKEN" -Value $MonitorClassMPKeyToken
$obj | Add-Member -Type NoteProperty -Name "DATASOURCE" -Value "NA"
$obj | Add-Member -Type NoteProperty -Name "CLASSIFICATION" -Value $MonitorClassification
$obj | Add-Member -Type NoteProperty -Name "ALERT_NAME" -Value $AlertDisplayName
$obj | Add-Member -Type NoteProperty -Name "ALERT_PRIORITY" -Value $AlertPriority
$obj | Add-Member -Type NoteProperty -Name "ALERT_SEVERITY" -Value $AlertSeverity
$obj | Add-Member -Type NoteProperty -Name "MONITOR_TYPE" -Value $MonitorType
$obj | Add-Member -Type NoteProperty -Name "DESCRIPTION" -Value $Description
$Output += $obj
}
# Get all the SCOM Discoveries
Write-Host "Getting discoveries..."
$Discoveries= Get-SCOMDiscovery
#Loop through each Discovery and get properties
FOREACH ($Discovery in $Discoveries)
{
[string]$DiscoveryName=$Discovery.Name
[string]$DiscoveryDisplayName=$Discovery.DisplayName
[string]$DiscoveryHasOverride=$Discovery.HasNonCategoryOverride
[string]$DiscoveryMPName=$Discovery.GetManagementPack().Name
[string]$DiscoveryMPDisplayName=$Discovery.GetManagementPack().DisplayName
[string]$DiscoveryMPFriendlyName=$Discovery.GetManagementPack().FriendlyName
[string]$DiscoveryMPVersion=$Discovery.GetManagementPack().Version
[string]$DiscoveryMPKeyToken=$Discovery.GetManagementPack().KeyToken
[string]$DiscoveryClassId=$Discovery.Target.Id.Guid
[string]$DiscoveryClassName=$Hash[$DiscoveryClassId][1]
[string]$DiscoveryClassDisplayName=$Hash[$DiscoveryClassId][0]
[string]$DiscoveryClassMPName=$Hash[$DiscoveryClassId][3]
[string]$DiscoveryClassMPDisplayName=$Hash[$DiscoveryClassId][2]
[string]$DiscoveryClassMPFriendlyName=$Hash[$DiscoveryClassId][4]
[string]$DiscoveryClassMPVersion=$Hash[$DiscoveryClassId][5]
[string]$DiscoveryClassMPKeyToken=$Hash[$DiscoveryClassId][6]
[string]$Category=$Discovery.Category
[string]$Enabled=$Discovery.Enabled
[string]$DataSource=$Discovery.DataSource
[string]$Description=$Discovery.Description
#Create generic object and assign values  
$obj=New-Object -TypeName psobject
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_NAME" -Value $DiscoveryName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_DISPLAYNAME" -Value $DiscoveryDisplayName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_TYPE" -Value "Discovery"
$obj | Add-Member -Type NoteProperty -Name "ENABLED" -Value $Enabled
$obj | Add-Member -Type NoteProperty -Name "GENERATE_ALERT" -Value "NA"
$obj | Add-Member -Type NoteProperty -Name "HAS_OVERRIDE" -Value $DiscoveryHasOverride
$obj | Add-Member -Type NoteProperty -Name "CATEGORY" -Value $Category
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_NAME" -Value $DiscoveryMPName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_DISPLAYNAME" -Value $DiscoveryMPDisplayName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_FRIENDLYNAME" -Value $DiscoveryMPFriendlyName
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_VERSION" -Value $DiscoveryMPVersion
$obj | Add-Member -Type NoteProperty -Name "WORKFLOW_MP_KEYTOKEN" -Value $DiscoveryMPKeyToken
$obj | Add-Member -Type NoteProperty -Name "CLASS_NAME" -Value $DiscoveryClassName
$obj | Add-Member -Type NoteProperty -Name "CLASS_DISPLAYNAME" -Value $DiscoveryClassDisplayName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_NAME" -Value $DiscoveryClassMPName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_DISPLAYNAME" -Value $DiscoveryClassMPDisplayName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_FRIENDLYNAME" -Value $DiscoveryClassMPFriendlyName
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_VERSION" -Value $DiscoveryClassMPVersion
$obj | Add-Member -Type NoteProperty -Name "CLASS_MP_KEYTOKEN" -Value $DiscoveryClassMPKeyToken  
$obj | Add-Member -Type NoteProperty -Name "DATASOURCE" -Value $DataSource
$obj | Add-Member -Type NoteProperty -Name "CLASSIFICATION" -Value "NA"
$obj | Add-Member -Type NoteProperty -Name "ALERT_NAME" -Value "NA"
$obj | Add-Member -Type NoteProperty -Name "ALERT_PRIORITY" -Value "NA"
$obj | Add-Member -Type NoteProperty -Name "ALERT_SEVERITY" -Value "NA"
$obj | Add-Member -Type NoteProperty -Name "MONITOR_TYPE" -Value "NA"
$obj | Add-Member -Type NoteProperty -Name "DESCRIPTION" -Value $Description
$Output += $obj
}
Write-Host
Write-Host -foregroundcolor yellow "Writing output to $OutDir\SCOM_Workflows_$MGName.csv"
Write-Host
$Output | Export-Csv $OutDir\SCOM_Workflows_$MGName.csv -NotypeInformation
