@echo off
chcp 65001 >nul
setlocal
set "MC=%APPDATA%\.minecraft"
cd /d "%~dp0"

if not exist "%MC%" (
  echo Папка %MC% не найдена. Сначала запусти TLauncher и любую версию игры один раз.
  pause & exit /b 1
)

echo [1/3] Ищу Java...
set "JAVA="
for %%R in (java-runtime-gamma java-runtime-beta java-runtime-delta java-runtime-epsilon) do (
  if not defined JAVA if exist "%MC%\runtime\%%R\windows\%%R\bin\java.exe" set "JAVA=%MC%\runtime\%%R\windows\%%R\bin\java.exe"
)
if not defined JAVA for /d %%J in ("%APPDATA%\.tlauncher\starter\jre_default\*") do (
  if not defined JAVA if exist "%%J\bin\java.exe" set "JAVA=%%J\bin\java.exe"
)
if not defined JAVA set "JAVA=java"
echo     Java: %JAVA%

echo [2/3] Ставлю Forge 1.20.1-47.4.10...
if not exist "%MC%\launcher_profiles.json" echo {"profiles":{}}> "%MC%\launcher_profiles.json"
"%JAVA%" -jar "forge-1.20.1-47.4.10-installer.jar" --installClient "%MC%" > install_log.txt 2>&1
if errorlevel 1 (
  echo Ошибка установки Forge, подробности в install_log.txt
  pause & exit /b 1
)

echo [3/3] Скачиваю моды, ресурспаки и шейдеры (около 600 МБ, нужен интернет)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Mc "%MC%"
if errorlevel 1 (
  echo Ошибка при скачивании модов. Запусти install.bat ещё раз: уже скачанное повторно не качается.
  pause & exit /b 1
)

echo.
echo Готово! В TLauncher обнови список версий и выбери "1.20.1-forge-47.4.10" (Forge 1.20.1),
echo в настройках поставь память около 9000 МБ и запускай. Мир создавай новый.
pause
