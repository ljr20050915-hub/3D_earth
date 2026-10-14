@echo off
cd /d "%~dp0"
set "GODOT_EXE=%~dp0..\Godot_v4.6.3-stable_win64.exe"
set "APPDATA=%~dp0.runtime"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%GODOT_EXE%" (
  echo Godot executable not found. Open project.godot with Godot 4.6.
  pause
  exit /b 1
)
if not exist "%~dp0.godot\imported" start "Import Earth" /wait "%GODOT_EXE%" --headless --editor --path "%~dp0." --import --log-file "%~dp0.runtime\import.log"
start "Earth" "%GODOT_EXE%" --path "%~dp0." --log-file "%~dp0.runtime\run.log"
