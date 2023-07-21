Function Write-Log {
    Param($ScriptState)
    Switch ($ScriptState) {
        "Information" {
            $EventId = 17623
            $EventLevel = 0 # 0=Info
        }
        "Error" {
            $EventId = 17625
            $EventLevel = 1 # 1=Error
        }        
        "Warning" {
            $EventId = 17624
            $EventLevel = 2 # 2=Warning
        }
    }
    $End = Get-Date
    $TimeCount = (New-TimeSpan -Start $StartTime -End $End)
    $MomApi.LogScriptEvent("$ScriptName executed in $($TimeCount.Minutes)`m $($TimeCount.Seconds)`s $($TimeCount.Milliseconds)`ms", $EventId, $EventLevel, "`nRunning as: $Account`nWorkflow Name: $WorkflowName`nManagement Pack: $($MPName) $("($MpVersion)")`nPowerShell Version: $PSVersion`nOutput: $Message")
    Break
}
Function Set-TerminatingError {
    $ScriptState = "Error"
    $Message += $_.Exception.Message
    Write-Log -ScriptState $ScriptState
}
Function SQLQuery {
    param($DbServer, $DbName, $DbQuery)
    $Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "Data Source=$DbServer;Database=$DbName;Trusted_Connection=True;"
    $Connection.Open()
    $Command = New-Object System.Data.SQLClient.SQLCommand
    $Command.Connection = $Connection
    $Command.CommandText = $DbQuery
    $Reader = $Command.ExecuteReader()
    $SqlTable = New-Object System.Data.DataTable
    $SqlTable.Load($Reader)
    $Connection.Close()
    Return $SqlTable
}
Function Get-BackupStatus {
    $ErrorActionPreference = "Stop" # This works well. It still logs terminating and non-terminating events.
    Try {
        $PSVersion = $PSVersionTable.PSVersion
        [string]$PSMajor = $PSVersion.Major
        [string]$PSMinor = $PSVersion.Minor
        $PSVersion = $PSMajor + "." + $PSMinor
        $SetupRegKey = "HKLM:\SOFTWARE\CommVault Systems\Galaxy\Instance001\Database"
        $CommDbServer = (Get-ItemProperty $SetupRegKey).sINSTANCE
        $CommDbName = (Get-ItemProperty $SetupRegKey).sCSDBNAME

        # Get total jobs.
        $DbQuery = "SELECT COUNT(*) as TotalBackupJobs
FROM [$CommDbName].[dbo].[CommCellBackupInfo]
where CONVERT(datetime,SWITCHOFFSET(CONVERT(datetimeoffset,enddate),DATENAME(TzOffset, SYSDATETIMEOFFSET()))) > GETDATE()-1 --and jobstatus = 'successZ'"
        $SqlTable = SQLQuery -DbServer $CommDbServer -DbName $CommDbName -DbQuery $DbQuery
        $CntTotalBackupJobs = $SqlTable.TotalBackupJobs

        # We expect a lot of jobs so if 0 log event and quit.
        If ($CntTotalBackupJobs -lt 1) {
            $Message += "SQL query executed successfully but 0 total jobs were returned. Please investigate."
            $ScriptState = "Warning"
            Write-Log -ScriptState $ScriptState
        }
        Else {
            # Get unsuccessful jobs.
            $Bag = $MomApi.CreatePropertyBag()
            $DbQuery = "SELECT COUNT(*) as UnsuccessfulBackupJobs
FROM [$CommDbName].[dbo].[CommCellBackupInfo]
where CONVERT(datetime,SWITCHOFFSET(CONVERT(datetimeoffset,enddate),DATENAME(TzOffset, SYSDATETIMEOFFSET()))) > GETDATE()-1
and jobstatus != 'Success'"
            $SqlTable = SQLQuery -DbServer $CommDbServer -DbName $CommDbName -DbQuery $DbQuery
            $CntUnsuccessfulBackupJobs = $SqlTable.UnsuccessfulBackupJobs
            # Do math to get % success jobs.
            $PctSuccessfulBackupJobs = [Math]::Round(($CntTotalBackupJobs - $CntUnsuccessfulBackupJobs) / $CntTotalBackupJobs * 100, 2)
            $SuccessJobsThreshold = '99.99' # Set to 98.00 in prod.
            # Add count and % to property bag regardless of what threshold is.
            $Bag.AddValue('CntTotalBackupJobs', $CntTotalBackupJobs)
            $Bag.AddValue('CntUnsuccessfulBackupJobs', $CntUnsuccessfulBackupJobs)
            $Bag.AddValue('PctSuccessfulBackupJobs', $PctSuccessfulBackupJobs)
            If ($PctSuccessfulBackupJobs -lt $SuccessJobsThreshold) {
                $Bag.AddValue('BackupStatus', 'Unhealthy')
            }
            Else {
                $Bag.AddValue('BackupStatus', 'Healthy')
            }
            <# FOR TESTING
write-host "Total Jobs: $CntTotalBackupJobs"
write-host "Unsuccessful Jobs: $UnsuccessfulBackupJobs"
write-host "% Success Jobs: $PctSuccessfulBackupJobs"
write-host "% Success Threshold: $SuccessJobsThreshold"
write-host
$MomApi.Return($Bag)
#>
            $Bag
            $Message += "$CntUnsuccessfulBackupJobs failed jobs."
            $ScriptState = "Information"
            Write-Log -ScriptState $ScriptState
        }
    } # end try
    Catch {
        Set-TerminatingError
    }
}
# Declare all constants used by the script
$MomApi = New-Object -comObject 'MOM.ScriptAPI'
$ScriptName = "BackupStatus.ps1"
$Account = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$WorkflowName = "Commvault.Monitor.BackupStatus"
$MPName = "Commvault.Monitoring"
$MpVersion = "2023.7.21.5"
[datetime]$StartTime = Get-Date
Get-BackupStatus
