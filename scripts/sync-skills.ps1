$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$skillsSrc = Join-Path $root "skills"
$skillsDst = Join-Path $env:USERPROFILE ".gemini\config\skills"

foreach ($s in @("windows-computer-use","pc","pc-flash","pc-pro")) {
    $srcFile = Join-Path $skillsSrc "$s\SKILL.md"
    $dstDir = Join-Path $skillsDst $s
    if (Test-Path $srcFile) {
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        Copy-Item $srcFile (Join-Path $dstDir "SKILL.md") -Force
        Write-Host "[OK] Synced skill: $s" -ForegroundColor Green
    }
}
