# Generate a sinlge GUID
[guid]::NewGuid().ToString("N")

# Generate x number of GUIDs
1..5 | % {[guid]::NewGuid().ToString("N")}
