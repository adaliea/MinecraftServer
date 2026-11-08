# play.dacubeking.com

Static site served by a Cloudflare Worker (assets only, no script).

- Edit `index.src.html` (the ridge art is generated into `public/index.html`) or the
  files in `public/`.
- Deploy: `npx wrangler deploy` from this folder (needs `wrangler login`).

`play.dacubeking.com` is proxied to this Worker, so Minecraft reaches the server through
`_minecraft._tcp.play.dacubeking.com` SRV -> `mc.dacubeking.com:25565` (DNS only).
