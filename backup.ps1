function exit_on_error {
    param($errormessage)
    if ($LASTEXITCODE -ne "0") {
        Write-Host ERROR: $errormessage
        Exit $LASTEXITCODE
    }
}

$result=docker ps -qf name=^bitbucket$ *>&1
$was_running = $?
if ($was_running) {
    Write-Host "Stopping Bitbucket during backup..."
    $result=docker-compose -f bitbucket-compose.yml -f postgres-compose.yml -f traefik-compose.yml stop *>1
    exit_on_error $result
}

Write-Host "Starting backup container with db and bitbucket_home volumes mounted..."
$result = docker-compose -f backup-compose.yml up -d --remove-orphans *>&1
exit_on_error $result

$today = $(get-date -Format filedate)
$backup_dir = "$pwd/backup"
if (-Not (Test-Path $backup_dir)) {
    New-Item -ItemType Directory $backup_dir -ErrorVariable result -Force *>&1
    exit_on_error $result
}

Write-Host "Backing up bitbucket_home as a tarball..."
$result = docker exec backup-bitbucket sh -c "cd /bitbucket_data && tar czf /host/backup/$today-bitbucket-data.tar.gz ." *>$1
exit_on_error $result

Write-Host "Backing up database with pg_dump..."
# See https://www.commandprompt.com/blog/a_better_backup_with_postgresql_using_pg_dump/ for recommendations on backup format
$result = docker exec backup-bitbucket sh -c "pg_dump --username bitbucket --format=c --dbname=bitbucket --file=/host/backup/$today-bitbucket-db.bin" *>$1
exit_on_error $result

Write-Host "Shutting down backup container..."
$result = docker-compose -f backup-compose.yml down *>&1
exit_on_error $result

if ($was_running) {
    Write-Host "Restarting Bitbucket after backup..."
    $result = docker-compose -f bitbucket-compose.yml -f postgres-compose.yml -f traefik-compose.yml up -d --remove-orphans *>&1
    exit_on_error $result
}

Write-Host "Done..."