#Requires -Version 5.1

<#
.SYNOPSIS
    Connects to a remote Linux server via SSH to update and restart a Docker Compose application.

.DESCRIPTION
    This script automates the deployment process for the Minecraft server. It connects to the
    specified remote host, navigates to the project directory, pulls the latest changes
    from Git, and then restarts the Docker containers in detached mode.

    Prerequisite: Passwordless SSH access must be configured from this machine to the remote server.
#>

# --- Configuration ---
$remoteUser = "adalie"
$remoteHost = "adalie-linux"
$remoteDir  = "~/MinecraftServer" # Use ~ for the home directory

# --- Script Start ---
Write-Host "🚀 Starting deployment to ${remoteUser}@${remoteHost}..." -ForegroundColor Cyan

# Define the sequence of commands to be executed on the remote server.
# The '&&' ensures that the next command only runs if the previous one succeeds.
$remoteCommand = "cd ${remoteDir} && git pull && docker compose up -d"

try {
    # Execute the command string on the remote server using ssh.exe
    # The output from the remote command will be streamed to the PowerShell console.
    ssh.exe "${remoteUser}@${remoteHost}" -t $remoteCommand

    Write-Host "`n✅ Deployment process completed successfully!" -ForegroundColor Green
}
catch {
    # This block will catch errors if ssh.exe itself fails (e.g., host not found).
    Write-Error "❌ An error occurred during the SSH connection or command execution."
    Write-Error $_.Exception.Message
}