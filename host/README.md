# Host services

## chunky-when-empty

Pre-generates terrain with Chunky only while nobody is online. Every 15 s it checks
the player count over RCON: when the server is empty it runs `chunky continue`
(resumes every saved task), and when anyone is online it runs `chunky pause`.

Current tasks (all circles centered on 0,0): Overworld 6,000 blocks, Nether 2,000,
End 3,000. Add or change one with `chunky start <world> circle 0 0 <radius>`, then
`chunky pause` if people are online; the service picks it up from there.

Install or update on the host:

```
sudo cp host/chunky-when-empty.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now chunky-when-empty
journalctl -u chunky-when-empty -f   # see each pause/continue
```
