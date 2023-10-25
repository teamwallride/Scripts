Use OperationsManagerDW
SELECT
CONVERT(datetime,SWITCHOFFSET(CONVERT(datetimeoffset,vAlert.RaisedDateTime),DATENAME(TzOffset, SYSDATETIMEOFFSET()))) [AlertGenerated],
Path as ComputerName,
--vAlert.AlertName,
--vAlert.Severity,
--vAlert.Priority,
--vAlert.AlertDescription,
replace (vAlert.AlertDescription, 'The threshold for the Processor Information\% Processor Time\_Total performance counter has been exceeded. The values that exceeded the threshold are: ', '') as [Values]
FROM
alert.vAlert vAlert
inner join
vManagedEntity vEntity
on
vAlert.ManagedEntityRowId = vEntity.ManagedEntityRowId
WHERE vAlert.AlertName = 'Total CPU Utilization Percentage is too high'
--and path = 'FQDN'
AND vAlert.RaisedDateTime > DATEADD(DAY, -31, GETUTCDATE())
ORDER by raiseddatetime desc
