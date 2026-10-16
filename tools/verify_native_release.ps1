param([string]$Version = '3.1.0')
$ErrorActionPreference = 'Stop'
$releaseRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$packageRoot = Join-Path $releaseRoot "dist/NightRoad-v$Version"
$reportRoot = Join-Path $releaseRoot 'godot/test-output'
$isolatedRoot = Join-Path $env:TEMP ('NightRoad-release-smoke-'+[guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $isolatedRoot
Copy-Item -LiteralPath (Join-Path $packageRoot 'NightRoad.exe'),(Join-Path $packageRoot 'NightRoad.pck') -Destination $isolatedRoot
$results = @()
foreach ($kind in @('menu','arena')) {
    $shot = Join-Path $reportRoot "release-$kind.png"
    $stdout = Join-Path $reportRoot "release-$kind.stdout.txt"
    $stderr = Join-Path $reportRoot "release-$kind.stderr.txt"
    $arguments = @('--',('"--screenshot='+$shot+'"'))
    if ($kind -eq 'arena') { $arguments += '--arena-preview' }
    $process = Start-Process -FilePath (Join-Path $isolatedRoot 'NightRoad.exe') -WorkingDirectory $isolatedRoot -ArgumentList $arguments -Environment @{PATH="$env:SystemRoot/System32;$env:SystemRoot"} -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(25000)) { Stop-Process -Id $process.Id; throw "Standalone $kind timed out" }
    $process.Refresh()
    $errors = [IO.File]::ReadAllText($stderr)
    if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|SHADER ERROR|ERROR:' -or -not (Test-Path -LiteralPath $shot)) { throw "Standalone $kind failed: $errors" }
    $results += @{ screen=$kind; exit_code=$process.ExitCode; stderr=$errors; image=$shot }
}
$manifest = Get-Content -LiteralPath (Join-Path $packageRoot 'manifest.json') -Raw | ConvertFrom-Json
foreach ($entry in $manifest.files) {
    $file = Join-Path $packageRoot $entry.path
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) { throw "Manifest mismatch: $($entry.path)" }
}
$zipPath = Join-Path $releaseRoot "dist/燃灯夜行-四章动作版-Windows-v$Version.zip"
$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    foreach ($entry in $manifest.files) {
        $zipEntry = $archive.GetEntry("NightRoad-v$Version/"+$entry.path)
        if ($null -eq $zipEntry -or $zipEntry.Length -ne $entry.bytes) { throw "Archive mismatch: $($entry.path)" }
        $stream = $zipEntry.Open()
        try { $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant() }
        finally { $stream.Dispose() }
        if ($hash -ne $entry.sha256) { throw "Archive checksum mismatch: $($entry.path)" }
    }
} finally { $archive.Dispose() }
$report = @{ passed=$true; isolated_directory=$isolatedRoot; directory_files=@(Get-ChildItem -LiteralPath $isolatedRoot -File | Select-Object -ExpandProperty Name); restricted_path=$true; file_version=(Get-Item -LiteralPath (Join-Path $packageRoot 'NightRoad.exe')).VersionInfo.FileVersion; manifest_verified=$true; archive_verified=$true; zip_sha256=(Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant(); results=$results }
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $reportRoot 'release-smoke.json') -Encoding utf8
$report | ConvertTo-Json -Depth 6
