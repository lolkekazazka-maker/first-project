# Better MC 5 на Forge 1.20.1

Сборка для **Minecraft 1.20.1 + Forge 47.4.10**: Dynamic Trees + Better Leaves, Distant Horizons, Embeddium + Oculus,
шейдеры Complementary Unbound + Euphoria Patches, Vanilla Backport, Corpse, кровь, Neat, Kaleidoscope, Alex's Mobs/Caves и многое другое
(391 мод, 32 ресурспака, из них 26 включаются автоматически).

## Установка (Windows + TLauncher)

1. Поставь TLauncher, один раз запусти любую версию игры и закрой её (появится `%appdata%\.minecraft`).
2. Скачай ветку репозитория (Code → Download ZIP) и распакуй. Нужна только папка `forge-1.20.1`.
3. Запусти `forge-1.20.1\install.bat`. Он ставит Forge, скачивает моды (около 930 МБ) с проверкой sha512, ресурспаки и шейдер,
   включает язык, ресурспаки и шейдеры. Нужен интернет. Если обрыв — запусти ещё раз, уже скачанное не качается повторно.
4. В TLauncher обнови список версий и выбери **1.20.1-forge-47.4.10**.
5. В настройках TLauncher: память **7000–9000 МБ**. С 4 ГБ игра падает с `OutOfMemoryError`, а мод Memory Settings при запуске показывает окно «Less memory allocated» (там «Продолжить»).
6. Создай новый мир.

В окне установщика должна быть строка «Версия сборки: …»: если её нет, у тебя старый ZIP, скачай ветку заново.
Всё, чего нет в `mods.lock.json`, установщик переносит в `mods_backup_…`; Mizuno от прошлых установок переносит в `resourcepacks_backup_…`.
Сами jar в git не лежат: список и контрольные суммы в `mods.lock.json`. Он собирается `tools/build_lock.py` из `tools/slugs.json` (Modrinth)
и `tools/curseforge.json` (то, чего на Modrinth нет: `tools/cf_resolve.py` берёт файлы с CDN CurseForge и считает sha512).

## Что проверено

Сборка запускалась в тестовой среде: клиент дошёл до меню, зашёл в мир с шейдерами и Distant Horizons. Вживую посмотрены:
жители-девушки (Melody's Cute Girl Villagers) и железный голем Iron Girl с шейдерами, меню и инвентарь с розовыми цветами (Overgrown Flowery),
меню Female Gender Mod, палка и инструменты в 3D, JourneyMap на M. Статическая проверка (`build_lock.py --check`): у всех jar есть зависимости.
Это проверка работоспособности, а не замер FPS: FPS на RTX 3070 не измерялся.

## Ресурспаки

Порядок от нижнего слоя к верхнему: Fresh Animations (+ Extensions и Details), Fresh Animations Player, анимации оружия для Punchy (Polaris и Blacksea),
3D-верстаки и 3D-инструменты (Actually 3D Workbenches и Equipment), Better Lanterns, Fancy Crops, 3D Crops, 3D-лестницы и рельсы, Simple Grass Flowers,
Fresh Flower Pots, Just Expressions, 3D FOOD, 3D-грибы, Melody's Cute Girl Villagers, Witches, Illagers и Traders, Iron Girl,
Overgrown Flowery GUI и Hotbar, Better Leaves.

- Minecraft 1.20.1 молча выкидывает паки с «чужим» pack_format (старше или новее 15). Поэтому установщик делает для таких паков копии `… [1.20.1].zip` с pack_format 15.
- В копиях Overgrown Flowery GUI/Hotbar убран `icons.png`: в нём здоровье нарисовано цветами, а голод каплями воды. Теперь иконки обычные, а рамки, кнопки и хотбар цветочные.
- **Actually 3D Equipment** сделан под новые версии игры: углы поворота частей моделей там любые и сразу по трём осям, а 1.20.1 разрешает только -45, -22.5, 0, 22.5 и 45 градусов вокруг одной оси.
  Из-за этого палка, топоры, мотыги и лопаты были фиолетовыми «шашечками». В копии установщик округляет углы до допустимых (части палки и топоров слегка выпрямляются).
  В инвентаре эти предметы тоже показываются в 3D: выбрать вид по контексту (3D в руке, 2D в слоте) в 1.20.1 без модов нельзя.
- Melody's Cute Girl Villagers и Iron Girl работают через Entity Model Features и Entity Texture Features (оба в сборке).

## Мод на грудь для скина (Female Gender Mod)

Wildfire's Female Gender Mod добавляет к любому скину (в том числе своему) выбор пола и настройки груди с физикой.
Меню на клавише **]** (по умолчанию у мода G, но на ней же Curios, а K занята шейдерами и Pro Placer; установщик переносит меню на ]; на русской раскладке это клавиша «ъ»): «Gender» переключает пол, «Character Settings…» — размер, расстояние, высота, глубина, поворот и физика. Работает поверх скина, сам скин не меняет.
Клавишу G у справочника More Villagers установщик снимает: он тоже висел на G.

## Настройки, которые ставит установщик

Один раз на версию набора из папки `config` рядом с `install.bat` копируются настройки из старой сборки и мои правки; заменённые файлы лежат в `config_backup_…_replaced`.
- **Distant Horizons**: стартовые предупреждения и ошибки убраны из чата (остаются в логе).
- **Alex's Caves**: отключены `biome_sky_overrides`, `biome_sky_fog_overrides`, `biome_ambient_light_coloring`, `radiation_glow_effect`, `sugar_rush_saturation_effect` — Distant Horizons просит их выключить.
- **Adaptive Performance Tweaks, Advancement Plaques, TrashSlot** — настройки из старой сборки. **FTB Quests**: книга заданий из старой сборки (клавиша O или кнопка в инвентаре); главы про убранные моды могут быть пустыми.
- **Карта**: JourneyMap, полноэкранная карта на клавише **M** (установщик прописывает клавишу в `options.txt`, J освобождена), миникарта на экране.
- **options.txt**: если в нём нет строки `version`, установщик её добавляет: без неё Minecraft не понимает имена клавиш и сбрасывает все настройки (язык, ресурспаки).
- **Загрузка модов в один поток** (`config/fml.toml`, `maxThreads = 1`): при параллельной загрузке один раз из десяти Quark падал на старте (гонка потоков в его библиотеке Zeta), а после такого вылета Minecraft сбрасывал список ресурспаков. Время загрузки от этого не выросло.
- **FancyMenu**: панель редактора и приветственное окно скрыты. **Load My F***ing Tags**: сообщение в чат отключено.

## Взято с CurseForge (на Modrinth нет)

FTB Quests, FTB Library, FTB Teams, FTB Filter System, Framework, Goblin Traders, Cupboard, Chunk Sending, Smooth Chunk Save, Fast Async World Save,
Memory Settings, Recipe Essentials, Structure Essentials, Loot Integrations, Client Crafting, Biome Music. Файлы качаются прямыми ссылками с CDN CurseForge, sha512 проверяется.

## Убрано и почему

- **Mizuno's 16 Craft и все дополнения Mizuno** (по просьбе).
- **MCA Reborn**: подменял всех жителей своими «людьми» с моделью игрока, поэтому Melody's Cute Girl Villagers не применялся.
- **Better Animations Collection**: подменял модели жителей и железного голема своими (получались житель с кусками в воздухе и обычный голем), а Fresh Animations, Melody's и Iron Girl работают через те же модели.
- **Backpacked**: третий рюкзак (уже есть Sophisticated Backpacks и Traveler's Backpack), все три открываются на B.
- **Connectivity** (дублирует Packet Fixer, при запуске конфликт миксинов) и **AllTheLeaks** (дублирует MemoryLeakFix, часть исправлений для EMF не грузится и пишет ошибку в лог).
- Xaero's Minimap/World Map/XaeroPlus (вместо них JourneyMap), Simple Voice Chat, Default Options, Visual Workbench (оставляет предметы в верстаке),
  Actually 3D Blocks & Items (по просьбе), Physics Mod (по просьбе), Accessories (ошибка миксина на Forge), Chunks Fade In (ломает Distant Horizons),
  Oh The Biomes We've Gone (цикл порядка фич с Climate Rivers: вылет при создании мира), Subtle Effects (нужен Forge новее 47.4.10), Feature Recycler, Chunky, Distraction Free Recipes, ImmediatelyFast.

## Из старой сборки не добавлено

- Страшное: Goat Man, Stalker, Hydra, Weather2 (торнадо), Twilight Forest. Остались ранее выбранные Born in Chaos, Mutant Monsters, Deeper and Darker, Cataclysm.
- Нет под Forge 1.20.1: Farsight (его заменяет Distant Horizons).
- Конфликтуют с тем, что в сборке: Falling Tree, BetterFoliage (Dynamic Trees и Better Leaves), Golem Overhaul (Iron Girl), Plasmo Voice (голосовой чат убран по просьбе), Your Grave Is Dead (Corpse),
  Sodium/Iris/Lithium (вместо них Embeddium, Oculus, Radium), Connector и Continuity.

## Не нашлось под Java

- **Spark Pets** — дополнение только для Bedrock (Marketplace), для Java его нет. Ближайшее: Critters and Companions, Doggy Talents Next, Pickable Pets (в сборку не добавлены).
- **Еда с откусыванием в 3D**: Fresh Food на 1.20.1 требует Fabric-моды (Puzzle, Modefite) через Sinytra Connector, это ломает Embeddium и Oculus. Стоит обычный 3D FOOD, откусывание показывает мод Eating Animations.

## Обновление с прошлой версии

Скачай ветку заново и ещё раз запусти `forge-1.20.1\install.bat`. Если после вылета пропали ресурспаки, запусти `install.bat` ещё раз: он включит их снова. Если вылет, пришли `latest.log` или crash-report из `%appdata%\.minecraft`.
