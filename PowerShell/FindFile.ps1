param($Filename)
Get-ChildItem -Path C:\ -Filter $Filename -Recurse -ErrorAction SilentlyContinue -Force | ft Directory -au