"""Статическая проверка jar-файлов Forge 1.20.1: modId, обязательные зависимости, диапазон Forge/Minecraft, дубликаты."""
import io, re, zipfile
from pathlib import Path

SKIP = {"minecraft", "forge", "neoforge", "java", "mixinextras"}


def toml_of(z):
    for n in ("META-INF/mods.toml", "META-INF/neoforge.mods.toml"):
        if n in z.namelist():
            return z.read(n).decode("utf-8", "ignore")
    return ""


def own_versions(text, manifest):
    """modId -> версия (${file.jarVersion} берём из MANIFEST)."""
    out = {}
    jv = re.search(r"^Implementation-Version:\s*(\S+)", manifest, flags=re.M)
    for block in re.split(r"^\s*\[\[", text, flags=re.M):
        if block.startswith("mods]]"):
            mid = re.search(r'^\s*modId\s*=\s*["\']([^"\']+)["\']', block, flags=re.M)
            v = re.search(r'^\s*version\s*=\s*["\']([^"\']+)["\']', block, flags=re.M)
            if mid and v:
                out[mid.group(1)] = (jv.group(1) if jv and "jarVersion" in v.group(1) else v.group(1))
    for m in re.finditer(r"\{\s*modId\s*=\s*['\"]([^'\"]+)['\"][^}]*?version\s*=\s*['\"]([^'\"]+)['\"]", text):
        out.setdefault(m.group(1), m.group(2))
    return out


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


vers, loader = {}, ['', '']


def ids_with_nested(z, depth=0):
    text = toml_of(z)
    own, deps = parse(text)
    top = list(own)
    manifest = z.read("META-INF/MANIFEST.MF").decode("utf-8", "ignore") if "META-INF/MANIFEST.MF" in z.namelist() else ""
    vers.update(own_versions(text, manifest))
    loader[0] = re.search(r'^\s*loaderVersion\s*=\s*["\']([^"\']+)["\']', text, flags=re.M)
    loader[0] = loader[0].group(1) if loader[0] else ""
    ml = re.search(r'^\s*modLoader\s*=\s*["\']([^"\']+)["\']', text, flags=re.M)
    loader[1] = ml.group(1) if ml else ""
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
    versions = {}
    for j in jars:
        try:
            z = zipfile.ZipFile(j)
        except zipfile.BadZipFile:
            problems.append(f"{j.name}: битый jar")
            continue
        vers.clear()
        own, deps, top = ids_with_nested(z)
        for k, v in vers.items():
            versions.setdefault(k, v)
        if loader[1] == "javafml" and loader[0] and not in_range("47.4.10", loader[0]):
            problems.append(f"{j.name}: нужен javafml {loader[0]}, у Forge 1.20.1 — 47")
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
    for name in per_jar:
        if re.search(r"1\.(21|20\.[2-6])(?!\d)", name) and "1.20.1" not in name and not re.search(r"1\.\d+(\.\d+)?-1\.20\.[2-6]", name):
            problems.append(f"{name}: в имени файла другая версия игры")
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
            elif rng and mid in versions and re.search(r"\d", versions[mid]) and not in_range(versions[mid], rng) and not incompatible:
                problems.append(f"{name}: нужен {mid} {rng}, а стоит {versions[mid]}" + ("" if required else " (необязательная зависимость, но Forge проверяет)"))
            if incompatible and mid in provided:
                problems.append(f"{name}: несовместим с {mid} ({', '.join(provided[mid])})")
    print(f"проверено {len(jars)} jar, modId: {len(provided)}")
    print("ПРОБЛЕМЫ:" if problems else "проблем не найдено", *sorted(set(problems)), sep="\n  ")
    return 1 if problems else 0
