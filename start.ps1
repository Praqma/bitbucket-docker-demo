# Include required files
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ("$ScriptDirectory\helper_functions.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
}

$result = docker-compose.exe -f postgres-compose.yml -f bitbucket-compose.yml -f traefik-compose.yml up -d
exit_on_error $result