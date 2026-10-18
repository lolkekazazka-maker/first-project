# Better MC 5 на Forge 1.20.1

Сборка для **Minecraft 1.20.1 + Forge 47.4.10**: Dynamic Trees + Better Leaves, Distant Horizons, Embeddium + Oculus,
шейдеры Complementary Unbound + Euphoria Patches, Vanilla Backport и спутники, Corpse, кровь, Neat, Physics Mod, MCA Reborn и др.

## Установка (Windows + TLauncher)

1. Поставь TLauncher, один раз запусти любую версию игры и закрой её (появится `%appdata%\.minecraft`).
2. Скачай ветку репозитория (Code → Download ZIP) и распакуй. Нужна только папка `forge-1.20.1`.
3. Запусти `forge-1.20.1\install.bat`. Он: ставит Forge, скачивает ~250 модов (около 600 МБ) с проверкой sha512,
   кладёт ресурспаки и шейдер, включает язык, ресурспаки и шейдеры. Нужен интернет. Если обрыв — запусти ещё раз.
4. В TLauncher обнови список версий и выбери **1.20.1-forge-47.4.10**.
5. В настройках TLauncher: память около 9000 МБ.
6. Создай новый мир.

Чужие моды из `%appdata%\.minecraft\mods` (например, от 1.21.1) переносятся в `mods_backup_…`.
Сами jar в git не лежат: список и контрольные суммы в `mods.lock.json`, собирается `tools/build_lock.py`.

## Не проверено

Запуск игры и FPS не проверялись: если вылет, пришли `latest.log` или crash-report из `%appdata%\.minecraft`.
