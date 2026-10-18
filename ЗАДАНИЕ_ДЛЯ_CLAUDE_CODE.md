# Задание для Claude Code: докачать моды в сборку

Это репозиторий моей сборки Better MC 5 (Minecraft 1.21.1, NeoForge 21.1.176). Моды лежат в `minecraft/mods`. Я скачиваю репозиторий через **Code → Download ZIP** и запускаю `install.bat`, поэтому всё нужное должно быть закоммичено в репозиторий.

## Что сделать

1. Запусти скрипт из корня репозитория:
   ```bash
   python3 tools/add_mods.py
   ```
   Он:
   - удаляет `youre-in-grave-danger` (вместо него Corpse) и `particle_core` (из-за него мерцает Particle Rain);
   - качает с Modrinth моды из `tools/mods_to_add.json` с `"enabled": true`, только версии **NeoForge 1.21.1**, со сверкой sha512;
   - докачивает обязательные зависимости, но пропускает моды, которые уже есть в сборке (сверяет по modId внутри jar).

   Если я прошу «поставь всё, включая необязательные», запусти с `--all`. Если прошу конкретный необязательный мод, поменяй ему `enabled` на `true` в `tools/mods_to_add.json` и запусти без флага.

2. Если скрипт завершился с ошибкой (exit code 1), прочитай блок `ОШИБКИ`. Сетевую ошибку повтори один раз. Мод без версии под NeoForge 1.21.1 пропусти и напиши мне о нём, другие версии игры не подставляй.

3. Проверь, что в `minecraft/mods` нет двух jar одного мода с разными версиями: `ls minecraft/mods | sort`, посмотри похожие имена. Если такие есть, оставь новую версию, только если её требует новый мод. Иначе оставь старую.

4. Допиши в `README.md`, в раздел «Что изменено относительно оригинала», одну строку со списком добавленных модов и пометкой, что Corpse заменил You're in Grave Danger. Обнови число модов в таблице «Что в репозитории» (посчитай `ls minecraft/mods/*.jar | wc -l`).

5. Закоммить и запушь в `main`. Если `main` запушить нельзя, запушь ветку и напиши мне, как скачать её ZIP (на GitHub выбрать ветку → Code → Download ZIP). Если push отвалится из-за размера (HTTP 413 или RPC failed), разбей коммит на 2–3 части по папкам или файлам и пушь по очереди, как в прошлый раз («Моды, часть N из 4»).

6. В конце напиши мне коротко по-русски: что добавлено, что удалено, что пропущено и почему.

## Чего не делать

- Не трогай `minecraft/config`, `options.txt`, шейдеры и ресурспаки, если я не попросил.
- Не ставь Oh The Biomes We've Gone и Oh The Trees You'll Grow: я их убрал специально.
- Не делай репозиторий публичным: часть модов нельзя распространять.
- Не качай Fabric-версии модов, кроме тех, что сами помечены `fabric-neoforge`, например Distant Horizons.

## Что добавится (enabled = true)

Distant Horizons, Particle Rain, CravenCraft's Bloody Bits, Ribbits, Corpse, AmbientSounds, Falling Leaves, Naturalist, Guard Villagers, Better Combat, Combat Roll, Exposure, Simple Voice Chat, Wavey Capes, Chunky, Nullscape. Плюс зависимости: CreativeCore и playerAnimator.

## Необязательные (enabled = false)

Incendium, Tectonic, Terralith + Dynamic Trees Terralith (ставить только парой), Towns and Towers, MCA Reborn, Physics Mod.
