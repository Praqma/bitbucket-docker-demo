# Include required files
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ("$ScriptDirectory\helper_functions.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
}

param (
    [bool]$remove=$false
)

exit_if_running $remove