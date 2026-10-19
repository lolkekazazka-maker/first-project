# Better MC 5 на Forge 1.20.1

Сборка для **Minecraft 1.20.1 + Forge 47.4.10**: Dynamic Trees + Better Leaves, Distant Horizons, Embeddium + Oculus,
шейдеры Complementary Unbound + Euphoria Patches, Vanilla Backport, Corpse, кровь, Neat, MCA Reborn, Kaleidoscope, Alex's Mobs/Caves и многое другое
(около 376 модов, 34 ресурспака, из них 26 включаются автоматически).

## Установка (Windows + TLauncher)

1. Поставь TLauncher, один раз запусти любую версию игры и закрой её (появится `%appdata%\.minecraft`).
2. Скачай ветку репозитория (Code → Download ZIP) и распакуй. Нужна только папка `forge-1.20.1`.
3. Запусти `forge-1.20.1\install.bat`. Он ставит Forge, скачивает моды (около 950 МБ) с проверкой sha512, ресурспаки и шейдер,
   включает язык, ресурспаки и шейдеры. Нужен интернет. Если обрыв — запусти ещё раз, уже скачанное не качается повторно.
4. В TLauncher обнови список версий и выбери **1.20.1-forge-47.4.10**.
5. В настройках TLauncher: память около 9000 МБ.
6. Создай новый мир.

В окне установщика должна быть строка «Версия сборки: …»: если её нет, у тебя старый ZIP, скачай ветку заново.
Всё, чего нет в `mods.lock.json` (моды от 1.21.1, Feature Recycler, Chunky и т.п.), установщик переносит в `mods_backup_…`.
Сами jar в git не лежат: список и контрольные суммы в `mods.lock.json`, собирается `tools/build_lock.py` из `tools/slugs.json`.

## Что проверено

Сборка запускалась в тестовой среде: сервер сгенерировал мир в верхнем мире, Незере, Крае и Эфире, клиент дошёл до меню,
создал мир, зашёл в него (шейдеры, Distant Horizons, достижения, инвентарь, предметы на полу, мобы). Это проверка работоспособности,
а не замер FPS: FPS на RTX 3070 не измерялся.

## Ресурспаки

Порядок от нижнего слоя к верхнему: Mizuno's 16 Craft (лежит рядом с `install.bat`, условия автора в `readme.txt` внутри zip), Fresh Animations,
Fresh Animations Player, анимации оружия для Punchy (Polaris и Blacksea), Mizuno x Fresh Animations, 3D-верстаки (Actually 3D Workbenches),
Better Lanterns, Fancy Crops, 3D Crops, 3D-лестницы и рельсы, Simple Grass Flowers, дополнения Mizuno (трава, стекло, посевы), Fresh Flower Pots,
Just Expressions, 3D FOOD, 3D-грибы, Melody's Cute Girl Villagers, Iron Girl, Overgrown Flowery GUI и Hotbar, листва Mizuno Better Leaves.

- Minecraft 1.20.1 молча выкидывает паки с «чужим» pack_format (старше или новее 15). Поэтому установщик делает для таких паков копии `… [1.20.1].zip` с pack_format 15.
- В копиях Overgrown Flowery GUI/Hotbar убран `icons.png`: в нём здоровье нарисовано цветами, а голод каплями воды. Теперь иконки обычные, а рамки, кнопки и хотбар остались цветочными.
- Овцы целиком берутся из Mizuno: в копиях Fresh Animations и Mizuno x Fresh Animations файлы овцы убраны. Смесь частей модели овцы из разных паков давала овец без лица. Fresh Animations Extensions/Details не включаются, пока есть Mizuno.
- Melody's Cute Girl Villagers и Iron Girl работают через Entity Model Features (мод в сборке).

## Настройки, которые ставит установщик

Один раз на версию набора из папки `config` рядом с `install.bat` копируются настройки из старой сборки и мои правки; заменённые файлы лежат в `config_backup_…_replaced`.
- **Distant Horizons**: стартовые предупреждения и ошибки убраны из чата (остаются в логе).
- **Alex's Caves**: отключены `biome_sky_overrides`, `biome_sky_fog_overrides`, `biome_ambient_light_coloring`, `radiation_glow_effect`, `sugar_rush_saturation_effect` — Distant Horizons просит их выключить.
- **MCA Reborn**: выключены стартовый экран «Кто ты?», история Destiny и редактор внешности игрока. Он менял форму тела, а скин не сохранялся, и получался «Стив другой формы».
- **Adaptive Performance Tweaks, Advancement Plaques, TrashSlot** — настройки из старой сборки.
- **Карта**: JourneyMap, полноэкранная карта на клавише **M** (установщик прописывает клавишу в `options.txt`, J освобождена), миникарта на экране.
- **options.txt**: если в нём нет строки `version`, установщик её добавляет: без неё Minecraft не понимает имена клавиш и сбрасывает все настройки (язык, ресурспаки).
- **FancyMenu**: панель редактора сверху экрана скрыта. **Load My F***ing Tags**: сообщение в чат отключено.

## Убрано и почему

Xaero's Minimap/World Map/XaeroPlus (у тебя карта не показывала ничего; вместо них JourneyMap), Simple Voice Chat (по просьбе: при входе в мир показывал окно настройки микрофона), Default Options (не нужен),

Visual Workbench (оставляет предметы в верстаке), Actually 3D Blocks & Items и Actually 3D Equipment (по просьбе; у Equipment модели палки, топоров и лопат собраны под новый формат, 1.20.1 их не грузит, и вместо предметов фиолетовая «шашечка»), Physics Mod (по просьбе), Accessories (ошибка миксина на Forge, нужен только Immersive Lanterns как необязательный),
Chunks Fade In (ломает Distant Horizons: рендерер не привязывается, в чате «ClientServer level loading failed»), Oh The Biomes We've Gone (цикл порядка фич с Climate Rivers: вылет при создании мира),
Subtle Effects (нужен Forge новее 47.4.10), Feature Recycler, Chunky, Distraction Free Recipes, ImmediatelyFast.

## Из старой сборки не добавлено

- Страшное: Goat Man, Stalker, Hydra, Weather2 (торнадо), Twilight Forest. Остались ранее выбранные Born in Chaos, Mutant Monsters, Deeper and Darker, Cataclysm.
- Нет под Forge 1.20.1 на Modrinth (только CurseForge или другая версия): FTB Quests/Library/Teams/Filter System, Framework, Backpacked, Goblin Traders, Farsight, Cupboard, Connectivity,
  Chunk Sending, Smooth Chunk, Fast Async World Save, Memory Settings, Recipe Essentials, Structure Essentials, Loot Integrations, Client Crafting, Biome Music, alltheleaks.
- Конфликтуют с тем, что в сборке: Falling Tree, BetterFoliage (Dynamic Trees и Better Leaves), Golem Overhaul (Iron Girl), Plasmo Voice (голосовой чат убран по просьбе), Your Grave Is Dead (Corpse),
  Sodium/Iris/Lithium (вместо них Embeddium, Oculus, Radium), Connector и Continuity.

## Обновление с прошлой версии

Скачай ветку заново и ещё раз запусти `forge-1.20.1\install.bat`. Если вылет, пришли `latest.log` или crash-report из `%appdata%\.minecraft`.
