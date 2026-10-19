"""Собирает mods.lock.json для сборки Forge 1.20.1: версии, ссылки, sha512.

  python3 forge-1.20.1/tools/build_lock.py            # разрешить зависимости и записать mods.lock.json (версии уже проверенных модов не меняются)
  python3 forge-1.20.1/tools/build_lock.py --update   # то же, но взять самые новые версии
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
BUILD = "2026-10-19-r20"  # меняется при каждом изменении набора модов: установщик печатает её


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
# Sodium на Forge заменяет Embeddium: Chunks Fade In в mods.toml Sodium не требует, это метка Modrinth
# Accessories на Forge даёт ошибку миксина (ContainerMixin) и нужен только Immersive Lanterns как необязательный
IGNORE = {"ohNO6lps", "AANobbMI", "jtmvUHXj"}  # forge-config-api-port, sodium, accessories

# уже проверенные версии из текущего mods.lock.json остаются, пока их не просят обновить (--update):
# иначе при каждой пересборке мод тихо переезжает на новую, не проверенную версию
PINNED = set()
if OUT.exists() and "--update" not in sys.argv:
    _old = json.loads(OUT.read_text("utf-8"))
    PINNED = {m["file"] for m in _old["mods"]}
    PINNED |= {m["file"] for m in _old.get("resourcepacks", []) + _old.get("shaderpacks", [])}


# версии, которые нельзя брать новыми (например, требуют Forge новее 47.4.10)
MOD_VERSION = {}


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
    pick = next((v for v in good if v["version_number"] == MOD_VERSION.get(project)), None) \
        or next((v for v in good if any(f["filename"] in PINNED for f in v["files"])), None)
    for kinds in (() if pick else (("release", "beta"), ("alpha",))):  # JEI и др. выпускают только beta: берём самую новую
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



# у этих паков свежие версии сделаны под новые игры (формат 46+), а для 1.20.1 нужна старая версия
PACK_VERSION = {"3d-crops": "1", "3d-equipment": "r1.0-beta1"}  # «Grow your blossoms», pack_format 15


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
        v = (next((x for x in vs if x["version_number"] == PACK_VERSION.get(slug)), None)
             or next((x for x in vs if any(f["filename"] in PINNED for f in x["files"])), None)
             or next((x for x in vs if x["version_type"] == "release"), vs[0]))
        f = next((x for x in v["files"] if x["primary"]), v["files"][0])
        found.append({"slug": slug, "version": v["version_number"], "file": f["filename"], "url": f["url"],
                      "sha512": f["hashes"]["sha512"], "size": f["size"]})
    return found, missing


cfg = json.loads((HERE / "slugs.json").read_text("utf-8"))
# моды и паки, которых нет на Modrinth: их файлы с CurseForge выбирает cf_resolve.py (curseforge.json -> curseforge.lock.json)
cf = json.loads((HERE / "curseforge.lock.json").read_text("utf-8")) if (HERE / "curseforge.lock.json").exists() else {}
lock += [m for m in cf.get("mods", []) if m["file"] not in {x["file"] for x in lock}]
lock.sort(key=lambda m: m["slug"])
rp, rp_missing = packs(cfg.get("resourcepacks", []), ["minecraft"], "1.20.1")
sp, sp_missing = packs(cfg.get("shaderpacks", []), ["iris"], None)
rp += [m for m in cf.get("resourcepacks", []) if m["file"] not in {x["file"] for x in rp}]
OUT.write_text(json.dumps({"minecraft": "1.20.1", "forge": FORGE, "build": BUILD, "mods": lock, "resourcepacks": rp,
                           "shaderpacks": sp}, ensure_ascii=False, indent=1), "utf-8")
print(f"в lock: {len(lock)} модов, {sum(m['size'] for m in lock) / 1e6:.0f} МБ; ресурспаков {len(rp)}, шейдеров {len(sp)}")
print("выброшено:", *dropped, sep="\n  ")
print("нет под 1.20.1:", *(rp_missing + sp_missing), sep="\n  ")
