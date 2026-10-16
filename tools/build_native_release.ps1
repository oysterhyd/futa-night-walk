param(
    [ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version = '3.1.0',
    [string]$EnginePath = "$env:LOCALAPPDATA/FutaGameTools/Godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe"
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Run this script with PowerShell 7.' }
if (-not (Test-Path -LiteralPath $EnginePath)) { throw "Godot missing: $EnginePath" }
$nativeRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = Join-Path $nativeRoot 'godot'
$distRoot = Join-Path $nativeRoot 'dist'
$packageRoot = Join-Path $distRoot "NightRoad-v$Version"
$null = New-Item -ItemType Directory -Path $packageRoot -Force
$projectFile = Join-Path $projectRoot 'project.godot'
$presetFile = Join-Path $projectRoot 'export_presets.cfg'
$projectText = [IO.File]::ReadAllText($projectFile)
$projectText = [regex]::Replace($projectText,'config/version="[^"]*"',"config/version=`"$Version`"")
[IO.File]::WriteAllText($projectFile,$projectText,[Text.UTF8Encoding]::new($false))
$presetText = [IO.File]::ReadAllText($presetFile)
foreach ($field in @('file_version','product_version')) {
    $presetText = [regex]::Replace($presetText,"application/$field=`"[^`"]*`"","application/$field=`"$Version.0`"")
}
[IO.File]::WriteAllText($presetFile,$presetText,[Text.UTF8Encoding]::new($false))
$importLog = Join-Path $nativeRoot 'godot/test-output/release-import.log'
& $EnginePath --headless --path $projectRoot --editor --import *> $importLog
if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText($importLog) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:') { throw "Godot import failed: $importLog" }
$exePath = Join-Path $packageRoot 'NightRoad.exe'
$exportLog = Join-Path $nativeRoot 'godot/test-output/release-export.log'
& $EnginePath --headless --path $projectRoot --export-release 'Windows Desktop' $exePath *> $exportLog
if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText($exportLog) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:') { throw "Godot export failed: $exportLog" }
if (-not (Test-Path -LiteralPath (Join-Path $packageRoot 'NightRoad.pck'))) { throw 'Export did not produce the game data package.' }
$legalRoot = Join-Path $packageRoot 'legal'
$null = New-Item -ItemType Directory -Path $legalRoot -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'legal/GODOT-LICENSE.txt'),(Join-Path $projectRoot 'legal/GODOT-THIRD-PARTY.txt'),(Join-Path $projectRoot 'assets/fonts/LXGWWenKai-OFL.txt'),(Join-Path $projectRoot 'assets/fonts/MaShanZheng-OFL.txt') -Destination $legalRoot
Copy-Item -LiteralPath (Join-Path $nativeRoot 'LICENSE') -Destination (Join-Path $legalRoot 'GAME-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $nativeRoot 'docs/CAMPAIGN_GUIDE.md') -Destination (Join-Path $packageRoot 'README.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/ART_RECORD.md') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/data/chapter_art_record.json') -Destination (Join-Path $packageRoot 'ART_PROMPTS.json')
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/data/campaign_art_record.json') -Destination (Join-Path $packageRoot 'CAMPAIGN_ART_PROMPTS.json')
$files = @()
foreach ($file in Get-ChildItem -LiteralPath $packageRoot -Recurse -File) {
    if ($file.Name -eq 'manifest.json') { continue }
    $files += [ordered]@{ path = [IO.Path]::GetRelativePath($packageRoot,$file.FullName).Replace('\','/'); bytes = $file.Length; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
}
$manifest = [ordered]@{ game = '燃灯夜行 · 夜渡'; content = '四章连续冒险 · 灯市旧巷 / 白狐渡 / 沉钟寺 / 无明塔'; ruleset = 'nightroad_campaign'; version = $Version; platform = 'Windows x86_64'; engine = (& $EnginePath --version | Out-String).Trim(); built_at_utc = [DateTime]::UtcNow.ToString('o'); files = $files }
[IO.File]::WriteAllText((Join-Path $packageRoot 'manifest.json'),($manifest | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$zipPath = Join-Path $distRoot "燃灯夜行-四章动作版-Windows-v$Version.zip"
Compress-Archive -LiteralPath $packageRoot -DestinationPath $zipPath -CompressionLevel Optimal -Force
Write-Output ([ordered]@{ folder = $packageRoot; zip = $zipPath; zip_sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant() } | ConvertTo-Json)
