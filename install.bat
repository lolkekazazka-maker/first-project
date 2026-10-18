@echo off
chcp 65001 >nul
setlocal
set "MC=%APPDATA%\.minecraft"
set "SRC=%~dp0minecraft"
cd /d "%~dp0"

if not exist "%MC%" (
  echo Папка %MC% не найдена. Сначала запусти TLauncher и любую версию игры один раз.
  pause & exit /b 1
)

echo [1/4] Ищу Java...
set "JAVA="
for %%R in (java-runtime-delta java-runtime-epsilon java-runtime-gamma) do (
  if not defined JAVA if exist "%MC%\runtime\%%R\windows\%%R\bin\java.exe" set "JAVA=%MC%\runtime\%%R\windows\%%R\bin\java.exe"
)
if not defined JAVA for /d %%J in ("%APPDATA%\.tlauncher\starter\jre_default\*") do (
  if not defined JAVA if exist "%%J\bin\java.exe" set "JAVA=%%J\bin\java.exe"
)
if not defined JAVA set "JAVA=java"
echo     Java: %JAVA%

echo [2/4] Ставлю NeoForge 21.1.176 (Minecraft 1.21.1)...
if not exist "%MC%\launcher_profiles.json" echo {"profiles":{}}> "%MC%\launcher_profiles.json"
"%JAVA%" -jar "neoforge-21.1.176-installer.jar" --install-client "%MC%" > install_log.txt 2>&1
if errorlevel 1 (
  echo Ошибка установки NeoForge, подробности в install_log.txt
  pause & exit /b 1
)

echo [3/4] Убираю старые моды в бэкап...
if exist "%MC%\mods" (
  ren "%MC%\mods" "mods_backup_%RANDOM%"
)

echo [4/4] Копирую моды, конфиги, ресурспаки и шейдеры...
robocopy "%SRC%" "%MC%" /E /NFL /NDL /NJH /NJS /NP >nul
if %errorlevel% GEQ 8 (
  echo Ошибка копирования
  pause & exit /b 1
)

echo.
echo Готово! В TLauncher выбери версию neoforge-21.1.176 (или "NeoForge 1.21.1"),
echo в настройках поставь память около 9000 МБ и запускай. Мир создавай новый.
pause
