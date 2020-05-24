function exit_on_error {
    param([String]$errormessage)
    if ($LASTEXITCODE -ne "0") {
        Write-Host ERROR: $errormessage
        Exit $LASTEXITCODE
    }
}

function exit_if_running {
    Write-Host "Checking if Bitbucket container is running..."
    docker ps -qf name="^bitbucket$" *>&1
    $wasrunning=$?
    if ($?) {
        Write-Host "Stopping Bitbucket during backup..."
        $result=docker-compose -f bitbucket-compose.yml -f postgres-compose.yml -f traefik-compose.yml stop *>&1
        exit_on_error $result
        Write-Host "Bitbucket will be restarted after the backup"
    } else {
        Write-Host "No running bitbucket container found"
    }
    return $wasrunning
}