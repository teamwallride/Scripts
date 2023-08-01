<#
Syntax: "search-two-files.ps1 %argument%" (only the number 1 or 2 can be the argument).
If you type "search-two-files.ps1 1" it will compare the content of File 1 to File 2.
If you type "search-two-files.ps1 2" it will compare the content of File 2 to File 1.
#>

#$ErrorActionPreference = "SilentlyContinue"
$arg1 = $args[0]

switch ($arg1)
{
	"1" 
	{
	$File1 = "File1.txt"
	$File2 = "File2.txt"
	}
	"2" 
	{
	$File1 = "File2.txt"
	$File2 = "File1.txt"
	}
}

$SourceFile = Get-Content "C:\temp\$File1" | sort
$DestFile = Get-Content "C:\temp\$File2" | sort
$countmatch = 0
$countnomatch = 0
$date = Get-Date
Write-Host
write-host "Script started:" $date
Write-Host
Write-Host "------------------------"
Write-Host -ForegroundColor green "GREEN=Match " -NoNewline ; Write-Host -ForegroundColor red "RED=No Match"
Write-Host "------------------------"
Write-Host
Write-Host -ForegroundColor yellow "Comparing $File1 to $File2..."
Write-Host

foreach($item in $SourceFile)
{
#OG line: $match = Select-String -InputObject $DestFile -Pattern $item -Quiet -SimpleMatch
$match = Select-String -InputObject $DestFile "\b$item\b" -Quiet

 if ($match -eq $true)
        {
        Write-Host -ForegroundColor green $item.ToUpper() ", Yes"
        $countmatch = $countmatch + 1
		#$item.ToUpper() | Out-File C:\Temp\_output.txt -Append
        }
    else
        {
        Write-Host -ForegroundColor red $item.ToUpper() ", No"
		$countnomatch = $countnomatch + 1
		#$comps += "$item `n"
		
		#Uncomment this line to write output to file.
		#$item.ToUpper() | Out-File C:\Temp\_output.txt -Append
        }
}
Write-Host ""
Write-Host -ForegroundColor yellow "------------------------------------------------"
Write-Host -ForegroundColor yellow "*** TOTALS ***"
Write-Host
Write-Host -ForegroundColor yellow "Source file ($File1) -" $SourceFile.count
Write-Host -ForegroundColor yellow "Destination file ($File2) -" $DestFile.count
Write-Host -ForegroundColor yellow "Matches:" $countmatch #"($pcntmatch%)"
Write-Host -ForegroundColor yellow "Missing:" $countnomatch #"($pcntnomatch%)"
Write-Host -ForegroundColor yellow "------------------------------------------------"
Write-Host
