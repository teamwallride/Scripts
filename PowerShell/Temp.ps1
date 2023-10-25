<#
29/9/2023 script seems good but now need to test.
Things to consider:
-Need to alert on warnings, test them.
#>

Param ($SourceId, $ManagedEntityId, $ComputerName)
Function Write-Log {
    Param($EventLevel)
    Write-Host -ForegroundColor Red $EventLevel
    if ($EventLevel -eq 0) {
        $EventId = 17609
    }
    else {
        $EventId = 17610
    }
    $End = Get-Date
    $TimeCount = (New-TimeSpan -Start $StartTime -End $End)
    $Minutes = $TimeCount.Minutes
    $Seconds = $TimeCount.Seconds
    $Milliseconds = $TimeCount.Milliseconds
    $MomApi.LogScriptEvent("$ScriptName executed and ran for $Minutes`m $Seconds`s $Milliseconds`ms", $EventId, $EventLevel, "`nRunning As: $Account`nWorkflow Name: $MpWorkflow`nManagement Pack: $Mp ($MpVersion)`nPowerShell Version: $PSVersion`Any issues encountered will be shown below.`n$Message")
    Break
}
Function Get-URInfo {
    # Need event output so don't quit on error.
    $ErrorActionPreference = "Continue"
    Try {
        # FOR TESTING
        $SourceId = '{00000000-0000-0000-0000-000000000000}'
        $ManagedEntityId = '{00000000-0000-0000-0000-000000000000}'
        $ComputerName = 'agent.scomtest.local'
        #>
        $DiscoveryData = $MomApi.CreateDiscoveryData(0, $SourceId, $ManagedEntityId)
        # Get PowerShell version.
        $PSVersion = $PSVersionTable.PSVersion
        [string]$PSMajor = $PSVersion.Major
        [string]$PSMinor = $PSVersion.Minor
        $PSVersion = $PSMajor + "." + $PSMinor
        # Get basic info.
        $ComputerFqdn = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname
        $WinDir = (Get-ChildItem Env:windir).Value
        $OperatingSystem = (Get-WmiObject Win32_OperatingSystem).Caption
        $ComputerType = (Get-WmiObject Win32_ComputerSystem).Model
        # Get SCOM role.
        $SetupRegKey = "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup"
        $Product = (Get-ItemProperty -Path $SetupRegKey).Product
        <#
        COMMON SECTION. This applies to all agents, gateways and management servers.
        #>
        # Get management groups.
        $InstallDirectory = (Get-ItemProperty -Path $SetupRegKey).InstallDirectory.TrimEnd("\")
        $MGFolders = Get-ChildItem -Path "$InstallDirectory\Health Service State\Connector Configuration Cache"
        $MGFolders | ForEach-Object {
            $MGName = $_.Name
            $ManagementGroups += "$MGName,"
            $ConfigFile = "$InstallDirectory\Health Service State\Connector Configuration Cache\$MGName\OpsMgrConnector.Config.xml"
            If (-Not(Test-Path -Path $ConfigFile)) {
                # Log warning.
                [int]$EventLevel = 2
                $Message += "Management group '$MGName' is missing OpsMgrConnector.Config.xml file.`n"
            }
        }
        $ManagementGroups = $ManagementGroups.TrimEnd(",")
        # Get HealthService account. We just want to know the account it's using. Don't care about service state.
        $HealthServiceAccount = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\HealthService").ObjectName
        # Get certificate.
        $CertRegKey = "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Machine Settings"
        If ((Get-ItemProperty -Path $CertRegKey -ErrorAction Ignore).ChannelCertificateHash) {
            $Hash = (Get-ItemProperty -Path $CertRegKey).ChannelCertificateHash
            $Thumbprint = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $Hash }
            $CertificateExpiry = $Thumbprint.NotAfter.ToString("yyyy/MM/dd HH:mm:ss")
        }
        Else {
            $CertificateExpiry = "n/a"
        }
        # Get AD Integration. The key is on every agent, gateway and management server so we just want to know if it's enabled or disabled.
        $ADIntegRegKey = "HKLM:\SYSTEM\CurrentControlSet\Services\HealthService\Parameters\ConnectorManager"
        $ADIntegration = (Get-ItemProperty -Path $ADIntegRegKey -ErrorAction Ignore).EnableADIntegration
        Switch ($ADIntegration) {
            "0" { $ADIntegration = "Disabled"; BREAK }
            "1" { $ADIntegration = "Enabled"; BREAK }
        }
        # Get APM status. If installed get service state otherwise set to NotInstalled.
        $APMServiceRegKey = "HKLM:\SYSTEM\CurrentControlSet\Services\System Center Management APM"
        If (Get-Item -Path $APMServiceRegKey -ErrorAction Ignore) {
            $APMServiceStartMode = (Get-ItemProperty -Path $APMServiceRegKey -ErrorAction Ignore).Start
            Switch ($APMServiceStartMode) {
                "2" { $APMServiceStartMode = "Automatic"; BREAK }
                "3" { $APMServiceStartMode = "Manual"; BREAK }
                "4" { $APMServiceStartMode = "Disabled"; BREAK }
            }
        }
        Else {
            $APMServiceStartMode = "NotInstalled"
        }
        # Get ACS forwarder. This key is on every agent, gateway and management server so we just want to know the service status.
        $ACSForwarderServiceRegKey = "HKLM:SYSTEM\CurrentControlSet\Services\AdtAgent"
        $ACSForwarderServiceStartMode = (Get-ItemProperty -Path $ACSForwarderServiceRegKey -ErrorAction Ignore).Start
        Switch ($ACSForwarderServiceStartMode) {
            "2" { $ACSForwarderServiceStartMode = "Automatic"; BREAK }
            "3" { $ACSForwarderServiceStartMode = "Manual"; BREAK }
            "4" { $ACSForwarderServiceStartMode = "Disabled"; BREAK }
        }
        # Get Log Analytics workspaces. Use the registry as it's more reliable than AgentConfigManager.MgmtSvcCfg.
        $LAWorkspaceRegKey = "HKLM:\SYSTEM\CurrentControlSet\Services\HealthService\Parameters\Service Connector Services"
        If ((Get-Item -Path $LAWorkspaceRegKey -ErrorAction Ignore).SubKeyCount -gt 0) {
            (Get-Item $LAWorkspaceRegKey).GetSubKeyNames() | ForEach-Object {
                $LAWorkspaceId = $_.Substring(16) # Remove "Log Analytics - " from the key name so we just have the workspace id.
                $LogAnalyticsAWorkspaces += "$LAWorkspaceId,"
            }
            $LogAnalyticsAWorkspaces = $LogAnalyticsAWorkspaces.TrimEnd(",")
        }
        Else {
            $LogAnalyticsAWorkspaces = "n/a"
        }
        <#
        AGENTS. This section applies to agents only.
        #>
        If ((Get-ItemProperty -Path $SetupRegKey -ErrorAction Ignore).AgentVersion) {
            $AgentInstallDirectory = (Get-ItemProperty -Path $SetupRegKey).InstallDirectory.TrimEnd("\")
            $AgentVersion = (Get-Item "$AgentInstallDirectory\Tools\TMF\OMAgentTraceTMFVer.Dll").VersionInfo.FileVersion
            Switch ($AgentVersion) {
                # SCOM 2012 R2
                "7.1.10184.0" { $AgentVersion = "2012 R2 RTM"; BREAK }
                "7.1.10195.0" { $AgentVersion = "2012 R2 UR2"; BREAK }
                "7.1.10204.0" { $AgentVersion = "2012 R2 UR3"; BREAK }
                "7.1.10211.0" { $AgentVersion = "2012 R2 UR4"; BREAK }
                "7.1.10213.0" { $AgentVersion = "2012 R2 UR5"; BREAK }
                "7.1.10218.0" { $AgentVersion = "2012 R2 UR6"; BREAK }
                "7.1.10229.0" { $AgentVersion = "2012 R2 UR7"; BREAK }
                "7.1.10241.0" { $AgentVersion = "2012 R2 UR8"; BREAK }
                "7.1.10268.0" { $AgentVersion = "2012 R2 UR9"; BREAK }
                "7.1.10285.0" { $AgentVersion = "2012 R2 UR11"; BREAK }
                "7.1.10292.0" { $AgentVersion = "2012 R2 UR12"; BREAK }
                "7.1.10302.0" { $AgentVersion = "2012 R2 UR13"; BREAK }
                "7.1.10305.0" { $AgentVersion = "2012 R2 UR14"; BREAK }
                # SCOM 2016
                "8.0.10918.0" { $AgentVersion = "2016 RTM"; BREAK }
                "8.0.10931.0" { $AgentVersion = "2016 UR1"; BREAK }
                "8.0.10949.0" { $AgentVersion = "2016 UR2"; BREAK }
                "8.0.10970.0" { $AgentVersion = "2016 UR3"; BREAK }
                "8.0.10977.0" { $AgentVersion = "2016 UR4"; BREAK }
                "8.0.10990.0" { $AgentVersion = "2016 UR5"; BREAK }
                "8.0.11004.0" { $AgentVersion = "2016 UR6"; BREAK }
                "8.0.11025.0" { $AgentVersion = "2016 UR7"; BREAK }
                "8.0.11037.0" { $AgentVersion = "2016 UR8"; BREAK }
                "8.0.11049.0" { $AgentVersion = "2016 UR9"; BREAK }
                "8.0.11057.0" { $AgentVersion = "2016 UR10"; BREAK }
                # SCOM 1801
                "8.0.13053.0" { $AgentVersion = "1801"; BREAK }
                "8.0.13067.0" { $AgentVersion = "1807"; BREAK }
                # SCOM 2019
                "10.19.10014.0" { $AgentVersion = "2019 RTM"; BREAK }
                "10.19.10140.0" { $AgentVersion = "2019 UR1"; BREAK }
                "10.19.10153.0" { $AgentVersion = "2019 UR2"; BREAK }
            }
        }
        Else {
            $AgentInstallDirectory = "n/a"
            $AgentVersion = "n/a"
        }


        <#
        MANAGEMENT SERVERS. This section applies to management servers only.
        #>
        If ((Get-ItemProperty -Path $SetupRegKey -ErrorAction Ignore).ServerVersion) {
            $MgmtServerInstallDirectory = (Get-ItemProperty -Path $SetupRegKey).InstallDirectory.TrimEnd("\")
            $MgmtServerVersion = (Get-Item "$MgmtServerInstallDirectory\Tools\TMF\OMTraceTMFVer.Dll").VersionInfo.FileVersion
            Switch ($MgmtServerVersion) {
                # SCOM 2012 R2
                "7.1.10226.0" { $MgmtServerVersion = "2012 R2 RTM"; BREAK }
                "7.1.10226.1009" { $MgmtServerVersion = "2012 R2 UR1"; BREAK }
                "7.1.10226.1015" { $MgmtServerVersion = "2012 R2 UR2"; BREAK }
                "7.1.10226.1037" { $MgmtServerVersion = "2012 R2 UR3"; BREAK }
                "7.1.10226.1046" { $MgmtServerVersion = "2012 R2 UR4"; BREAK }
                "7.1.10226.1052" { $MgmtServerVersion = "2012 R2 UR5"; BREAK }
                "7.1.10226.1064" { $MgmtServerVersion = "2012 R2 UR6"; BREAK }
                "7.1.10226.1090" { $MgmtServerVersion = "2012 R2 UR7"; BREAK }
                "7.1.10226.1118" { $MgmtServerVersion = "2012 R2 UR8"; BREAK }
                "7.1.10226.1177" { $MgmtServerVersion = "2012 R2 UR9"; BREAK }
                "7.1.10226.1239" { $MgmtServerVersion = "2012 R2 UR11"; BREAK }
                "7.1.10226.1304" { $MgmtServerVersion = "2012 R2 UR12"; BREAK }
                "7.1.10226.1360" { $MgmtServerVersion = "2012 R2 UR13"; BREAK }
                "7.1.10226.1387" { $MgmtServerVersion = "2012 R2 UR14"; BREAK }
                # SCOM 2016
                "7.2.11719.0" { $MgmtServerVersion = "2016 RTM"; BREAK }
                "7.2.11759.0" { $MgmtServerVersion = "2016 UR1"; BREAK }
                "7.2.11822.0" { $MgmtServerVersion = "2016 UR2"; BREAK }
                "7.2.11878.0" { $MgmtServerVersion = "2016 UR3"; BREAK }
                "7.2.11938.0" { $MgmtServerVersion = "2016 UR4"; BREAK }
                "7.2.12016.0" { $MgmtServerVersion = "2016 UR5"; BREAK }
                "7.2.12066.0" { $MgmtServerVersion = "2016 UR6"; BREAK }
                "7.2.12150.0" { $MgmtServerVersion = "2016 UR7"; BREAK }
                "7.2.12213.0" { $MgmtServerVersion = "2016 UR8"; BREAK }
                "7.2.12265.0" { $MgmtServerVersion = "2016 UR9"; BREAK }
                "7.2.12324.0" { $MgmtServerVersion = "2016 UR10"; BREAK }
                # SCOM 1801
                "7.3.13142.0" { $MgmtServerVersion = "1801"; BREAK }
                "7.3.13261.0" { $MgmtServerVersion = "1807"; BREAK }
                # SCOM 2019
                "10.19.10050.0" { $MgmtServerVersion = "2019 RTM"; BREAK }
                "10.19.10311.0" { $MgmtServerVersion = "2019 UR1"; BREAK }
                "10.19.10349.0" { $MgmtServerVersion = "2019 UR1 Hotfix"; BREAK }
                "10.19.10407.0" { $MgmtServerVersion = "2019 UR2"; BREAK }
            }
            # Get CSHostService account.
            $ConfigServiceAccount = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\cshost").ObjectName
            # Get OMSDKService account.
            $DataAccessServiceAccount = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\OMSDK").ObjectName
            # Get ops db name.
            $OpsDbName = (Get-ItemProperty -Path $SetupRegKey).DatabaseName
            # Get ops db server name.
            $OpsDbServer = (Get-ItemProperty -Path $SetupRegKey).DatabaseServerName
            # Get data warehouse db name.
            $DWDbName = (Get-ItemProperty -Path $SetupRegKey).DataWarehouseDBName
            # Get data warehouse db server name.
            $DwDbServer = (Get-ItemProperty -Path $SetupRegKey).DataWarehouseDBServerName
            # Get RMS owner.
            $Connection = New-Object System.Data.SQLClient.SQLConnection
            $Query = "SELECT [PrincipalName] FROM [$OpsDbName].[dbo].[MTV_HealthService] WHERE IsRHS='1'"
            $Connection.ConnectionString = "Data Source=$OpsDbServer;Database=$OpsDbName;Trusted_Connection=True;"
            $Connection.Open()
            $Command = New-Object System.Data.SQLClient.SQLCommand
            $Command.Connection = $Connection
            $Command.CommandText = $Query
            $Reader = $Command.ExecuteReader()
            $Datatable = New-Object System.Data.DataTable
            $Datatable.Load($Reader)
            $RMSFqdn = $Datatable.PrincipalName
            $Connection.Close() 
            If ($RMSFqdn -eq $ComputerFqdn) {
                $RMS = "Yes"
            }
            Else {
                $RMS = "No"
            }
        }
        Else {
            $MgmtServerInstallDirectory = "n/a"
            $MgmtServerVersion = "n/a"
            $ConfigServiceAccount = "n/a"
            $DataAccessServiceAccount = "n/a"
            $OpsDbName = "n/a"
            $OpsDbServer = "n/a"
            $DWDbName = "n/a"
            $DwDbServer = "n/a"
            $RMS = "n/a"
        }
        <#
        ACS COLLECTORS. This section applies to ACS Collector servers only.
        #>
        $ACSCollectorServiceRegKey = "HKLM:SYSTEM\CurrentControlSet\Services\AdtServer"
        If ((Get-ItemProperty -Path $ACSCollectorServiceRegKey -ErrorAction Ignore).DisplayName) {
            $ACSCollectorVersion = (Get-Item "$WinDir\System32\Security\AdtServer\OmacAdmn.dll").VersionInfo.FileVersion
            Switch ($ACSCollectorVersion) {
                # SCOM 2012 R2
                "7.1.10226.0" { $ACSCollectorVersion = "2012 R2 RTM"; BREAK }
                "7.1.10226.1239" { $ACSCollectorVersion = "2012 R2 UR11"; BREAK }
                "7.1.10226.1304" { $ACSCollectorVersion = "2012 R2 UR12"; BREAK }
                "7.1.10226.1360" { $ACSCollectorVersion = "2012 R2 UR13"; BREAK }
                "7.1.10226.1387" { $ACSCollectorVersion = "2012 R2 UR14"; BREAK }
                # SCOM 2016
                "7.2.11719.0" { $ACSCollectorVersion = "2016 RTM"; BREAK }		
                "7.2.11938.0" { $ACSCollectorVersion = "2016 UR4"; BREAK }		
                "7.2.12016.0" { $ACSCollectorVersion = "2016 UR5"; BREAK }
                "7.2.12066.0" { $ACSCollectorVersion = "2016 UR6"; BREAK }
                "7.2.12150.0" { $ACSCollectorVersion = "2016 UR7"; BREAK }
                "7.2.12213.0" { $ACSCollectorVersion = "2016 UR8"; BREAK }		
                "7.2.12265.0" { $ACSCollectorVersion = "2016 UR9"; BREAK }		
                "7.2.12324.0" { $ACSCollectorVersion = "2016 UR10"; BREAK }
                # SCOM 1801
                "7.3.13142.0" { $ACSCollectorVersion = "1801"; BREAK }		
                "7.3.13261.0" { $ACSCollectorVersion = "1807"; BREAK }	
                # SCOM 2019
                "10.19.10050.0" { $ACSCollectorVersion = "2019 RTM"; BREAK }
                "10.19.10140.0" { $ACSCollectorVersion = "2019 UR1"; BREAK }
            }
            # Get ACS Collector account.
            $ACSCollectorServiceAccount = (Get-ItemProperty -Path $ACSCollectorServiceRegKey).ObjectName
        }
        Else {
            $ACSCollectorServiceAccount = "n/a"
            $ACSCollectorVersion = "n/a"
        }
        <#
        GATEWAY SERVERS. This section applies to gateway servers only.
        #>
        If ((Get-ItemProperty -Path $SetupRegKey -ErrorAction Ignore).MOMGatewayVersion) {
            $GatewayServerInstallDirectory = (Get-ItemProperty -Path $SetupRegKey).InstallDirectory.TrimEnd("\")
            # Get Gateway UR info. Note there are different files for different versions.This should be on all versions. Best UR file for 2012 R2 (All URs), 2016 (UR2, UR4-9), 2019 UR1.
            $GatewayServerVersion = (Get-Item "$GatewayServerInstallDirectory\HealthService.dll").VersionInfo.FileVersion
            If ($GatewayServerVersion -match "8.0.10970.0") {
                # Best UR file for 2016 UR3.
                $GatewayServerVersion = (Get-Item "$GatewayServerInstallDirectory\MomWsManModules.dll").VersionInfo.FileVersion
            }
            ElseIf ($GatewayServerVersion -match "8.0.13053.0") {
                # Best UR file for 1801.
                $GatewayServerVersion = (Get-Item "$GatewayServerInstallDirectory\MOMAgentManagement.dll").VersionInfo.FileVersion
            }
            Switch ($GatewayServerVersion) {
                # SCOM 2012 R2
                "7.1.10184.0" { $GatewayServerVersion = "2012 R2 RTM"; BREAK }
                "7.1.10188.0" { $GatewayServerVersion = "2012 R2 UR1"; BREAK }
                "7.1.10195.0" { $GatewayServerVersion = "2012 R2 UR2"; BREAK }
                "7.1.10204.0" { $GatewayServerVersion = "2012 R2 UR3"; BREAK }
                "7.1.10211.0" { $GatewayServerVersion = "2012 R2 UR4"; BREAK }
                "7.1.10213.0" { $GatewayServerVersion = "2012 R2 UR5"; BREAK }
                "7.1.10218.0" { $GatewayServerVersion = "2012 R2 UR6"; BREAK }
                "7.1.10229.0" { $GatewayServerVersion = "2012 R2 UR7"; BREAK }
                "7.1.10241.0" { $GatewayServerVersion = "2012 R2 UR8"; BREAK }
                "7.1.10268.0" { $GatewayServerVersion = "2012 R2 UR9"; BREAK }
                "7.1.10285.0" { $GatewayServerVersion = "2012 R2 UR11"; BREAK }
                "7.1.10292.0" { $GatewayServerVersion = "2012 R2 UR12"; BREAK }
                "7.1.10302.0" { $GatewayServerVersion = "2012 R2 UR13"; BREAK }
                "7.1.10305.0" { $GatewayServerVersion = "2012 R2 UR14"; BREAK }
                # SCOM 2016
                "8.0.10918.0" { $GatewayServerVersion = "2016 RTM"; BREAK }
                "8.0.10949.0" { $GatewayServerVersion = "2016 UR2"; BREAK }
                "8.0.10970.0" { $GatewayServerVersion = "2016 UR3"; BREAK }
                "8.0.10977.0" { $GatewayServerVersion = "2016 UR4"; BREAK }		
                "8.0.10990.0" { $GatewayServerVersion = "2016 UR5"; BREAK }
                "8.0.11004.0" { $GatewayServerVersion = "2016 UR6"; BREAK }
                "8.0.11025.0" { $GatewayServerVersion = "2016 UR7"; BREAK }
                "8.0.11037.0" { $GatewayServerVersion = "2016 UR8"; BREAK }		
                "8.0.11049.0" { $GatewayServerVersion = "2016 UR9"; BREAK }		
                "8.0.11057.0" { $GatewayServerVersion = "2016 UR10"; BREAK } # Unverified. Hoping HealthService.dll gets updated.
                # SCOM 1801
                "8.0.13053.0" { $GatewayServerVersion = "1801"; BREAK }		
                "7.3.13261.0" { $GatewayServerVersion = "1807"; BREAK } # yes this is the correct version even though the number is older.
                # SCOM 2019
                "10.19.10014.0" { $GatewayServerVersion = "2019 RTM"; BREAK }
                "10.19.10140.0" { $GatewayServerVersion = "2019 UR1"; BREAK }
                "10.19.10153.0" { $GatewayServerVersion = "2019 UR2"; BREAK }
            }
        }
        Else {
            $GatewayServerInstallDirectory = "n/a"
            $GatewayServerLastUpdate = "n/a"
            $GatewayServerVersion = "n/a"
        }
        <#
        WEB CONSOLE SERVER. This section applies to web console servers only.
        #>
        $WebConsoleRegKey = "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup\WebConsole"
        If ((Get-ItemProperty -Path $SetupRegKey -ErrorAction Ignore).WEB_CONSOLE_URL) {
            $WebConsoleInstallDirectory = (Get-ItemProperty -Path $WebConsoleRegKey).InstallDirectory.TrimEnd("\")
            # Get web console UR file info. Note there are different files for different versions.
            # Best UR file for 2012 R2.
            If (Test-Path "$WebConsoleInstallDirectory\WebHost\bin\Microsoft.EnterpriseManagement.Management.DataProviders.dll") {
                $WebConsoleURFile = (Get-Item "$WebConsoleInstallDirectory\WebHost\bin\Microsoft.EnterpriseManagement.Management.DataProviders.dll").VersionInfo.FileVersion
                If ($WebConsoleURFile -match "7.1.1") {
                    $WebConsoleVersion = $WebConsoleURFile
                }
            }
            # Best UR file for 2016.
            If (Test-Path "$WebConsoleInstallDirectory\WebHost\bin\Microsoft.EnterpriseManagement.Monitoring.DataProviders.dll") {
                $WebConsoleURFile = (Get-Item "$WebConsoleInstallDirectory\WebHost\bin\Microsoft.EnterpriseManagement.Monitoring.DataProviders.dll").VersionInfo.FileVersion
                If ($WebConsoleURFile -match "7.2.1") {
                    $WebConsoleVersion = $WebConsoleURFile
                }
            }

            # Best UR file for 1801.
            If (Test-Path "$WebConsoleInstallDirectory\WebHost\bin\Microsoft.Mom.Common.dll") {
                $WebConsoleURFile = (Get-Item "$WebConsoleInstallDirectory\WebHost\bin\Microsoft.Mom.Common.dll").VersionInfo.FileVersion
                If ($WebConsoleURFile -match "7.3.1") {
                    $WebConsoleVersion = $WebConsoleURFile
                }
            }
            # Best UR file for 2019.
            If (Test-Path "$WebConsoleInstallDirectory\Dashboard\bin\Microsoft.EnterpriseManagement.OMDataService.dll") {
                $WebConsoleURFile = (Get-Item "$WebConsoleInstallDirectory\Dashboard\bin\Microsoft.EnterpriseManagement.OMDataService.dll").VersionInfo.FileVersion
                If ($WebConsoleURFile -match "10.19") {
                    $WebConsoleVersion = $WebConsoleURFile
                }
            }
            Switch ($WebConsoleVersion) {
                # SCOM 2012 R2
                "7.1.10226.0" { $WebConsoleVersion = "2012 R2 RTM"; BREAK }
                "7.1.10226.1009" { $WebConsoleVersion = "2012 R2 UR1"; BREAK }
                "7.1.10226.1015" { $WebConsoleVersion = "2012 R2 UR2"; BREAK }
                "7.1.10226.1037" { $WebConsoleVersion = "2012 R2 UR3"; BREAK }
                "7.1.10226.1046" { $WebConsoleVersion = "2012 R2 UR4"; BREAK }
                "7.1.10226.1052" { $WebConsoleVersion = "2012 R2 UR5"; BREAK }
                "7.1.10226.1064" { $WebConsoleVersion = "2012 R2 UR6"; BREAK }
                "7.1.10226.1090" { $WebConsoleVersion = "2012 R2 UR7"; BREAK }
                "7.1.10226.1118" { $WebConsoleVersion = "2012 R2 UR8"; BREAK }
                "7.1.10226.1177" { $WebConsoleVersion = "2012 R2 UR9"; BREAK }
                "7.1.10226.1239" { $WebConsoleVersion = "2012 R2 UR11"; BREAK }
                "7.1.10226.1304" { $WebConsoleVersion = "2012 R2 UR12"; BREAK }
                "7.1.10226.1360" { $WebConsoleVersion = "2012 R2 UR13"; BREAK }
                "7.1.10226.1387" { $WebConsoleVersion = "2012 R2 UR14"; BREAK }
                # SCOM 2016
                "7.2.11719.0" { $WebConsoleVersion = "2016 RTM"; BREAK }
                "7.2.11759.0" { $WebConsoleVersion = "2016 UR1"; BREAK }
                "7.2.11822.0" { $WebConsoleVersion = "2016 UR2"; BREAK }
                "7.2.11878.0" { $WebConsoleVersion = "2016 UR3"; BREAK }
                "7.2.11938.0" { $WebConsoleVersion = "2016 UR4"; BREAK }		
                "7.2.12016.0" { $WebConsoleVersion = "2016 UR5"; BREAK }
                "7.2.12066.0" { $WebConsoleVersion = "2016 UR6"; BREAK }
                "7.2.12150.0" { $WebConsoleVersion = "2016 UR7"; BREAK }
                "7.2.12213.0" { $WebConsoleVersion = "2016 UR8"; BREAK }		
                "7.2.12265.0" { $WebConsoleVersion = "2016 UR9"; BREAK }		
                "7.2.12324.0" { $WebConsoleVersion = "2016 UR10"; BREAK }
                # SCOM 1801
                "7.3.13142.0" { $WebConsoleVersion = "1801"; BREAK }		
                "7.3.13261.0" { $WebConsoleVersion = "7.3.13261.0 (1807"; BREAK } # this is how we id the 1807 patch on a web server.
                # SCOM 2019
                "10.19.10050.0" { $WebConsoleVersion = "2019 RTM"; BREAK }
                "10.19.10311.0" { $WebConsoleVersion = "2019 UR1"; BREAK }
                "10.19.10349.0" { $WebConsoleVersion = "2019 UR1 Hotfix"; BREAK }
                "10.19.10407.0" { $WebConsoleVersion = "2019 UR2"; BREAK }
            }
            # Get Authentication Mode.
            $AuthenticationMode = (Get-ItemProperty -Path $WebConsoleRegKey).AUTHENTICATION_MODE
            # Get DefaultServer.
            $DefaultServer = (Get-ItemProperty -Path $WebConsoleRegKey).DEFAULT_SERVER
            # Get WebConsoleUrl.
            $WebConsoleUrl = (Get-ItemProperty -Path $WebConsoleRegKey).WEB_CONSOLE_URL
            # Get ApmAdvisorUrl.
            $ApmAdvisorUrl = (Get-ItemProperty -Path $WebConsoleRegKey).APM_ADVISOR_URL
            # Get ApmDiagnosticsUrl.
            $ApmDiagnosticsUrl = (Get-ItemProperty -Path $WebConsoleRegKey).APM_DIAGNOSTICS_URL
        }
        Else {
            $WebConsoleInstallDirectory = "n/a"
            $WebConsoleVersion = "n/a"
            $AuthenticationMode = "n/a"
            $DefaultServer = "n/a"
            $WebConsoleUrl = "n/a"
            $ApmAdvisorUrl = "n/a"
            $ApmDiagnosticsUrl = "n/a"
        }
        <#
        REPORT SERVER. This section applies to report servers only.
        #>
        $ReportServerRegKey = "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup\Reporting"
        If ((Get-ItemProperty -Path $ReportServerRegKey -ErrorAction Ignore).InstallDirectory) {
            $ReportServerInstallDirectory = (Get-ItemProperty -Path $ReportServerRegKey).InstallDirectory.TrimEnd("\")
            # 2016, 1801.
            If (Test-Path "$ReportServerInstallDirectory\Microsoft.Mom.Common.dll") {
                $ReportServerURFile = (Get-Item "$ReportServerInstallDirectory\Microsoft.Mom.Common.dll").VersionInfo.FileVersion
                If (($ReportServerURFile -match "7.2.1") -or ($Script:FileVersion -match "7.3.1" )) {
                    $ReportServerURFile = (Get-Item "C:\Windows\Microsoft.NET\assembly\GAC_MSIL\Microsoft.EnterpriseManagement.OperationsManager\v4.0_7.0.5000.0__31bf3856ad364e35\Microsoft.EnterpriseManagement.OperationsManager.dll").VersionInfo.FileVersion
                    $ReportServerVersion = $ReportServerURFile
                }
            }
            Switch ($ReportServerVersion) {
                # SCOM 2012 R2
                "7.1.10226.0" { $ReportServerVersion = "2012 R2 RTM"; BREAK }
                "7.1.10226.1304" { $ReportServerVersion = "2012 R2 UR12"; BREAK }
                "7.1.10226.1360" { $ReportServerVersion = "2012 R2 UR13"; BREAK }
                "7.1.10226.1387" { $ReportServerVersion = "2012 R2 UR14"; BREAK }
                # SCOM 2016
                "7.2.11719.0" { $ReportServerVersion = "2016 RTM"; BREAK }
                "7.2.12016.0" { $ReportServerVersion = "2016 UR5"; BREAK }
                "7.2.12066.0" { $ReportServerVersion = "2016 UR6"; BREAK }
                "7.2.12150.0" { $ReportServerVersion = "2016 UR7"; BREAK }
                "7.2.12213.0" { $ReportServerVersion = "2016 UR8"; BREAK }		
                "7.2.12265.0" { $ReportServerVersion = "2016 UR9"; BREAK }		
                "7.2.12324.0" { $ReportServerVersion = "2016 UR10"; BREAK }
                # SCOM 1801
                "7.3.13142.0" { $ReportServerVersion = "1801"; BREAK }		
                "7.3.13261.0" { $ReportServerVersion = "1807"; BREAK }	
                # SCOM 2019
                "10.19.1032.0" { $ReportServerVersion = "2019 RTM"; BREAK }
                "10.19.10311.0" { $ReportServerVersion = "2019 UR1"; BREAK }
                "10.19.1035.82" { $ReportServerVersion = "2019 UR1 Hotfix"; BREAK }
                "10.19.1035.100" { $ReportServerVersion = "2019 UR2"; BREAK } # Microsoft.EnterpriseManagement.Core.dll. Adding 2 values for UR2 in case date compare gets weird.
                "10.19.10407.0" { $ReportServerVersion = "2019 UR2"; BREAK } # Microsoft.EnterpriseManagement.OperationsManager.dll.
            }
            # Get ReportServerDwDbServer.
            $ReportServerDwDbServer = (Get-ItemProperty -Path $ReportServerRegKey\..\..\Reporting).DWDBInstance
            # Get ReportServerDWDBName.
            $ReportServerDWDBName = (Get-ItemProperty -Path $ReportServerRegKey\..\..\Reporting).DWDBName
            # Get ReportServerUrl.
            $ReportServerUrl = (Get-ItemProperty -Path $ReportServerRegKey\..\..\Reporting).ReportingServerUrl
            #Get SRSInstance.
            $SRSInstance = (Get-ItemProperty -Path $ReportServerRegKey\..\..\Reporting).SRSInstance
            <# Get report service account. Using the registry to get report server service info is unreliable because info returned by different SQL versions and named instances is inconsistent.
            #>
            $ReportServerService = Get-WmiObject Win32_Service -Filter "DisplayName like 'SQL Server Reporting Services%'" # Confirmed this works on SQL 2012SP4, 2017.
            $ReportServerServiceAccount = $ReportServerService.StartName
        }
        Else {
            $ReportServerInstallDirectory = "n/a"
            $ReportServerVersion = "n/a"
            $ReportServerDwDbServer = "n/a"
            $ReportServerDWDBName = "n/a"
            $ReportServerUrl = "n/a"
            $SRSInstance = "n/a"
            $ReportServerServiceAccount = "n/a"
        }
        <#
        CONSOLES. This section applies to operations manager consoles only.
        #>
        $ConsoleRegKey = "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup\Console"
        If ((Get-ItemProperty -Path $ConsoleRegKey -ErrorAction Ignore).InstallDirectory) {
            $ConsoleInstallDirectory = (Get-ItemProperty -Path $ConsoleRegKey).InstallDirectory.TrimEnd("\")
            $ConsoleVersion = (Get-Item "$ConsoleInstallDirectory\Tools\TMF\OMTraceTMFVer.Dll").VersionInfo.FileVersion
            Switch ($ConsoleVersion) {
                # SCOM 2012
                "7.0.9538.0" { $ConsoleVersion = "2012 SP1"; BREAK }
                # SCOM 2012 R2
                "7.1.10226.0" { $ConsoleVersion = "2012 R2 RTM"; BREAK }
                "7.1.10226.1009" { $ConsoleVersion = "2012 R2 UR1"; BREAK }
                "7.1.10226.1015" { $ConsoleVersion = "2012 R2 UR2"; BREAK }
                "7.1.10226.1037" { $ConsoleVersion = "2012 R2 UR3"; BREAK }
                "7.1.10226.1046" { $ConsoleVersion = "2012 R2 UR4"; BREAK }
                "7.1.10226.1064" { $ConsoleVersion = "2012 R2 UR6"; BREAK }
                "7.1.10226.1090" { $ConsoleVersion = "2012 R2 UR7"; BREAK }
                "7.1.10226.1118" { $ConsoleVersion = "2012 R2 UR8"; BREAK }
                "7.1.10226.1177" { $ConsoleVersion = "2012 R2 UR9"; BREAK }
                "7.1.10226.1239" { $ConsoleVersion = "2012 R2 UR11"; BREAK }
                "7.1.10226.1304" { $ConsoleVersion = "2012 R2 UR12"; BREAK }
                "7.1.10226.1360" { $ConsoleVersion = "2012 R2 UR13"; BREAK }
                "7.1.10226.1387" { $ConsoleVersion = "2012 R2 UR14"; BREAK }
                # SCOM 2016
                "7.2.11719.0" { $ConsoleVersion = "2016 RTM"; BREAK }
                "7.2.11759.0" { $ConsoleVersion = "2016 UR1"; BREAK }
                "7.2.11822.0" { $ConsoleVersion = "2016 UR2"; BREAK }
                "7.2.11878.0" { $ConsoleVersion = "2016 UR3"; BREAK }
                "7.2.11938.0" { $ConsoleVersion = "2016 UR4"; BREAK }		
                "7.2.12016.0" { $ConsoleVersion = "2016 UR5"; BREAK }
                "7.2.12066.0" { $ConsoleVersion = "2016 UR6"; BREAK }
                "7.2.12150.0" { $ConsoleVersion = "2016 UR7"; BREAK }
                "7.2.12213.0" { $ConsoleVersion = "2016 UR8"; BREAK }		
                "7.2.12265.0" { $ConsoleVersion = "2016 UR9"; BREAK }		
                "7.2.12324.0" { $ConsoleVersion = "2016 UR10"; BREAK }
                # SCOM 1801
                "7.3.13142.0" { $ConsoleVersion = "1801"; BREAK }		
                "7.3.13261.0" { $ConsoleVersion = "1807"; BREAK }	
                # SCOM 2019
                "10.19.10050.0" { $ConsoleVersion = "2019 RTM"; BREAK }
                "10.19.10311.0" { $ConsoleVersion = "2019 UR1"; BREAK }
                "10.19.10349.0" { $ConsoleVersion = "2019 UR1 Hotfix"; BREAK }
                "10.19.10407.0" { $ConsoleVersion = "2019 UR2"; BREAK }

            }
        }
        Else {
            $ConsoleInstallDirectory = "n/a"
            $ConsoleVersion = "n/a"
        }
        # FOR TESTING
        write-host "PrincipalName: $ComputerName"
        write-host "ComputerType: $ComputerType"
        write-host "OperatingSystem: $OperatingSystem"
        write-host "Product: $Product"
        write-host "AgentInstallDirectory: $AgentInstallDirectory"
        write-host "AgentVersion: $AgentVersion"
        write-host "ManagementGroups: $ManagementGroups"
        write-host "HealthServiceAccount: $HealthServiceAccount"
        write-host "CertificateExpiry: $CertificateExpiry"
        write-host "ADIntegration: $ADIntegration"
        write-host "APMServiceStartMode: $APMServiceStartMode"
        write-host "ACSForwarderServiceStartMode: $ACSForwarderServiceStartMode"
        write-host "LogAnalyticsAWorkspaces: $LogAnalyticsAWorkspaces"
        write-host "MgmtServerInstallDirectory: $MgmtServerInstallDirectory"
        write-host "MgmtServerVersion: $MgmtServerVersion"
        write-host "ConfigServiceAccount: $ConfigServiceAccount"
        write-host "DataAccessServiceAccount: $DataAccessServiceAccount"
        write-host "OpsDbName: $OpsDbName"
        write-host "OpsDbServer: $OpsDbServer"
        write-host "DWDbName: $DWDbName"
        write-host "DwDbServer: $DwDbServer"
        write-host "ACSCollectorServiceAccount: $ACSCollectorServiceAccount"
        write-host "ACSCollectorVersion: $ACSCollectorVersion"
        write-host "RMS: $RMS"
        write-host "GatewayServerInstallDirectory: $GatewayServerInstallDirectory"
        write-host "GatewayServerLastUpdate: $GatewayServerLastUpdate"
        write-host "GatewayServerVersion: $GatewayServerVersion"
        write-host "WebConsoleInstallDirectory: $WebConsoleInstallDirectory"
        write-host "WebConsoleVersion: $WebConsoleVersion"
        write-host "AuthenticationMode: $AuthenticationMode"
        write-host "DefaultServer: $DefaultServer"
        write-host "WebConsoleUrl: $WebConsoleUrl"
        write-host "ApmAdvisorUrl: $ApmAdvisorUrl"
        write-host "ApmDiagnosticsUrl: $ApmDiagnosticsUrl"
        write-host "ReportServerInstallDirectory: $ReportServerInstallDirectory"
        write-host "ReportServerVersion: $ReportServerVersion"
        write-host "ReportServerDwDbServer: $ReportServerDwDbServer"
        write-host "ReportServerDWDBName: $ReportServerDWDBName"
        write-host "ReportServerUrl: $ReportServerUrl"
        write-host "SRSInstance: $SRSInstance"
        write-host "ReportServerServiceAccount: $ReportServerServiceAccount"
        write-host "ConsoleInstallDirectory: $ConsoleInstallDirectory"
        write-host "ConsoleVersion: $ConsoleVersion"
        write-host "DisplayName: $ComputerName"
        #>
        # Return discovery data.
        $Instance = $DiscoveryData.CreateClassInstance("$MPElement[Name='SCOM.Class.URWindowsComputer']$")
        $Instance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $ComputerName)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ComputerType$", $ComputerType)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/OperatingSystem$", $OperatingSystem)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/Product$", $Product)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/AgentInstallDirectory$", $AgentInstallDirectory)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/AgentVersion$", $AgentVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ManagementGroups$", $ManagementGroups)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/HealthServiceAccount$", $HealthServiceAccount)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/CertificateExpiry$", $CertificateExpiry)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ADIntegration$", $ADIntegration)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/APMServiceStartMode$", $APMServiceStartMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ACSForwarderServiceStartMode$", $ACSForwarderServiceStartMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/LogAnalyticsAWorkspaces$", $LogAnalyticsAWorkspaces)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/MgmtServerInstallDirectory$", $MgmtServerInstallDirectory)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/MgmtServerVersion$", $MgmtServerVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ConfigServiceAccount$", $ConfigServiceAccount)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/DataAccessServiceAccount$", $DataAccessServiceAccount)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/OpsDbName$", $OpsDbName)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/OpsDbServer$", $OpsDbServer)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/DWDbName$", $DWDbName)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/DwDbServer$", $DwDbServer)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ACSCollectorServiceAccount$", $ACSCollectorServiceAccount)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ACSCollectorVersion$", $ACSCollectorVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/RMS$", $RMS)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/GatewayServerInstallDirectory$", $GatewayServerInstallDirectory)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/GatewayServerLastUpdate$", $GatewayServerLastUpdate)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/GatewayServerVersion$", $GatewayServerVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/WebConsoleInstallDirectory$", $WebConsoleInstallDirectory)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/WebConsoleVersion$", $WebConsoleVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/AuthenticationMode$", $AuthenticationMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/DefaultServer$", $DefaultServer)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/WebConsoleUrl$", $WebConsoleUrl)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ApmAdvisorUrl$", $ApmAdvisorUrl)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ApmDiagnosticsUrl$", $ApmDiagnosticsUrl)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerInstallDirectory$", $ReportServerInstallDirectory)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerVersion$", $ReportServerVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerDwDbServer$", $ReportServerDwDbServer)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerDWDBName$", $ReportServerDWDBName)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerUrl$", $ReportServerUrl)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/SRSInstance$", $SRSInstance)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerServiceAccount$", $ReportServerServiceAccount)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ConsoleInstallDirectory$", $ConsoleInstallDirectory)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ConsoleVersion$", $ConsoleVersion)
        $Instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $ComputerName)
        $DiscoveryData.AddInstance($Instance)



        # Submit discovery data back to Operations Manager and complete the script.
        $DiscoveryData
        # FOR TESTING
        $MomApi.Return($DiscoveryData)
        #>
         # Log info.
        [int]$EventLevel = 0
        Write-Log -ScriptState $EventLevel   
    }
    Catch {
         # Log warning.
        [int]$EventLevel = 2
        $Message += $_.Exception.Message
        Write-Log -ScriptState $EventLevel   
    }
}
# Declare all constants used by the script`
[datetime]$StartTime = Get-Date
$MomApi = New-Object -comObject 'MOM.ScriptAPI'
$ScriptName = "GetURInfo.ps1"
$Account = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Mp = "Microsoft.SCOM.UpdateRollup"
$MpVersion = "2023.10.2.0"
$MpWorkflow = "SCOM.Discovery.WindowsUpdateRollup"
Get-URInfo -SourceId $SourceId -ManagedEntityId $ManagedEntityId -ComputerName $ComputerName