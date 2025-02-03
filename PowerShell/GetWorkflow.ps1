<#
Last update: 03/02/2025
This searches for rules, monitors or discoveries and returns either the name/displayname and class id (target) of the workflow.
If you search by name or displayname (n/d) that will be the first column sorted alphabetically. 
Improvements: Get proper class name instead of ID.
#>
param($SearchBy, $WorkflowType, $WorkflowName)
Write-Host
Write-Host -ForegroundColor yellow "Getting $WorkflowType(s)..."
Write-Host
Write-Host -ForegroundColor green "NAME | DISPLAYNAME, CLASS_ID (Sorted by column '$SearchBy')."
Write-Host
if ($SearchBy -eq "n") {
	
    if ($WorkflowType -eq "rule") {
        $Workflows = Get-SCOMRule -Name "*$WorkflowName*" | sort Name
    }
    elseif ($WorkflowType -eq "monitor") {
        $Workflows = Get-SCOMMonitor -Name "*$WorkflowName*" | sort Name
    }
    elseif ($WorkflowType -eq "discovery") {
        $Workflows = Get-SCOMDiscovery -Name "*$WorkflowName*" | sort Name
    }
}
elseif ($SearchBy -eq "d") {
    if ($WorkflowType -eq "rule") {
        $Workflows = Get-SCOMRule -DisplayName "*$WorkflowName*" | sort DisplayName
    }
    elseif ($WorkflowType -eq "monitor") {
        $Workflows = Get-SCOMMonitor -DisplayName "*$WorkflowName*" | sort DisplayName
    }	
    elseif ($WorkflowType -eq "discovery") {
        $Workflows = Get-SCOMDiscovery -DisplayName "*$WorkflowName*" | sort DisplayName
    }	
}
foreach ($Workflow in $Workflows) {
    [string]$WorkflowClassId = $Workflow.Target.Id.Guid
    if ($SearchBy -eq "n") {
        [string]$WorkflowName = $Workflow.Name
        Write-Host "$WorkflowName, $WorkflowClassId"
    }
    elseif ($SearchBy -eq "d") {
        [string]$WorkflowDisplayName = $Workflow.DisplayName
        Write-Host "$WorkflowDisplayName, $WorkflowClassId"
    }
}