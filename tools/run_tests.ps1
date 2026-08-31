# Runs every headless check in the project and fails the run on anything the
# engine complains about -- a green counter is not the same thing as a clean
# run, because a script that fails to parse still lets the suite "finish".

param(
    [string]$Godot = "D:\Drive\programs\godot\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = "Continue"
$project = Split-Path -Parent $PSScriptRoot
$suites = @("rules_check", "audio_check", "smoke", "santa")
$bad = @("SCRIPT ERROR", "USER ERROR", "Parse Error", "Compile Error",
         "Failed to load", "Invalid access", "Invalid call", "Nonexistent")
$failed = $false

foreach ($s in $suites) {
    Write-Host ""
    Write-Host "=== $s ===" -ForegroundColor Cyan
    $out = & $Godot --headless --path $project --script "res://tools/$s.gd" 2>&1 | Out-String
    Write-Host $out.Trim()
    $code = $LASTEXITCODE
    foreach ($pattern in $bad) {
        if ($out -match [regex]::Escape($pattern)) {
            Write-Host "  engine reported: $pattern" -ForegroundColor Red
            $failed = $true
        }
    }
    if ($out -notmatch "failure\(s\)") {
        Write-Host "  the suite never reached its last line" -ForegroundColor Red
        $failed = $true
    }
    if ($code -ne 0) {
        Write-Host "  exit code $code" -ForegroundColor Red
        $failed = $true
    }
}

Write-Host ""
if ($failed) {
    Write-Host "CHECKS FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "all checks passed" -ForegroundColor Green
exit 0
