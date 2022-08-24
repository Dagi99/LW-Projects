# Warning - this script will delete itself and all files in the directory its in

# Get absolute path of current directory
$scriptpath = $MyInvocation.MyCommand.Path
$directorypath = $MyInvocation.MyCommand.Path | Split-Path

# Delete all the evidence
Get-ChildItem $directorypath -Exclude cleanup.ps1 | Remove-Item -Force -Recurse -Confirm:$false
Remove-Item $scriptpath -Recurse -Force -Confirm:$false

# Remove the installer-user
Remove-LocalUser -Name "test"

# It's probably a good idea to give the system some time to think about things...
Start-Sleep -s 3

# Cleanup the TaskScheduler
Unregister-ScheduledTask -TaskName ScriptCleanup -Confirm:$false

logoff