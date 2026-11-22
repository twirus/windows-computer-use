$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$root = Split-Path -Parent $PSScriptRoot
$distDir = Join-Path $root "dist"
$stageDir = Join-Path $root "_tmp_release"
$zipPath = Join-Path $distDir "windows-computer-use-antigravity.zip"

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$stageDir\mcp","$stageDir\skill\pc","$stageDir\skill\pc-flash","$stageDir\skill\pc-pro" | Out-Null

$pkg = Get-Content (Join-Path $root "package.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$version = if ($pkg.version) { [string]$pkg.version } else { "3.1.1" }

# Copy MCP runtime files
Copy-Item (Join-Path $root "src\server.js") "$stageDir\mcp\" -Force
Copy-Item (Join-Path $root "src\desktop_worker.ps1") "$stageDir\mcp\" -Force
Copy-Item (Join-Path $root "src\overlay.ps1") "$stageDir\mcp\" -Force
("{`"name`":`"windows-desktop-mcp`",`"version`":`"$version`",`"type`":`"module`",`"main`":`"server.js`"}") | Set-Content -Path "$stageDir\mcp\package.json" -Encoding UTF8

# Copy skills
Copy-Item (Join-Path $root "skills\windows-computer-use\SKILL.md") "$stageDir\skill\SKILL.md" -Force
foreach ($s in @("pc","pc-flash","pc-pro")) {
    Copy-Item (Join-Path $root "skills\$s\SKILL.md") "$stageDir\skill\$s\SKILL.md" -Force
}

# Copy installer & README
Copy-Item (Join-Path $root "installer\*") "$stageDir\" -Force
Copy-Item (Join-Path $root "README.md") "$stageDir\README.md" -Force

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$stageDir\*" -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item $stageDir -Recurse -Force

$item = Get-Item $zipPath
Write-Host "[OK] Built release archive: $($item.FullName) ($($item.Length) bytes)" -ForegroundColor Green
