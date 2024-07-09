param($Log, $Source, $Id, $Level, $Message)
<#
$Level: Error, Warning, Information
#>
Write-EventLog -LogName $Log -Source $Source -EventId $Id -EntryType $Level -Message $Message -Category 0