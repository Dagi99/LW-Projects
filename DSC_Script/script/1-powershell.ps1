# Get absolute path to current directory
$DirPath = $MyInvocation.MyCommand.Path | Split-Path

# Download Powershell 7
Write-Output "Download Powershell 7..."
Invoke-WebRequest -Uri "https://github.com/PowerShell/PowerShell/releases/download/v7.2.6/PowerShell-7.2.6-win-x64.msi" -Outfile $DirPath\powershell7.msi

# Install Powershell 7
Start-Process C:\Windows\System32\msiexec.exe -ArgumentList "/package $DirPath\powershell7.msi /quiet /passive" -Wait

# Setup Task Scheduler to run the next script (2-modules.ps1)
$STA = New-ScheduledTaskAction -Execute "C:\Program Files\PowerShell\7\pwsh.exe" -Argument "-File $DirPath\2-modules.ps1"
$STT = New-ScheduledTaskTrigger -At 12:00 -Once
$STP = New-ScheduledTaskPrincipal -UserId "$env:computername\$env:username" -RunLevel "Highest"
$settings = New-ScheduledTaskSettingsSet
$task = New-ScheduledTask -Action $STA -Trigger $STT -Settings $settings -Principal $STP
Register-ScheduledTask Script2 -InputObject $task
Start-ScheduledTask -TaskName Script2

# Close the window
Stop-Process -Id $PID