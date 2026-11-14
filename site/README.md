# play.dacubeking.com

Static site served by a Cloudflare Worker. `src/index.js` only handles `/api/status`,
which pings the Minecraft server for the online player count (cached 30 s); everything else
is served straight from `public/`.

- Edit the files in `public/` directly.
- Deploy: `npx wrangler deploy` from this folder (needs `wrangler login`).

`play.dacubeking.com` is proxied to this Worker, so Minecraft reaches the server through
`_minecraft._tcp.play.dacubeking.com` SRV -> `mc.dacubeking.com:25565` (DNS only).
