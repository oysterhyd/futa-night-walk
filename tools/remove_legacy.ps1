param([switch]$Apply)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Use PowerShell 7.' }
$cleanupRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not (Test-Path -LiteralPath (Join-Path $cleanupRoot 'godot/project.godot'))) { throw 'Native project missing.' }
foreach ($name in @('LXGWWenKai-Medium-source.ttf','MaShanZheng-source.ttf')) {
    $nativeFont = Join-Path $cleanupRoot ('tools/_sources/'+$name)
    if (-not (Test-Path -LiteralPath $nativeFont)) { throw "Preserve native font source first: $name" }
    $oldFont = Join-Path $cleanupRoot ('tests/_scratch/'+$name)
    if ((Test-Path -LiteralPath $oldFont) -and (Get-FileHash -LiteralPath $nativeFont).Hash -ne (Get-FileHash -LiteralPath $oldFont).Hash) { throw "Font source mismatch: $name" }
}
$relativePaths = @(
    'game','assets','tests','build','__pycache__','main.py','requirements.txt',
    'tools/build_audio.py','tools/build_icon.py','tools/build_release.ps1','tools/bundle_fonts.py',
    'tools/export_godot_content.py','tools/playtest.py','tools/verify_game.py','tools/__pycache__',
    'docs/玩家手册.md','docs/验证记录.md',
    'dist/符塔夜行','dist/符塔夜行-夜渡','dist/nightroad-candidate','dist/符塔夜行.zip','dist/符塔夜行-夜渡-Windows.zip'
)
$targets = [Collections.Generic.List[string]]::new()
foreach ($relative in $relativePaths) {
    $absolute = [IO.Path]::GetFullPath((Join-Path $cleanupRoot $relative))
    if (Test-Path -LiteralPath $absolute) { $targets.Add($absolute) }
}
$selectedImages = @('title-print','arena-print','arena-fox-print','arena-temple-print','arena-tower-print',
    'keeper-print','swordswoman-print','alchemist-print','keeper-cast-print','swordswoman-cast-print',
    'alchemist-cast-print','enemy-print-v2','boss-print','environment-props-print')
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $cleanupRoot 'godot/assets/images') -File) {
    $base = $file.Name -replace '\.import$','' -replace '\.png$',''
    if ($base -notin $selectedImages) { $targets.Add($file.FullName) }
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $cleanupRoot 'godot/assets/fonts') -File) {
    if ($file.Name -like '*Noto*') { $targets.Add($file.FullName) }
}
foreach ($name in @('night.wav','battle.wav','ui.wav','pickup.wav')) {
    foreach ($suffix in @('','.import')) {
        $path = Join-Path $cleanupRoot ('godot/assets/audio/'+$name+$suffix)
        if (Test-Path -LiteralPath $path) { $targets.Add($path) }
    }
}
$importRoot = Join-Path $cleanupRoot 'godot/.godot/imported'
if (Test-Path -LiteralPath $importRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $importRoot -File) {
        if ($file.Name -match 'Noto|actions\.png|^characters\.png|^arena(-fox|-temple|-tower)?\.png|^title\.png|^enemy-print\.png|^environment-props\.png|^icon\.png|^(night|battle|ui|pickup)\.wav') {
            $targets.Add($file.FullName)
        }
    }
}
foreach ($target in $targets) {
    $absolute = [IO.Path]::GetFullPath($target)
    if (-not $absolute.StartsWith($cleanupRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw "Outside workspace: $target" }
    $item = Get-Item -LiteralPath $absolute -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing linked path: $target" }
}
if (-not $Apply) { $targets; Write-Output "Preview only: $($targets.Count) paths. Apply with -Apply."; exit 0 }
foreach ($target in $targets) { Remove-Item -LiteralPath $target -Recurse -Force }
Write-Output "Removed $($targets.Count) legacy paths. Native sources, v1.0.0 package and personal saves preserved."
