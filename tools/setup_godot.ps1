param([string]$Version = '4.7.2-stable')
$ErrorActionPreference = 'Stop'
$toolDir = Join-Path $env:LOCALAPPDATA ('FutaGameTools/Godot-' + $Version)
$exeName = 'Godot_v' + $Version + '_win64.exe'
$exePath = Join-Path $toolDir $exeName
if (-not (Test-Path -LiteralPath $exePath)) {
    New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
    $release = Invoke-RestMethod -Uri ('https://api.github.com/repos/godotengine/godot/releases/tags/' + $Version)
    $asset = $release.assets | Where-Object name -EQ ($exeName + '.zip') | Select-Object -First 1
    if (-not $asset) { throw 'Official Windows engine asset is missing.' }
    $archive = Join-Path $toolDir 'engine.zip'
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archive
    if ($asset.digest -and $asset.digest.StartsWith('sha256:')) {
        $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $asset.digest.Substring(7)) { throw 'Engine download SHA256 mismatch.' }
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $toolDir -Force
}
& $exePath --version
Write-Output $exePath
