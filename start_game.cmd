@echo off
setlocal
if not exist "%~dp0build\EmberSanctuary.exe" (
  echo Game executable not found. Open project.godot with Godot 4.5.1.
  pause
  exit /b 1
)
if not exist "%~dp0build\EmberSanctuary.pck" (
  echo Game data not found. Keep EmberSanctuary.pck beside the executable.
  pause
  exit /b 1
)
start "" /D "%~dp0build" "%~dp0build\EmberSanctuary.exe"
