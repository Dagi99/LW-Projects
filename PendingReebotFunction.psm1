function Get-PendingReboot {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        $reboot = 0
        $pendingRebootTests = @(
            @{
                Name     = 'RebootPending'
                Test     = { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing'  -Name 'RebootPending' -ErrorAction Ignore }
                TestType = 'ValueExists'
            }
            @{
                Name     = 'RebootRequired'
                Test     = { Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update'  -Name 'RebootRequired' -ErrorAction Ignore }
                TestType = 'ValueExists'
            }
            @{
                Name     = 'PendingFileRenameOperations'
                Test     = { Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction Ignore }
                TestType = 'NonNullValue'
            }
        )
    }
    
    process {
        foreach ($test in $pendingRebootTests) {
            $result = Invoke-Command  -ScriptBlock $test.Test
            if ($test.TestType -eq 'ValueExists' -and $result) {
                $reboot += 1
            }
            elseif ($test.TestType -eq 'NonNullValue' -and $result -and $result.($test.Name)) {
                $reboot += 1
            }
            else {
                
            }
        }
    }
    
    end {
        return $reboot
    }
}

<#
    .SYNOPSIS
        Creates a Scheduled Task
    .Description
        This Funktion Creates a Scheduled Task running under System
        Updates this Task to run with the defined psUser and on the defined interval

    .PARAMETER
        $desctiption: What is the Purpose of this Task
        $taskname: The Name of the Task
        $interval: How often should it run. Defined with "PT4H"
        $psArguments: Arguments for the Task i.e. Silently
        $psUser: What user should the task be run under.
#>
function new-ScriptTask {
    [CmdletBinding()]
    param (
        [string]$description,
        [string]$taskName,
        $psArguments
    )
    
    begin {
        $psPath = $PSHOME + "\pwsh.exe"
        
    }
    
    process {
        $action = New-ScheduledTaskAction -Execute "$psPath" -Argument $psArguments
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:username
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -RunOnlyIfIdle -IdleDuration 00:01:00 -IdleWaitTimeout 02:30:00 -Compatibility Win8 -DontStopOnIdleEnd
        $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Description $description
        $msg = "Enter the username and password that will run the task"; 
        $credential = $Host.UI.PromptForCredential("Task username and password", $msg, "$env:username", $env:userdomain)
        $username = $credential.UserName
        $password = $credential.GetNetworkCredential().Password
       
   <#      $username = "gid"
        $password = "12345" #>
        Register-ScheduledTask -TaskName $taskName -Action $action -Settings $settings -Trigger $trigger -User $username -RunLevel Highest -Password $password

        <# #Get Credentials for psUser
        $password = Get-SecretKeePass -SecretName $PSUser -ReturnType "PlainTextPassword" -KeepassDB $keepassDB -KeepassKey $keepassKey
        $password = $password.ToString()
        #Update task with duration and interval
        $taskUpdate = Get-ScheduledTask -TaskName $taskName
        $taskUpdate.Triggers.Repetition.Duration = "P1D"
        $taskUpdate.Triggers.Repetition.interval = $interval
        $taskUpdate | Set-ScheduledTask -User $psUser -Password $password #>
    }
    
    end {
        
    }
}

function Update-Computer {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        try {
           
            if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                Write-Debug "Module is installed"
                Import-Module PSWindowsUpdate
            }
            else {
                Write-Debug "Module is not installed"
                Install-Module PSWindowsUpdate -Force
                Import-Module PSWindowsUpdate
            }
        }
        catch {
            $errorMessage = "Module PSWindowsUpdate  could not be installed or Import Failed"
            write-EventLog -ScriptName "WindowsUpdate" -Message $errorMessage
            exit
        }
        $Updates = Get-WUList
        $psArguments = "-NonInteractive -NoLogo -NoProfile -File " + '"' + $MyInvocation.MyCommand.path + '"'
    }
    
    process {
        while ($Updates.count -gt 0) {
            Get-WindowsUpdate -Download -Verbose -AcceptAll
            Get-WindowsUpdate -Install -Verbose -AcceptAll
            $Updates = Get-WUList
            new-ScriptTask -description "Does Updates" -taskName "Windows Updates" -psArguments $psArguments
            #Restart-Computer
        }
        
        
    }
    
    end {
        Write-Host "No Updates"
    }
}
<#
    .SYNOPSIS
        Creates a EventLog entry
    .Description
        This funktion is used for Logging purposes and creates a EventLog Warning under System

    .PARAMETER
        $scriptName: What Skript caused the error.
        $messege: What caused the error.
#>
function write-EventLog {
    [CmdletBinding()]
    param (
        [string]$scriptName,
        [string]$message
    )
        
    process {
        eventcreate /l System /t Warning /so $scriptName /id 1 /d $message
    }

}

<#
    .SYNOPSIS
        Writes ErrorMessages to Influx
    .Description
        This Funktion is used for Loggings purposes. It writes a message to the Influx database.

    .PARAMETER
        $influxURL: The InfluxURL,    
        $organisation: Name of the Influx organisation,  
        $scriptName: Name of the Script that caused the error,
        $errorMessage: The Message that gets send to Influx,
        $errorToken: Token used to access Influx,
        $keepassDB: Path to the KeePass Database,
        $keepassKey: Path to the KeePass KeyFile
#>
function write-ErrorInflux {
    [CmdletBinding()]
    [CmdletBinding()]
    param (
        $influxURL,    
        $organisation,  
        $scriptName,
        $errorMessage,
        $errorToken,
        $keepassDB,
        $keepassKey
    )
    $errorInfluxdb = $influxURL
    $errorBucket = "Error"
    $errorMeasure = "Errors"
    $timestamp = Get-Date -Format o
    $tokenError = Get-SecretKeePass -SecretName $errorToken -ReturnType "ErrorToken" -KeepassDB $keepassDB -KeepassKey $keepassKey
    Write-Influx -Measure $errorMeasure -Tags @{Script = "$scriptName" } -Metrics @{ErrorMessage = $errorMessage } -TimeStamp $timestamp -Organisation $organisation -Bucket $errorBucket -Token $tokenError -Server $errorInfluxdb  -Verbose

}

function Update-Computer {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        try {
           
            if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                Write-Debug "Module is installed"
                Import-Module PSWindowsUpdate
            }
            else {
                Write-Debug "Module is not installed"
                Install-Module PSWindowsUpdate -Force
                Import-Module PSWindowsUpdate
            }
        }
        catch {
            $errorMessage = "Module PSWindowsUpdate  could not be installed or Import Failed"
            write-EventLog -ScriptName "WindowsUpdate" -Message $errorMessage
            exit
        }
        $Updates = Get-WUList
        $psArguments = "-NonInteractive -NoLogo -NoProfile -File " + '"' + $MyInvocation.MyCommand.path + '"'
    }
    
    process {
        while ($Updates.count -gt 0) {
            Get-WindowsUpdate -Download -Verbose -AcceptAll
            Get-WindowsUpdate -Install -Verbose -AcceptAll
            $Updates = Get-WUList
            new-ScriptTask -description "Does Updates" -taskName "Windows Updates" -psArguments $psArguments
            #Restart-Computer
        }
        
        
    }
    
    end {
        Write-Host "No Updates"
    }
}
<#
    .SYNOPSIS
        Gets Passwords from KeePass
    .Description
        Gets password or token from KeePass and returns it in a Chosen Typ:
        PSCredential objekt,
        userame and password in plaintext,
        just the password in plaintext

    .PARAMETER
        $secretName: Name of the KeePass Secret
        $returnType: In what typ it should be returned
        $keepassDB: Path to the KeePass Database
        $keepassKey: Path to the KeePass KeyFile
#>
function get-SecretKeePass {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$secretName,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$returnType,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$keepassDB,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$keepassKey
    )
    #Check if Modules are installed
    begin {
        try {
           
            if (Get-Module -ListAvailable -Name SecretManagement.KeePass) {
                Write-Debug "Module is installed"
                Import-Module SecretManagement.KeePass
            }
            else {
                Write-Debug "Module is not installed"
                Install-Module SecretManagement.KeePass -Force
                Import-Module SecretManagement.KeePass
            }
        }
        catch {
            $errorMessage = "Module SecretManagement.KeePass  could not be installed or Import Failed"
            write-EventLog -ScriptName "GetKeepassSecret" -Message $errorMessage
            exit
        }

        try {
            if (Get-Module -ListAvailable -Name  Microsoft.PowerShell.SecretManagement) {
                Write-Debug "Module is installed"
                Import-Module  Microsoft.PowerShell.SecretManagement
            }
            else {
                Write-Debug "Module is not installed"
                Install-Module  Microsoft.PowerShell.SecretManagement -Force
                Import-Module  Microsoft.PowerShell.SecretManagement
            }
        }
        catch {
            $errorMessage = "Module  Microsoft.PowerShell.SecretManagement  could not be installed or Import Failed"
            write-EventLog -ScriptName "GetKeepassSecret" -Message $errorMessage
            exit
        }

        try {
            if (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretStore) {
                Write-Debug "Module is installed"
                Import-Module Microsoft.PowerShell.SecretStore
            }
            else {
                Write-Debug "Module is not installed"
                Install-Module Microsoft.PowerShell.SecretStore -Force
                Import-Module Microsoft.PowerShell.SecretStore
            }
        }
        catch {
            $errorMessage = "Module Microsoft.PowerShell.SecretStore  could not be installed or Import Failed"
            write-EventLog -ScriptName "GetKeepassSecret" -Message $errorMessage
            exit
        }

        $secretName = ($env:COMPUTERNAME + "_" + $secretName).ToLower()
        $secretVault = "secretVault" 
    }
    
    process {
        $vault = Get-SecretVault -Name $secretVault -ErrorAction SilentlyContinue

        if ($null -eq $vault) {
            Register-SecretVault -Name "$secretVault" -ModuleName 'SecretManagement.Keepass' -VaultParameters @{
                Path              = "$keepassDB"
                UseMasterPassword = $false
                KeyPath           = "$keepassKey"
            }
        }
        else {
            Write-Debug "Vault exists"
            Test-SecretVault -Name $secretVault
        }
    }
    
    end {
        if ($secretName -like "*token*") {
            $secretToken = Get-Secret -Name $secretName -Vault "$secretVault" -AsPlainText
            $secretToken = $secretToken.password
            $secretToken = ConvertFrom-SecureString $secretToken -AsPlainText
            Unregister-SecretVault -Name "$secretVault"
            return $secretToken
            ; break
        }
        else {
            switch ($returnType) {
                SecureString {
                    $secretString = Get-Secret -Name $secretName -Vault "$secretVault"
                    $secretUserName = $secretString.UserName
                    $secretPassword = $secretString.password
                    [pscredential]$secretCredential = New-Object System.Management.Automation.PSCredential ($secretUserName, $secretPassword)
                    Unregister-SecretVault -Name "$secretVault"
                    return $secretCredential
                    ; break
                }
                PlainText {
                    $secretString = Get-Secret -Name $secretName -Vault "$secretVault" -AsPlainText
                    $secretUserName = $secretString.UserName
                    $secretPassword = $secretString.password
                    $secretPassword = ConvertFrom-SecureString $secretPassword -AsPlainText
                    Unregister-SecretVault -Name "$secretVault"
                    return $secretUserName, $secretPassword
                    ; break 
                }
                PlainTextPassword {
                    $secretString = Get-Secret -Name $secretName -Vault "$secretVault" -AsPlainText
                    $secretPassword = $secretString.password
                    $secretPassword = ConvertFrom-SecureString $secretPassword -AsPlainText
                    Unregister-SecretVault -Name "$secretVault"
                    return $secretPassword
                    ; break 
                }
                Default {
                    Unregister-SecretVault -Name "$secretVault"
                    ; break
                }
            }
        }
    }
}

<#
    .SYNOPSIS
        Creates the Backup Path
    .Description
        Checks what typ of Day it is i.e Daily, Weekly, Monthly
        Creates the Path acroding to the above results.

    .PARAMETER
        $date: Todays date in DateTime format
        $backupShare: Path to the Backp Share
        $time: Current Time in "yyMMddHHmm" format
#>
function get-TypeOfDay {
    [CmdletBinding()]
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][DateTime]$date,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$backupShare,
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$time
    )
    
    begin {
        $time = $time
        $backupShare = $backupShare
        $today = $date
        $dayOfWeek = $today.DayOfWeek.value__
        $lastDay = [DateTime]::DaysInMonth($today.Year, $today.Month)
        $lastDate = [DateTime]::new($today.Year, $today.Month, $lastDay)
        $today = $today.ToString("yyyyMMdd")
        $lastDate = $lastDate.ToString("yyyyMMdd")
    }
    
    process {
        if ($today -eq $lastDate) {
            $backupPath = $BackupShare + "Monthly\"
            Write-Debug  "Last Day of Month"
            return $backupPath
        }
        elseif ($dayOfWeek -eq 0) {
            Write-Debug "Sunday"
            $backupPath = $BackupShare + "Weekly\"
            return $backupPath
                
            
        }
        else {
            Write-Debug "Just a regular day"
            $backupPath = $backupShare + "Daily\"
            Write-Debug  $backupPath
            return $backupPath
        }
    
    }
    
    end {
        
    }
}

<#
    .SYNOPSIS
        Creates the folder structure for the Backups
    .Description
        Check if the required Folders exist.
        Creates the folder that dont exist.

    .PARAMETER
        $backupShare: Path to the Backuplocation.
#>
function initialize-BackupStructure {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$backupShare
    )
    
    begin {
        $backupLocation = $backupShare | Split-Path
        $backupRoot = "\InfluxBackup"
        $backUPDaily = "\Daily\"
        $backUPWeekly = "\Weekly\"
        $backUPMonthly = "\Monthly\"
    }
    
    process {
        #Check if the root folder for the Buckups exist
        if (Test-Path -Path $backupShare) {
            Write-Debug "Share Folder Exists"
        }
        else {
            try {
                New-Item -Path $backupLocation -name $backupRoot -ItemType Directory
            }
            catch {
                $errorMessage = "Creating Folder Failed"
                write-ErrorInflux -influxURL $influxURL -organisation $organisation -scriptName $scriptName -errorMessage $errorMessage -errorToken $errorToken -keepassDB $keepassDB -keepassKey $keepassKey
                Throw $_
            }
        }

    
        #Check if the Daily Backupfolder exists
        if (Test-Path -Path $backupShare$backUPDaily) {
            Write-Debug "Todays Folder Exists"
        }

        else {
            try {
                New-Item -Path $backupShare  -name "Daily" -ItemType Directory
            }
            catch {
                $errorMessage = "Creating Folder Failed"
                write-ErrorInflux -influxURL $influxURL -organisation $organisation -scriptName $scriptName -errorMessage $errorMessage -errorToken $errorToken -keepassDB $keepassDB -keepassKey $keepassKey
                Throw $_
            }
        }
    
        #Check if the Weekly Backupfolder exists
        #$WeeklyFolderExists = Get-ChildItem -Path $BackupShare | Where-Object { $_.BaseName -eq $BackUPWeekly }
        if (Test-Path -Path $backupShare$backUPWeekly) {
            Write-Debug "Weekly Folder Exists"
        }

        else {
            try {
                New-Item -Path $backupShare  -name "Weekly" -ItemType Directory
            }
            catch {
                $errorMessage = "Creating Folder Failed"
                write-ErrorInflux -influxURL $influxURL -organisation $organisation -scriptName $scriptName -errorMessage $errorMessage -errorToken $errorToken -keepassDB $keepassDB -keepassKey $keepassKey
                Throw $_
            }
        }
    
        #Check if the Monthly Backupfolder exists
        #$MonthlyFolderExists = Get-ChildItem -Path $BackupShare | Where-Object { $_.BaseName -eq $BackUPMonthly }
        if (Test-Path -Path $backupShare$backUPMonthly) {
            Write-Debug "Monthly Folder Exists"
        }

        else {
            try {
                New-Item -Path $backupShare  -name "Monthly" -ItemType Directory
            }
            catch {
                $errorMessage = "Creating Folder Failed"
                write-ErrorInflux -influxURL $influxURL -organisation $organisation -scriptName $scriptName -errorMessage $errorMessage -errorToken $errorToken -keepassDB $keepassDB -keepassKey $keepassKey
                Throw $_
            }
        }
    }
    
    end {
        Write-Debug "Done"
    }
}