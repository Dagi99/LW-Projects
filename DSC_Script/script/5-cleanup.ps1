# Warning - this script will delete itself and all files in the directory its in

# Get absolute path of current directory
$scriptpath = $MyInvocation.MyCommand.Path
$dirPath = $MyInvocation.MyCommand.Path | Split-Path

# Copy registry to default desktop
Copy-Item -Path $dirPath\6-registry-pinnedapps -Destination C:\Users\Default\Desktop -Recurse -Force

# New scheduled task to execute the registry script for the new user
$STA = New-ScheduledTaskAction -Execute "C:\Program Files\PowerShell\7\pwsh.exe" -Argument "-File C:\Users\$username\Desktop\6-registry-pinnedapps\6-registry-pinnedapps.ps1"
$STT = New-ScheduledTaskTrigger -AtLogOn -User $hostname\$username
$STP = New-ScheduledTaskPrincipal -UserId "$hostname\$username" -RunLevel "Highest"
$settings = New-ScheduledTaskSettingsSet
$task = New-ScheduledTask -Action $STA -Trigger $STT -Settings $settings -Principal $STP
Register-ScheduledTask Script6 -InputObject $task

# Delete all the evidence
Get-ChildItem $dirPath -Exclude "5-cleanup.ps1" | Remove-Item -Force -Recurse -Confirm:$false
Remove-Item $scriptpath -Recurse -Force -Confirm:$false

# Remove the installer-user
Remove-LocalUser -Name $env:USERNAME

# Cleanup the TaskScheduler
Unregister-ScheduledTask -TaskName Script5 -Confirm:$false

logoff