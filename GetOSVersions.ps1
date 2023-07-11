clear-host
$date= Get-Date
Write-Host
Write-Host "Script Start:" $date
Write-Host
Write-Host -ForegroundColor yellow "Getting operating system versions`r"
$AIX53 = get-scomclass -name Microsoft.AIX.5.3.OperatingSystem | get-scomclassinstance
$AIX61 = get-scomclass -name Microsoft.AIX.6.1.OperatingSystem | get-scomclassinstance
$AIX70 = get-scomclass -name Microsoft.AIX.7.OperatingSystem | get-scomclassinstance
$SOL9 = get-scomclass -name Microsoft.Solaris.9.OperatingSystem | get-scomclassinstance
$SOL10 = get-scomclass -name Microsoft.Solaris.10.OperatingSystem | get-scomclassinstance
$SOL11 = get-scomclass -name Microsoft.Solaris.11.OperatingSystem | get-scomclassinstance
$RHEL4 = get-scomclass -name Microsoft.Linux.RHEL.4.OperatingSystem | get-scomclassinstance
$RHEL5 = get-scomclass -name Microsoft.Linux.RHEL.5.OperatingSystem | get-scomclassinstance
$RHEL6 = get-scomclass -name Microsoft.Linux.RHEL.6.OperatingSystem | get-scomclassinstance
$RHEL7 = get-scomclass -name Microsoft.Linux.RHEL.7.OperatingSystem | get-scomclassinstance
$SLES9 = get-scomclass -name Microsoft.Linux.SLES.9.OperatingSystem | get-scomclassinstance
$SLES10 = get-scomclass -name Microsoft.Linux.SLES.10.OperatingSystem | get-scomclassinstance
$SLES11 = get-scomclass -name Microsoft.Linux.SLES.11.OperatingSystem | get-scomclassinstance
$SLES12 = get-scomclass -name Microsoft.Linux.SLES.12.OperatingSystem | get-scomclassinstance
$SUSE = get-scomclass -name Microsoft.Linux.SUSE.OperatingSystem | get-scomclassinstance
$WIN2003 = get-scomclass -name Microsoft.Windows.Server.2003.OperatingSystem | get-scomclassinstance
$WIN2008 = get-scomclass -name Microsoft.Windows.Server.2008.Full.OperatingSystem | get-scomclassinstance
$WIN2008R2 = get-scomclass -name Microsoft.Windows.Server.2008.R2.Full.OperatingSystem | get-scomclassinstance
$WIN2012 = get-scomclass -name Microsoft.Windows.Server.6.2.OperatingSystem | get-scomclassinstance
$WIN2016 = get-scomclass -name Microsoft.Windows.Server.10.0.OperatingSystem | get-scomclassinstance
write-host "AIX 5.3:"$AIX53.count
write-host "AIX 6.1:"$AIX61.count
write-host "AIX 7.0:"$AIX70.count
write-host "SOL 9:"$SOL9.count
write-host "SOL 10:"$SOL10.count
write-host "SOL 11:"$SOL11.count
write-host "RHEL 4:"$RHEL4.count
write-host "RHEL 5:"$RHEL5.count
write-host "RHEL 6:"$RHEL6.count
write-host "RHEL 7:"$RHEL7.count
write-host "SLES 9:"$SLES9.count
write-host "SLES 10:"$SLES10.count
write-host "SLES 11:"$SLES11.count
write-host "SLES 12:"$SLES12.count
write-host "SUSE:"$SUSE.count
write-host "WIN 2003:"$WIN2003.count
write-host "WIN 2008:"$WIN2008.count
write-host "WIN 2008 R2:"$WIN2008R2.count
write-host "WIN 2012:"$WIN2012.count
write-host "WIN 2016:"$WIN2016.count
write-host