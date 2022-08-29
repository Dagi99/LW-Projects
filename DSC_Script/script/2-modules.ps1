# Get absolute path to current directory
$DirPath = $MyInvocation.MyCommand.Path | Split-Path

# Set network to private
Set-NetConnectionProfile -InterfaceAlias "Ethernet Instance 0" -NetworkCategory "Private"

# Set the repository to a trusted state in order to bypass manual user confirmation.
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted

# Install necessary modules.
Write-Output "Installing modules..."
Install-Module PSDesiredStateConfiguration -Repository 'PSGallery' -MaximumVersion 2.99
Install-Module xComputerManagement
Install-Module NetworkingDsc
Install-Module cChoco

# Move certain Modules to a path that works for them
Move-Item "C:\Users\$env:username\Documents\Powershell\Modules\xComputerManagement" "C:\Program Files\WindowsPowerShell\Modules"
Move-Item "C:\Users\$env:username\Documents\Powershell\Modules\cChoco" "C:\Program Files\WindowsPowerShell\Modules"
Move-Item "C:\Users\$env:username\Documents\Powershell\Modules\NetworkingDsc" "C:\Program Files\WindowsPowerShell\Modules"

# Setup Task Scheduler to run the next script (3-host-ip-software.ps1)
Unregister-ScheduledTask -TaskName Script2 -Confirm:$false
$STA = New-ScheduledTaskAction -Execute "C:\Program Files\PowerShell\7\pwsh.exe" -Argument "-File $DirPath\3-host-ip-software.ps1"
$STT = New-ScheduledTaskTrigger -At 12:00 -Once
$STP = New-ScheduledTaskPrincipal -UserId "$env:computername\$env:username" -RunLevel "Highest"
$settings = New-ScheduledTaskSettingsSet
$task = New-ScheduledTask -Action $STA -Trigger $STT -Settings $settings -Principal $STP
Register-ScheduledTask Script3 -InputObject $task
Start-ScheduledTask -TaskName Script3

# Close the window
Exit