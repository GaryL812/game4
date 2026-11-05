$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$deliveryPath=Join-Path $taskRoot 'deliverables'
New-Item -ItemType Directory -Force -Path $deliveryPath | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$sourceZip=Join-Path $deliveryPath 'SkylineRush-source.zip'
if(Test-Path -LiteralPath $sourceZip){Remove-Item -LiteralPath $sourceZip -Force}
$zip=[IO.Compression.ZipFile]::Open($sourceZip,[IO.Compression.ZipArchiveMode]::Create)
try {
  $include=@('scripts','scenes','assets','art','docs','tools','tests','licenses')
  foreach($folder in $include){
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $taskRoot $folder) -Recurse -File){
      if($file.Extension -eq '.blend1' -or $file.Extension -eq '.import'){continue}
      $relative=$file.FullName.Substring($taskRoot.Length+1).Replace('\','/')
      [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,$relative,[IO.Compression.CompressionLevel]::Optimal)|Out-Null
    }
  }
  foreach($name in @('project.godot','export_presets.cfg','README.md','THIRD_PARTY_NOTICES.md','运行游戏.cmd','.gitignore')){
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $taskRoot $name),$name,[IO.Compression.CompressionLevel]::Optimal)|Out-Null
  }
  foreach($name in @('performance_portrait.json','performance_landscape.json','package-portrait.json','package-landscape.json','tests.log','benchmark_portrait.log','benchmark_landscape.log')){
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $taskRoot ('build\'+$name)),('verification/'+$name),[IO.Compression.CompressionLevel]::Optimal)|Out-Null
  }
}finally{$zip.Dispose()}
foreach($orientation in @('portrait','landscape')){
  $destination=Join-Path $deliveryPath ('SkylineRush-wechat-'+$orientation+'.zip')
  if(Test-Path -LiteralPath $destination){Remove-Item -LiteralPath $destination -Force}
  [IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $taskRoot ('build\wechat-'+$orientation)),$destination,[IO.Compression.CompressionLevel]::Optimal,$false)
}
Get-ChildItem -LiteralPath $deliveryPath -Filter '*.zip' | Select-Object Name,Length
