@echo off
chcp 65001 >nul
set "GODOT_EXE=E:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_EXE%" (
  echo 请使用 Godot 4.7.2 打开此目录的 project.godot，或修改本文件的 GODOT_EXE 路径。
  pause
  exit /b 1
)
if not exist "%~dp0.godot\global_script_class_cache.cfg" (
  "%GODOT_EXE%" --headless --editor --path "%~dp0." --import
  if errorlevel 1 goto failed
)
"%GODOT_EXE%" --path "%~dp0." %*
if not "%errorlevel%"=="0" goto failed
exit /b 0

:failed
set "LAUNCH_CODE=%errorlevel%"
echo Godot exited with code %LAUNCH_CODE%. See the error above.
pause
exit /b %LAUNCH_CODE%
