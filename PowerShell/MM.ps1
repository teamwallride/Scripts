CLS
<#
Version: 2024.10.29.0
This is mainly for on-demand MM, it could be re-jigged for scheduled task MM. It has the following features:
- Reads computer names from a file then MMs them.
- Works on Windows and UNIX/Linux agents.
- Sends email confirmation showing if the computer is ready for the MM job, already in MM, or not in SCOM at all.

Variables to update per your needs:
- $File
- $EndTimeString
- $Comment
- $Reason
- $SmtpServer
- $FromAddress
- $Recipients
- $SmtpSubject
#>
# Reset variables when testing.
[int]$CountTotal=""
[int]$CountEach=""
$User=""
$ScheduledEndTime=""
$Output=""


#NEW ADDED
$ManagementServers=Get-SCOMManagementServer




# Add list of computers to the file. Must be FQDN of agent, not just the server name.
$File = "C:\Temp\file.txt"
$SourceFile = gc $File | sort
$CountTotal=($SourceFile.Count)
# MM cannot be scheduled so the start time is when script is executed manually or by scheduled task.
$StartTime = Get-Date
# Add end time here in valid PowerShell date format dd-MM-yyyy HH:mm:ss
$EndTimeString = "08-11-2024 21:00:00"
# This converts the string to a valid PowerShell date.
$EndTimeConvertFromString = [datetime]::ParseExact($EndTimeString, 'dd-MM-yyyy HH:mm:ss', $null)
<#
MM in PowerShell is weird with the end date. If you use an actual date/time the end time in the console is wrong.
If you use a calculate the number of hours/minutes/seconds until that end date and use that as end time it works.
This code works out the number of seconds until the end date.
#>
$EndTimeSeconds=(New-TimeSpan -Start $StartTime -End $EndTimeConvertFromString).TotalSeconds
$RoundUpEndTimeSeconds=[math]::Round($EndTimeSeconds)
$RoundUpEndTimeSeconds
$EndTimeSeconds = ($StartTime.AddSeconds($RoundUpEndTimeSeconds))
$Comment = "CHG000456042"
$Reason = "PlannedOther"
<#
Possible values for $Reason:
PlannedOther
UnplannedOther
PlannedHardwareMaintenance
UnplannedHardwareMaintenance
PlannedHardwareInstallation
UnplannedHardwareInstallation
PlannedOperatingSystemReconfiguration
UnplannedOperatingSystemReconfiguration
PlannedApplicationMaintenance
ApplicationInstallation
ApplicationUnresponsive
ApplicationUnstable
SecurityIssue
LossOfNetworkConnectivity
#>
<#
write-host
write-host "Total servers: $CountTotal"
write-host
#>
# Email settings.
$SmtpServer = "ExchangeRelay.prod.atonet.gov.au"
$FromAddress = "NoReplyScom@ato.gov.au"
$Recipients = "Anthony.Milic@ato.gov.au"
$SmtpSubject = "Maintenance Mode Notification"
#Add-PSSnapin Microsoft.EnterpriseManagement.OperationsManager.Client
#New-PSDrive Monitoring Microsoft.EnterpriseManagement.OperationsManager.Client\OperationsManagerMonitoring ""
#Set-Location Monitoring:
#New-SCOMManagementGroupConnection -ComputerName "mgmt_server"

$Output = '<style type="text/css">
table.gridtable {
font-family: arial;
font-size:12px;
color:#E4E3E7;
border-width: 1px;
border-color: white;
border-collapse: collapse;
}
table.gridtable th {
border-width: 1px;
padding: 8px;
border-style: solid;
border-color: white;
background-color:#E4E3E7;
}
table.gridtable td {
border-width: 1px;
padding: 8px;
border-style: solid;
border-color: white;
}
tr.cursor {cursor:pointer;}
a.cursor {cursor:pointer;}
</style>'

#$Get Windows and Unix agents
$SCOMComputers=Get-SCOMClass -name Microsoft.Windows.Computer | Get-SCOMClassInstance
$SCOMComputers+=Get-SCOMClass -name Microsoft.Unix.Computer | Get-SCOMClassInstance
$Output += "<p style='font-family:arial;font-size:20;color:#222924'>Maintenance Mode Notification</p>"
$Output += "<p style='font-family:arial;font-size:12;color:#222924'>A maintenance mode job has started.<p>Total Servers: $CountTotal<br>Start Time: $StartTimeString<br>End Time: $EndTimeString<br>Comment: $Comment</p>"
$Output += "<table class=gridtable>"
$Output += "<tr><th style=background-color:#34568B><div style=font-family:arial;font-size:12;width:300px;>Server</div></th><th style=background-color:#34568B><div style=font-family:arial;font-size:12;width:100px;>Status</div></th></tr>"
#foreach ($_ in $SourceFile) { # start for

$SourceFile | foreach {
$CountEach=$CountEach +1
$ComputerUpper=$_.ToUpper()


<#
if ($ManagementServers.DisplayName -notcontains $_) {
# IT'S AN AGENT, PROCEED.
write-host -foregroundcolor green $_
} else {
# IT'S A MGMT OR GTW SERVER!!!
write-host -foregroundcolor red $_
}
#>

#$Server=$SCOMComputers -match "^$_$"
#If ($SCOMComputers -match "^$_") {
If ($SCOMComputers -match $_) {
#write-host -foregroundcolor green $_

	#Get current MM status.
		#Connect to the computer instance. WARNING I've seen duplicates using this (like Exchange servers.):
	#$Computer = Get-SCOMClassInstance -Name "$_"
	# This might be better:
	#$Computer = Get-SCOMClass -Name "Microsoft.Windows.Computer" | Get-SCOMClassInstance | Where-Object {$_.DisplayName -eq "EMLXMST02E4028V.uat.atoqnet.gov.au"}
	$Computer = Get-SCOMClass -Name "Microsoft.Windows.Computer" | Get-SCOMClassInstance | Where-Object {$_.DisplayName -eq $ComputerUpper}

	if ($ManagementServers.DisplayName -contains $_) {
		$MMStatus = "SCOM Gateway or Management Server, not putting into MM"
		$Output += "<tr><th><div style=font-family:arial;font-size:12;width:200px;color:#222924 align=left>$ComputerUpper</div></th><th style=font-family:arial;font-size:12;background-color:#FA6258;color:#222924><div style=width:200px;>$MMStatus</div></th></tr>"
		write-host -foregroundcolor red "$CountEach/$CountTotal. $_ - $MMStatus"
	} elseif ($Computer.InMaintenanceMode -ne $True)	
		{
		$MMStatus = "Ready for MM"
		$Output += "<tr><th><div style=font-family:arial;font-size:12;width:200px;color:#222924 align=left>$ComputerUpper</div></th><th style=font-family:arial;font-size:12;background-color:#4CAF50;color:#222924><div style=width:200px;>$MMStatus</div></th></tr>"
		write-host "$CountEach/$CountTotal. $_ - $MMStatus"
		#This puts the windows computer object into MM.
		#Start-SCOMMaintenanceMode -Instance $Computer -EndTime $EndTimeSeconds -Comment "$Comment" -Reason "$Reason"
		#sleep 10 need this?
		} elseif ($Computer.InMaintenanceMode -eq $True) {
		# Could add MM end date and username here?
		#$User = $Computer.GetMaintenanceWindow().User
		$UTCEndTime = (Get-SCOMMaintenanceMode -Instance $Computer).ScheduledEndTime
		$LocalEndTime = $UTCEndTime.ToLocalTime()
		$FormatLocalEndTime = $LocalEndTime.ToString("dd/MM/yyyy HH:mm:ss")
		#$LocalEndTime = "two string?"
		#$MMStatus = "Currently in MM (ends " + $UTCEndTime.ToLocalTime() + ")" # need to format date properly, still in mm-dd-yyyy
		$MMStatus = "Currently in MM (ends $FormatLocalEndTime)" # need to format date properly, still in mm-dd-yyyy
		$Output += "<tr><th><div style=font-family:arial;font-size:12;width:200px;color:#222924 align=left>$ComputerUpper</div></th><th style=font-family:arial;font-size:12;background-color:#FAF558;color:#222924><div style=width:200px;>$MMStatus</div></th></tr>"
		write-host -foregroundcolor green "$CountEach/$CountTotal. $_ - $MMStatus"
		}
	else
		{
		$MMStatus = "Unknown error"
		$Output += "<tr><th><div style=font-family:arial;font-size:12;width:200px;color:#222924 align=left>$ComputerUpper</div></th><th style=font-family:arial;font-size:12;background-color:#FA6258;color:#222924><div style=width:200px;>$MMStatus</div></th></tr>"
		write-host -foregroundcolor yellow "$CountEach/$CountTotal. $_ - $MMStatus"
		}
} else {
	$MMStatus = "Not in SCOM"
	$Output += "<tr><th><div style=font-family:arial;font-size:12;width:200px;color:#222924 align=left>$ComputerUpper</div></th><th style=font-family:arial;font-size:12;background-color:#FA6258;color:#222924><div style=width:200px;>$MMStatus</div></th></tr>"
	write-host -foregroundcolor red "$CountEach/$CountTotal. $_ - $MMStatus"
}
#} # end for
}
$Output += "</table><p>"
Send-MailMessage -From $FromAddress -To $Recipients -Subject $SmtpSubject -BodyAsHtml ($Output | out-string) -SmtpServer $SmtpServer
