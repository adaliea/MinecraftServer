#!/bin/bash
# Runs Chunky pre-generation only while nobody is online: continues every saved
# Chunky task when the server is empty and pauses them all as soon as someone joins.
# Installed as a systemd service on the host (see host/README.md).
set -u
cd "$(dirname "$0")/.." || exit 1

POLL_SECONDS=15
# Re-send the current command this often, so a server restart (Chunky does not
# resume tasks on its own) or a missed command heals without a state change.
REASSERT_SECONDS=300

rcon() { docker compose exec -T mc rcon-cli "$@" </dev/null 2>/dev/null; }

last_action=""
last_sent=0
while true; do
  out=$(rcon list)
  if [[ $out =~ There\ are\ ([0-9]+)\ of ]]; then
    players=${BASH_REMATCH[1]}
    if (( players == 0 )); then action=continue; else action=pause; fi
    now=$(date +%s)
    if [[ $action != "$last_action" ]] || (( now - last_sent >= REASSERT_SECONDS )); then
      result=$(rcon "chunky $action" | sed 's/\x1b\[[0-9;]*m//g' | tr '\n' ' ')
      [[ $action != "$last_action" ]] && echo "players=$players -> chunky $action: $result"
      last_action=$action
      last_sent=$now
    fi
  else
    # Server down or starting: forget the state so the right command is sent once it is back.
    last_action=""
  fi
  sleep "$POLL_SECONDS"
done
