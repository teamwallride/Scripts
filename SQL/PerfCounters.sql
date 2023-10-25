--Basic query to get C: driver counter. Need to figure out how to pull back last sampled value from single computer.
select Path, ObjectName, CounterName, InstanceName, SampleValue, TimeSampled
from PerformanceDataAllView pdv with (NOLOCK) 
inner join PerformanceCounterView pcv on pdv.performancesourceinternalid = pcv.performancesourceinternalid 
inner join BaseManagedEntity bme on pcv.ManagedEntityId = bme.BaseManagedEntityId 
where path = 'server_fqdn'
AND objectname = 'LogicalDisk' 
AND countername = 'Free Megabytes'
AND InstanceName = 'c:'
order by timesampled DESC

--Get every perf counter - single computer
select Distinct Path, ObjectName, CounterName, InstanceName 
from PerformanceDataAllView pdv with (NOLOCK) 
inner join PerformanceCounterView pcv on pdv.performancesourceinternalid = pcv.performancesourceinternalid 
inner join BaseManagedEntity bme on pcv.ManagedEntityId = bme.BaseManagedEntityId 
where path = 'server_fqdn'
order by objectname, countername, InstanceName

--CPU % Processor Time - single computer
select Path, ObjectName, CounterName, InstanceName, SampleValue, TimeSampled
from PerformanceDataAllView pdv with (NOLOCK) 
inner join PerformanceCounterView pcv on pdv.performancesourceinternalid = pcv.performancesourceinternalid 
inner join BaseManagedEntity bme on pcv.ManagedEntityId = bme.BaseManagedEntityId 
where path = 'server_fqdn' 
AND  objectname = 'Processor Information' 
AND countername = '% Processor Time'
order by timesampled DESC

--CPU % Processor Time - single computer
select Path, ObjectName, CounterName, InstanceName, SampleValue, TimeSampled
from PerformanceDataAllView pdv with (NOLOCK) 
inner join PerformanceCounterView pcv on pdv.performancesourceinternalid = pcv.performancesourceinternalid 
inner join BaseManagedEntity bme on pcv.ManagedEntityId = bme.BaseManagedEntityId 
where path = 'server_fqdn' 
AND objectname = 'System' 
AND countername = 'Processor Queue Length'
order by timesampled DESC

--Get memory Available MBytes - single computer
select Path, ObjectName, CounterName, InstanceName, SampleValue, TimeSampled
from PerformanceDataAllView pdv with (NOLOCK) 
inner join PerformanceCounterView pcv on pdv.performancesourceinternalid = pcv.performancesourceinternalid 
inner join BaseManagedEntity bme on pcv.ManagedEntityId = bme.BaseManagedEntityId 
where path = 'server_fqdn' 
AND objectname = 'Memory' 
AND countername = 'Available MBytes'
order by timesampled DESC

--Get memory PercentMemoryUsed - single computer
select Path, ObjectName, CounterName, InstanceName, SampleValue, TimeSampled
from PerformanceDataAllView pdv with (NOLOCK) 
inner join PerformanceCounterView pcv on pdv.performancesourceinternalid = pcv.performancesourceinternalid 
inner join BaseManagedEntity bme on pcv.ManagedEntityId = bme.BaseManagedEntityId 
where path = 'server_fqdn' 
AND objectname = 'Memory' 
AND countername = 'PercentMemoryUsed'
order by timesampled DESC
