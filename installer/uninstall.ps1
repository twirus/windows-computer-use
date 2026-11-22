$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$agyRoot = Join-Path $env:USERPROFILE ".gemini\antigravity"
$mcpInstallDir = Join-Path $agyRoot "windows-desktop-mcp"
$skillInstallDir = Join-Path $env:USERPROFILE ".gemini\config\skills\windows-computer-use"
$mcpConfigPath = Join-Path $agyRoot "mcp_config.json"

if (Test-Path $mcpInstallDir) {
    Remove-Item $mcpInstallDir -Recurse -Force
    Write-Host "[OK] Removed $mcpInstallDir" -ForegroundColor Green
}
if (Test-Path $skillInstallDir) {
    Remove-Item $skillInstallDir -Recurse -Force
    foreach ($s in @("pc","pc-flash","pc-pro")) { $d = Join-Path $env:USERPROFILE ".gemini\config\skills\$s"; if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
    Write-Host "[OK] Removed $skillInstallDir" -ForegroundColor Green
}
if (Test-Path $mcpConfigPath) {
    try {
        $configObj = (Get-Content $mcpConfigPath -Raw -Encoding UTF8) | ConvertFrom-Json
        if ($configObj.mcpServers -and ($configObj.mcpServers.PSObject.Properties.Name -contains "windows-desktop")) {
            $configObj.mcpServers.PSObject.Properties.Remove("windows-desktop")
            $jsonOut = $configObj | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($mcpConfigPath, $jsonOut, [System.Text.UTF8Encoding]::new($false))
            Write-Host "[OK] Removed 'windows-desktop' from mcp_config.json" -ForegroundColor Green
        }
    } catch { }
}
Write-Host "Uninstall complete. Restart Antigravity." -ForegroundColor Cyan
