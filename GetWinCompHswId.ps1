#Make sure the FQDN is used in the text file, comp name only does not work.
clear-host
$date= Get-Date
Write-Host
Write-Host "Script Start:" $date
Write-Host
Write-Host -ForegroundColor yellow "Getting Windows Computer & HSW object IDs..."
Write-Host
write-host -foregroundcolor green "First GUID=Windows Computer, Second=HSW."
write-host
$a = gc "C:\temp\_Computers.txt"
foreach ($i in $a)
{
$count = $count + 1
$wc = get-scomclass -name Microsoft.Windows.Computer | get-scomclassinstance | where {$_.displayname -eq $i}
$CompName = $wc.displayname
$CompId = $wc.id
#$hsw = get-scomclass -name Microsoft.SystemCenter.HealthServiceWatcher | get-scomclassinstance | where {$_.displayname -eq $i}
$hsw = get-scomclass -name Microsoft.SystemCenter.HealthService | get-scomclassinstance | where {$_.displayname -eq $i}
$HSWId = $hsw.id
#write-host -foregroundcolor yellow $CompName
#write-host $CompId
#write-host $HSWId
#write-host
write-host  "$count.$CompName <MonitoringObjectId>$CompId</MonitoringObjectId> <MonitoringObjectId>$HSWId</MonitoringObjectId>"
}


