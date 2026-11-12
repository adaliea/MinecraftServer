# dacubeking SMP client modpack

Vanilla-plus Fabric pack for `play.dacubeking.com`: Sodium/Lithium-family performance
mods, Iris with shader packs, Voxy + Voxy Server Side (distant terrain streamed from
the server) and Simple Voice Chat (matching the server), plus QoL (Mod Menu, Zoomify, Freecam, AppleSkin, Jade, Xaero's maps, ...). The server
is pre-added to the multiplayer list.

Edit `pack.json`, then build:

```sh
python3 modpack/build.py   # -> modpack/dist/*.mrpack
```

Import the `.mrpack` in the Modrinth App or Prism Launcher. Xaero's maps and all shader
packs except Complementary Reimagined are optional and can be deselected on import.

Resource packs enabled by default through yosbr: Simple Voice Chat's `black_icons`,
Vanilla Tweaks (`local/VanillaTweaks_r429177_MC26.3.x.zip`, a custom vanillatweaks.net
bundle; its `Selected Packs.txt` lists what's in it), xali's Enchanted Books and Continuity's
`continuity:default`. xali's Enchanted Books' pack.mcmeta predates 26.3,
so it has to be listed under `incompatibleResourcePacks` too, or the game drops it from
`resourcePacks` at startup.

New installs default to render distance 8 (Voxy draws beyond it) via
yosbr, which never overwrites existing settings. Keep `simple-voice-chat` pinned to the same version as the server's `docker-compose.yml`.

Sodium and Iris are pinned to the versions Voxy 0.2.20 accepts (Sodium 0.9.2–0.9.3,
Iris < 1.12); bump them together with Voxy. Sodium Extra and Reese's Sodium Options
require an exact Sodium build, so they're pinned to the releases built for that Sodium.
Bump all four together, then launch the pack once to check before uploading.
