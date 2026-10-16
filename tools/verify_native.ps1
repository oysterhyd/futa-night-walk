param([string]$EnginePath = "$env:LOCALAPPDATA/FutaGameTools/Godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe")
$ErrorActionPreference = 'Stop'
$verifyRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = Join-Path $verifyRoot 'godot'
$reportRoot = Join-Path $projectRoot 'test-output'
$null = New-Item -ItemType Directory -Path $reportRoot -Force
& $EnginePath --headless --path $projectRoot --editor --import *> (Join-Path $reportRoot 'verify-import.log')
if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText((Join-Path $reportRoot 'verify-import.log')) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:') { throw 'Godot resource import failed.' }
$results = @()
$cases = @(
    @{ name='world'; scene='chapter_tests'; graphical=$false; timeout=30; report='chapter-tests.json' },
    @{ name='campaign'; scene='chapter_playtest'; graphical=$false; timeout=180; report='chapter-playtest.json' },
    @{ name='modes'; scene='chapter_modes'; graphical=$false; timeout=30; report='chapter-modes.json' },
    @{ name='campaign_rules'; scene='campaign_tests'; graphical=$false; timeout=30; report='campaign-tests.json' },
    @{ name='campaign_content'; scene='campaign_content_tests'; graphical=$false; timeout=30; report='campaign-content-tests.json' },
    @{ name='full_journey'; scene='campaign_playtest'; graphical=$false; timeout=240; report='campaign-playtest.json' },
    @{ name='input'; scene='chapter_flow'; graphical=$true; timeout=60; report='chapter-flow.json' },
    @{ name='animation'; scene='chapter_animation'; graphical=$true; timeout=40; report='chapter-animation.json' },
    @{ name='visual'; scene='chapter_visual'; graphical=$true; timeout=60; report='chapter-visual.json' },
    @{ name='combat_quality'; scene='campaign_quality'; graphical=$true; timeout=90; report='campaign-quality.json' },
    @{ name='performance'; scene='performance_audit'; graphical=$true; timeout=60; report='performance.json' }
)
foreach ($case in $cases) {
    $stdout = Join-Path $reportRoot ($case.name+'.verify.stdout.txt')
    $stderr = Join-Path $reportRoot ($case.name+'.verify.stderr.txt')
    $arguments = @('--path',('"'+$projectRoot+'"'),('res://tests/'+$case.scene+'.tscn'))
    if (-not $case.graphical) { $arguments = @('--headless')+$arguments }
    $process = Start-Process -FilePath $EnginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $finished = $process.WaitForExit($case.timeout*1000)
    if (-not $finished) { Stop-Process -Id $process.Id; throw "Timed out: $($case.name)" }
    $process.Refresh()
    $errors = [IO.File]::ReadAllText($stderr)
    $passed = $process.ExitCode -eq 0 -and $errors -notmatch 'SCRIPT ERROR|SHADER ERROR|ERROR:'
    $reportPath = Join-Path $reportRoot $case.report
    if (-not (Test-Path -LiteralPath $reportPath)) { $passed=$false }
    if ($passed -and $case.name -eq 'campaign') {
        $runs = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $passed = $runs.Count -eq 6 -and ($runs | Where-Object { -not $_.victory -or $_.room -ne 6 -or $_.shrines -ne 1 -or $_.rooms_visited -lt 10 }).Count -eq 0
    }
    if ($passed -and $case.name -eq 'performance') {
        $performance = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $passed = $performance.target_60fps_passed -and $performance.average_mobs -ge 170 -and $performance.average_projectiles -ge 400
    }
    if ($passed -and $case.name -eq 'full_journey') {
        $journey = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $passed = $journey.passed -and $journey.runs.Count -eq 6 -and ($journey.runs | Where-Object { -not $_.victory -or $_.stage -ne 4 -or $_.bosses -ne 4 -or $_.shrines -ne 4 -or $_.rooms_visited -lt 48 }).Count -eq 0
    }
    $results += [ordered]@{ name=$case.name; passed=$passed; exit_code=$process.ExitCode; report=$case.report }
    Write-Output ("{0}: {1}" -f $case.name,$passed)
    if (-not $passed) { Get-Content -LiteralPath $stderr; throw "Verification failed: $($case.name)" }
}
$summary = [ordered]@{ ruleset='nightroad_campaign'; passed=$true; verified_at_utc=[DateTime]::UtcNow.ToString('o'); engine=(& $EnginePath --version | Out-String).Trim(); results=$results; controller_scope='Keyboard, mouse, and native simulated joypad button/axis events, including RT/LT/right stick; no physical controller claim.' }
[IO.File]::WriteAllText((Join-Path $reportRoot 'verification.json'),($summary | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
