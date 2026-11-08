# Local mods

Jars here are copied into `/data/mods` when the container starts, alongside the
Modrinth downloads.

## voxy-server-side-fabric-0.20.0-cmefix.jar

Voxy Server Side 0.20.0 (MIT, https://github.com/VoX/lod-server-support) with one fix.
In the official jar, `ChunkGenerationService.tick()` could crash the server tick with a
`ConcurrentModificationException` (2026-11-07 crash report). The patched loop walks a
snapshot of in-flight generations, so changes made during the walk can't crash it.
It also logs the call stack of whatever made the change, once per run, so the real
cause can be found.

Built from tag `v0.20.0` plus commit `7e19292ba` (branch `fix/generation-tick-cme` in
`~/src/lod-server-support` on adalie-linux) with `./gradlew :fabric:vssJar` on JDK 25.
Apart from `ChunkGenerationService.class`, it is byte-identical to the official 0.20.0 jar.

When upstream ships a fix: delete this jar, put `voxy-server-side` back in
`MODRINTH_PROJECTS`, and drop the `REMOVE_OLD_MODS*` lines.
