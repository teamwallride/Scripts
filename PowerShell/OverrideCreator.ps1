param($MpImportFile)

# Disable rule/monitor.
Function EnableOrDisableWorkflow {
$Script:GUID=[guid]::NewGuid().ToString("N")
$Script:ID="OverrideFor$Script:WORKFLOW_TYPE$Script:WORKFLOW_NAME_COMPACT$Script:GUID"
$Script:OUTPUT_OVERRIDES+="<$Script:WORKFLOW_TYPE`PropertyOverride ID=""$Script:ID"" Context=""$Script:CLASS_MP_NAME_ALIAS!$Script:CLASS_NAME"" Enforced=""$Script:ENFORCED_VALUE"" $Script:WORKFLOW_TYPE=""$Script:WORKFLOW_MP_NAME_ALIAS!$Script:WORKFLOW_NAME"" Property=""Enabled""><Value>$Script:ENABLED_VALUE</Value></$Script:WORKFLOW_TYPE`PropertyOverride>"
if (-not ($Script:Hash.ContainsKey($Script:WORKFLOW_MP_NAME_ALIAS))) {
$Script:Hash+=@{$Script:WORKFLOW_MP_NAME_ALIAS=@($Script:WORKFLOW_MP_NAME, $Script:WORKFLOW_MP_VERSION, $Script:WORKFLOW_MP_KEYTOKEN)}
} 
if (-not ($Script:Hash.ContainsKey($Script:CLASS_MP_NAME_ALIAS))) {
$Script:Hash+=@{$Script:CLASS_MP_NAME_ALIAS=@($Script:CLASS_MP_NAME, $Script:CLASS_MP_VERSION, $Script:CLASS_MP_KEYTOKEN)}
}
}

# Enable rule/monitor targeting group.
Function EnableGroup {
$Script:GUID=[guid]::NewGuid().ToString("N")
$Script:ID="OverrideFor$Script:WORKFLOW_TYPE$Script:WORKFLOW_NAME_COMPACT$Script:GUID"
$Script:OUTPUT_OVERRIDES+="<$Script:WORKFLOW_TYPE`PropertyOverride ID=""$Script:ID"" Context=""Cmdb!$Script:GroupName"" ContextInstance=""$Script:GroupId"" Enforced=""$Script:ENFORCED_VALUE"" $Script:WORKFLOW_TYPE=""$Script:WORKFLOW_MP_NAME_ALIAS!$Script:WORKFLOW_NAME"" Property=""Enabled""><Value>$Script:ENABLED_VALUE</Value></$Script:WORKFLOW_TYPE`PropertyOverride>"
if (-not ($Script:Hash.ContainsKey($Script:WORKFLOW_MP_NAME_ALIAS))) {
$Script:Hash+=@{$Script:WORKFLOW_MP_NAME_ALIAS=@($Script:WORKFLOW_MP_NAME, $Script:WORKFLOW_MP_VERSION, $Script:WORKFLOW_MP_KEYTOKEN)}
} 
if (-not ($Script:Hash.ContainsKey($Script:CLASS_MP_NAME_ALIAS))) {
$Script:Hash+=@{$Script:CLASS_MP_NAME_ALIAS=@($Script:CLASS_MP_NAME, $Script:CLASS_MP_VERSION, $Script:CLASS_MP_KEYTOKEN)}
}
}

# Set alert priorty for group.
Function SetAlertPriority {
$Script:GUID=[guid]::NewGuid().ToString("N")
$Script:ID="OverrideFor$Script:WORKFLOW_TYPE$Script:WORKFLOW_NAME_COMPACT$Script:GUID"
$Script:OUTPUT_OVERRIDES+="<$Script:WORKFLOW_TYPE`PropertyOverride ID=""$Script:ID"" Context=""Cmdb!$Script:GroupName"" ContextInstance=""$Script:GroupId"" Enforced=""$Script:ENFORCED_VALUE"" $Script:WORKFLOW_TYPE=""$Script:WORKFLOW_MP_NAME_ALIAS!$Script:WORKFLOW_NAME"" Property=""AlertPriority""><Value>$Script:AlertPriority</Value></$Script:WORKFLOW_TYPE`PropertyOverride>"
if (-not ($Script:Hash.ContainsKey($Script:WORKFLOW_MP_NAME_ALIAS))) {
$Script:Hash+=@{$Script:WORKFLOW_MP_NAME_ALIAS=@($Script:WORKFLOW_MP_NAME, $Script:WORKFLOW_MP_VERSION, $Script:WORKFLOW_MP_KEYTOKEN)}
} 
if (-not ($Script:Hash.ContainsKey($Script:CLASS_MP_NAME_ALIAS))) {
$Script:Hash+=@{$Script:CLASS_MP_NAME_ALIAS=@($Script:CLASS_MP_NAME, $Script:CLASS_MP_VERSION, $Script:CLASS_MP_KEYTOKEN)}
}
}

# Set variables.
Clear-Host
$Script:CountAll=0
$Script:CountReview=0
$Script:CountDisabledRules=0
$Script:CountEnforceDisable=0
$Script:CountDisabledMonitors=0
$Script:CountEnabledMonitors=0
$Script:CountEnabledRules=0
$Script:OUTPUT_MP=""
$Script:OUTPUT_START=""
$Script:OUTPUT_REFERENCE=""
$Script:OUTPUT_OVERRIDES=""
$Script:OUTPUT_END=""
$Script:Hash=""
$Script:Hash=@{}
$Script:MP_OUTPUT_FOLDER="C:\Build\MP\Overrides\Export" # Update this. Overrides xml file will be dumpled here.
$Script:OVERRIDES=Import-Csv $MpImportFile
$Script:CatAGroupName=get-scomclass -name "Microsoft.SCOM.CMDB.Group.WindowsServerCatA" # Update this. Use dot name.
$Script:CatBGroupName=get-scomclass -name "Microsoft.SCOM.CMDB.Group.WindowsServerCatB" # Update this. Use dot name.
$Script:CatCGroupName=get-scomclass -name "Microsoft.SCOM.CMDB.Group.WindowsServerCatC" # Update this. Use dot name.

ForEach($Script:OVERRIDE in $Script:OVERRIDES){
[int]$Script:CountAll+=1
$Script:WORKFLOW_NAME=$Script:OVERRIDE.WORKFLOW_NAME
$Script:WORKFLOW_DISPLAYNAME=$Script:OVERRIDE.WORKFLOW_DISPLAYNAME
$Script:WORKFLOW_TYPE=$Script:OVERRIDE.WORKFLOW_TYPE
$Script:WORKFLOW_NAME_COMPACT=$Script:OVERRIDE.WORKFLOW_NAME -replace "[.]"
$Script:WORKFLOW_MP_NAME=$Script:OVERRIDE.WORKFLOW_MP_NAME
$Script:WORKFLOW_MP_NAME_ALIAS=$Script:OVERRIDE.WORKFLOW_MP_NAME -replace "[.]"
$Script:WORKFLOW_MP_VERSION=$Script:OVERRIDE.WORKFLOW_MP_VERSION
$Script:WORKFLOW_MP_KEYTOKEN=$Script:OVERRIDE.WORKFLOW_MP_KEYTOKEN
$Script:CLASS_NAME=$Script:OVERRIDE.CLASS_NAME
$Script:CLASS_DISPLAYNAME=$Script:OVERRIDE.CLASS_DISPLAYNAME
$Script:CLASS_MP_NAME=$Script:OVERRIDE.CLASS_MP_NAME
$Script:CLASS_MP_NAME_ALIAS=$Script:OVERRIDE.CLASS_MP_NAME -replace "[.]"
$Script:CLASS_MP_VERSION=$Script:OVERRIDE.CLASS_MP_VERSION
$Script:CLASS_MP_KEYTOKEN=$Script:OVERRIDE.CLASS_MP_KEYTOKEN
$Script:ENABLED=$Script:OVERRIDE.ENABLED # value will be true or false.
$Script:EXISTING_OVERRIDE=$Script:OVERRIDE.EXISTING_OVERRIDE # value will be true or false.
$Script:KEEP=$Script:OVERRIDE.KEEP

# Notify on existing overrides.
if($Script:KEEP -eq "review"){
[int]$Script:CountReview+=1
write-host "$CountReview`. Review $Script:WORKFLOW_TYPE | $Script:WORKFLOW_DISPLAYNAME | $Script:CLASS_DISPLAYNAME"
}

# Disable unwanted rules.
if(($Script:KEEP -eq "no") -AND ($Script:WORKFLOW_TYPE -eq "rule") -AND ($Script:ENABLED -eq "true")){
$Script:ENABLED_VALUE="false"
$Script:ENFORCED_VALUE="false"
[int]$Script:CountDisabledRules+=1
EnableOrDisableWorkflow}

# Enforce disable rules and monitors that have a sealed override to enable them.
if($Script:KEEP -eq "EnforceDisable"){
$Script:ENABLED_VALUE="false"
$Script:ENFORCED_VALUE="true"
[int]$Script:CountEnforceDisable+=1
EnableOrDisableWorkflow}

# Enable disabled rules.
if(($Script:KEEP -eq "yes") -AND ($Script:WORKFLOW_TYPE -eq "rule") -AND ($Script:ENABLED -eq "false")){
$Script:ENABLED_VALUE="true"
$Script:ENFORCED_VALUE="false"
[int]$Script:CountEnabledRules+=1
EnableOrDisableWorkflow}

# Disable unwanted monitors.
if(($Script:KEEP -eq "no") -AND ($Script:WORKFLOW_TYPE -eq "monitor") -AND ($Script:ENABLED -eq "true")){
$Script:ENABLED_VALUE="false"
$Script:ENFORCED_VALUE="false"
[int]$Script:CountDisabledMonitors+=1
EnableOrDisableWorkflow}

# Enable monitors at group level, disable at class, and set alert priority for each group.
if(($Script:KEEP -eq "yes") -AND ($Script:WORKFLOW_TYPE -eq "monitor") -AND ($Script:ENABLED -eq "true")){
[int]$Script:CountEnabledMonitors+=1

	# Disable at class first
	$Script:ENABLED_VALUE="false"
	$Script:ENFORCED_VALUE="false"
	EnableOrDisableWorkflow

	# CatA
	$Script:ENABLED_VALUE="true"
	$Script:ENFORCED_VALUE="false"
	$Script:GroupName=$Script:CatAGroupName.Name
	$Script:GroupId=$Script:CatAGroupName.Id.Guid
	EnableGroup
	$Script:AlertPriority=$Script:OVERRIDE.CATA
	SetAlertPriority

	<# CatB
	Comment out if not needed.
	#>
	$Script:ENABLED_VALUE="true"
	$Script:ENFORCED_VALUE="false"
	$Script:GroupName=$Script:CatBGroupName.Name
	$Script:GroupId=$Script:CatBGroupName.Id.Guid
	EnableGroup
	$Script:AlertPriority=$Script:OVERRIDE.CatB
	SetAlertPriority

	<# CatC.
	Comment out if not needed.
	#>
	$Script:ENABLED_VALUE="true"
	$Script:ENFORCED_VALUE="false"
	$Script:GroupName=$Script:CatCGroupName.Name
	$Script:GroupId=$Script:CatCGroupName.Id.Guid
	EnableGroup
	$Script:AlertPriority=$Script:OVERRIDE.CatC
	SetAlertPriority
	#>
} # end enable monitors to group.

} # end foreach loop


$Script:Hash.GetEnumerator() | ForEach-Object {
$Script:ALIAS=$Script:_.key
$Script:MP_ID=$Script:_.value[0]
$Script:MP_VERSION=$Script:_.value[1]
$Script:MP_KEYTOKEN=$Script:_.value[2]
$Script:OUTPUT_REFERENCE+=@"
<Reference Alias="$Script:ALIAS">
<ID>$Script:MP_ID</ID>
<Version>$Script:MP_VERSION</Version>
<PublicKeyToken>$Script:MP_KEYTOKEN</PublicKeyToken>
</Reference>
"@
}

# Tack on cmdb reference.
$Script:OUTPUT_REFERENCE+=@"
<Reference Alias="Cmdb">
<ID>Microsoft.SCOM.CMDB.Monitoring</ID>
<Version>2023.10.23.0</Version>
<PublicKeyToken>b9103d6ec5285c3a</PublicKeyToken>
</Reference>
</References>
</Manifest>
<Monitoring>
  <Overrides>
"@

# MP preamble
# Format date for mp version.
$a=get-date
$year = $a.year
$month = $a.month
$day = $a.day
$increment = 0
$MpVersion = "$year.$month.$day.$increment"
$Script:WORKFLOW_MP_NAME=$Script:OVERRIDES.WORKFLOW_MP_NAME | Select-Object -Unique
$Script:WORKFLOW_MP_DISPLAYNAME=$Script:OVERRIDES.WORKFLOW_MP_DISPLAYNAME | Select-Object -Unique
$Script:WORKFLOW_MP_FRIENDLYNAME=$Script:OVERRIDES.WORKFLOW_MP_FRIENDLYNAME | Select-Object -Unique
$Script:OUTPUT_START=@"
<ManagementPack ContentReadable="true" SchemaVersion="2.0" OriginalSchemaVersion="1.1" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <Manifest>
    <Identity>
      <ID>$Script:WORKFLOW_MP_NAME.Overrides</ID>
      <Version>$MpVersion</Version>
    </Identity>
    <Name>$Script:WORKFLOW_MP_FRIENDLYNAME Overrides</Name> <!--This is the mp "FriendlyName".-->
    <References>
"@

# MP end bit.
$Script:OUTPUT_END+=@"
</Overrides>
</Monitoring>
<LanguagePacks>
  <LanguagePack ID="ENU" IsDefault="false">
    <DisplayStrings>
      <DisplayString ElementID="$Script:WORKFLOW_MP_NAME.Overrides">
        <Name>$Script:WORKFLOW_MP_DISPLAYNAME Overrides</Name>
        <Description>Overrides for the $Script:WORKFLOW_MP_NAME management pack.</Description>
      </DisplayString>
    </DisplayStrings>
  </LanguagePack>
</LanguagePacks>
</ManagementPack>
"@

# Dump output to overrides file.
$Script:OUTPUT_MP=$Script:OUTPUT_START, $Script:OUTPUT_REFERENCE, $Script:OUTPUT_OVERRIDES, $Script:OUTPUT_END
$Script:OUTPUT_MP | Out-File "$Script:MP_OUTPUT_FOLDER\$Script:WORKFLOW_MP_NAME.Overrides.xml" #-Append
Write-Host
Write-Host -ForegroundColor yellow "Total Rules/Monitors: $Script:CountAll"
Write-Host -ForegroundColor yellow "Review: $Script:CountReview"
Write-Host -ForegroundColor yellow "Disabled Rules: $Script:CountDisabledRules"
Write-Host -ForegroundColor yellow "Force Disabled Rules/Monitors: $Script:CountEnforceDisable"
Write-Host -ForegroundColor yellow "Enabled Rules: $Script:CountEnabledRules"
Write-Host -ForegroundColor yellow "Disabled Monitors: $Script:CountDisabledMonitors"
Write-Host -ForegroundColor yellow "Enabled Monitors: $Script:CountEnabledMonitors"
Write-Host