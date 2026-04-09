#Requires -Version 5.1

<#
.SYNOPSIS
    Copies mods from the local PrismLauncher instance to the remote server's downloads/mods directory.

.DESCRIPTION
    SCPs all .jar files from the "All of Create 1.21.1-v1.7" PrismLauncher instance
    to ~/MinecraftServer/downloads/mods on the remote server so they can be picked up
    by the Docker container via the /downloads volume mount.
#>

# --- Configuration ---
$remoteUser = "adalie"
$remoteHost = "adalie-linux"
$remoteDir  = "~/MinecraftServer/downloads/mods"

$source = "$env:APPDATA\PrismLauncher\instances\All of Create 1.21.1-v1.7\minecraft\mods"

if (-not (Test-Path $source)) {
    Write-Error "Source directory not found: $source"
    exit 1
}

$mods = Get-ChildItem -Path $source -Filter "*.jar"
Write-Host "Uploading $($mods.Count) mods to ${remoteUser}@${remoteHost}:${remoteDir}..." -ForegroundColor Cyan

# Ensure the remote directory exists
ssh.exe "${remoteUser}@${remoteHost}" "mkdir -p ${remoteDir}"

# SCP all jars in one call using a glob
rsync -avzP -c "$source\*.jar" "${remoteUser}@${remoteHost}:${remoteDir}"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nDone! $($mods.Count) mods uploaded to ${remoteHost}:${remoteDir}." -ForegroundColor Green
} else {
    Write-Error "SCP failed with exit code $LASTEXITCODE"
}
