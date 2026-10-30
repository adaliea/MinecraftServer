#!/usr/bin/env python3
"""Build the client .mrpack from pack.json using the Modrinth API.

Usage: python3 modpack/build.py   ->  modpack/dist/<name>-<version>.mrpack
"""
import datetime
import json
import struct
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

API = "https://api.modrinth.com/v2"
UA = {"User-Agent": "adaliea/MinecraftServer modpack builder"}
HERE = Path(__file__).resolve().parent


def get(path, **params):
    q = urllib.parse.urlencode({k: json.dumps(v) if isinstance(v, list) else v for k, v in params.items()})
    req = urllib.request.Request(f"{API}{path}{'?' + q if q else ''}", headers=UA)
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def pick_version(project, mc, loaders, beta=False):
    versions = get(f"/project/{project}/version", game_versions=[mc], loaders=loaders)
    allowed = ("release", "beta") if beta else ("release",)
    for v in versions:
        if v["version_type"] in allowed:
            return v
    raise SystemExit(f"No {'/'.join(allowed)} version of {project} for {mc} {loaders}")


def primary_file(version):
    return next((f for f in version["files"] if f["primary"]), version["files"][0])


def servers_dat(name, address):
    """Uncompressed NBT: {servers: [{name, ip}]} — what the client reads for the multiplayer list."""
    def s(x):
        b = x.encode()
        return struct.pack(">H", len(b)) + b

    entry = b"\x08" + s("name") + s(name) + b"\x08" + s("ip") + s(address) + b"\x00"
    return b"\x0a" + s("") + b"\x09" + s("servers") + b"\x0a" + struct.pack(">i", 1) + entry + b"\x00"


def main():
    pack = json.loads((HERE / "pack.json").read_text())
    mc = pack["minecraft"]
    files, seen = [], {}

    def add(version, folder, optional=False, required_by=None):
        pid = version["project_id"]
        if pid in seen:
            return
        f = primary_file(version)
        seen[pid] = f["filename"]
        files.append({
            "path": f"{folder}/{f['filename']}",
            "hashes": {"sha1": f["hashes"]["sha1"], "sha512": f["hashes"]["sha512"]},
            "env": {"client": "optional" if optional else "required", "server": "unsupported"},
            "downloads": [f["url"]],
            "fileSize": f["size"],
        })
        print(f"  {folder}/{f['filename']}" + (f"  (dependency of {required_by})" if required_by else ""))
        if folder == "mods":
            for dep in version["dependencies"]:
                if dep["dependency_type"] != "required" or dep["project_id"] in seen:
                    continue
                try:
                    dv = get(f"/version/{dep['version_id']}") if dep.get("version_id") else \
                        pick_version(dep["project_id"], mc, ["fabric"], beta=True)
                except SystemExit:
                    # Multi-loader jars (e.g. Zoomify) list other loaders' libraries as required
                    print(f"  skipped {dep['project_id']}: no Fabric build (required by {f['filename']})")
                    continue
                add(dv, "mods", required_by=f["filename"])

    print("Mods:")
    for m in pack["mods"]:
        v = get(f"/version/{m['version']}") if "version" in m else \
            pick_version(m["slug"], mc, ["fabric"], beta=m.get("beta", False))
        add(v, "mods", optional=m.get("optional", False))
    print("Shader packs:")
    for sp in pack["shaderpacks"]:
        add(pick_version(sp["slug"], mc, ["iris"]), "shaderpacks", optional=sp.get("optional", False))

    req = urllib.request.Request(f"https://meta.fabricmc.net/v2/versions/loader/{mc}", headers=UA)
    with urllib.request.urlopen(req) as r:
        fabric_loader = next(l["loader"]["version"] for l in json.load(r) if l["loader"]["stable"])

    version_id = datetime.date.today().isoformat()
    index = {
        "formatVersion": 1,
        "game": "minecraft",
        "versionId": version_id,
        "name": pack["name"],
        "summary": pack["summary"],
        "files": files,
        "dependencies": {"minecraft": mc, "fabric-loader": fabric_loader},
    }

    out = HERE / "dist" / f"{pack['name'].replace(' ', '-')}-{mc}-{version_id}.mrpack"
    out.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("modrinth.index.json", json.dumps(index, indent=2))
        z.writestr("overrides/servers.dat", servers_dat(pack["server"]["name"], pack["server"]["address"]))
    print(f"\n{len(files)} files, Fabric Loader {fabric_loader} -> {out}")


if __name__ == "__main__":
    main()
