param([string]$Python = 'E:\blender\5.2\python\bin\python.exe')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$cachePath=Join-Path $taskRoot '.tools'
New-Item -ItemType Directory -Force -Path $cachePath | Out-Null
& $Python -m pip install 'fonttools==4.68.0' 'lameenc==1.9.0' --target (Join-Path $cachePath 'pylibs') --quiet
if ($LASTEXITCODE -ne 0) { throw 'Art tool dependencies unavailable' }
$inkFontPath=Join-Path $cachePath 'NotoSerifSC.ttf'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf' -OutFile $inkFontPath
if ((Get-FileHash -LiteralPath $inkFontPath -Algorithm SHA256).Hash -ne '050080D9255A86808F2945BFFAC582B31EF32BC36411CE29563B4961670C66F9') { throw 'Ink font source changed; review before rebuilding.' }
& $Python (Join-Path $PSScriptRoot 'subset_ink_font.py')
& $Python (Join-Path $PSScriptRoot 'create_audio.py')
