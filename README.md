# Better MC 5 (1.21.1 NeoForge) — моя доработанная сборка

Сборка **Better MC [NEOFORGE] BMC5** для Minecraft **1.21.1** на **NeoForge 21.1.176**, доработанная под TLauncher.

## Что изменено относительно оригинала

- **Dynamic Trees** + **Dynamic Trees Plus**: деревья растут и падают целиком, вместо Falling Tree.
- **Better Leaves**, Simple Grass Flowers, Fancy Crops, 3D-лестницы и рельсы, Fresh Animations и аддоны к ним, Just Expressions, Better Lanterns, Fresh Flower Pots, Low On Fire.
- Убраны Oh The Biomes We've Gone и Oh The Trees You'll Grow: гигантские хвойные и «безумные» биомы.
- Карта: **Xaero's Minimap**, **Xaero's World Map** и XaeroPlus.
- Шейдеры: **Complementary Unbound r5.5.1** + **Euphoria Patches 1.6.4**, настроены на высокий FPS. Клавиша **K** (переключение шейдеров) отключена.
- Добавлены моды, которых нет на Modrinth (Twilight Forest, Deeper Darker, Deep Aether, Supplementaries, FTB Quests и др.).
- Русский язык, рендер 12 чанков, без ограничения FPS (260).

## Установка на новом компьютере

1. Установи TLauncher и один раз запусти любую версию, чтобы появилась папка `%appdata%\.minecraft`.
2. Скачай репозиторий: **Code → Download ZIP** и распакуй, или сделай `git clone`.
3. Запусти **`install.bat`** двойным кликом. Он:
   - найдёт Java (из TLauncher или Minecraft);
   - поставит NeoForge 21.1.176;
   - переименует старую папку `mods` в `mods_backup_…`;
   - скопирует всё из папки `minecraft/` в `%appdata%\.minecraft`.
4. В TLauncher нажми кнопку обновления списка версий и выбери **neoforge-21.1.176**.
5. В настройках TLauncher поставь память **около 9000 МБ** (не больше 10000, иначе будут лаги).
6. Запускай и создавай **новый мир**.

### Вручную, без install.bat
- Установи NeoForge: `java -jar neoforge-21.1.176-installer.jar --install-client "%appdata%\.minecraft"` (или через установщик с интерфейсом → *Install client*).
- Скопируй содержимое папки `minecraft/` в `%appdata%\.minecraft` с заменой.

## Что в репозитории

| Путь | Что это |
|---|---|
| `minecraft/mods` | все 285 модов |
| `minecraft/config`, `defaultconfigs`, `configureddefaults` | настройки модов |
| `minecraft/resourcepacks` | ресурспаки |
| `minecraft/shaderpacks` | Complementary + настройки Euphoria |
| `minecraft/options.txt` | настройки игры: графика, клавиши, язык |
| `neoforge-21.1.176-installer.jar` | установщик NeoForge |
| `install.bat` | автоустановка |

## Если что-то не так

- **Тормозит.** Проверь память в TLauncher (~9000 МБ). Если всё равно тормозит, выключи шейдеры: Настройки → Видео → Пакеты шейдеров.
- **Экран «Modrinth does not have some certain mods».** Значит, не скопировались моды с CurseForge: проверь, что папка `minecraft/mods` скопирована целиком.

> Репозиторий приватный: часть модов запрещено распространять публично, поэтому не делай его открытым.
