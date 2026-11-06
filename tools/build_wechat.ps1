param(
    [string]$Godot = 'E:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe',
    [string]$Template = '',
    [string]$AppId = 'touristappid',
    [string]$RewardAdUnitId = '',
    [ValidateSet('portrait','landscape')][string]$Orientation = 'portrait'
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
if (!$Template) { $Template = Join-Path $taskRoot '.tools\template47' }
$destination = Join-Path $taskRoot ('build\wechat-' + $Orientation)
if (!(Test-Path -LiteralPath (Join-Path $Template 'engine\godot.wasm.br'))) { throw 'Template not found. Run tools/fetch_wechat_template.ps1 first.' }
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Copy-Item -Path (Join-Path $Template '*') -Destination $destination -Recurse -Force
# Remove the template demo packages and its AppID, keeping only engine/runtime files.
$oldSubpack = Join-Path $destination 'subpackages'
$oldManifest = Join-Path $destination 'subpacks'
foreach ($targetPath in @($oldSubpack,$oldManifest)) {
    $resolved = [IO.Path]::GetFullPath($targetPath)
    if (!$resolved.StartsWith([IO.Path]::GetFullPath($destination) + [IO.Path]::DirectorySeparatorChar)) { throw 'Path outside output directory' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
& $Godot --headless --path $taskRoot --export-pack 'Web Resources' (Join-Path $destination 'engine\skyline.pck')
if ($LASTEXITCODE -ne 0) { throw 'Godot resource export failed' }
Move-Item -LiteralPath (Join-Path $destination 'engine\skyline.pck') -Destination (Join-Path $destination 'engine\empty-tips.bin') -Force
Copy-Item -Path (Join-Path $PSScriptRoot 'wechat\*') -Destination $destination -Recurse -Force
Copy-Item -LiteralPath (Join-Path $taskRoot 'licenses') -Destination $destination -Recurse -Force
$bridgeConfig = @{ appId=$AppId;rewardAdUnitId=$RewardAdUnitId;title='云端飞奔 · SKYLINE RUSH'} | ConvertTo-Json -Compress
Set-Content -LiteralPath (Join-Path $destination 'skyline-config.js') -Value ('module.exports = ' + $bridgeConfig + ';') -Encoding utf8
$entry = Join-Path $destination 'game.js'
$entryText = Get-Content -LiteralPath $entry -Raw
$entryText = $entryText.Replace("import './glx-config'", "import './glx-config'`nimport './skyline-platform'")
$entryText = $entryText.Replace('首次加载请耐心等待','正在展开山海画卷').Replace('#4CAF50','#aa4939').Replace('#ffffff','#293d34').Replace("backgroundImage: 'images/background.jpg'", "backgroundImage: ''").Replace('visible: true','visible: false')
Set-Content -LiteralPath $entry -Value $entryText -Encoding utf8
$loaderPath=Join-Path $destination 'godot-loader.js'
$loaderText=Get-Content -LiteralPath $loaderPath -Raw
$loaderText=$loaderText.Replace('ctx.clearRect(0, 0, width, height);', "ctx.fillStyle = '#f2ead4'; ctx.fillRect(0, 0, width, height);")
Set-Content -LiteralPath $loaderPath -Value $loaderText -Encoding utf8
# Prefer standard WebGL2 for predictable cross-device behavior; GLX can be enabled after QA.
Set-Content -LiteralPath (Join-Path $destination 'glx-config.js') -Value 'GameGlobal.__GODOT_DISABLE_WXGLX = true;' -Encoding utf8
$gameConfig = @{deviceOrientation=$Orientation;openDataContext='open-data';'iOSHighPerformance'= $true;'iOSHighPerformance+'=$true;subpackages=@(@{name='engine';root='engine/'})}
$gameConfig | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $destination 'game.json') -Encoding utf8
$projectPath=Join-Path $destination 'project.config.json'
$projectConfig = Get-Content -LiteralPath $projectPath -Raw | ConvertFrom-Json
$projectConfig.appid=$AppId
$projectConfig.isGameTourist=($AppId -eq 'touristappid')
$projectConfig.description='云端飞奔 / Godot + Blender / 首关测试版'
$projectConfig | Add-Member -NotePropertyName projectname -NotePropertyValue 'SkylineRush' -Force
$projectConfig | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $projectPath -Encoding utf8
$privatePath=Join-Path $destination 'project.private.config.json'
if (Test-Path -LiteralPath $privatePath) { Remove-Item -LiteralPath $privatePath -Force }
$mainBytes=0L; $totalBytes=0L
foreach ($file in Get-ChildItem -LiteralPath $destination -Recurse -File) {
    $relative = $file.FullName.Substring($destination.Length + 1).Replace('\','/')
    $totalBytes += $file.Length
    if (!$relative.StartsWith('engine/')) { $mainBytes += $file.Length }
}
if ($mainBytes -gt 4MB) { throw ('Main package exceeds 4MB: '+$mainBytes) }
$report=@{main_bytes=$mainBytes;engine_subpackage_bytes=$totalBytes-$mainBytes;total_bytes=$totalBytes;main_limit_bytes=4MB;app_id=$AppId;device_orientation=$Orientation;devtools_verified=$false;real_device_verified=$false}
$report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRoot ('build\package-' + $Orientation + '.json')) -Encoding utf8
Write-Output ('WECHAT_PACKAGE_OK ' + ($report | ConvertTo-Json -Compress))
