$current = get-date
$MMDuration = 4 #Any number 
$Increment = "Hours" #Can be Days, Hours or Minutes, make sure you update $EndTime on the next line.
$EndTime = ($current.AddHours($MMDuration)) # Can be AddDays, AddHours or AddMinutes.
$StartMM = ($current).ToString("dddd d MMMM yyyy h:mm tt")
$EndMM = ($EndTime).ToString("dddd d MMMM yyyy h:mm tt")
$Duration = "$MMDuration $Increment"
$Source = "C:\temp\_Computers.txt" # Update this if needed.
$Reason = "PlannedOther" # Update this if needed.
$Comment = "Change number here" # Update this if needed.
$CountLines = (Get-Content $Source | Measure-Object)
$SmtpServer = "your.smtp.server"
$FromAddress = "from@address.com"
$Recipients = "to@address.com"
$SmtpSubject = "Scheduled Maintenance Mode Notification"
Add-PSSnapin Microsoft.EnterpriseManagement.OperationsManager.Client
New-PSDrive Monitoring Microsoft.EnterpriseManagement.OperationsManager.Client\OperationsManagerMonitoring ""
#Set-Location Monitoring:
New-SCOMManagementGroupConnection -ComputerName "mgmt_server"
cls
$Output = '<style type="text/css">
table.gridtable {
font-family: verdana;
font-size:8px;
color:#FFFFFF;
border-width: 1px;
border-color: #FFFFFF;
border-collapse: collapse;
}
table.gridtable th {
border-width: 1px;
padding: 8px;
border-style: solid;
border-color: #FFFFFF;
background-color:#E4E3E7;
}
table.gridtable td {
border-width: 1px;
padding: 8px;
border-style: solid;
border-color: #000000;
}
tr.cursor {cursor:pointer;}
a.cursor {cursor:pointer;}
</style>'
#Get source list of computers to be put in MM.
$SourceList = gc $Source | sort
$CountSource=($CountLines.count)
write-host
write-host "Total servers: $CountSource"
write-host
#$Get Windows and Unix agents
$GetSCOMAgents=Get-SCOMClass -name Microsoft.Windows.Computer | Get-SCOMClassInstance
$GetSCOMAgents+=Get-SCOMClass -name Microsoft.Unix.Computer | Get-SCOMClassInstance
$Output += "<p style='font-family:verdana;font-size:20;color:#222924'>Scheduled Maintenance Mode Notification</p>"
$Output += "<p style='font-family:verdana;font-size:10;color:#222924'><b>Total Servers:</b> $CountSource<br><b>Start Time:</b> $StartMM<br><b>End Time: </b>$EndMM<br><b>Duration: </b>$Duration<br><b>Source: </b>$Source<br><b>Comment: </b>$Comment</p>"
$Output += "<table class=gridtable>"
$Output += "<tr><th style=background-color:#222924><div style=width:300px;>Server</div></th><th style=background-color:#222924><div style=width:100px;>Maintenance Mode Status</div></th></tr>"
foreach ($SourceComputer in $SourceList)
{
$count=$count +1
$Server=$GetSCOMAgents -match "^$SourceComputer$"
$ComputerUpper=$SourceComputer.ToUpper()
if ([string]::IsNullOrWhitespace($Server))
{
$match="false"
}
else
{
$match="true"
}
if ($match -ne $True)
	{
	$MMStatus = "Not in SCOM"
	$Output += "<tr><th><div style=width:200px;color:#222924 align=left>$ComputerUpper</div></th><th style=background-color:#FACC2E;color:#222924><div style=width:200px;>$MMStatus</div></th></tr>"
	write-host -foregroundcolor red "$count. $SourceComputer - $MMStatus"
	}
else
	{
	#Connect to the computer instance
	$computer = Get-SCOMClassInstance -Name "$SourceComputer"
	#Get current MM status.
	if ($computer.InMaintenanceMode -eq $False)	
		{
		$MMStatus = "OK"
		$Output += "<tr><th><div style=width:200px;color:#222924 align=left>$ComputerUpper</div></th><th style=background-color:#D2D1D6;color:#222924><div style=width:200px;>$MMStatus</div></th></tr>"
		write-host "$count. $SourceComputer - $MMStatus"
		#This puts the windows computer object into MM.
		Start-SCOMMaintenanceMode -Instance $computer -EndTime $EndTime -Comment "$Comment" -Reason "$Reason"
		#sleep 10
		}
	elseif ($computer.InMaintenanceMode -eq $True)
		{
		$MMStatus = "Already in MM"
		$Output += "<tr><th><div style=width:200px;color:#222924 align=left>$ComputerUpper</div></th><th style=background-color:#58FA58;color:#222924><div style=width:200px;>$MMStatus</div></th></tr>"
		write-host -foregroundcolor green "$count. $SourceComputer - $MMStatus"
		}
	else
		{
		$MMStatus = "Unknown error"
		$Output += "<tr><th><div style=width:200px;color:#222924 align=left>$ComputerUpper</div></th><th style=background-color:#FF4000;color:#222924><div style=width:200px;>$MMStatus</div></th></tr>"
		write-host -foregroundcolor yellow "$count. $SourceComputer - $MMStatus"
		}
}
}
$Output += "</table><p>"
Send-MailMessage -From $FromAddress -To $Recipients -Subject $SmtpSubject -BodyAsHtml ($Output | out-string) -SmtpServer $SmtpServer
