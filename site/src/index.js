// Serves the static site from ./public and one API route, /api/status, which
// asks the Minecraft server how many players are online (Server List Ping).
import { connect } from "cloudflare:sockets";

const MC_HOST = "mc.dacubeking.com";
const MC_PORT = 25565;
const CACHE_SECONDS = 30;
const TIMEOUT_MS = 4000;

function varInt(n) {
  const out = [];
  n >>>= 0;
  do {
    let b = n & 0x7f;
    n >>>= 7;
    if (n) b |= 0x80;
    out.push(b);
  } while (n);
  return out;
}

function packet(id, body) {
  const data = [...varInt(id), ...body];
  return new Uint8Array([...varInt(data.length), ...data]);
}

// Reads a VarInt from buf at pos. Returns [value, nextPos], or null if buf ends first.
function readVarInt(buf, pos) {
  let value = 0;
  for (let shift = 0; shift < 35; shift += 7) {
    if (pos >= buf.length) return null;
    const b = buf[pos++];
    value |= (b & 0x7f) << shift;
    if (!(b & 0x80)) return [value, pos];
  }
  throw new Error("VarInt too long");
}

async function ping() {
  const socket = connect({ hostname: MC_HOST, port: MC_PORT });
  try {
    const writer = socket.writable.getWriter();
    const host = new TextEncoder().encode(MC_HOST);
    await writer.write(packet(0x00, [
      ...varInt(-1),                 // protocol version: "any", status only
      ...varInt(host.length), ...host,
      MC_PORT >> 8, MC_PORT & 0xff,
      ...varInt(1),                  // next state: status
    ]));
    await writer.write(packet(0x00, []));

    const reader = socket.readable.getReader();
    let buf = new Uint8Array(0);
    for (;;) {
      const { value, done } = await reader.read();
      if (done) throw new Error("connection closed early");
      const merged = new Uint8Array(buf.length + value.length);
      merged.set(buf);
      merged.set(value, buf.length);
      buf = merged;

      const len = readVarInt(buf, 0);
      if (!len || buf.length < len[1] + len[0]) continue;
      let pos = readVarInt(buf, len[1])[1];          // packet id
      const [strLen, start] = readVarInt(buf, pos);
      return JSON.parse(new TextDecoder().decode(buf.subarray(start, start + strLen)));
    }
  } finally {
    socket.close().catch(() => {});
  }
}

async function status() {
  try {
    const timeout = new Promise((_, reject) =>
      setTimeout(() => reject(new Error("timeout")), TIMEOUT_MS));
    const s = await Promise.race([ping(), timeout]);
    return { online: true, players: s.players?.online ?? 0, max: s.players?.max ?? 0 };
  } catch {
    return { online: false };
  }
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname !== "/api/status") return env.ASSETS.fetch(request);

    const cache = caches.default;
    const key = new Request(url.origin + "/api/status");
    const hit = await cache.match(key);
    if (hit) return hit;

    const res = new Response(JSON.stringify(await status()), {
      headers: {
        "content-type": "application/json",
        "cache-control": `public, max-age=${CACHE_SECONDS}`,
      },
    });
    ctx.waitUntil(cache.put(key, res.clone()));
    return res;
  },
};
