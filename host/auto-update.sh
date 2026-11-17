#!/bin/bash
# Daily container updates and health checks for the Minecraft host. Runs from
# mc-auto-update.timer at 06:30 America/New_York, after unattended-upgrades (06:00).
#
# - Pulls new images for mc, backups and cloudflared. Minecraft, Fabric and mods are
#   pinned in docker-compose.yml, so a new mc image only brings Java and itzg's scripts.
# - mc is only recreated while nobody is online. If it isn't healthy within 10 minutes
#   it is rolled back to the previous image, and that image ID is held so it isn't
#   retried. Delete /var/lib/mc-auto-update/held-* to allow it again.
# - Reboots for OS updates (unattended-upgrades no longer reboots on its own), again
#   only while nobody is online.
# - Emails the admin (via play.dacubeking.com/api/alert) on updates, rollbacks and failures.
set -uo pipefail

REPO=/home/ubuntu/MinecraftServer
STATE=/var/lib/mc-auto-update
HEALTH_TIMEOUT=600
SERVICES=(cloudflared backups mc)

cd "$REPO" || exit 1
mkdir -p "$STATE"
# shellcheck disable=SC1091
[ -r /etc/mc-alert.env ] && . /etc/mc-alert.env

report=()      # lines for the summary email
problems=0

log() { echo "$*"; report+=("$*"); }

email() { # subject, body
  [ -n "${ALERT_URL:-}" ] || { echo "no alert config, would have emailed: $1"; return; }
  local payload
  payload=$(jq -n --arg s "$1" --arg t "$2" '{subject: $s, text: $t}')
  curl -sS -m 30 -X POST "$ALERT_URL" -H "authorization: Bearer $ALERT_TOKEN" \
    -H "content-type: application/json" -d "$payload" || echo "alert email failed"
  echo
}

compose() { docker compose "$@" </dev/null; }

image_of() { compose config --format json | jq -r ".services[\"$1\"].image"; }
container_image_id() { docker inspect -f '{{.Image}}' "$(compose ps -q "$1")" 2>/dev/null; }
tag_image_id() { docker image inspect -f '{{.Id}}' "$1" 2>/dev/null; }

players_online() { # prints the count, or nothing if the server can't be asked
  compose exec -T mc rcon-cli list 2>/dev/null | sed -n 's/^There are \([0-9]*\) of.*/\1/p'
}

mc_health() { docker inspect -f '{{.State.Health.Status}}' "$(compose ps -q mc)" 2>/dev/null; }

wait_ready() { # service: healthy for mc, running for the others
  local svc=$1 deadline=$((SECONDS + HEALTH_TIMEOUT))
  while ((SECONDS < deadline)); do
    if [ "$svc" = mc ]; then
      [ "$(mc_health)" = healthy ] && return 0
    else
      sleep 30   # give it a chance to crash first
      [ "$(docker inspect -f '{{.State.Running}}' "$(compose ps -q "$svc")" 2>/dev/null)" = true ] && return 0
      return 1
    fi
    sleep 10
  done
  return 1
}

java_version() {
  compose exec -T mc java -version 2>&1 | sed -n '1s/.*"\(.*\)".*/\1/p'
}

update_service() {
  local svc=$1 image old new
  image=$(image_of "$svc")
  old=$(container_image_id "$svc")
  new=$(tag_image_id "$image")
  [ -n "$old" ] && [ -n "$new" ] || { log "$svc: couldn't read image IDs, skipped"; problems=1; return; }
  [ "$old" = "$new" ] && return 0

  if [ -f "$STATE/held-$svc" ] && [ "$(cat "$STATE/held-$svc")" = "$new" ]; then
    echo "$svc: $new is held after a failed update, skipping"
    return 0
  fi

  if [ "$svc" = mc ]; then
    local n; n=$(players_online)
    if [ "$n" != 0 ]; then
      echo "mc: update available but players online (${n:-unknown}), trying again tomorrow"
      return 0
    fi
  fi

  local before=""; [ "$svc" = mc ] && before=$(java_version)
  echo "$svc: updating $old -> $new"
  compose up -d --no-deps --pull never "$svc"
  if wait_ready "$svc"; then
    local extra=""
    [ "$svc" = mc ] && extra=" (Java ${before:-?} -> $(java_version))"
    log "$svc: updated to $image ${new:7:12}$extra"
    rm -f "$STATE/held-$svc"
    return 0
  fi

  log "$svc: new image ${new:7:12} did not come up within $((HEALTH_TIMEOUT / 60)) min, rolling back to ${old:7:12}"
  problems=1
  echo "$new" > "$STATE/held-$svc"
  docker tag "$old" "$image"
  compose up -d --no-deps --pull never "$svc"
  if wait_ready "$svc"; then
    log "$svc: rollback succeeded; the new image is held until $STATE/held-$svc is removed"
  else
    log "$svc: ROLLBACK ALSO FAILED, needs a look now (docker compose logs $svc)"
  fi
  local lines; mapfile -t lines < <(compose logs --tail 40 "$svc" 2>&1 | sed "s/^/    /")
  report+=("    last log lines:" "${lines[@]}")
}

# --- OS updates (unattended-upgrades ran at 06:00) ---
if systemctl is-failed --quiet apt-daily-upgrade.service; then
  log "OS: unattended-upgrades failed, see journalctl -u apt-daily-upgrade"
  problems=1
fi

# --- Container images ---
for svc in "${SERVICES[@]}"; do
  compose pull -q "$svc" || { log "$svc: image pull failed"; problems=1; }
done
for svc in "${SERVICES[@]}"; do update_service "$svc"; done
docker image prune -f >/dev/null

# --- Daily health checks ---
h=$(mc_health)
[ "$h" = healthy ] || { log "mc: health is '${h:-missing}'"; problems=1; }

# Ask the restic repository itself (container logs reset whenever the container is recreated)
last=$(compose exec -T backups restic snapshots --latest 1 --host minecraft-smp-server --json 2>/dev/null | jq -r '.[-1].time // empty')
if [ -z "$last" ]; then
  log "backups: couldn't read the backup repository"; problems=1
elif (( $(date +%s) - $(date -d "$last" +%s) > 26 * 3600 )); then
  log "backups: last successful backup was $last"; problems=1
fi

used=$(df --output=pcent / | tail -1 | tr -dc 0-9)
[ "$used" -lt 85 ] || { log "disk: / is ${used}% full"; problems=1; }

# --- Reboot for OS updates ---
if [ -f /var/run/reboot-required ]; then
  since=$(stat -c %Y /var/run/reboot-required)
  days=$(( ($(date +%s) - since) / 86400 ))
  if [ "$(players_online)" = 0 ]; then
    log "OS: rebooting for updates ($(tr '\n' ' ' < /var/run/reboot-required.pkgs 2>/dev/null))"
    reboot_now=1
  elif [ "$days" -ge 3 ]; then
    log "OS: reboot pending for $days days, players were online every morning"
    problems=1
  fi
fi

if ((${#report[@]})); then
  subject="Daily update: all good"
  ((problems)) && subject="Daily update: needs attention"
  email "$subject" "$(printf '%s\n' "${report[@]}")

Log: journalctl -u mc-auto-update"
fi

[ "${reboot_now:-0}" = 1 ] && systemctl reboot
exit 0
