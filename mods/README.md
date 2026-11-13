# Local mods

Jars here are copied into `/data/mods` when the container starts, alongside the
Modrinth downloads.

## voxy-server-side-fabric-0.20.0-dacubeking.jar

Voxy Server Side 0.20.0 (MIT, https://github.com/VoX/lod-server-support) with two fixes:

1. **Tick crash.** In the official jar, `ChunkGenerationService.tick()` could crash the
   server tick with a `ConcurrentModificationException` (2026-11-07 crash report). The
   patched loop walks a snapshot of in-flight generations, so changes made during the walk
   can't crash it. It also logs the call stack of whatever made the change, once per run.
2. **Lag on join and dimension change.** When a player arrives, their whole loaded view is
   requested at once, and VSS serialized (and anti-xray-masked) up to 512 loaded columns in
   a single tick on the server thread. A spark profile on 2026-11-13 showed 2–3 s freezes
   for everyone each time someone went through a portal. The in-memory probe pass now
   stops after 5 ms per tick; the rest go through VSS's off-thread disk path or the next
   tick, the same fallthrough its count caps already use.

Built from tag `v0.20.0` plus commits `7e19292ba` and `c3475b2dc` (branch
`fix/generation-tick-cme` in `~/src/lod-server-support` on adalie-linux) with
`./gradlew :fabric:vssJar` on JDK 25. sha256
a0a94b83dc2f4e2b8d8555c3197cb8f0eae5f3a736cbf88b3f2b60fb7e803b41.

When upstream ships both fixes: delete this jar, put `voxy-server-side` back in
`MODRINTH_PROJECTS`, and drop the `REMOVE_OLD_MODS*` lines.
