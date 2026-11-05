$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$cachePath=Join-Path $taskRoot '.tools'
New-Item -ItemType Directory -Force -Path $cachePath | Out-Null
$zipPath=Join-Path $cachePath 'minigame47.zip'
Invoke-WebRequest -Uri 'https://github.com/godothub/godot-minigame/releases/download/4.7/minigame4.7.0.8.tpz' -OutFile $zipPath
$expected = '6E9938EC4F8DE0CD9B693A1D851A6B361A7397D6F3EE6A6DE4909B053BAC8A23'
if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash -ne $expected) { throw 'Template SHA256 differs from verified artifact' }
Expand-Archive -LiteralPath $zipPath -DestinationPath (Join-Path $cachePath 'template47') -Force
Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
