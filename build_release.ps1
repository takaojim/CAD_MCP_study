# AutoCAD MCP Portable Build Script
# Creates a .bundle folder in the Output directory for manual distribution

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Join-Path $SCRIPT_DIR "AutoCAD-MCP-Addin"
$OUTPUT_DIR = Join-Path $SCRIPT_DIR "Output"
$BUNDLE_DIR = "$OUTPUT_DIR\AutoCADMCP.bundle"

Write-Host "Building AutoCAD MCP Package (Multi-Targeting)..." -ForegroundColor Cyan

# 1. Build C# Project
Write-Host "Compiling C# Project..." -ForegroundColor Yellow
try {
    dotnet build "$PROJECT_DIR\AutoCADMCP.csproj" -c Release
}
catch {
    Write-Warning "dotnet build failed. Please ensure .NET SDK is installed."
}

# 2. Create Output Structure
Write-Host "Creating Bundle Structure in Output..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "$BUNDLE_DIR\Contents\net48" -Force | Out-Null
New-Item -ItemType Directory -Path "$BUNDLE_DIR\Contents\net8.0-windows" -Force | Out-Null

# 3. Copy Files
Write-Host "Gathering Files..." -ForegroundColor Yellow
$BinDir48 = "$PROJECT_DIR\bin\Release\net48"
$BinDir80 = "$PROJECT_DIR\bin\Release\net8.0-windows"

if (Test-Path "$BinDir48\AutoCADMCP.dll") {
    Copy-Item "$BinDir48\AutoCADMCP.dll" "$BUNDLE_DIR\Contents\net48\" -Force
    Copy-Item "$BinDir48\Newtonsoft.Json.dll" "$BUNDLE_DIR\Contents\net48\" -Force
    Copy-Item "$BinDir48\AutoCADMCP.dll" "$BUNDLE_DIR\Contents\" -Force
    Copy-Item "$BinDir48\Newtonsoft.Json.dll" "$BUNDLE_DIR\Contents\" -Force
}

if (Test-Path "$BinDir80\AutoCADMCP.dll") {
    Copy-Item "$BinDir80\AutoCADMCP.dll" "$BUNDLE_DIR\Contents\net8.0-windows\" -Force
    Copy-Item "$BinDir80\AutoCADMCP.deps.json" "$BUNDLE_DIR\Contents\net8.0-windows\" -Force
    Copy-Item "$BinDir80\Newtonsoft.Json.dll" "$BUNDLE_DIR\Contents\net8.0-windows\" -Force
}

# PackageContents.xml
Copy-Item "$PROJECT_DIR\PackageContents.xml" "$BUNDLE_DIR\" -Force

Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "Bundle Location: $BUNDLE_DIR"
Write-Host "You can copy this 'AutoCADMCP.bundle' folder to '%APPDATA%\Autodesk\ApplicationPlugins\' on any machine."
