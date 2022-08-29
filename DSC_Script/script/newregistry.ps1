
# get local path to script and script directory
$dirPath = $MyInvocation.MyCommand.Path | Split-Path

# read json data file
$config = Get-Content -Raw "$dirPath\data.json" | ConvertFrom-Json


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


<# function isCurrentUserPath {
    param (
        $path
    )

    return $path -like "HKEY_CURRENT_USER*"
} #>


# set the registry tweaks
foreach ($t in $config.RegistryTweaks) {
    if ($t.Status -eq $true) {
        createRegistryEntry -path $t.Path -subkey $t.SubkeyName -type $t.Datatype -data $t.Data
    }
}


# get path to start.bin file for default pinned apps
$destination = "$env:USERPROFILE\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start.bin"


# set default pinned apps from copied start.bin file
Copy-Item -Path "$dirPath\start.bin" -Destination $destination -Force

<# 
Restart-Computer -Force #>