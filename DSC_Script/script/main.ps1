#Region | Set-up | install modules & set important variables

# Get absolute path to current directory
$DirPath = $MyInvocation.MyCommand.Path | Split-Path

# Get data from json file
$Config = Get-Content -Raw "$DirPath\data.json" | ConvertFrom-Json

#Endregion


#Region | Main | Desired State Configuration

# Hostname configuration
Configuration HostnameConfig {
    Import-DscResource -Module xComputerManagement
    $hostname = Read-Host -Prompt "Name your PC"
    Node "localhost" {
        xComputer NewHostName {
            Name = $hostname
        }
    }
} HostnameConfig -OutputPath $DirPath\HostnameConfig

# IP, DNS and default gateway configuration
Configuration IPConfig {
    # Variables
    $NetInterface = 'Ethernet Instance 0'
    $IpVersion = 'IPv4'

    # Import required DscResource
    Import-DscResource -Module NetworkingDsc

    Node localhost
    {
        IPAddress SetIpAddress {
            IPAddress      = $Config.IpConfig.IpAddress
            InterfaceAlias = $NetInterface
            AddressFamily  = $IpVersion
        }
        DnsServerAddress SetDnsServer {
            Address        = $Config.IpConfig.DNSServer
            InterfaceAlias = $NetInterface
            AddressFamily  = $IpVersion
        }
        DefaultGatewayAddress SetDefaultGateway {
            Address        = $Config.IpConfig.DefaultGateway
            InterfaceAlias = $NetInterface
            AddressFamily  = $IpVersion
        }
    }
} IPConfig -OutputPath $DirPath\IPConfig

# Software configuration
Configuration SoftwareConfig {
    # Import required module
    Import-DscResource -Module cChoco
    Node localhost
    {
        LocalConfigurationManager {
            DebugMode = 'ForceModuleImport'
        }
        cChocoInstaller installChoco {
            InstallDir = "c:\choco"
        }
        foreach ($Software in $Config.Software) {
            cChocoPackageInstaller $Software.Name {
                Name      = $Software.Name
                Ensure    = 'Present'
                DependsOn = '[cChocoInstaller]installChoco'
            }
        }
    }
} SoftwareConfig -OutputPath $DirPath\SoftwareConfig

# Registry configuration
<# Configuration RegistryConfig {

    # Import requires DscResources
    Import-DscResource -Module PSDesiredStateConfiguration

    do {
        # Get the user's desired taskbar position and change the binary settings value accordingly.
        try {
            [string]$pos = Read-Host -Prompt "Choose taskbar position:`nTop (1)`nBottom (2)`n"
            $top = $pos -eq "1" ? $true : $false
        }
        catch {
            Write-Host "Enter either 1 or 2."
        }

    } while (($pos -ne "1") -and ($pos -ne "2"))


    # Top taskbar position
    $taskbarVal = "30000000feffffff7af40000010000003000000030000000000000000000000036070000300000006000000001000000"

    Node localhost {
        # Set registry tweaks
        foreach ($Tweak in $Config.RegistryTweaks) {

            # Classic context menu registry tweak seems to only work with the reg.exe add command.
            if ($Tweak.Status -eq "true") {
                if ($Tweak.Name -eq "ClassicContextMenu") {
                    reg.exe add $Tweak.Path /f /ve
                }
                else {
                    Registry $Tweak.Name {
                        Key       = $Tweak.Path
                        Ensure    = "Present"
                        ValueName = $Tweak.Subkeyname
                        ValueData = ($Tweak.Name -eq "TaskbarPosition") -and ($top -eq $true) ? $taskbarVal : $Tweak.Data
                        ValueType = $Tweak.Datatype
                        Force     = $true
                    }
                }
            }
        }
    }
} RegistryConfig -OutputPath $DirPath\RegistryConfig #>


# Activate WinRM
Set-WsManQuickConfig -Force

# Run the MOF files
Start-DscConfiguration -Path "$DirPath\IPConfig" -Force -Verbose -Wait
Start-Sleep -s 8 #Wait for the Internet Connection
Start-DscConfiguration -Path "$DirPath\SoftwareConfig" -Force -Verbose -Wait
Start-DscConfiguration -Path "$DirPath\HostnameConfig" -Force -Verbose -Wait

# Use reg load to ensure registry tweaks are set as default for new user creations (Also works for local registry paths HKCU).
<# reg load HKLM\DEFAULT c:\users\default\ntuser.dat
Start-DscConfiguration -Path "$DirPath\RegistryConfig" -Verbose -Force -Wait
reg unload HKLM\DEFAULT #>

#Endregion


#Region | Finish | Create new user, delete the script files & delete the user used for running this script

# Create the actual new user account
Write-Host "Creating your user account. Enter your new credentials."
$username = Read-Host -Prompt "Username"
$password = Read-Host -Prompt "Password" -AsSecureString
Start-Sleep -s 8
New-LocalUser -Name $username -Password $password -PasswordNeverExpires
Add-LocalGroupMember -Group "Administrators" -Member $username

# Setup Task Scheduler to run the next script after logon (features.ps1)
Unregister-ScheduledTask -TaskName ScriptMain -Confirm:$false
$STA = New-ScheduledTaskAction -Execute "C:\Program Files\PowerShell\7\pwsh.exe" -Argument "-File $DirPath\features.ps1"
$STT = New-ScheduledTaskTrigger -AtLogOn
$STP = New-ScheduledTaskPrincipal -UserId "$env:computername\$env:username" -RunLevel "Highest"
$settings = New-ScheduledTaskSettingsSet
$task = New-ScheduledTask -Action $STA -Trigger $STT -Settings $settings -Principal $STP
Register-ScheduledTask ScriptFeatures -InputObject $task

# Check if Choco is still installing. If not, restart
do {
    $running = Get-Process choco.exe -ErrorAction SilentlyContinue
    if (!$running) {
        Restart-Computer -Confirm:$false -Force
    }
    Start-Sleep -s 5

} while (1 -eq 1)

#Endregion