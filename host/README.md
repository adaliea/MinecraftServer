# Host services

## chunky-when-empty

Pre-generates terrain with Chunky only while nobody is online. Every 15 s it checks
the player count over RCON: when the server is empty it runs `chunky continue`
(resumes every saved task), and when anyone is online it runs `chunky pause`.

Tasks so far (all circles centered on 0,0): Overworld 8,192 blocks, Nether 2,000,
End 3,000. Add or change one with `chunky start <world> circle 0 0 <radius>`, then
`chunky pause` if people are online; the service picks it up from there.

Install or update on the host:

```
sudo cp host/chunky-when-empty.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now chunky-when-empty
journalctl -u chunky-when-empty -f   # see each pause/continue
```

## mc-auto-update (daily updates, rollback, email alerts)

All times US Eastern (`America/New_York`, so they follow daylight saving):

| Time | What |
|---|---|
| 05:30 | apt downloads package lists and updates (`apt/apt-daily.timer.conf`) |
| 06:00 | unattended-upgrades installs OS security updates (`apt/apt-daily-upgrade.timer.conf`). A Docker update restarts every container. |
| 06:30 | `auto-update.sh` (`mc-auto-update.timer`) |

`auto-update.sh`:

- Pulls new images for `cloudflared`, `backups` and `mc`. Minecraft, Fabric and the mods are
  pinned in `docker-compose.yml`, so a new `mc` image only brings Java and itzg's startup
  scripts; those stay manual.
- Recreates `cloudflared` and `backups` whenever their image changed, and `mc` only while
  nobody is online (otherwise it retries the next morning).
- If `mc` isn't healthy within 10 minutes (or the others crash within 30 s), it re-tags the
  previous image, brings that back up and records the bad image ID in
  `/var/lib/mc-auto-update/held-<service>` so it isn't retried. Delete that file to allow it.
  Note: while an image is held, a manual `docker compose up -d` would start the held image;
  run `docker compose pull` only after the upstream fix.
- Reboots when `/var/run/reboot-required` exists and nobody is online
  (`apt/52mc-no-auto-reboot` turns off unattended-upgrades' own 05:00 UTC reboot).
- Checks that `mc` is healthy, a backup succeeded in the last 26 hours and the disk is under
  85% full.
- Emails a summary when anything changed or went wrong; quiet days send nothing.

Email goes through the site Worker: `POST https://play.dacubeking.com/api/alert` with a
bearer token, sent from `server@alerts.dacubeking.com` (Cloudflare Email Sending) to the
Worker secret `ALERT_TO`. The token lives in `/etc/mc-alert.env` (root, 0600) and in the
Worker secret `ALERT_TOKEN`. Send a test with `sudo host/alert.sh "Test" "hello"`.

Install or update on the host:

```
sudo cp host/mc-auto-update.service host/mc-auto-update.timer /etc/systemd/system/
sudo install -D -m 644 host/apt/apt-daily.timer.conf /etc/systemd/system/apt-daily.timer.d/override.conf
sudo install -D -m 644 host/apt/apt-daily-upgrade.timer.conf /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf
sudo install -m 644 host/apt/52mc-no-auto-reboot /etc/apt/apt.conf.d/
sudo systemctl daemon-reload
sudo systemctl enable --now mc-auto-update.timer
systemctl list-timers apt-daily apt-daily-upgrade mc-auto-update
journalctl -u mc-auto-update        # last run
```
