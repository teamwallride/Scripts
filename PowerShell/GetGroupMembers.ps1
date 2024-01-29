param ($DisplayName)
(get-scomgroup -DisplayName $DisplayName).GetRelatedMonitoringObjects() | sort displayname | ft displayname, fullname