"""Докачивает моды из tools/mods_to_add.json в minecraft/mods (NeoForge 1.21.1, с Modrinth).

  python tools/add_mods.py            # только enabled=true
  python tools/add_mods.py --all      # плюс необязательные
  python tools/add_mods.py --dry-run  # только показать, что будет сделано

Обязательные зависимости докачиваются сами, но только если такого мода (по modId) ещё нет в сборке.
"""
import hashlib, json, re, sys, urllib.parse, urllib.request, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODS = ROOT / "minecraft" / "mods"
API = "https://api.modrinth.com/v2"
UA = {"User-Agent": "lolkekazazka-maker/first-project modpack script"}
DRY = "--dry-run" in sys.argv
ALL = "--all" in sys.argv


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
        return r.read()


def mod_ids(jar):
    try:
        with zipfile.ZipFile(jar) as z:
            names = [n for n in ("META-INF/neoforge.mods.toml", "META-INF/mods.toml") if n in z.namelist()]
            text = "".join(z.read(n).decode("utf-8", "ignore") for n in names)
            ids = set()
            if "fabric.mod.json" in z.namelist():
                ids.add(json.loads(z.read("fabric.mod.json")).get("id", ""))
    except (zipfile.BadZipFile, OSError, ValueError):
        return set()
    # modId берём только из секций [[mods]], а не из [[dependencies.*]]
    for block in re.split(r"^\s*\[\[", text, flags=re.M):
        if block.startswith("mods]]"):
            ids.update(re.findall(r'modId\s*=\s*"([^"]+)"', block))
    return ids - {"", "minecraft", "neoforge", "forge", "java"}


def latest(project):
    q = urllib.parse.urlencode({"loaders": '["neoforge"]', "game_versions": '["1.21.1"]'})
    versions = json.loads(get(f"{API}/project/{project}/version?{q}"))
    if not versions:
        return None
    releases = [v for v in versions if v["version_type"] == "release"]
    return (releases or versions)[0]


cfg = json.loads((ROOT / "tools" / "mods_to_add.json").read_text("utf-8"))

for rule in cfg["remove"]:
    for jar in MODS.glob(rule["file_prefix"] + "*.jar"):
        print(f"[удалить] {jar.name} — {rule['why']}")
        if not DRY:
            jar.unlink()

installed = {}
for jar in MODS.glob("*.jar"):
    for mid in mod_ids(jar):
        installed[mid] = jar.name

queue = [(m["slug"], m["what"]) for m in cfg["mods"] if m["enabled"] or ALL]
seen, added, skipped, failed = set(), [], [], []
while queue:
    project, what = queue.pop(0)
    if project in seen:
        continue
    seen.add(project)
    try:
        v = latest(project)
    except Exception as e:  # noqa: BLE001
        failed.append(f"{project}: {e}")
        continue
    if not v:
        failed.append(f"{project}: нет версии под NeoForge 1.21.1")
        continue
    f = next((x for x in v["files"] if x["primary"]), v["files"][0])
    for d in v["dependencies"]:
        if d["dependency_type"] == "required" and d.get("project_id"):
            queue.append((d["project_id"], f"зависимость {project}"))
    target = MODS / f["filename"]
    if target.exists():
        skipped.append(f"{f['filename']} (уже есть)")
        continue
    if DRY:
        print(f"[скачать] {f['filename']} — {what}")
        added.append(f["filename"])
        continue
    data = get(f["url"])
    if hashlib.sha512(data).hexdigest() != f["hashes"]["sha512"]:
        failed.append(f"{project}: не совпал хеш")
        continue
    target.write_bytes(data)
    dup = {i: installed[i] for i in mod_ids(target) if i in installed and installed[i] != target.name}
    if dup:
        target.unlink()
        skipped.append(f"{f['filename']} (уже есть: {', '.join(sorted(set(dup.values())))})")
        continue
    for mid in mod_ids(target):
        installed[mid] = target.name
    added.append(f"{f['filename']} — {what}")
    print(f"[ok] {f['filename']}")

print("\nДобавлено:", *added, sep="\n  ")
if skipped:
    print("Пропущено, уже в сборке:", *skipped, sep="\n  ")
if failed:
    print("ОШИБКИ:", *failed, sep="\n  ")
    sys.exit(1)
