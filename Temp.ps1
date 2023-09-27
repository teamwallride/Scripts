Param ($SourceId, $ManagedEntityId, $ComputerName)
Function Write-Log {
    Param($ScriptState)
    if ($ScriptState -eq "Information") {
        $EventId = 17609
        $EventLevel = 0 # 0=Info
    }
    else {
        $EventId = 17610
        $EventLevel = 2 # 2=Warning
    }
    $End = Get-Date
    $TimeCount = (New-TimeSpan -Start $StartTime -End $End)
    $Minutes = $TimeCount.Minutes
    $Seconds = $TimeCount.Seconds
    $Milliseconds = $TimeCount.Milliseconds
    $MomApi.LogScriptEvent("$ScriptName executed and ran for $Minutes`m $Seconds`s $Milliseconds`ms", $EventId, $EventLevel, "`nRunning As: $Account`nWorkflow Name: $MpWorkflow`nManagement Pack: $Mp ($MpVersion)`nPowerShell Version: $PSVersion`nScript Output: Any issues encountered will be shown below.`n$Message")
    Break
}
Function CheckNull ($PassedInParam) {
    If ([string]::IsNullOrEmpty($PassedInParam)) {
        $Script:IsItNull = $True # Update this so we can make decisions.
        If ($ValueToCheck -eq "LAProxyUrl") {
            # This If statement allows us to do custom things when an empty value is not considered an error.
            $Script:LAProxyUrl = "n/a"
        }
        ElseIf ($ValueToCheck -eq "LAProxyUsername") {
            $Script:LAProxyUsername = "n/a"
        }
        Else {
            $Script:CountError += 1
            $Script:Message += "[CODE_SECTION_$CodeSection] $ValueToCheck is empty. Error output: ($Error).`n"
        }
    }
    Else {
        $Script:IsItNull = $False # Update this so we can make decisions.
    }
}
Function Get-URInfo {
    #$ErrorActionPreference = "Stop"
    $ErrorActionPreference = "Continue"
    Try {
        # FOR TESTING
        $SourceId = '{00000000-0000-0000-0000-000000000000}'
        $ManagedEntityId = '{00000000-0000-0000-0000-000000000000}'
        $ComputerName = 'agent.scomtest.local'
        #>
        $DiscoveryData = $MomApi.CreateDiscoveryData(0, $SourceId, $ManagedEntityId) # Create MOMDiscoveryData object to store discovery data.
        $ObjAgentConfig = New-Object -ComObject "AgentConfigManager.MgmtSvcCfg" # Agent config API object.
        # Get PowerShell version.
        $PSVersion = $PSVersionTable.PSVersion
        [string]$PSMajor = $PSVersion.Major
        [string]$PSMinor = $PSVersion.Minor
        $PSVersion = $PSMajor + "." + $PSMinor
        # Set common variables.
        $ComputerFqdn = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname
        $WinDir = (Get-ChildItem Env:windir).Value
        $OperatingSystem = (Get-WmiObject Win32_OperatingSystem).Caption
        $SetupRegKey = "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup"
        # Get the SCOM role of the computer.
        $Product = (Get-ItemProperty $SetupRegKey).Product
        

        ##################################################### COMMON
        <# CODE_SECTION_9
        Get management groups on agents, mgmt/gateway servers.
        The folder is the best way to check for invalid mgmt groups that didn't clean up properly after removal.
        #>
        $InstallDirectory = (Get-ItemProperty $SetupRegKey).InstallDirectory.TrimEnd("\")
        $MGFolders = Get-ChildItem -Path "$InstallDirectory\Health Service State\Connector Configuration Cache"
        $MGCount = ($MGFolders | Measure-Object).Count
        $MGFolders | ForEach-Object {
            $MGName = $_.Name
            write-host -foregroundcolor red "$MGName"
            $MGNames += "$MGName,"
            $ConfigFile = "$InstallDirectory\Health Service State\Connector Configuration Cache\$MGName\OpsMgrConnector.Config.xml" # Script is running so don't check for existence.
            If (-not(Test-Path -Path $ConfigFile)) {
                $Script:Message += "[CODE_SECTION_$CodeSection] Management group '$MGName' is missing OpsMgrConnector.Config.xml file.`n"
                $Script:CountError += 1
            }
        } # end for
        $MGNames = $MGNames.TrimEnd(",")


        <# CODE_SECTION_9
        Get HealthService account.
        #>
        $CodeSection = "9"
        $HealthServiceRegKey = "HKLM:\SYSTEM\CurrentControlSet\Services\HealthService"
        # Get-ServiceInfo $HealthServiceRegKey
        $Script:HealthServiceAccount = $Script:ServiceAccount
        $Script:HealthServiceStartMode = $Script:ServiceStartMode
        <# CODE_SECTION_10
        Get certificate.
        #>
        $CodeSection = "10"
        $CertRegKey = "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Machine Settings"
        If ((Get-ItemProperty $CertRegKey).ChannelCertificateHash) {
            $Hash = (Get-ItemProperty $CertRegKey).ChannelCertificateHash
            $Thumbprint = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $Hash }
            $CertificateExpiry = $Thumbprint.NotAfter.ToString("yyyy/MM/dd HH:mm:ss")
            $ValueToCheck = "CertificateExpiry"; CheckNull $CertificateExpiry # Expect value.
        }
        Else {
            $CertificateExpiry = "n/a"
        }
        <# CODE_SECTION_11
        Get AD Integration setting.
        #>
        $CodeSection = "11"
        $ADIntegRegKey = "HKLM:\SYSTEM\CurrentControlSet\Services\HealthService\Parameters\ConnectorManager"
        $ADIntegration = (Get-ItemProperty $ADIntegRegKey).EnableADIntegration
        $ValueToCheck = "ADIntegration"; CheckNull $ADIntegration # Expect value.
        If ($Script:IsItNull -ne $True) {
            Switch ($ADIntegration) {
                "0" { $ADIntegration = "Disabled"; BREAK }
                "1" { $ADIntegration = "Enabled"; BREAK }
                Default {
                    $Script:Message += "[CODE_SECTION_$CodeSection] Unknown AD Integration value: $ADIntegration`n";
                    $Script:CountError += 1
                }
            }
        }
        <# CODE_SECTION_12
        Get APM service StartMode type.
        This may not be installed so don't alert if not found.
        #>
        $CodeSection = "12"
        $APMServiceRegKey = "HKLM:\SYSTEM\CurrentControlSet\Services\System Center Management APM"
        If (Test-Path $APMServiceRegKey) {
            $APMInstalled = "Yes"
            # Get-ServiceInfo $APMServiceRegKey
            $Script:APMServiceAccount = $Script:ServiceAccount
            $Script:APMServiceStartMode = $Script:ServiceStartMode
        }
        Else {
            $APMInstalled = "No"
            $APMServiceAccount = "n/a"
            $APMServiceStartMode = "n/a"
        }
        <# CODE_SECTION_13
        Get ACS forwarder.
        This should be installed on all ms, gw, agent. Alert if not found.
        #>
        $CodeSection = "13"
        $ACSForwarderServiceRegKey = "HKLM:SYSTEM\CurrentControlSet\Services\AdtAgent"
        # Get-ServiceInfo $ACSForwarderServiceRegKey
        $Script:ACSForwarderServiceAccount = $Script:ServiceAccount
        $Script:ACSForwarderServiceStartMode = $Script:ServiceStartMode
        <# CODE_SECTION_14
        Get TLS1.2 registry settings.
        This checks if the server has been explicitly configured to communicate with only TLS1.2 (i.e. all other protocols disabled).
        #>
        $CodeSection = "14"
        $Count = 0
        $ArrayTLS12NETEnabled = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319"
        $ArrayTLS12NETEnabled | ForEach-Object {
            If (Test-Path -Path $_) {
                $TLS12NETEnabled = (Get-ItemProperty $_).SchUseStrongCrypto
                If ($TLS12NETEnabled -eq 1) {
                    $Count += 1
                }
            }
        }
        $TLS12OSRegKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2"
        $ArrayTLS12OS = "Client", "Server"
        $ArrayTLS12OS | ForEach-Object {
            If (Test-Path -Path "$TLS12OSRegKey\$_") {
                $TLS12OSEnabled = (Get-ItemProperty "$TLS12OSRegKey\$_").Enabled
                $TLS12OSDisabledByDefault = (Get-ItemProperty "$TLS12OSRegKey\$_").DisabledByDefault
                If ($TLS12OSEnabled -eq 1 -and $TLS12OSDisabledByDefault -eq 0) {
                    $Count += 1
                }
            }
        }
        If ($Count -eq 0) {
            $TLS12 = "NoConfig"
        }
        ElseIf ($Count -eq 4) {
            $TLS12 = "CorrectConfig"
        }
        Else {
            $TLS12 = "IncompleteConfig"
        }
        <# CODE_SECTION_15
        Get Log Analytics workspaces.
        Using the AgentConfigManager.MgmtSvcCfg object isn't reliable for collecting LA workspace info so we use the registry instead.
        #>
        $CodeSection = "15"
        $LAWorkspaceRegKey = "HKLM:\SYSTEM\CurrentControlSet\Services\HealthService\Parameters\Service Connector Services"
        If (Test-Path $LAWorkspaceRegKey) {
            $BindLAWorkspaceRegKey = Get-Item $LAWorkspaceRegKey # Bind to the reg key so we can get properties.
            $LAWorkspaceCount = ($BindLAWorkspaceRegKey).SubKeyCount # This is the $LAWorkspaceCount property.
            If ($LAWorkspaceCount -gt 0) {
                # If 0 workspaces set $LAWorkspaces to "None" otherwise do below...
                $ArrayLAWorkspaces = $BindLAWorkspaceRegKey.GetSubKeyNames() # Get each subkey and create an array in case there's more than 1.
                $ArrayLAWorkspaces | ForEach-Object { # Cycle through each item in the array.
                    $LAWorkspaceId = $_.Substring(16) # Remove "Log Analytics - " from the key name so we just have the workspace id.
                    $LAWorkspaceType = (Get-ItemProperty -Path $LAWorkspaceRegKey\$_)."Azure Cloud Type"
                    $ValueToCheck = "LAWorkspaceType"; CheckNull $LAWorkspaceType
                    If ($Script:IsItNull -ne $True) {
                        # 
                        Switch ($LAWorkspaceType) {
                            "0" { $LAWorkspaceType = "Azure Commercial"; BREAK }
                            "1" { $LAWorkspaceType = "Azure US Government"; BREAK }
                            "2" { $LAWorkspaceType = "Azure China"; BREAK }
                            "3" { $LAWorkspaceType = "Azure US Nat"; BREAK }
                            "4" { $LAWorkspaceType = "Azure US Sec"; BREAK }
                            Default {
                                $Script:Message += "[CODE_SECTION_$CodeSection] Unknown log analytics workspace type: $LAWorkspaceType`n";
                                $Script:CountError += 1
                            }
                        }
                    }
                    $LAWorkspaces += "Type=$LAWorkspaceType,WorkSpaceId=$LAWorkspaceId;"
                }
                $LAWorkspaces = $LAWorkspaces.TrimEnd(";")
            }
            Else {
                $LAWorkspaceCount = "0"
                $LAWorkspaces = "n/a"
            }
        }
        Else {
            $LAWorkspaceCount = "0"
            $LAWorkspaces = "n/a"
        }
        <# CODE_SECTION_16
        Get Log Analytics proxy server used to connect to Log Analytics.
        If this is empty it's not an error but we need to add custom discovery data so need a null check. There is a reference in the CheckNull function for this. It's not pretty but it let's us reuse code.
        #>
        $CodeSection = "16"
        $Script:LAProxyUrl = $ObjAgentConfig.proxyUrl
        $ValueToCheck = "LAProxyUrl"; CheckNull $Script:LAProxyUrl # Add custom discovery data
        <# CODE_SECTION_17
        Get Log Analytics account used to authenticate to the proxy server.
        If this is empty it's not an error but we need to add custom discovery data so need a null check. There is a reference in the CheckNull function for this. It's not pretty but it let's us reuse code.
        #>
        $CodeSection = "17"
        $Script:LAProxyUsername = $ObjAgentConfig.proxyUsername
        $ValueToCheck = "LAProxyUsername"; CheckNull $Script:LAProxyUsername # Expect value.
        <# CODE_SECTION_18
        Get computer type.
        #>
        $CodeSection = "18"
        $ComputerType = (Get-WmiObject Win32_ComputerSystem).Model
        $ValueToCheck = "ComputerType"; CheckNull $ComputerType # Expect value.

        ##################################################### AGENT
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

        ##################################################### MANAGEMENT SERVER
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
            $OpsDbName = (Get-ItemProperty $SetupRegKey).DatabaseName
            # Get ops db server name.
            $OpsDbServer = (Get-ItemProperty $SetupRegKey).DatabaseServerName
            # Get data warehouse db name.
            $DWDbName = (Get-ItemProperty $SetupRegKey).DataWarehouseDBName
            # Get data warehouse db server name.
            $DwDbServer = (Get-ItemProperty $SetupRegKey).DataWarehouseDBServerName
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
        ##################################################### ACS COLLECTOR
        $ACSCollectorServiceRegKey = "HKLM:SYSTEM\CurrentControlSet\Services\AdtServer"
        If ((Get-ItemProperty -Path $ACSCollectorServiceRegKey -ErrorAction Ignore).DisplayName) {
            #$ACSCollector = "Yes"
            $ACSCollectorVersion = (Get-Item "$WinDir\System32\Security\AdtServer\OmacAdmn.dll").VersionInfo.FileVersion
            # Get ACS Collector account.
            $ACSCollectorServiceAccount = (Get-ItemProperty $ACSCollectorServiceRegKey).ObjectName
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
        }
        Else {
            $ACSCollectorServiceAccount = "n/a"
            $ACSCollectorVersion = "n/a"
            #$ACSCollector = "No"
            #$ACSCollectorServiceStartMode = "n/a"
            #$ACSCollectorLastUpdate = "n/a"
        }

        ##################################################### GATEWAY SERVER
        If ((Get-ItemProperty $SetupRegKey).MOMGatewayVersion) {
            $GatewayServerInstallDirectory = (Get-ItemProperty $SetupRegKey).InstallDirectory.TrimEnd("\")
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
            #$GatewayMGCount="n/a"
            #$GatewayMGFailovers="n/a"
        }




        <#**************************************** WEB CONSOLE SERVER SECTION ****************************************#>
        $WebConsoleRegKey = "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup\WebConsole"
        If ((Get-ItemProperty $WebConsoleRegKey).WEB_CONSOLE_URL) {
            write "in web console bit"
            $WebConsoleInstallDirectory = (Get-ItemProperty $WebConsoleRegKey).InstallDirectory.TrimEnd("\")
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
            $AuthenticationMode = (Get-ItemProperty $WebConsoleRegKey).AUTHENTICATION_MODE
            # Get DefaultServer.
            $DefaultServer = (Get-ItemProperty $WebConsoleRegKey).DEFAULT_SERVER
            # Get WebConsoleUrl.
            $WebConsoleUrl = (Get-ItemProperty $WebConsoleRegKey).WEB_CONSOLE_URL
            # Get ApmAdvisorUrl.
            $ApmAdvisorUrl = (Get-ItemProperty $WebConsoleRegKey).APM_ADVISOR_URL
            # Get ApmDiagnosticsUrl.
            $ApmDiagnosticsUrl = (Get-ItemProperty $WebConsoleRegKey).APM_DIAGNOSTICS_URL
        }
        Else {
            $WebConsoleInstallDirectory = "n/a"
            #$WebConsoleLastUpdate = "n/a"
            $WebConsoleVersion = "n/a"
            $AuthenticationMode = "n/a"
            $DefaultServer = "n/a"
            $WebConsoleUrl = "n/a"
            $ApmAdvisorUrl = "n/a"
            $ApmDiagnosticsUrl = "n/a"
        }




        <#**************************************** REPORT SERVER SECTION ****************************************#>
        # If this key exists it's a SCOM report server.
        $ReportServerRegKey = "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup\Reporting"
        If ((Get-ItemProperty $ReportServerRegKey).InstallDirectory) {
            $ReportServerInstallDirectory = (Get-ItemProperty $ReportServerRegKey).InstallDirectory.TrimEnd("\")
            # 2016, 1801.
            If (Test-Path "$ReportServerInstallDirectory\Microsoft.Mom.Common.dll") {
                $ReportServerURFile = (Get-Item "$ReportServerInstallDirectory\Microsoft.Mom.Common.dll").VersionInfo.FileVersion
                If (($ReportServerURFile -match "7.2.1") -or ($Script:FileVersion -match "7.3.1" )) {
                    $ReportServerURFile = (Get-Item "C:\Windows\Microsoft.NET\assembly\GAC_MSIL\Microsoft.EnterpriseManagement.OperationsManager\v4.0_7.0.5000.0__31bf3856ad364e35\Microsoft.EnterpriseManagement.OperationsManager.dll").VersionInfo.FileVersion
                    $ReportServerVersion = $ReportServerURFile
                }
                <#
                2019. This needs to be re-done.
                ElseIf ($Script:FileVersion -match "10.19") {
                    # 2019.
                    $File1 = "C:\Windows\Microsoft.NET\assembly\GAC_MSIL\Microsoft.EnterpriseManagement.Core\v4.0_7.0.5000.0__31bf3856ad364e35\Microsoft.EnterpriseManagement.Core.dll" # RTM & UR1Hotfix. Created when RS installed.
                    # Get-FileInfo $File1 # Alert if file doesn't exist.
                    $ReportServerLastUpdate = $Script:FileLastAccessTime # Determines when UR was installed.
                    $ReportServerVersion = $Script:FileVersion
                    $File1Date = $Script:FileLastAccessTimeRaw
                    $File1Version = $Script:FileVersion
                    $File2 = "C:\Windows\Microsoft.NET\assembly\GAC_MSIL\Microsoft.EnterpriseManagement.OperationsManager\v4.0_7.0.5000.0__31bf3856ad364e35\Microsoft.EnterpriseManagement.OperationsManager.dll" # UR1, UR2.
                    # Get-FileInfo $File2 NoAlert # Don't alert if file doesn't exist.
                    If ($Script:FileExists -eq $True) {
                        $File2Date = $Script:FileLastAccessTimeRaw
                        $File2Version = $Script:FileVersion
                        If ($File1Date -lt $File2Date) {
                            # If $File2Date is older than $File1Date it means UR1Hotfix has been installed.
                            $ReportServerLastUpdate = $Script:FileLastAccessTime # Determines when UR was installed.
                            $ReportServerVersion = $Script:FileVersion
                        }
                    }
                }
                #>
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
            $ReportServerDwDbServer = (Get-ItemProperty $ReportServerRegKey\..\..\Reporting).DWDBInstance
            # Get ReportServerDWDBName.
            $ReportServerDWDBName = (Get-ItemProperty $ReportServerRegKey\..\..\Reporting).DWDBName
            # Get ReportServerUrl.
            $ReportServerUrl = (Get-ItemProperty $ReportServerRegKey\..\..\Reporting).ReportingServerUrl
            #Get SRSInstance.
            $SRSInstance = (Get-ItemProperty $ReportServerRegKey\..\..\Reporting).SRSInstance
            <# Get report service account. Using the registry to get report server service info is unreliable because info returned by different SQL versions and named instances is inconsistent.
            #>
            $ReportServerService = Get-WmiObject Win32_Service -Filter "DisplayName like 'SQL Server Reporting Services%'" # Confirmed this works on SQL 2012SP4, 2017.
            $ReportServerServiceAccount = $ReportServerService.StartName
        }
        Else {
            $ReportServerInstallDirectory = "n/a"
            #$ReportServerLastUpdate = "n/a"
            $ReportServerVersion = "n/a"
            $ReportServerDwDbServer = "n/a"
            $ReportServerDWDBName = "n/a"
            $ReportServerUrl = "n/a"
            $SRSInstance = "n/a"
            $ReportServerServiceAccount = "n/a"
            #$ReportServerServiceStartMode = "n/a"
        }

        <#**************************************** CONSOLE SECTION ****************************************#>
        # If this key exists the console is installed.
        $ConsoleRegKey = "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup\Console"
        If (($ConsoleInstallDirectory = Get-ItemProperty -Path $ConsoleRegKey).InstallDirectory) {
            $ConsoleInstallDirectory = $ConsoleInstallDirectory.InstallDirectory.TrimEnd("\")
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
            #$ConsoleLastUpdate = "n/a"
            $ConsoleVersion = "n/a"
        }
        <#**************************************** TESTING SECTION ****************************************#>
        # FOR TESTING
        write-host "OperatingSystem: $OperatingSystem"
        write-host "Product: $Product"
        write-host "AgentInstallDirectory: $AgentInstallDirectory"
        #write-host "AgentLastUpdate: $AgentLastUpdate"
        write-host "AgentVersion: $AgentVersion"
        #write-host "AgentMGCount: $AgentMGCount"
        #write-host "AgentMGFailovers: $AgentMGFailovers"
        write-host "MGCount: $MGCount"
        write-host "MGNames: $MGNames"
        write-host "HealthServiceAccount: $HealthServiceAccount"
        write-host "HealthServiceStartMode: $HealthServiceStartMode"
        write-host "CertificateExpiry: $CertificateExpiry"
        write-host "ADIntegration: $ADIntegration"
        write-host "APMInstalled: $APMInstalled"
        write-host "APMServiceAccount: $APMServiceAccount"
        write-host "APMServiceStartMode: $APMServiceStartMode"
        write-host "ACSForwarderServiceAccount: $ACSForwarderServiceAccount"
        write-host "ACSForwarderServiceStartMode: $ACSForwarderServiceStartMode"
        write-host "TLS12: $TLS12"
        write-host "LAWorkspaceCount: $LAWorkspaceCount"
        write-host "LAWorkspaces: $LAWorkspaces"
        write-host "LAProxyUrl: $LAProxyUrl"
        write-host "LAProxyUsername: $LAProxyUsername"
        write-host "ComputerType: $ComputerType"
        write-host "MgmtServerInstallDirectory: $MgmtServerInstallDirectory"
        #write-host "MgmtServerLastUpdate: $MgmtServerLastUpdate"
        write-host "MgmtServerVersion: $MgmtServerVersion"
        write-host "ConfigServiceAccount: $ConfigServiceAccount"
        #write-host "ConfigServiceStartMode: $ConfigServiceStartMode"
        write-host "DataAccessServiceAccount: $DataAccessServiceAccount"
        #write-host "DataAccessServiceStartMode: $DataAccessServiceStartMode"
        write-host "OpsDbName: $OpsDbName"
        write-host "OpsDbServer: $OpsDbServer"
        write-host "DWDbName: $DWDbName"
        write-host "DwDbServer: $DwDbServer"
        write-host "ACSCollector: $ACSCollector"
        write-host "ACSCollectorServiceAccount: $ACSCollectorServiceAccount"
        #write-host "ACSCollectorServiceStartMode: $ACSCollectorServiceStartMode"
        write-host "ACSCollectorLastUpdate: $ACSCollectorLastUpdate"
        write-host "ACSCollectorVersion: $ACSCollectorVersion"
        write-host "RMS: $RMS"
        write-host "GatewayServerInstallDirectory: $GatewayServerInstallDirectory"
        write-host "GatewayServerLastUpdate: $GatewayServerLastUpdate"
        write-host "GatewayServerVersion: $GatewayServerVersion"
        #write-host "GatewayMGCount: $GatewayMGCount"
        #write-host "GatewayMGFailovers: $GatewayMGFailovers"
        write-host "WebConsoleInstallDirectory: $WebConsoleInstallDirectory"
        #write-host "WebConsoleLastUpdate: $WebConsoleLastUpdate"
        write-host "WebConsoleVersion: $WebConsoleVersion"
        write-host "AuthenticationMode: $AuthenticationMode"
        write-host "DefaultServer: $DefaultServer"
        write-host "WebConsoleUrl: $WebConsoleUrl"
        write-host "ApmAdvisorUrl: $ApmAdvisorUrl"
        write-host "ApmDiagnosticsUrl: $ApmDiagnosticsUrl"
        write-host "ReportServerInstallDirectory: $ReportServerInstallDirectory"
        #write-host "ReportServerLastUpdate: $ReportServerLastUpdate"
        write-host "ReportServerVersion: $ReportServerVersion"
        write-host "ReportServerDwDbServer: $ReportServerDwDbServer"
        write-host "ReportServerDWDBName: $ReportServerDWDBName"
        write-host "ReportServerUrl: $ReportServerUrl"
        write-host "SRSInstance: $SRSInstance"
        write-host "ReportServerServiceAccount: $ReportServerServiceAccount"
        #write-host "ReportServerServiceStartMode: $ReportServerServiceStartMode"
        write-host "ConsoleInstallDirectory: $ConsoleInstallDirectory"
        #write-host "ConsoleLastUpdate: $ConsoleLastUpdate"
        write-host "ConsoleVersion: $ConsoleVersion"
        Write-Host "PSVersion: $PSVersion" # Not returned as discovery data. Only used in events.
        #>
        <#**************************************** ADD DISCOVERY DATA SECTION ****************************************#>
        $Instance = $DiscoveryData.CreateClassInstance("$MPElement[Name='SCOM.Class.URWindowsComputer']$")
        $Instance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $ComputerName)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/OperatingSystem$", $OperatingSystem)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/Product$", $Product)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/AgentInstallDirectory$", $AgentInstallDirectory)
        #$Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/AgentLastUpdate$", $AgentLastUpdate)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/AgentVersion$", $AgentVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/MGCount$", $MGCount)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/MGNames$", $MGNames)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/HealthServiceAccount$", $HealthServiceAccount)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/HealthServiceStartMode$", $HealthServiceStartMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/CertificateExpiry$", $CertificateExpiry)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ADIntegration$", $ADIntegration)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/APMInstalled$", $APMInstalled)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/APMServiceAccount$", $APMServiceAccount)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/APMServiceStartMode$", $APMServiceStartMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ACSForwarderServiceAccount$", $ACSForwarderServiceAccount)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ACSForwarderServiceStartMode$", $ACSForwarderServiceStartMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/TLS12$", $TLS12)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/LAWorkspaceCount$", $LAWorkspaceCount)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/LAWorkspaces$", $LAWorkspaces)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/LAProxyUrl$", $Script:LAProxyUrl)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/LAProxyUsername$", $Script:LAProxyUsername)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ComputerType$", $ComputerType)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/MgmtServerInstallDirectory$", $MgmtServerInstallDirectory)
        #$Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/MgmtServerLastUpdate$", $MgmtServerLastUpdate)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/MgmtServerVersion$", $MgmtServerVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ConfigServiceAccount$", $ConfigServiceAccount)
        #$Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ConfigServiceStartMode$", $ConfigServiceStartMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/DataAccessServiceAccount$", $DataAccessServiceAccount)
        #$Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/DataAccessServiceStartMode$", $DataAccessServiceStartMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/OpsDbName$", $OpsDbName)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/OpsDbServer$", $OpsDbServer)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/DWDbName$", $DWDbName)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/DwDbServer$", $DwDbServer)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ACSCollector$", $ACSCollector)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ACSCollectorServiceAccount$", $ACSCollectorServiceAccount)
        #$Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ACSCollectorServiceStartMode$", $ACSCollectorServiceStartMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ACSCollectorLastUpdate$", $ACSCollectorLastUpdate)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ACSCollectorVersion$", $ACSCollectorVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/RMS$", $RMS)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/GatewayServerInstallDirectory$", $GatewayServerInstallDirectory)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/GatewayServerLastUpdate$", $GatewayServerLastUpdate)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/GatewayServerVersion$", $GatewayServerVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/WebConsoleInstallDirectory$", $WebConsoleInstallDirectory)
        #$Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/WebConsoleLastUpdate$", $WebConsoleLastUpdate)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/WebConsoleVersion$", $WebConsoleVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/AuthenticationMode$", $AuthenticationMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/DefaultServer$", $DefaultServer)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/WebConsoleUrl$", $WebConsoleUrl)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ApmAdvisorUrl$", $ApmAdvisorUrl)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ApmDiagnosticsUrl$", $ApmDiagnosticsUrl)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerInstallDirectory$", $ReportServerInstallDirectory)
        #$Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerLastUpdate$", $ReportServerLastUpdate)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerVersion$", $ReportServerVersion)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerDwDbServer$", $ReportServerDwDbServer)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerDWDBName$", $ReportServerDWDBName)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerUrl$", $ReportServerUrl)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/SRSInstance$", $SRSInstance)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerServiceAccount$", $ReportServerServiceAccount)
        #$Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ReportServerServiceStartMode$", $ReportServerServiceStartMode)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ConsoleInstallDirectory$", $ConsoleInstallDirectory)
        #$Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ConsoleLastUpdate$", $ConsoleLastUpdate)
        $Instance.AddProperty("$MPElement[Name='SCOM.Class.URWindowsComputer']/ConsoleVersion$", $ConsoleVersion)
        $Instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $ComputerName)
        $DiscoveryData.AddInstance($Instance)
        # Submit discovery data back to Operations Manager and complete the script.
        $DiscoveryData
        # FOR TESTING
        $MomApi.Return($DiscoveryData)
        #>
        $ScriptState = "Information"
        Write-Log -ScriptState $ScriptState   
    }
    Catch {
        $ScriptState = "Warning"
        $Message += $_.Exception.Message
        Write-Log -ScriptState $ScriptState       
    }
}
# Declare all constants used by the script`
[datetime]$StartTime = Get-Date
$MomApi = New-Object -comObject 'MOM.ScriptAPI'
$ScriptName = "GetURInfo.ps1"
$Account = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Mp = "SCOM.UpdateRollup"
$MpVersion = "2023.9.25.0"
$MpWorkflow = "SCOM.Discovery.WindowsUpdateRollup"
Get-URInfo -SourceId $SourceId -ManagedEntityId $ManagedEntityId -ComputerName $ComputerName