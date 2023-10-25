use OperationsManager
SELECT  AlertStringName, TimeRaised as Utc_Time,
dateadd(HH, datediff(HH,GETUTCDATE(), getdate()), TimeRaised) as Local_Time, --UTC date conversion.
IsMonitorAlert
FROM [OperationsManager].[dbo].[AlertView] -- use this table coz 'Alerts' table shows weird alert names that aren't in the console.
where ResolutionState!='255'
ORDER BY TimeRaised desc
