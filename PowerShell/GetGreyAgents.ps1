$output="c:\temp\GreyAgents.csv"
$date= Get-Date
Write-Host
Write-Host "Script start: $date"
Write-Host
$green=0
$red=0
$csv+="Ping,FQDN,ComputerName,DomainName`r"
$Class=get-scomclass -name "Microsoft.SystemCenter.Agent"
$Instance=get-scomclassinstance -class $Class | where {$_.IsAvailable -eq $false -and $_.InMaintenanceMode -eq $false} | sort DisplayName
Write-Host -ForegroundColor yellow "Getting grey agents..."
Write-Host
$CountGrey = $Instance | Measure-Object
If ($CountGrey.count -gt 0) {
foreach ($x in $Instance) {
$fqdn = $x.DisplayName
$compname=$fqdn.split("{.}",2)[0]
$domname=$fqdn.split("{.}",2)[1]
$count = $count + 1
If (Test-Connection -computername $fqdn -Count 2 -quiet) {
$Green+=1
$csv+="Up,$fqdn,$compname,$domname`r"
Write-Host -ForegroundColor green "Up,$fqdn,$compname,$domname"
}
Else {
$Red+=1
$csv+="Down,$fqdn,$compname,$domname`r"
Write-Host -ForegroundColor red "Down,$fqdn,$compname,$domname"
}}
write-host
write-host -ForegroundColor yellow "Total:" ($Green + $Red)
write-host -ForegroundColor green "Green: $Green"
write-host -ForegroundColor red "Red: $Red"
write-host "Exporting output to $output"
$csv | out-file $output
write-host
} Else {
write-host -ForegroundColor green "No grey agents"
Write-Host
}
$date= Get-Date
Write-Host "Script finish: $date"
Write-Host
