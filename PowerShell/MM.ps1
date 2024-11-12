CLS
<#
Version: 2024.11.13.0 (yyyy.mm.dd.increment_starting_at_0)
This is mainly for on-demand MM, it could be re-jigged for scheduled task MM. It has the following features:
- Reads computer names from a file then MMs them.
- Works on Windows and UNIX/Linux agents.
- Sends email confirmation showing if the computer is ready for the MM job, already in MM, or not in SCOM at all.

Variables to update per your needs:
- $OutputFile
- $InputFile
- $EndTimeString
- $Comment
- $Reason
- $SmtpServer
- $FromAddress
- $Recipients
- $SmtpSubject

If you've been given computer names only (not FQDN) this will extract the FQDN which you need for mm to work:
$InputFile = "C:\Temp\file.txt"
$SourceFile = gc $InputFile | sort
foreach ($i in $SourceFile) {
$b=Get-SCOMClass -Name "Microsoft.Windows.Computer" | Get-SCOMClassInstance | Where-Object {$_."[Microsoft.Windows.Computer].NetbiosComputerName".value -eq $i}
$displayname=$b.displayname
write-host "$i^$displayname"
}
#>
# Set these variables before running the script.
$OutputFile = "C:\Temp\MMOutput.txt"
# Add list of computers to the file. Must be FQDN of agent, not just the server name.
$InputFile = "C:\Temp\file.txt"
# Add end time here in valid PowerShell date format dd-MM-yyyy HH:mm:ss
$EndTimeString = "19-11-2024 21:00:00"
$Comment = ""
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
# Email settings.
$SmtpServer = ""
$FromAddress = ""
$Recipients = ""
$SmtpSubject = "Maintenance Mode Notification"
# Load the console if needed.
<#Add-PSSnapin Microsoft.EnterpriseManagement.OperationsManager.Client
New-PSDrive Monitoring Microsoft.EnterpriseManagement.OperationsManager.Client\OperationsManagerMonitoring ""
Set-Location Monitoring:
New-SCOMManagementGroupConnection -ComputerName "mgmt_server"
#>

# Reset variables when testing.
[int]$CountTotal=""
[int]$CountEach=""
$User=""
$ScheduledEndTime=""
$Output=""
$User=whoami
$ManagementServers=Get-SCOMManagementServer
$SourceFile = gc $InputFile | sort
$CountTotal=($SourceFile.Count)
# MM cannot be scheduled so the start time is when script is executed manually or by scheduled task.
$StartTime = Get-Date
$StartTimeString = $StartTime.ToString("dd-MM-yyyy HH:mm:ss")

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
<#
write-host
write-host "Total servers: $CountTotal"
write-host
#>

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

# This class works for Windows and UNIX/Linux computers.
$SCOMComputers+=Get-SCOMClass -name System.Computer | Get-SCOMClassInstance
$Output += "<p style='font-family:arial;font-size:20;color:#222924'>Maintenance Mode Notification</p>"
$Output += "<p style='font-family:arial;font-size:12;color:#222924'>A maintenance mode job has started.<br><br>Initiated By: $User<br>Total Servers: $CountTotal<br>Start Time: $StartTimeString<br>End Time: $EndTimeString<br>Comment: $Comment</p>"
$Output += "<table class=gridtable>"
$Output += "<tr><th style=background-color:#34568B><div style=font-family:arial;font-size:12;width:100%;>Server</div></th><th style=background-color:#34568B><div style=font-family:arial;font-size:12;width:100%;>Status</div></th></tr>"

$SourceFile | foreach {
$CountEach=$CountEach +1
$ComputerUpper=$_.ToUpper()

If ($SCOMComputers -match $_) {
	# This class works for Windows and UNIX/Linux computers.
	$Computer = Get-SCOMClass -Name "System.Computer" | Get-SCOMClassInstance | Where-Object {$_.DisplayName -eq $ComputerUpper}
	# Check it's not a management or gateway server.
	if ($ManagementServers.DisplayName -eq $_) {
		$MMStatus = "SCOM server"
		$Output += "<tr><th><div style=font-family:arial;font-size:11;width:100%;color:#222924 align=left>$ComputerUpper</div></th><th style=font-family:arial;font-size:11;background-color:#FA6258;color:#222924><div style=width:100%;  align=left>$MMStatus</div></th></tr>"
		write-host -foregroundcolor yellow "$CountEach/$CountTotal. $_ - $MMStatus"
	} elseif ($Computer.InMaintenanceMode -ne $True)	
		{
		$MMStatus = "Maintenance mode job started successfully."
		$Output += "<tr><th><div style=font-family:arial;font-size:11;width:100%;color:#222924 align=left>$ComputerUpper</div></th><th style=font-family:arial;font-size:11;background-color:#4CAF50;color:#222924><div style=width:100%; align=left>$MMStatus</div></th></tr>"
		write-host -foregroundcolor green "$CountEach/$CountTotal. $_ - $MMStatus"
		################################################
		# This puts the windows computer object into MM.
		Start-SCOMMaintenanceMode -Instance $Computer -EndTime $EndTimeSeconds -Comment "$Comment" -Reason "$Reason"
		################################################
		} elseif ($Computer.InMaintenanceMode -eq $True) {
		$UTCEndTime = (Get-SCOMMaintenanceMode -Instance $Computer).ScheduledEndTime
		$LocalEndTime = $UTCEndTime.ToLocalTime()
		$FormatLocalEndTime = $LocalEndTime.ToString("dd-MM-yyyy HH:mm:ss")
		$MMStatus = "Computer already in maintenance mode. Scheduled to end $FormatLocalEndTime" # need to format date properly, still in mm-dd-yyyy
		$Output += "<tr><th><div style=font-family:arial;font-size:11;width:100%;color:#222924 align=left>$ComputerUpper</div></th><th style=font-family:arial;font-size:11;background-color:#FAF558;color:#222924><div style=width:100%; align=left>$MMStatus</div></th></tr>"
		write-host -foregroundcolor yellow "$CountEach/$CountTotal. $_ - $MMStatus"
		}
	else
		{
		$MMStatus = "Unknown error"
		$Output += "<tr><th><div style=font-family:arial;font-size:11;width:100%;color:#222924 align=left>$ComputerUpper</div></th><th style=font-family:arial;font-size:11;background-color:#FA6258;color:#222924><div style=width:100%; align=left>$MMStatus</div></th></tr>"
		write-host -foregroundcolor red "$CountEach/$CountTotal. $_ - $MMStatus"
		}
} else {
	$MMStatus = "Not in SCOM"
	$Output += "<tr><th><div style=font-family:arial;font-size:11;width:100%;color:#222924 align=left>$ComputerUpper</div></th><th style=font-family:arial;font-size:11;background-color:#FA6258;color:#222924><div style=width:100%; align=left>$MMStatus</div></th></tr>"
	write-host -foregroundcolor yellow "$CountEach/$CountTotal. $_ - $MMStatus"
}
}
$Output += "</table><p>"
# Send email.
Send-MailMessage -From $FromAddress -To $Recipients -Subject $SmtpSubject -BodyAsHtml ($Output | out-string) -SmtpServer $SmtpServer
# Send to file.
# $Output | out-File $OutputFile
