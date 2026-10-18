"""Собирает mods.lock.json для сборки Forge 1.20.1: версии, ссылки, sha512.

  python3 forge-1.20.1/tools/build_lock.py            # разрешить зависимости и записать mods.lock.json
  python3 forge-1.20.1/tools/build_lock.py --check DIR # проверить jar из DIR (modId, зависимости, версия Forge)

Берутся только версии Forge + Minecraft 1.20.1. Мод, у которого обязательная зависимость
не имеет такой версии, выкидывается и попадает в блок «выброшено».
"""
import hashlib, json, re, sys, urllib.parse, urllib.request, zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "mods.lock.json"
API = "https://api.modrinth.com/v2"
UA = {"User-Agent": "lolkekazazka-maker/first-project modpack script"}
FORGE = "47.4.10"


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=90) as r:
        return r.read()


def jget(url):
    for attempt in range(3):
        try:
            return json.loads(get(url))
        except Exception:  # noqa: BLE001
            if attempt == 2:
                raise


# на Forge 1.20.1 конфиг встроен в Forge; Modrinth требует этот мод только для Fabric-связки
IGNORE = {"ohNO6lps"}  # forge-config-api-port

def wrong_game(name):
    """В имени файла указана другая версия игры (Modrinth иногда ошибочно ставит метку 1.20.1)."""
    if re.search(r"1\.\d+(\.\d+)?-1\.20\.[2-6]", name):  # диапазон вроде 1.18-1.20.4 покрывает и 1.20.1
        return False
    return bool(re.search(r"(?<![\d.])1\.(21|20\.[2-6])(?![\d])", name)) and "1.20.1" not in name


cache = {}


def best(project):
    """Лучшая версия проекта (slug или id) под Forge 1.20.1 или None."""
    if project in cache:
        return cache[project]
    q = urllib.parse.urlencode({"loaders": '["forge"]', "game_versions": '["1.20.1"]'})
    try:
        vs = jget(f"{API}/project/{project}/version?{q}")
    except Exception:  # noqa: BLE001
        vs = []
    pick = None
    good = [v for v in vs if not wrong_game(next((x for x in v["files"] if x["primary"]), v["files"][0])["filename"])]
    for kinds in (("release", "beta"), ("alpha",)):  # JEI и др. выпускают только beta: берём самую новую
        pick = next((v for v in good if v["version_type"] in kinds), None)
        if pick:
            break
    cache[project] = pick
    return pick


def check(dirpath):
    try:
        from check_mods import run
    except ImportError:
        sys.path.insert(0, str(HERE))
        from check_mods import run
    sys.exit(run(Path(dirpath), FORGE))


if "--check" in sys.argv:
    check(sys.argv[sys.argv.index("--check") + 1])

roots = json.loads((HERE / "slugs.json").read_text("utf-8"))["mods"]
nodes, edges, why_missing = {}, {}, {}


def visit(project, parent=None):
    v = best(project)
    key = v["project_id"] if v else project
    if key in nodes or key in why_missing:
        return key
    if not v:
        why_missing[key] = f"нет версии Forge 1.20.1 ({project})"
        return key
    nodes[key] = v
    edges[key] = []
    for d in v["dependencies"]:
        if d["dependency_type"] == "required" and d.get("project_id") and d["project_id"] not in IGNORE:
            edges[key].append(visit(d["project_id"], key))
    return key


root_keys = []
for slug in roots:
    root_keys.append((slug, visit(slug)))

# мод жив, только если жив он сам и все его обязательные зависимости
alive = set(nodes)
changed = True
while changed:
    changed = False
    for k in list(alive):
        if any(d not in alive for d in edges[k]):
            alive.discard(k)
            changed = True

slug_of = {}
for pid in nodes:
    slug_of[pid] = jget(f"{API}/project/{pid}")["slug"]

dropped = []
for slug, key in root_keys:
    if key not in alive:
        bad = [slug_of.get(d, d) for d in edges.get(key, []) if d not in alive] or [why_missing.get(key, "?")]
        dropped.append(f"{slug}: {', '.join(bad)}")

keep = set()
stack = [k for _, k in root_keys if k in alive]
while stack:
    k = stack.pop()
    if k in keep:
        continue
    keep.add(k)
    stack.extend(edges[k])

lock = []
for pid in sorted(keep, key=lambda p: slug_of[p]):
    v = nodes[pid]
    f = next((x for x in v["files"] if x["primary"]), v["files"][0])
    lock.append({"slug": slug_of[pid], "version": v["version_number"], "file": f["filename"],
                 "url": f["url"], "sha512": f["hashes"]["sha512"], "size": f["size"]})



def packs(slugs, loaders, game):
    """Ресурспаки / шейдеры: последняя версия под 1.20.1 (шейдеры от версии игры не зависят)."""
    found, missing = [], []
    for slug in slugs:
        params = {"loaders": json.dumps(loaders)}
        if game:
            params["game_versions"] = json.dumps([game])
        try:
            vs = jget(f"{API}/project/{slug}/version?{urllib.parse.urlencode(params)}")
        except Exception:  # noqa: BLE001
            vs = []
        if not vs:
            missing.append(slug)
            continue
        v = next((x for x in vs if x["version_type"] == "release"), vs[0])
        f = next((x for x in v["files"] if x["primary"]), v["files"][0])
        found.append({"slug": slug, "version": v["version_number"], "file": f["filename"], "url": f["url"],
                      "sha512": f["hashes"]["sha512"], "size": f["size"]})
    return found, missing


cfg = json.loads((HERE / "slugs.json").read_text("utf-8"))
rp, rp_missing = packs(cfg.get("resourcepacks", []), ["minecraft"], "1.20.1")
sp, sp_missing = packs(cfg.get("shaderpacks", []), ["iris"], None)
OUT.write_text(json.dumps({"minecraft": "1.20.1", "forge": FORGE, "mods": lock, "resourcepacks": rp,
                           "shaderpacks": sp}, ensure_ascii=False, indent=1), "utf-8")
print(f"в lock: {len(lock)} модов, {sum(m['size'] for m in lock) / 1e6:.0f} МБ; ресурспаков {len(rp)}, шейдеров {len(sp)}")
print("выброшено:", *dropped, sep="\n  ")
print("нет под 1.20.1:", *(rp_missing + sp_missing), sep="\n  ")
