#!/bin/bash
# Usage: alert.sh <subject> [body]. Emails the admin via play.dacubeking.com/api/alert.
# Needs /etc/mc-alert.env (root-only) with ALERT_URL and ALERT_TOKEN.
set -u
. /etc/mc-alert.env
jq -n --arg s "$1" --arg t "${2:-}" '{subject: $s, text: $t}' |
  curl -sS -m 30 -X POST "$ALERT_URL" -H "authorization: Bearer $ALERT_TOKEN" \
    -H "content-type: application/json" --data-binary @-
echo
