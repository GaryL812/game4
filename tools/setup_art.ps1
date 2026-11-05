param([string]$Python = 'E:\blender\5.2\python\bin\python.exe')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$cachePath=Join-Path $taskRoot '.tools'
New-Item -ItemType Directory -Force -Path $cachePath | Out-Null
$fontPath=Join-Path $cachePath 'NotoSansSC.ttf'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf' -OutFile $fontPath
$expected='A3041811A78C361B1DE50F953C805E0244951C21C5BD412F7232EF0D899AF0DA'
if ((Get-FileHash -LiteralPath $fontPath -Algorithm SHA256).Hash -ne $expected) { throw 'Font source changed; review before rebuilding the subset.' }
& $Python -m pip install 'fonttools==4.68.0' 'lameenc==1.9.0' --target (Join-Path $cachePath 'pylibs') --quiet
if ($LASTEXITCODE -ne 0) { throw 'Art tool dependencies unavailable' }
& $Python (Join-Path $PSScriptRoot 'subset_font.py')
& $Python (Join-Path $PSScriptRoot 'create_audio.py')
