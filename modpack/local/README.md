# Local mods

Mods that aren't on Modrinth for 26.3. `build.py` ships them inside the pack as
`overrides/mods/`.

## euphonium-1.0.3+26.3-dacubeking.jar

Unofficial port of [Euphonium](https://github.com/sisby-folk/euphonium) (biome and cave
ambience, by svenhjol and Sisby folk) to Minecraft 26.3 Fabric. Upstream stopped at 1.21.1.

- Source: branch `port/26.3` (commit `eee3dac`) in `~/src/euphonium` on adalie-linux, based
  on upstream `1.21`. Changes: Yarn to Mojang names, Loom 1.17 / Gradle 9.5 / Java 25, and
  26.3 API renames (Identifier, convention tags v2, overworld clock time, a replacement for
  the removed `BlockPos.findClosestMatch`).
- Tested with a Fabric client gametest, alone and alongside the full pack: the surface,
  cave and End ambience all start playing.
- License: LGPL-3.0-or-later. The matching source is published next to the pack at
  https://pack.dacubeking.com/src/euphonium-1.0.3+26.3-dacubeking-src.zip
- sha256: `8a97d6ac19fc770571c27d33e080f7f1841232e560bcfd4d08f972a91d8c4a2f`

If an official 26.3 build appears on Modrinth, delete the jar and its `local_mods` entry
and add `{"slug": "euphonium"}` to `mods` instead.
