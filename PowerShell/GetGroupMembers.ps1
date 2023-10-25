param ($GroupName)
(get-scomgroup -DisplayName $GroupName).GetRelatedMonitoringObjects() | sort displayname | ft displayname, fullname
