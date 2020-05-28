# Include required files
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ("$ScriptDirectory\helper_functions.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
}

$result = docker volume create bitbucket_db
exit_on_error $result

$result = docker volume create bitbucket_data
exit_on_error $result

$result = docker run --rm -u root -v bitbucket_data:/var/atlassian/application-data/stash atlassian/stash:3.6 chown -R daemon /var/atlassian/application-data/stash
exit_on_error $result
