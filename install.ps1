# AutoCAD MCP Deployment Script
# Compiles the C# project and installs it to the user's AutoCAD ApplicationPlugins folder

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Join-Path $SCRIPT_DIR "AutoCAD-MCP-Addin"
$TARGET_DIR = "$env:APPDATA\Autodesk\ApplicationPlugins\AutoCADMCP.bundle"

Write-Host "Build and Deploy AutoCAD MCP..." -ForegroundColor Cyan

# 1. Build C# Project (net48 and net8.0-windows)
Write-Host "Building C# Project (Multi-Targeting net48 & net8.0-windows)..." -ForegroundColor Yellow
dotnet build "$PROJECT_DIR\AutoCADMCP.csproj" -c Release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed!"
    exit 1
}

# 2. Create Bundle Structure
Write-Host "Creating Bundle Structure..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "$TARGET_DIR\Contents\net48" -Force | Out-Null
New-Item -ItemType Directory -Path "$TARGET_DIR\Contents\net8.0-windows" -Force | Out-Null

# 3. Copy Files
Write-Host "Copying Files..." -ForegroundColor Yellow

# net48
Copy-Item "$PROJECT_DIR\bin\Release\net48\AutoCADMCP.dll" "$TARGET_DIR\Contents\net48\" -Force
Copy-Item "$PROJECT_DIR\bin\Release\net48\Newtonsoft.Json.dll" "$TARGET_DIR\Contents\net48\" -Force
# Backwards compatibility root files
try {
    Copy-Item "$PROJECT_DIR\bin\Release\net48\AutoCADMCP.dll" "$TARGET_DIR\Contents\" -Force -ErrorAction SilentlyContinue
    Copy-Item "$PROJECT_DIR\bin\Release\net48\Newtonsoft.Json.dll" "$TARGET_DIR\Contents\" -Force -ErrorAction SilentlyContinue
} catch {}

# net8.0-windows
Copy-Item "$PROJECT_DIR\bin\Release\net8.0-windows\AutoCADMCP.dll" "$TARGET_DIR\Contents\net8.0-windows\" -Force
Copy-Item "$PROJECT_DIR\bin\Release\net8.0-windows\AutoCADMCP.deps.json" "$TARGET_DIR\Contents\net8.0-windows\" -Force
Copy-Item "$PROJECT_DIR\bin\Release\net8.0-windows\Newtonsoft.Json.dll" "$TARGET_DIR\Contents\net8.0-windows\" -Force

# PackageContents.xml
Copy-Item "$PROJECT_DIR\PackageContents.xml" "$TARGET_DIR\" -Force

Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "Folder: $TARGET_DIR"
Write-Host "Supported AutoCAD versions: 2021 - 2026+"
