param(
    [Parameter(Mandatory=$true)]
    [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
    [string]$DataBackupPath
    ,
    [Parameter(Mandatory=$true)]
    [ValidateScript( { Test-Path $_ -PathType 'Leaf' })]
    [string]$DbBackupPath
)

# Include required files
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ("$ScriptDirectory\helper_functions.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
}

function Remove-DockerVolume {
    param (
        [string]$VolumeName
    )

    $result = docker volume ls --quiet --filter name=$VolumeName *>&1
    exit_on_error $result
    if ($null -ne $result) {
        $result = docker volume rm $VolumeName *>&1
        exit_on_error $result
    }
}

function New-DockerVolume {
    param (
        [string]$VolumeName
    )

    $result = docker volume create $VolumeName
    exit_on_error $result
}

function Reset-DockerVolume {
    param (
        [string]$VolumeName
    )
    Remove-DockerVolume $VolumeName
    New-DockerVolume $VolumeName
}

$BackupDir = "$pwd/backup"

$wasrunning = exit_if_running -remove $true

if ($null -ne $DataBackupPath) {
    Write-Host "Deleting and recreating bitbucket_data volume..."
    Reset-DockerVolume bitbucket_data
}

if ($null -ne $DbBackupPath) {
    Write-Host "Deleting and recreating bitbucket_db volume..."
    Reset-DockerVolume bitbucket_db
}

Write-Host "Starting backup container with empty bitbucket_db and bitbucket_home volumes mounted..."
$result = docker-compose -f backup-compose.yml up -d --remove-orphans *>&1
exit_on_error $result

$DataBackupFileName = Split-Path -Path $DataBackupPath -Leaf
$RestoreDataFromPath = Join-Path -Path $BackupDir -ChildPath $DataBackupFileName | Resolve-Path -Relative
Write-Host "Restore bitbucket_home data from $RestoreDataFromPath..."
$result = docker exec backup-bitbucket sh -c "cd /bitbucket_data && tar xzpf /host/backup/$DataBackupFileName ." *>&1
exit_on_error $result

$DbBackupFileName = Split-Path -Path $DbBackupPath -Leaf
$RestoreDbFromPath = Join-Path -Path $BackupDir -ChildPath $DbBackupFileName | Resolve-Path -Relative
Write-Host "Restore bitbucket_db database from $RestoreDbFromPath..."
$result = docker exec backup-bitbucket sh -c "pg_restore --username=bitbucket --dbname=bitbucket --no-owner /host/backup/$DbBackupFileName" *>&1
exit_on_error $result

Write-Host "Shutting down backup container..."
$result = docker-compose -f backup-compose.yml down *>&1
exit_on_error $result

if ($wasrunning) {
    Write-Host "Restarting Bitbucket after backup..."
    $result = docker-compose -f bitbucket-compose.yml -f postgres-compose.yml -f traefik-compose.yml up -d --remove-orphans *>&1
    exit_on_error $result
}

Write-Host "Done"