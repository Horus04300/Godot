@echo off
setlocal
if not exist "%~dp0runtime\Godot_v4.5.1-stable_win64.exe" (
  echo Bundled Godot executable not found. Open project.godot with Godot 4.5.1.
  pause
  exit /b 1
)
start "" "%~dp0runtime\Godot_v4.5.1-stable_win64.exe" --editor --path "%~dp0."
