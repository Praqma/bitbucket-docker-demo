function CheckLastExitCode {
    param ([int[]]$SuccessCodes = @(0), [scriptblock]$CleanupScript=$null)

    if ($SuccessCodes -notcontains $LastExitCode) {
        if ($CleanupScript) {
            "Executing cleanup script: $CleanupScript"
            &$CleanupScript
        }
        $msg = @"
EXE RETURNED EXIT CODE $LastExitCode
CALLSTACK:$(Get-PSCallStack | Out-String)
"@
        throw $msg
    }
}

docker ps -qf name=^bitbucket$ *> $null
$was_running = $?
if ($was_running) {
    Write-Host "Stopping Bitbucket during backup..."
    docker-compose -f bitbucket-compose.yml -f postgres-compose.yml stop *> $null
    CheckLastExitCode
}

Write-Host "Starting backup container with db and bitbucket_home volumes mounted..."
docker-compose -f backup-compose.yml up -d *> $null

$today = $(get-date -Format filedate)
$backup_dir = "$pwd/backup/$today"
if (-Not (Test-Path $backup_dir)) {
    New-Item -ItemType Directory $backup_dir -ErrorVariable errormessage -Force
}
if (-Not ($?)) {
     Write-Host ERROR: $errormessage
    exit
}

Write-Host "Backing up bitbucket_home as a tarball..."
docker exec backup-bitbucket sh -c "cd /bitbucket_data && mkdir -p /host/backup/ && tar czf /host/backup/$today-bitbucket-data.tar.gz ."
CheckLastExitCode

Write-Host "Backing up database with pg_dump..."
# See https://www.commandprompt.com/blog/a_better_backup_with_postgresql_using_pg_dump/ for recommendations on backup format
docker exec backup-bitbucket sh -c "pg_dump --username bitbucket --format=c --dbname=bitbucket --file=/host/backup/$today-bitbucket-db.bin"
CheckLastExitCode

Write-Host "Shutting down backup container..."
docker-compose -f backup-compose.yml down *> $null
CheckLastExitCode

if ($was_running) {
    Write-Host "Restarting Bitbucket after backup..."
    docker-compose -f bitbucket-compose.yml -f postgres-compose.yml up -d *> $null
    CheckLastExitCode
}

Write-Host "Done..."