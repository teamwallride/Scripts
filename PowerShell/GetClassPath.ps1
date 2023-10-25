##This script accepts a class name, and returns the entire
##Base class path.  It also returns Host Class for each
##Base class returned.  Essentially, you'll see the entire
##class path for the given class.
##Author: Jonathan Almquist
##Microsoft - Services - Premier Field Engineer
##version 1.0
##11-01-2008

##Usage = getClassPath.ps1 <class_name>
##Example = getClassPath.ps1 Microsoft.Windows.Computer
clear-host

$classname = $args[0]
$ast = "-"
$class = get-SCOMClass -name $classname
Write-Host ($ast * 80)
Write-Host -foregroundcolor green "Class Properties For:" $class
Write-Host ($ast * 80)`n
while ($class -ne "False")
	{
	$property = $class | foreach-object {$_.GetProperties()} | Select-Object name
	foreach ($value in $Property)
		{
		if ($value.name -ne $null)
			{
			write-host -foregroundcolor yellow $value.name
			}
			else
			{
			Write-Host -foregroundcolor red "No properties"
			}
		}
	write-host `n
	Write-Host ($ast * 80)
	Write-Host -foregroundcolor green "Base Class Path For:" $class
	Write-Host ($ast * 80)`n
	$baseclass = get-SCOMClass | where {$_.id -eq $class.base.id.tostring()}
	While ($baseclass.base.id -ne $NULL)
		{
		$baseclass.name
		$property = $baseclass | foreach-object {$_.GetProperties()} | Select-Object name
		foreach ($value in $Property)
			{
			write-host -foregroundcolor yellow $value.name
			}
		$baseclass = get-SCOMClass | where {$_.id -eq $baseclass.base.id.tostring()}
		}
	if ($class.hosted -eq "True")
		{
		$hostclass = get-SCOMClass | where {$_.name -eq $Class.Name} | ForEach-Object {$_.findHostClass()}
		write-host `n
		Write-Host ($ast * 80)
		Write-Host -foregroundcolor green "HOST CLASS For:" $class
		Write-Host ($ast * 80)`n
		$class = get-SCOMClass | where {$_.name -eq $Class.Name} | ForEach-Object {$_.findHostClass()}
		Write-Host $class
		}
		else
		{
		write-host -foregroundcolor red "*Not Hosted*" `n`n
		$class = "False"
		}
	}

