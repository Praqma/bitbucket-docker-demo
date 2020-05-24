# Include required files
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ("$ScriptDirectory\helper_functions.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
}

function delete_volume {
    param($volumename)

    $result = docker volume ls --quiet --filter name=$volumename *>&1
    exit_on_error $result
    if ($null -ne $result) {
        $result = docker volume rm $volumename *>&1
        exit_on_error $result
    }
}

function create_volume {
    param($volumename)

    $result = docker volume create $volumename
    exit_on_error $result
}

$backupdir="$pwd/backup"
$today = $(get-date -Format filedate)

# TODO: check if backup files exist
# TODO: Check if backup files are relatively new (<5 minutes) 

$wasrunning = exit_if_running -remove $true

Write-Host "Deleting bitbucket_data and bitbucket_db volumes containing the old data..."
delete_volume bitbucket_data
delete_volume bitbucket_db

Write-Host "Creating empty bitbucket_data and bitbucket_db volumes..."
create_volume bitbucket_data
create_volume bitbucket_db

Write-Host "Starting backup container with empty bitbucket_db and bitbucket_home volumes mounted..."
$result = docker-compose -f backup-compose.yml up -d --remove-orphans *>&1
exit_on_error $result

$bitbucket_data_filename = "$today-bitbucket-data.tar.gz"
$bitbucket_data_path = Join-Path $backupdir -ChildPath $bitbucket_data_filename
Write-Host "Restore bitbucket_home data from $bitbucket_data_path..."
$result = docker exec backup-bitbucket sh -c "cd /bitbucket_data && tar xzpf /host/backup/$bitbucket_data_filename ." *>&1
exit_on_error $result

$bitbucket_db_filename = "$today-bitbucket-db.bin"
$bitbucket_db_path = Join-Path $backupdir -ChildPath $bitbucket_db_filename
Write-Host "Restore bitbucket_db database from $bitbucket_db_path..."
$result = docker exec backup-bitbucket sh -c "pg_restore --username=bitbucket --dbname=bitbucket --no-owner /host/backup/$bitbucket_db_filename" *>&1
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