# Better MC 5 на Forge 1.20.1

Сборка для **Minecraft 1.20.1 + Forge 47.4.10**: Dynamic Trees + Better Leaves, Distant Horizons, Embeddium + Oculus,
шейдеры Complementary Unbound + Euphoria Patches, Vanilla Backport и спутники, Corpse, кровь, Neat, Physics Mod, MCA Reborn и др.

## Установка (Windows + TLauncher)

1. Поставь TLauncher, один раз запусти любую версию игры и закрой её (появится `%appdata%\.minecraft`).
2. Скачай ветку репозитория (Code → Download ZIP) и распакуй. Нужна только папка `forge-1.20.1`.
3. Запусти `forge-1.20.1\install.bat`. Он: ставит Forge, скачивает ~290 модов (около 800 МБ) с проверкой sha512,
   кладёт ресурспаки и шейдер, включает язык, ресурспаки и шейдеры. Нужен интернет. Если обрыв — запусти ещё раз.
4. В TLauncher обнови список версий и выбери **1.20.1-forge-47.4.10**.
5. В настройках TLauncher: память около 9000 МБ.
6. Создай новый мир.

Всё, чего нет в `mods.lock.json` (моды от 1.21.1, вылетающие Feature Recycler, Chunky, Distraction Free Recipes и т.п.),
`install.bat` переносит в `%appdata%\.minecraft\mods_backup_…`. При запуске он печатает «Версия сборки: 2026-10-18-r8»:
если такой строки нет, у тебя старый ZIP — скачай ветку заново.
Сами jar в git не лежат: список и контрольные суммы в `mods.lock.json`, собирается `tools/build_lock.py`.

## Обновление с прошлой версии

Скачай ветку заново (Code → Download ZIP), распакуй и ещё раз запусти `forge-1.20.1\install.bat`. Уже скачанное не качается повторно.
После запуска в `mods` должно быть 288 jar, а в `latest.log` не должно быть Feature Recycler, Chunky и Distraction Free Recipes.

## Ресурспаки

Включаются автоматически, порядок от нижнего слоя к верхнему: Fresh Animations (+ расширения), Better Lanterns, Fancy Crops, 3D Crops «Grow your blossoms»,
3D Ladders/Rails, Simple Grass Flowers, Fresh Flower Pots, Just Expressions, 3D FOOD, 3D грибы (Mikapika), Melody's Cute Girl Villagers, Iron Girl,
Overgrown Flowery GUI + Overgrown Flowery Hotbar, Better Leaves. Villagers и Iron Girl работают через Entity Model Features (мод уже в сборке) и перекрывают Fresh Animations
для жителей и железного голема.

### Mizuno's 16 Craft (скачать вручную)

Сам пак есть только на CurseForge, автоматически его скачать нельзя. Скачай zip со страницы
https://www.curseforge.com/minecraft/texture-packs/mizunos-16-craft и положи рядом с `install.bat` (в папку `forge-1.20.1`), потом запусти `install.bat` ещё раз.
Установщик найдёт файл, поставит его нижним слоем, включит дополнения Mizuno (Better Leaves, Connected Texture/Glass, Better Grass, Better Crops, Fresh Animations)
и вместо обычного Better Leaves возьмёт Mizuno Better Leaves. Без этого файла дополнения Mizuno скачаны, но не включены.

## Не проверено

FPS на RTX 3070 не измерялся, ресурспаки в игре я не просматривал (проверены только содержимое zip и формат). Если вылет, пришли `latest.log` или crash-report из `%appdata%\.minecraft`.
