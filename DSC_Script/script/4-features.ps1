# Features have the issue, that some need a restart, which is why it is a separate script

# Timestamp to later compare it to timestamp of reboot prompt
$TimeFromScriptStarted = Get-Date

# Get absolute path to current directory
$DirPath = $MyInvocation.MyCommand.Path | Split-Path

# Get data from json file
$Config = Get-Content -Raw "$DirPath\data.json" | ConvertFrom-Json

# Optional features configuration
Configuration FeatureConfig {
    # Import required DscResource
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node localhost
    {
        foreach ($Feature in $Config.Features) {
            WindowsOptionalFeature $Feature {
                Name                 = $Feature
                NoWindowsUpdateCheck = $false
                Ensure               = 'Enable'
            }
        }
    }
} FeatureConfig -OutputPath $DirPath\FeatureConfig

# Just in case...
Set-WSManQuickConfig -Force

# Run the MOF file
Write-Output "Configuring Windows Optional Features..."
Start-DscConfiguration -Path "$DirPath\FeatureConfig" -Force -Verbose -Wait

# Little pause to make sure the event is really available to read in the Event Viewer
Start-Sleep -s 5

# Restart computer if needed
$timeCreated = (get-WinEvent @{LogName = 'Microsoft-Windows-Dsc/operational'; id = 4253 } -maxevents 1).TimeCreated

if ($timeCreated -ge $TimeFromScriptStarted) {
    Restart-Computer
}
else {
    # Setup Task Scheduler to run the next script after logon (5-cleanup.ps1)
    Unregister-ScheduledTask -TaskName Script4 -Confirm:$false
    $STA = New-ScheduledTaskAction -Execute "C:\Program Files\PowerShell\7\pwsh.exe" -Argument "-File $DirPath\5-cleanup.ps1"
    $STT = New-ScheduledTaskTrigger -At 12:00 -Once
    $STP = New-ScheduledTaskPrincipal -UserId "$env:computername\$env:username" -RunLevel "Highest"
    $settings = New-ScheduledTaskSettingsSet
    $task = New-ScheduledTask -Action $STA -Trigger $STT -Settings $settings -Principal $STP
    Register-ScheduledTask Script5 -InputObject $task
    Start-ScheduledTask -TaskName Script5

    # New scheduled task to execute the registry script for the new user
    $STA = New-ScheduledTaskAction -Execute "C:\Program Files\PowerShell\7\pwsh.exe" -Argument "-File C:\Users\$username\Desktop\registry\6-registry-pinnedapps.ps1"
    $STT = New-ScheduledTaskTrigger -AtLogOn -User $hostname\$username
    $STP = New-ScheduledTaskPrincipal -UserId "$hostname\$username" -RunLevel "Highest"
    $settings = New-ScheduledTaskSettingsSet
    $task = New-ScheduledTask -Action $STA -Trigger $STT -Settings $settings -Principal $STP
    Register-ScheduledTask Script6 -InputObject $task
}