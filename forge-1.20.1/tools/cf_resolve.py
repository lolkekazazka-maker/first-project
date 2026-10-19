"""Находит на CurseForge последние файлы Forge 1.20.1 для проектов из curseforge.json, качает их, считает sha512
и записывает curseforge.lock.json (его подмешивает build_lock.py). Для модов, которых нет на Modrinth.

  python3 forge-1.20.1/tools/cf_resolve.py            # уже выбранные файлы остаются
  python3 forge-1.20.1/tools/cf_resolve.py --update   # взять самые новые
"""
import hashlib, json, sys, urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
UA = {"User-Agent": "Mozilla/5.0"}
CDN = "https://edge.forgecdn.net/files/{}/{}/{}"


def jget(url):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return json.load(r)
        except Exception:  # noqa: BLE001
            if attempt == 2:
                raise


def files(pid):
    out, page = [], 0
    while True:
        d = jget(f"https://www.curseforge.com/api/v1/mods/{pid}/files?pageIndex={page}&pageSize=50&sort=dateCreated&sortDescending=true")
        out += d["data"]
        page += 1
        if not d["data"] or len(out) >= d["pagination"]["totalCount"]:
            return out


def main():
    cfg = json.loads((HERE / "curseforge.json").read_text("utf-8"))
    out_path = HERE / "curseforge.lock.json"
    old = json.loads(out_path.read_text("utf-8")) if out_path.exists() and "--update" not in sys.argv else {}
    old_by_id = {(k, e["cf"]["project"]): e for k, v in old.items() for e in v}
    result = {"mods": [], "resourcepacks": []}
    for kind in ("mods", "resourcepacks"):
        for item in cfg.get(kind, []):
            pid = item["id"]
            if (kind, pid) in old_by_id:
                result[kind].append(old_by_id[(kind, pid)])
                continue
            fs = [f for f in files(pid) if "1.20.1" in f["gameVersions"] and (kind != "mods" or "Forge" in f["gameVersions"])
                  and f["fileName"].endswith((".jar", ".zip"))]
            if not fs:
                print(f"нет файла 1.20.1 для {item['slug']} ({pid})")
                continue
            f = next((x for x in fs if x["releaseType"] == 1), fs[0])  # свежий релиз, иначе свежая бета
            url = CDN.format(f["id"] // 1000, f["id"] % 1000, f["fileName"])
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180) as r:
                data = r.read()
            result[kind].append({"slug": item["slug"], "version": f["displayName"], "file": f["fileName"], "url": url,
                                 "sha512": hashlib.sha512(data).hexdigest(), "size": len(data),
                                 "cf": {"project": pid, "file": f["id"]}})
            print(f"{item['slug']}: {f['fileName']} ({len(data) // 1024} КБ)")
    out_path.write_text(json.dumps(result, ensure_ascii=False, indent=1), "utf-8")


main()
