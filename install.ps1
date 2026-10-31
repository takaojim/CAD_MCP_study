# AutoCAD MCP Deployment Script
# Compiles the C# project and installs it to the user's AutoCAD ApplicationPlugins folder

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Join-Path $SCRIPT_DIR "AutoCAD-MCP-Addin"
$TARGET_DIR = "$env:APPDATA\Autodesk\ApplicationPlugins\AutoCADMCP.bundle"

Write-Host "Build and Deploy AutoCAD MCP..." -ForegroundColor Cyan

# 0. Check running AutoCAD processes and wait if necessary
$acadProc = Get-Process acad -ErrorAction SilentlyContinue
if ($acadProc) {
    Write-Host "AutoCAD is currently running. Please close AutoCAD so files can be replaced..." -ForegroundColor Yellow
    while (Get-Process acad -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 1
    }
    Write-Host "AutoCAD closed. Proceeding with deployment..." -ForegroundColor Green
}

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

# 4. Ensure Registry Startup Entries (AutoCAD 2026 & 2027)
Write-Host "Ensuring Registry Startup entries (LOADCTRLS = 14)..." -ForegroundColor Yellow
$regConfigs = @(
    @{
        Key = "HKCU:\Software\Autodesk\AutoCAD\R25.1\ACAD-9101:404\Applications\AutoCADMCP"
        Loader = "$TARGET_DIR\Contents\net8.0-windows\AutoCADMCP.dll"
    },
    @{
        Key = "HKCU:\Software\Autodesk\AutoCAD\R25.1\ACAD-9101:404\Applications\Send2Rvt"
        Loader = "$env:APPDATA\Autodesk\ApplicationPlugins\Send2Rvt.AutoCad.bundle\Contents\net8\Send2Rvt.AutoCad.Addin.dll"
    }
)

foreach ($item in $regConfigs) {
    $parent = Split-Path $item.Key
    if (Test-Path $parent) {
        if (-not (Test-Path $item.Key)) {
            New-Item -Path $item.Key -Force | Out-Null
        }
        Set-ItemProperty -Path $item.Key -Name "LOADER" -Value $item.Loader
        Set-ItemProperty -Path $item.Key -Name "LOADCTRLS" -Value 14 -Type DWord
        Set-ItemProperty -Path $item.Key -Name "MANAGED" -Value 1 -Type DWord
        Set-ItemProperty -Path $item.Key -Name "DESCRIPTION" -Value (Split-Path $item.Key -Leaf)
    }
}

Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "Folder: $TARGET_DIR"
Write-Host "Supported AutoCAD versions: 2021 - 2027+"
