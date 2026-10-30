# dacubeking SMP client modpack

Vanilla-plus Fabric pack for `play.dacubeking.com`: Sodium/Lithium-family performance
mods, Iris with shader packs, Voxy + Voxy Server Side (distant terrain streamed from
the server) and Simple Voice Chat (matching the server), plus QoL (Mod Menu, Zoomify, AppleSkin, Jade, Xaero's maps, ...). The server
is pre-added to the multiplayer list.

Edit `pack.json`, then build:

```sh
python3 modpack/build.py   # -> modpack/dist/*.mrpack
```

Import the `.mrpack` in the Modrinth App or Prism Launcher. Xaero's maps and all shader
packs except Complementary Reimagined are optional and can be deselected on import.
New installs default to render distance 8 (Voxy draws beyond it) via
yosbr, which never overwrites existing settings. Keep `simple-voice-chat` pinned to the same version as the server's `docker-compose.yml`.

Sodium and Iris are pinned to the versions Voxy 0.2.20 accepts (Sodium 0.9.2–0.9.3,
Iris < 1.12); bump them together with Voxy.
