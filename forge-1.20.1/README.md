# Better MC 5 на Forge 1.20.1

Сборка для **Minecraft 1.20.1 + Forge 47.4.10**: Dynamic Trees + Better Leaves, Distant Horizons, Embeddium + Oculus,
шейдеры Complementary Unbound + Euphoria Patches, Vanilla Backport и спутники, Corpse, кровь, Neat, MCA Reborn и др.

## Установка (Windows + TLauncher)

1. Поставь TLauncher, один раз запусти любую версию игры и закрой её (появится `%appdata%\.minecraft`).
2. Скачай ветку репозитория (Code → Download ZIP) и распакуй. Нужна только папка `forge-1.20.1`.
3. Запусти `forge-1.20.1\install.bat`. Он: ставит Forge, скачивает ~300 модов (около 850 МБ) с проверкой sha512,
   кладёт ресурспаки и шейдер, включает язык, ресурспаки и шейдеры. Нужен интернет. Если обрыв — запусти ещё раз.
4. В TLauncher обнови список версий и выбери **1.20.1-forge-47.4.10**.
5. В настройках TLauncher: память около 9000 МБ.
6. Создай новый мир.

Всё, чего нет в `mods.lock.json` (моды от 1.21.1, вылетающие Feature Recycler, Chunky, Distraction Free Recipes и т.п.),
`install.bat` переносит в `%appdata%\.minecraft\mods_backup_…`. При запуске он печатает «Версия сборки: 2026-10-18-r11»:
если такой строки нет, у тебя старый ZIP — скачай ветку заново.
Сами jar в git не лежат: список и контрольные суммы в `mods.lock.json`, собирается `tools/build_lock.py`.

## Обновление с прошлой версии

Скачай ветку заново (Code → Download ZIP), распакуй и ещё раз запусти `forge-1.20.1\install.bat`. Уже скачанное не качается повторно.
После запуска в `mods` должно быть 306 jar, а в `latest.log` не должно быть Feature Recycler, Chunky и Distraction Free Recipes.

## Ресурспаки

Включаются автоматически, порядок от нижнего слоя к верхнему: Fresh Animations (+ расширения), Better Lanterns, Fancy Crops, 3D Crops «Grow your blossoms»,
3D Ladders/Rails, Simple Grass Flowers, Fresh Flower Pots, Just Expressions, 3D FOOD, 3D грибы (Mikapika), Melody's Cute Girl Villagers, Iron Girl,
Overgrown Flowery GUI + Overgrown Flowery Hotbar, Better Leaves. Villagers и Iron Girl работают через Entity Model Features (мод уже в сборке) и перекрывают Fresh Animations
для жителей и железного голема.

### Mizuno's 16 Craft

Сам пак лежит в этой папке (`Mizunos-16-Craft-Resource-Pack-1.20.1.zip`, 10 МБ), его автором является Mizuno (условия использования — в `readme.txt` внутри архива).
Установщик находит его по имени, ставит нижним слоем, включает дополнения Mizuno (Connected Texture/Glass, Better Grass, Better Crops, Fresh Animations)
и вместо обычного Better Leaves берёт Mizuno Better Leaves. Если файл убрать, установщик продолжит без него.
Если сделаешь репозиторий публичным, подумай, можно ли выкладывать этот файл: условия автора смотри в `readme.txt` внутри zip.

### Actually 3D

Версии «Actually 3D Stuff» под 1.20.1 нет, поэтому стоит его предшественник из той же серии: Actually 3D Blocks & Items, плюс Equipment и Workbenches.
Они лежат ниже остальных 3D-паков (3D Crops, 3D FOOD, грибы, лестницы), поэтому в спорных местах побеждают эти паки.

## Kaleidoscope

Kaleidoscope Cookery и дополнения: Chinese Food, Tavern, World Liquor, End, Nether, Sculk, Doll, Doll Workshop, Addons, Compat, Grilling, Sauce,
Texture Expansion, JEI Extension, Painting Extension, Bloodwine, Dimensions Wine. Не взяты: Automation и Contraption (тянут Create), Twilight (нужен Twilight Forest),
Satiated Shield Tuner (требует старый Kaleidoscope Cookery 1.1–1.2, а в сборке 1.6).

## Не проверено

FPS на RTX 3070 не измерялся, ресурспаки в игре я не просматривал (проверены только содержимое zip и формат). Если вылет, пришли `latest.log` или crash-report из `%appdata%\.minecraft`.
