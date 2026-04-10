#!/bin/bash

REMOTE_USER="adalie"
REMOTE_HOST="adalie-linux"
REMOTE_DIR="~/MinecraftServer"

# Get commit message from arg or prompt
if [ -n "$1" ]; then
  message="$1"
else
  read -rp "Commit message: " message
fi

if [ -z "$message" ]; then
  echo "No commit message provided. Aborting."
  exit 1
fi

# Push local changes
echo "Pushing local changes..."
git add -A && git commit -m "$message" && git push
if [ $? -ne 0 ]; then
  echo "Failed to push local changes. Aborting."
  exit 1
fi

LOCAL_HASH=$(git rev-parse HEAD)

# Pull on remote, verify it matches, then restart
echo "Deploying to ${REMOTE_USER}@${REMOTE_HOST}..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" -t "
  cd ${REMOTE_DIR} && \
  git pull && \
  REMOTE_HASH=\$(git rev-parse HEAD) && \
  if [ \"\$REMOTE_HASH\" != \"${LOCAL_HASH}\" ]; then
    echo 'Remote is not up to date with local. Aborting restart.'
    exit 1
  fi && \
  echo 'Remote is up to date. Restarting server...' && \
  docker compose up -d
"

if [ $? -eq 0 ]; then
  echo "Deployment completed successfully!"
else
  echo "Deployment failed."
  exit 1
fi
