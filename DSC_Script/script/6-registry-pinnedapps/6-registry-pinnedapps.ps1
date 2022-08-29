# Get absolute path of current directory
$scriptPath = $MyInvocation.MyCommand.Path
$dirPath = $MyInvocation.MyCommand.Path | Split-Path

# read json data file
$registryTweaks = Get-Content -Raw "$dirPath\data.json" | ConvertFrom-Json

function createRegistryEntry {
    param (
        $path,
        $subkey,
        $type,
        $data
    )

    if (!$type) {
        reg.exe add $path /f
    }
    else {
        reg.exe add $path /v $subkey /t $type /d $data /f
    }
}


# set the registry tweaks
foreach ($t in $registryTweaks) {
    if ($t.Status -eq $true) {
        createRegistryEntry -path $t.Path -subkey $t.SubkeyName -type $t.Datatype -data $t.Data
    }
}


# get path to start.bin file for default pinned apps
$destination = "$env:USERPROFILE\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start.bin"

# set default pinned apps from copied start.bin file
Copy-Item -Path "$dirPath\start.bin" -Destination $destination -Force

# Cleanup the TaskScheduler
Unregister-ScheduledTask -TaskName Script6 -Confirm:$false

# Delete all the evidence
Get-ChildItem $dirPath -Exclude "6-registry-pinnedapps.ps1" | Remove-Item -Force -Recurse -Confirm:$false
Remove-Item $scriptPath -Recurse -Force -Confirm:$false

# Restart computer at last
Restart-Computer -Force