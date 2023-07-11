<#
The purpose of this script is to ensure the information between SCOM and the CMDB is accurate.
This is done by comparing information between both environments using SQL queries.
Discrepencies are reported to screen and csv file.
You can run the script on a mgmt server or a computer with the OperationsManager PowerShell module installed.
For non-mgmt servers, you will need to add the name of a mgmt server and the Ops db name. 
==========
CHANGE LOG
==========
2023.7.4.0 - Initial release.
#>

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
    #write-host "Count:" $SqlTable.name.count
    Return $SqlTable
}

# This captures invalid class, category, status and CIs with pending status as they need to be progressed.
Function CheckValidFields {
    param($Param1, $Param2, $Param3)
    $match = select-string -inputobject $Param1 "\b$Param2\b" -quiet
    If ($Param2 -eq "Pending") {
        $Global:Output += "$CIName^$CIClass^$Param3 is $Param2"
    }
    ElseIf ($match -ne $true) {
        $Global:Marker = "BAD"
        $Global:Result += "Invalid $Param3`:$Param2,"
    }
}

# This compares two tables.
Function CompareTables {
    Param($PSourceTable, $PInputTable)
    ForEach ($i In $PSourceTable) {
        $CIName = $i.Name
        $match = select-string -inputobject $PInputTable.Name "\b$CIName\b" -quiet
        Switch ($Direction) {
            "CmdbToScom" {
                If (($CIStatus -eq "Active") -and ($match -ne $true)) {
                    $Global:Output += "$CIName^$PClass^Object should be in SCOM group $PGroup"
                }
                ElseIf (($CIStatus -eq "Decommissioned") -and ($match -eq $true)) {
                    $Global:Output += "$CIName^$PClass^Object should not be in SCOM group $PGroup"
                }
                ElseIf (($CIStatus -eq "Disabled") -and ($match -eq $true)) {
                    $Global:Output += "$CIName^$PClass^Object should not be in SCOM group $PGroup"
                }
                ElseIf (($CIStatus -eq "Invalid") -and ($match -eq $true)) {
                    $Global:Output += "$CIName^$PClass^Object should not be in SCOM group $PGroup"
                }
                ElseIf (($CIStatus -eq "Pending") -and ($match -eq $true)) {
                    $Global:Output += "$CIName^$PClass^Object should not be in SCOM group $PGroup"
                }
            }
            "ScomToCmdb" {
                If ($match -ne $true) {
                    $Global:Output += "$CIName^$PClass^Missing CI"
                }
            }
        }
    }
}

Function CmdbToScom {
    param($PClass, $PCategory, $PStatus, $PGroup, $PColumnName)
    $CmdbQuery = "SELECT Name from [$CmdbDbName].[dbo].[Configuration] where class = '$PClass' and [Category] = '$PCategory' and [Status] = '$PStatus' order by Name"
    $SqlTable = SQLQuery -DbServer $OpsDbServer -DbName $CmdbDbName -DbQuery $CmdbQuery
    $CmdbTable = $SqlTable
    if ($CmdbTable.count -eq 0) {
    }
    else {
        $ScomQuery = "SELECT $PColumnName AS Name from [$OpsDbName].[dbo].[RelationshipGenericView] where SourceObjectFullName = '$PGroup' and isDeleted=0 order by Name"
        $SqlTable = SQLQuery -DbServer $OpsDbServer -DbName $OpsDbName -DbQuery $ScomQuery
        $ScomTable = $SqlTable
        CompareTables -PSourceTable $CmdbTable -PInputTable $ScomTable
    }
}

Function ScomToCmdb {
    param($PScomQuery, $PClass)
    $ScomQuery = $PScomQuery
    $SqlTable = SQLQuery -DbServer $OpsDbServer -DbName $OpsDbName -DbQuery $ScomQuery
    $ScomTable = $SqlTable
    $CmdbQuery = "SELECT Name from [$CmdbDbName].[dbo].[Configuration] where class = '$PClass' order by Name"
    $SqlTable = SQLQuery -DbServer $OpsDbServer -DbName $CmdbDbName -DbQuery $CmdbQuery
    $CmdbTable = $SqlTable
    CompareTables -PSourceTable $ScomTable -PInputTable $CmdbTable
}

Function FlagBad {
    if ($Global:Marker -eq "BAD") {
        $Global:Result = $Global:Result.SubString(0, $Global:Result.Length - 1) # This removes the last comma.
        $Global:Output += "$CIName^$CIClass^$Global:Result"
        $Global:Result = $null
        $Global:Marker = $null
    }
}

Try {
    CLS
    $OutputFile = "C:\temp\SCOM_CMDB_TrueUp.csv"
    $Global:Result = $null
    $Global:Output = $null
    $Global:Output = @()
    $CmdbDbName = "SCOMCmdb"

    # Set these variables manually if not running on mgmt server.
	$SetupRegKey="HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup"
	$OpsDbServer=(Get-ItemProperty $SetupRegKey).DatabaseServerName
	$OpsDbName=(Get-ItemProperty $SetupRegKey).DatabaseName
	$DWDbName=(Get-ItemProperty $SetupRegKey).DataWarehouseDBName
	$DwDbServer=(Get-ItemProperty $SetupRegKey).DataWarehouseDBServerName
	#>

    # These are the only valid settings that can be used in the CMDB.
    $ValidClass = @('DomainController', 'FederationServer', 'IISWebServer', 'LinuxServer', 'SqlServer', 'WindowsCluster', 'WindowsDhcpServer', 'WindowsDnsServer', 'WindowsServer')
    $ValidCategory = @('CatA', 'CatB', 'CatC')
    $ValidStatus = @('Active', 'Decommissioned', 'Disabled', 'Invalid', 'Pending') # Only 'Active' CIs should be in a SCOM group.

    # Get CMDB CIs.
    $CmdbQuery = "SELECT Name, Class, Category, Status from [$CmdbDbName].[dbo].[Configuration] order by Class, Name"
    $SqlTable = SQLQuery -DbServer $OpsDbServer -DbName $CmdbDbName -DbQuery $CmdbQuery
    $CmdbTable = $SqlTable

    # Check each CI has a valid class, category and status.
    $CmdbTable | ForEach-Object {
        $CIName = $_.Name
        $CIClass = $_.Class
        $CICategory = $_.Category
        $CIStatus = $_.Status
        CheckValidFields -Param1 $ValidClass -Param2 $CIClass -Param3 "Class"
        CheckValidFields -Param1 $ValidCategory -Param2 $CICategory -Param3 "Category"
        CheckValidFields -Param1 $ValidStatus -Param2 $CIStatus -Param3 "Status"
        FlagBad
    }

    <#
The intention here is to make sure only CIs marked active are in the relevant SCOM group.
If a CI status is anything other than active and is in a SCOM group, that is bad and we need to know about it.
This can happen if a CI has recently changed from active and the group discovery has not updated yet.
Note: Not all groups listed here will exist in SCOM, it depends how many groups you need per customer.
#>
    $Direction = "CmdbToScom"
    foreach ($CIStatus in $ValidStatus) {
        CmdbToScom -PClass "DomainController" -PCategory "CatA" -PStatus "$CIStatus" -PGroup "Cmdb.Group.ADDSCatA" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "DomainController" -PCategory "CatB" -PStatus "$CIStatus" -PGroup "Cmdb.Group.ADDSCatB" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "DomainController" -PCategory "CatC" -PStatus "$CIStatus" -PGroup "Cmdb.Group.ADDSCatC" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "FederationServer" -PCategory "CatA" -PStatus "$CIStatus" -PGroup "Cmdb.Group.ADFSCatA" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "FederationServer" -PCategory "CatB" -PStatus "$CIStatus" -PGroup "Cmdb.Group.ADFSCatB" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "FederationServer" -PCategory "CatC" -PStatus "$CIStatus" -PGroup "Cmdb.Group.ADFSCatC" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsDhcpServer" -PCategory "CatA" -PStatus "$CIStatus" -PGroup "Cmdb.Group.DHCPCatA" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsDhcpServer" -PCategory "CatB" -PStatus "$CIStatus" -PGroup "Cmdb.Group.DHCPCatB" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsDhcpServer" -PCategory "CatC" -PStatus "$CIStatus" -PGroup "Cmdb.Group.DHCPCatC" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsDnsServer" -PCategory "CatA" -PStatus "$CIStatus" -PGroup "Cmdb.Group.DNSCatA" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsDnsServer" -PCategory "CatB" -PStatus "$CIStatus" -PGroup "Cmdb.Group.DNSCatB" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsDnsServer" -PCategory "CatC" -PStatus "$CIStatus" -PGroup "Cmdb.Group.DNSCatC" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsServer" -PCategory "CatA" -PStatus "$CIStatus" -PGroup "Cmdb.Group.HealthServiceWatcherCatA" -PColumnName "TargetObjectDisplayName" # note different name
        CmdbToScom -PClass "WindowsServer" -PCategory "CatB" -PStatus "$CIStatus" -PGroup "Cmdb.Group.HealthServiceWatcherCatB" -PColumnName "TargetObjectDisplayName" # note different name
        CmdbToScom -PClass "WindowsServer" -PCategory "CatC" -PStatus "$CIStatus" -PGroup "Cmdb.Group.HealthServiceWatcherCatC" -PColumnName "TargetObjectDisplayName" # note different name
        CmdbToScom -PClass "IISWebServer" -PCategory "CatA" -PStatus "$CIStatus" -PGroup "Cmdb.Group.IISCatA" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "IISWebServer" -PCategory "CatB" -PStatus "$CIStatus" -PGroup "Cmdb.Group.IISCatB" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "IISWebServer" -PCategory "CatC" -PStatus "$CIStatus" -PGroup "Cmdb.Group.IISCatC" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "SqlServer" -PCategory "CatA" -PStatus "$CIStatus" -PGroup "Cmdb.Group.SQLCatA" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "SqlServer" -PCategory "CatB" -PStatus "$CIStatus" -PGroup "Cmdb.Group.SQLCatB" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "SqlServer" -PCategory "CatC" -PStatus "$CIStatus" -PGroup "Cmdb.Group.SQLCatC" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsCluster" -PCategory "CatA" -PStatus "$CIStatus" -PGroup "Cmdb.Group.WindowsClusterCatA" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsCluster" -PCategory "CatB" -PStatus "$CIStatus" -PGroup "Cmdb.Group.WindowsClusterCatB" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsCluster" -PCategory "CatC" -PStatus "$CIStatus" -PGroup "Cmdb.Group.WindowsClusterCatC" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsServer" -PCategory "CatA" -PStatus "$CIStatus" -PGroup "Cmdb.Group.WindowsServerCatA" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsServer" -PCategory "CatB" -PStatus "$CIStatus" -PGroup "Cmdb.Group.WindowsServerCatB" -PColumnName "TargetObjectName"
        CmdbToScom -PClass "WindowsServer" -PCategory "CatC" -PStatus "$CIStatus" -PGroup "Cmdb.Group.WindowsServerCatC" -PColumnName "TargetObjectName"
    }

    <#
The intention here is to check for items that are in SCOM but have no CI in the CMDB.
For each valid class in the CMDB, it gets the matching class and objects in SCOM, then gets all CIs of that class from the CMDB (ignoring category + status) and reports discrepancies.
#>
    Foreach ($CIClass in $ValidClass) {
        $Direction = "ScomToCmdb"
        Switch ($CIClass) {
            "DomainController" {
                $ScomQuery = "SELECT TargetObjectPath AS Name from [$OpsDbName].[dbo].[RelationshipGenericView]
where SourceObjectFullName = 'Microsoft.Windows.Server.2012.R2.AD.DomainControllerComputerGroup' and isDeleted=0 -- 2012R2 servers. No DCs to test, haven't confirmed.
UNION ALL
SELECT TargetObjectPath AS Name from [$OpsDbName].[dbo].[RelationshipGenericView]
where SourceObjectFullName = 'Microsoft.Windows.Server.2016.AD.DomainControllerComputerGroup' and isDeleted=0 -- 2016 servers
order by Name"
                ScomToCmdb -PScomQuery $ScomQuery -PClass $CIClass ; break
            }

            "FederationServer" {
                $ScomQuery = "SELECT displayname AS Name from [$OpsDbName].[dbo].[MTV_Microsoft`$ActiveDirectoryFederationServices2012R2`$FederationServer] order by Name" # 2012R2 ADFSonly
                ScomToCmdb -PScomQuery $ScomQuery -PClass $CIClass ; break
            }

            "IISWebServer" {
                $ScomQuery = "SELECT TargetObjectPath AS Name from [$OpsDbName].[dbo].[RelationshipGenericView] where SourceObjectFullName = 'Microsoft.Windows.InternetInformationServices.ServerRoleGroup' and isDeleted=0 order by Name" # All IIS servers
                ScomToCmdb -PScomQuery $ScomQuery -PClass $CIClass ; break
            }

            "LinuxServer" {
                $ScomQuery = "SELECT DisplayName AS Name from [$OpsDbName].[dbo].[MT_Microsoft`$Unix`$Computer] order by Name" # All UNIX/Linux servers
                ScomToCmdb -PScomQuery $ScomQuery -PClass $CIClass ; break
            }

            "SqlServer" {
                $ScomQuery = "SELECT TargetObjectName AS Name from [$OpsDbName].[dbo].[RelationshipGenericView] where SourceObjectFullName = 'Microsoft.SQLServer.Windows.ComputersGroup' and isDeleted=0 order by Name" # All SQL servers
                ScomToCmdb -PScomQuery $ScomQuery -PClass $CIClass ; break
            }

            "WindowsCluster" {
                $ScomQuery = "SELECT displayname AS Name from [$OpsDbName].[dbo].[MT_Microsoft`$Windows`$Cluster] order by Name" # All clusters
                ScomToCmdb -PScomQuery $ScomQuery -PClass $CIClass ; break
            }

            "WindowsDhcpServer" {
                $ScomQuery = "SELECT displayname AS Name from [$OpsDbName].[dbo].[MT_Microsoft`$Windows`$DHCPServer`$Library`$Server] order by Name" # All DHCP servers
                ScomToCmdb -PScomQuery $ScomQuery -PClass $CIClass ; break
            }

            "WindowsDnsServer" {
                $ScomQuery = "SELECT Name_EE69CFA7_E62F_66D7_CAEF_775E4BBA1C62 AS Name FROM [$OpsDbName].[dbo].[MT_Microsoft`$Windows`$Server`$DNS`$Server] -- 2012R2 servers
UNION ALL
SELECT Name_53F40805_9E76_4453_C2E5_520541488459 FROM [$OpsDbName].[dbo].[MT_Microsoft`$Windows`$DNSServer`$2016`$Server] -- 2016 servers
order by Name"
                ScomToCmdb -PScomQuery $ScomQuery -PClass $CIClass ; break
            }

            "WindowsServer" {
                $ScomQuery = "SELECT DisplayName AS Name
FROM [$OpsDbName].[dbo].[MT_HealthService] hs
inner join [$OpsDbName].[dbo].[Availability] av
on hs.BaseManagedEntityId=av.BaseManagedEntityId
order by Name"
                ScomToCmdb -PScomQuery $ScomQuery -PClass $CIClass ; break
            }

        } # end switch
    } # end foreach
} # end try
Catch {
    $_.Exception.Message
}

#write-host -foregroundcolor cyan $Global:Output
$Global:Output = $Global:Output | sort
$WriteOutput = , "CI_NAME^CI_CLASS^PROBLEM" + $Global:Output
$WriteOutput | out-file $OutputFile
Write-Host
Write-Host -foregroundcolor yellow "Writing output to $OutputFile"
Write-Host
