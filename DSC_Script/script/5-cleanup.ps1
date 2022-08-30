# Warning - this script will delete itself and all files in the directory its in

# Get absolute path of current directory
$scriptpath = $MyInvocation.MyCommand.Path
$dirPath = $MyInvocation.MyCommand.Path | Split-Path

# Copy registry to default desktop
Copy-Item -Path $dirPath\6-registry-pinnedapps -Destination C:\Users\Default\Desktop -Recurse -Force

# Delete all the evidence
Get-ChildItem $dirPath -Exclude "5-cleanup.ps1" | Remove-Item -Force -Recurse -Confirm:$false
Remove-Item $scriptpath -Recurse -Force -Confirm:$false
Remove-Item $dirPath -Force -Confirm:$false

# Remove the installer-user
Remove-LocalUser -Name $env:USERNAME

# Cleanup the TaskScheduler
Unregister-ScheduledTask -TaskName Script5 -Confirm:$false

logoff