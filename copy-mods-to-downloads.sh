#!/bin/bash

REMOTE_USER="adalie"
REMOTE_HOST="adalie-linux"
REMOTE_DIR="~/MinecraftServer/downloads/mods"

SOURCE="/mnt/c/Users/varun/AppData/Roaming/PrismLauncher/instances/All of Create 1.21.1-v1.7/minecraft/mods/"

ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}"

rsync -avzP --checksum \
  --include="*.jar" --exclude="*" \
  "${SOURCE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
