"""Статическая проверка jar-файлов Forge 1.20.1: modId, обязательные зависимости, диапазон Forge/Minecraft, дубликаты."""
import io, re, zipfile
from pathlib import Path

SKIP = {"minecraft", "forge", "neoforge", "java", "mixinextras"}


def toml_of(z):
    for n in ("META-INF/mods.toml", "META-INF/neoforge.mods.toml"):
        if n in z.namelist():
            return z.read(n).decode("utf-8", "ignore")
    return ""


def parse(text):
    own, deps = [], []
    for block in re.split(r"^\s*\[\[", text, flags=re.M):
        if block.startswith("mods]]"):
            own += re.findall(r'^\s*modId\s*=\s*["\']([^"\']+)["\']', block, flags=re.M)
        m = re.match(r"dependencies\.([^\]]+)\]\]", block)
        if m:
            mid = re.search(r'^\s*modId\s*=\s*"([^"]+)"', block, flags=re.M)
            rng = re.search(r'^\s*versionRange\s*=\s*"([^"]*)"', block, flags=re.M)
            kind = re.search(r'^\s*type\s*=\s*"([^"]+)"', block, flags=re.M)
            mand = re.search(r'^\s*mandatory\s*=\s*(true|false)', block, flags=re.M)
            required = (kind and kind.group(1).lower() == "required") or (mand and mand.group(1) == "true")
            incompatible = kind and kind.group(1).lower() == "incompatible"
            if mid:
                deps.append((m.group(1), mid.group(1), rng.group(1) if rng else "", bool(required), bool(incompatible)))
    inline = re.search(r"^mods\s*=\s*\[(.*?)^\]", text, flags=re.M | re.S)  # lowcodefml: mods = [ { modId = ... } ]
    if inline:
        own += re.findall(r'\{\s*modId\s*=\s*["\']([^"\']+)["\']', inline.group(1))
    return sorted(set(own)), deps


def ids_with_nested(z, depth=0):
    own, deps = parse(toml_of(z))
    top = list(own)
    if depth < 2:
        for n in z.namelist():
            if n.startswith("META-INF/jarjar/") and n.endswith(".jar"):
                try:
                    o2, _, _ = ids_with_nested(zipfile.ZipFile(io.BytesIO(z.read(n))), depth + 1)
                    own += o2
                except zipfile.BadZipFile:
                    pass
    return own, deps, top


def ver(s):
    return tuple(int(x) for x in re.findall(r"\d+", s)[:4])


def in_range(version, rng):
    """Максимально простая проверка maven-диапазона: [a,b) (a,b] [a,] [a] a."""
    rng = rng.strip()
    if not rng or rng == "*":
        return True
    m = re.match(r"^([\[(])\s*([^,]*)\s*(?:,\s*([^\])]*))?\s*([\])])$", rng)
    if not m:
        return True
    lo_in, lo, hi, hi_in = m.group(1), m.group(2), m.group(3), m.group(4)
    v = ver(version)
    if hi is None:
        return v == ver(lo) if lo else True
    ok = True
    if lo and ver(lo):
        ok &= v >= ver(lo) if lo_in == "[" else v > ver(lo)
    if hi and ver(hi):
        ok &= v <= ver(hi) if hi_in == "]" else v < ver(hi)
    return ok


def run(folder, forge):
    jars = sorted(Path(folder).glob("*.jar"))
    provided, tops, per_jar, problems = {}, {}, {}, []
    for j in jars:
        try:
            z = zipfile.ZipFile(j)
        except zipfile.BadZipFile:
            problems.append(f"{j.name}: битый jar")
            continue
        own, deps, top = ids_with_nested(z)
        if not top:
            print(f"предупреждение: {j.name}: нет mods.toml (библиотека?)")
        per_jar[j.name] = (own, deps)
        for mid in own:
            provided.setdefault(mid, []).append(j.name)
        for mid in top:
            tops.setdefault(mid, []).append(j.name)
    for mid, fs in tops.items():
        if len(set(fs)) > 1:
            problems.append(f"дубликат modId {mid}: {', '.join(sorted(set(fs)))}")
    for name, (own, deps) in per_jar.items():
        for _, mid, rng, required, incompatible in deps:
            if mid in ("forge",) and not in_range(forge, rng):
                problems.append(f"{name}: нужен Forge {rng}, а у нас {forge}")
            if mid == "minecraft" and not in_range("1.20.1", rng):
                problems.append(f"{name}: нужен Minecraft {rng}")
            if mid in SKIP:
                continue
            if required and mid not in provided:
                problems.append(f"{name}: нет обязательной зависимости {mid}")
            if incompatible and mid in provided:
                problems.append(f"{name}: несовместим с {mid} ({', '.join(provided[mid])})")
    print(f"проверено {len(jars)} jar, modId: {len(provided)}")
    print("ПРОБЛЕМЫ:" if problems else "проблем не найдено", *sorted(set(problems)), sep="\n  ")
    return 1 if problems else 0
