# Better MC 5 на Forge 1.20.1

Сборка для **Minecraft 1.20.1 + Forge 47.4.10**: Dynamic Trees + Better Leaves, Distant Horizons, Embeddium + Oculus,
шейдеры Complementary Unbound + Euphoria Patches, Vanilla Backport и спутники, Corpse, кровь, Neat, Physics Mod, MCA Reborn и др.

## Установка (Windows + TLauncher)

1. Поставь TLauncher, один раз запусти любую версию игры и закрой её (появится `%appdata%\.minecraft`).
2. Скачай ветку репозитория (Code → Download ZIP) и распакуй. Нужна только папка `forge-1.20.1`.
3. Запусти `forge-1.20.1\install.bat`. Он: ставит Forge, скачивает ~260 модов (около 600 МБ) с проверкой sha512,
   кладёт ресурспаки и шейдер, включает язык, ресурспаки и шейдеры. Нужен интернет. Если обрыв — запусти ещё раз.
4. В TLauncher обнови список версий и выбери **1.20.1-forge-47.4.10**.
5. В настройках TLauncher: память около 9000 МБ.
6. Создай новый мир.

Всё, чего нет в `mods.lock.json` (моды от 1.21.1, вылетающие Feature Recycler, Chunky, Distraction Free Recipes и т.п.),
`install.bat` переносит в `%appdata%\.minecraft\mods_backup_…`. При запуске он печатает «Версия сборки: 2026-10-18-r5»:
если такой строки нет, у тебя старый ZIP — скачай ветку заново.
Сами jar в git не лежат: список и контрольные суммы в `mods.lock.json`, собирается `tools/build_lock.py`.

## Обновление с прошлой версии

Скачай ветку заново (Code → Download ZIP), распакуй и ещё раз запусти `forge-1.20.1\install.bat`. Уже скачанное не качается повторно.
После запуска в `mods` должно быть 258 jar, а в `latest.log` — не 307 модов, как раньше.

## Не проверено

FPS на RTX 3070 не измерялся. Если вылет, пришли `latest.log` или crash-report из `%appdata%\.minecraft`.
