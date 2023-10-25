clear-host
$date= Get-Date
$Match = 0
Write-Host
Write-Host "Script Start:" $date
Write-Host
New-SCOMManagementGroupConnection -ComputerName blah
$Servers = gc C:\temp\agents.txt #| sort
$Windows = Get-SCOMAgent #| sort PrincipalName
$Unix = Get-SCOMClass -Name Microsoft.Unix.Computer | Get-SCOMClassInstance #| sort DisplayName
$Pending = Get-SCOMPendingManagement #| sort AgentName
write-host
foreach($server in $Servers)
{
	$check = "Windows"
	$matchWindows = Select-String -InputObject $Windows.PrincipalName $server -Quiet
	$check = "Pending"
	$matchPending = Select-String -InputObject $Pending.AgentName $server -Quiet
	$check = "Unix"
	$matchUnix = Select-String -InputObject $Unix.DisplayName $server -Quiet

	If ($matchWindows -eq $true)
	{
		$Match = $Match+1
		Write-Host -ForegroundColor green $server.ToUpper() ", Windows, YES"
	}
	ElseIf ($matchUnix -eq $true)
	{
		$Match = $Match+1
		Write-Host -ForegroundColor yellow $server.ToUpper() ", Unix, YES"
	}
	ElseIf ($matchPending -eq $true)
	{
		$Match = $Match+1
		Write-Host -ForegroundColor yellow $server.ToUpper() ", NA, PENDING"
	}
	Else
	{
		$NoMatch = $NoMatch+1
		Write-Host -ForegroundColor red $server.ToUpper() ",NA, NO"
	}
}
write-host
write-host "Total:"($Match + $NoMatch)
write-host "Match:"$Match
write-host "No Match:"$NoMatch
write-host
