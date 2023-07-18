  Function Write-Log {
    Param($ScriptState)
    Switch ($ScriptState) {
        "Information" {
            $EventId=17623
            $EventLevel=0 # 0=Info
        }
        "Error" {
            $EventId=17625
            $EventLevel=1 # 1=Error
        }        
		"Warning" {
            $EventId=17624
            $EventLevel=2 # 2=Warning
        }
    }
    $End=Get-Date
    $TimeCount=(New-TimeSpan -Start $StartTime -End $End)
    $MomApi.LogScriptEvent("$ScriptName executed in $($TimeCount.Minutes)`m $($TimeCount.Seconds)`s $($TimeCount.Milliseconds)`ms", $EventId, $EventLevel, "`nRunning as: $Account`nWorkflow Name: $WorkflowName`nManagement Pack: $($MPName) $("($MpVersion)")`nPowerShell Version: $PSVersion`nOutput: $Message")
	Break
}
Function Set-TerminatingError {
    $ScriptState="Error"
    $Message+=$_.Exception.Message
    Write-Log -ScriptState $ScriptState
}
Function SQLQuery {
param($DbServer,$DbName,$DbQuery)
$Connection=New-Object System.Data.SQLClient.SQLConnection
$Connection.ConnectionString="Data Source=$DbServer;Database=$DbName;Trusted_Connection=True;"
$Connection.Open()
$Command=New-Object System.Data.SQLClient.SQLCommand
$Command.Connection=$Connection
$Command.CommandText=$DbQuery
$Reader=$Command.ExecuteReader()
$SqlTable=New-Object System.Data.DataTable
$SqlTable.Load($Reader)
$Connection.Close()
Return $SqlTable
}
Function Get-FailedJobs {
$ErrorActionPreference="Stop" # This works well. It still logs terminating and non-terminating events.
Try {
$PSVersion=$PSVersionTable.PSVersion
[string]$PSMajor=$PSVersion.Major
[string]$PSMinor=$PSVersion.Minor
$PSVersion=$PSMajor + "." + $PSMinor
$SetupRegKey="HKLM:\SOFTWARE\CommVault Systems\Galaxy\Instance001\Database"
$CommDbServer=(Get-ItemProperty $SetupRegKey).sINSTANCE
$CommDbName=(Get-ItemProperty $SetupRegKey).sCSDBNAME

# Get total jobs
$DbQuery="SELECT COUNT(*) as TotalJobs
FROM [$CommDbName].[dbo].[CommCellBackupInfo]
where CONVERT(datetime,SWITCHOFFSET(CONVERT(datetimeoffset,enddate),DATENAME(TzOffset, SYSDATETIMEOFFSET()))) > GETDATE()-1 --and jobstatus = 'successZ'"
$SqlTable=SQLQuery -DbServer $CommDbServer -DbName $CommDbName -DbQuery $DbQuery
$CntTotalJobs=$SqlTable.TotalJobs

# We expect lots of jobs so if 0 log event and quit.
If ($CntTotalJobs -lt 1) {
$Message+="SQL query executed successfully but 0 total jobs were returned. Please investigate."
$ScriptState="Warning"
Write-Log -ScriptState $ScriptState
} Else {
# Get failed jobs
$Bag=$MomApi.CreatePropertyBag()
$DbQuery="SELECT COUNT(*) as FailedJobs
FROM [$CommDbName].[dbo].[CommCellBackupInfo]
where CONVERT(datetime,SWITCHOFFSET(CONVERT(datetimeoffset,enddate),DATENAME(TzOffset, SYSDATETIMEOFFSET()))) > GETDATE()-1
and jobstatus != 'success'"
$SqlTable=SQLQuery -DbServer $CommDbServer -DbName $CommDbName -DbQuery $DbQuery
$CntFailedJobs=$SqlTable.FailedJobs
# Do math to get % success jobs.
$PctSuccess=[Math]::Round(($CntTotalJobs - $CntFailedJobs) / $CntTotalJobs * 100, 2)
$SuccessJobsThreshold='99.99' # Set to 98.00 in prod.
# Add count and % to property bag regardless of what threshold is.
$Bag.AddValue('CntTotalJobs', $CntTotalJobs)
$Bag.AddValue('CntFailedJobs', $CntFailedJobs)
$Bag.AddValue('PctSuccessJobs', $PctSuccess)
If ($PctSuccess -lt $SuccessJobsThreshold) {
$Bag.AddValue('FailedJobs', 'FailedJobsWarning')
} Else {
$Bag.AddValue('FailedJobs', 'FailedJobsOK')
}
<# FOR TESTING
write-host "Total Jobs: $CntTotalJobs"
write-host "Failed Jobs: $CntFailedJobs"
write-host "% Success Jobs: $PctSuccess"
write-host "% Success Threshold: $SuccessJobsThreshold"
write-host
$MomApi.Return($Bag)
#>
$Bag
$Message+="$CntFailedJobs failed jobs."
$ScriptState="Information"
Write-Log -ScriptState $ScriptState
}
} # end try
Catch {
Set-TerminatingError
}
}
# Declare all constants used by the script
$MomApi=New-Object -comObject 'MOM.ScriptAPI'
$ScriptName="FailedJobs.ps1"
$Account=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$WorkflowName="SQL.Monitor.FailedJobs"
$MPName="SQL.Monitoring"
$MpVersion="2023.7.19.0"
[datetime]$StartTime=Get-Date
Get-FailedJobs
