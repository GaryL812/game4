@echo off
setlocal
set "GODOT_EXE=E:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
set "SAMPLE=res://samples/ink_study/ink_study.tscn"

if not exist "%GODOT_EXE%" (
  echo Godot was not found at "%GODOT_EXE%".
  pause
  exit /b 1
)

pushd "%~dp0"
if errorlevel 1 (
  echo Could not open the project folder "%~dp0".
  pause
  exit /b 1
)

if not exist "project.godot" (
  echo project.godot is missing from the project folder.
  goto missing_file
)
if not exist "samples\ink_study\ink_study.tscn" (
  echo The ink study scene is missing from samples\ink_study.
  goto missing_file
)

if not exist ".godot\global_script_class_cache.cfg" (
  "%GODOT_EXE%" --headless --editor --path . --import
  if errorlevel 1 goto failed
)

"%GODOT_EXE%" --path . --resolution 1280x800 "%SAMPLE%" %*
if errorlevel 1 goto failed
popd
exit /b 0

:failed
set "LAUNCH_CODE=%errorlevel%"
echo.
echo Godot exited with code %LAUNCH_CODE%. See the error above.
pause
popd
exit /b %LAUNCH_CODE%

:missing_file
pause
popd
exit /b 1
