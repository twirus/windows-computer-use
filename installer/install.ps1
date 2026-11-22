$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "===============================================" -ForegroundColor DarkYellow
Write-Host "  Windows Computer Use v3.3.0 for Antigravity" -ForegroundColor White
Write-Host "===============================================" -ForegroundColor DarkYellow
Write-Host ""

# 1. Check Node.js
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Host "[ERROR] Node.js is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Node.js LTS from https://nodejs.org/ and run install.bat again." -ForegroundColor Yellow
    exit 1
}
$nodeVer = & node --version
Write-Host "[OK] Node.js found: $nodeVer" -ForegroundColor Green

# 2. Target paths
$agyRoot = Join-Path $env:USERPROFILE ".gemini\antigravity"
$geminiConfigRoot = Join-Path $env:USERPROFILE ".gemini\config"
$mcpInstallDir = Join-Path $agyRoot "windows-desktop-mcp"
$skillInstallDir = Join-Path $geminiConfigRoot "skills\windows-computer-use"
$mcpConfigPaths = @(
    (Join-Path $geminiConfigRoot "mcp_config.json"),
    (Join-Path $agyRoot "mcp_config.json")
)

New-Item -ItemType Directory -Force -Path $mcpInstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $geminiConfigRoot | Out-Null
New-Item -ItemType Directory -Force -Path $skillInstallDir | Out-Null

# 3. Copy MCP server files
$srcMcp = Join-Path $PSScriptRoot "mcp"
Copy-Item (Join-Path $srcMcp "server.js") $mcpInstallDir -Force
Copy-Item (Join-Path $srcMcp "desktop_worker.ps1") $mcpInstallDir -Force
Copy-Item (Join-Path $srcMcp "overlay.ps1") $mcpInstallDir -Force
Copy-Item (Join-Path $srcMcp "package.json") $mcpInstallDir -Force
Write-Host "[OK] MCP server files copied to: $mcpInstallDir" -ForegroundColor Green

# 4. Copy Antigravity Skill
$srcSkill = Join-Path $PSScriptRoot "skill\SKILL.md"
Copy-Item $srcSkill (Join-Path $skillInstallDir "SKILL.md") -Force
foreach ($s in @("pc","pc-flash","pc-pro")) {
    $d = Join-Path $env:USERPROFILE ".gemini\config\skills\$s"
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Copy-Item (Join-Path $PSScriptRoot "skill\$s\SKILL.md") (Join-Path $d "SKILL.md") -Force
}
Write-Host "[OK] Skill copied to: $skillInstallDir" -ForegroundColor Green

# 5. Update mcp_config.json safely (both ~/.gemini/config/mcp_config.json and legacy ~/.gemini/antigravity/mcp_config.json)
$serverJsPath = (Join-Path $mcpInstallDir "server.js") -replace '\\', '/'
$entry = [PSCustomObject]@{
    command = "node"
    args    = @($serverJsPath)
}

foreach ($mcpConfigPath in $mcpConfigPaths) {
    $configObj = $null
    if (Test-Path $mcpConfigPath) {
        try {
            $raw = Get-Content $mcpConfigPath -Raw -Encoding UTF8
            if ($raw -and $raw.Trim().Length -gt 0) {
                $configObj = $raw | ConvertFrom-Json
            }
        } catch {
            Write-Host "[WARN] Existing $mcpConfigPath could not be parsed, creating backup..." -ForegroundColor Yellow
            Copy-Item $mcpConfigPath "$mcpConfigPath.bak" -Force
            $configObj = $null
        }
    }

    if ($null -eq $configObj) {
        $configObj = [PSCustomObject]@{ mcpServers = [PSCustomObject]@{} }
    }
    if (-not ($configObj.PSObject.Properties.Name -contains "mcpServers") -or $null -eq $configObj.mcpServers) {
        $configObj | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }

    if ($configObj.mcpServers.PSObject.Properties.Name -contains "windows-desktop") {
        $configObj.mcpServers."windows-desktop" = $entry
    } else {
        $configObj.mcpServers | Add-Member -NotePropertyName "windows-desktop" -NotePropertyValue $entry -Force
    }

    $jsonOut = $configObj | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($mcpConfigPath, $jsonOut, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[OK] Updated $mcpConfigPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart Antigravity." -ForegroundColor White
Write-Host "  2. On first use, choose 'Always allow' (option 3) for windows-desktop tools." -ForegroundColor White
Write-Host "  3. Press Ctrl+Alt+X at any time to immediately stop AI control." -ForegroundColor White
Write-Host ""
