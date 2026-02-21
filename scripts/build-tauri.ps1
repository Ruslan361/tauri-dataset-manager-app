# build-tauri.ps1
# PowerShell script for building Tauri Desktop Application on Windows

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "🔨 Building Tauri Desktop Application" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Функции для вывода статуса
function Print-Status {
    param([string]$Message)
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Print-Error {
    param([string]$Message)
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Print-Info {
    param([string]$Message)
    Write-Host "ℹ " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Print-Warning {
    param([string]$Message)
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

# Определяем платформу
$Platform = "windows"
$Arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }

Print-Info "Platform: $Platform"
Print-Info "Architecture: $Arch"
Write-Host ""

# Переходим в директорию frontend
Set-Location -Path (Join-Path $PSScriptRoot "..\frontend")

# ========================================
# 1. Проверка зависимостей
# ========================================
Write-Host "📦 Step 1/5: Checking dependencies..." -ForegroundColor Cyan

# Проверка Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Print-Error "Node.js not found!"
    Write-Host "Download from: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}
$nodeVersion = (node --version)
Print-Status "Node.js $nodeVersion"

# Проверка npm
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Print-Error "npm not found!"
    exit 1
}
$npmVersion = (npm --version)
Print-Status "npm $npmVersion"

# Проверка Rust
if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
    Print-Error "Rust not found!"
    Print-Warning "Installing Rust..."
    
    # Скачиваем и запускаем rustup-init.exe
    $rustupUrl = "https://win.rustup.rs/x86_64"
    $rustupPath = "$env:TEMP\rustup-init.exe"
    
    Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupPath
    & $rustupPath -y --default-toolchain stable
    
    # Обновляем PATH для текущей сессии
    $cargoPath = "$env:USERPROFILE\.cargo\bin"
    $env:Path = "$cargoPath;$env:Path"
    
    Remove-Item $rustupPath -Force
}
$rustVersion = (rustc --version).Split()[1]
Print-Status "Rust $rustVersion"

# Проверка Cargo
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Print-Error "Cargo not found!"
    exit 1
}
$cargoVersion = (cargo --version).Split()[1]
Print-Status "Cargo $cargoVersion"

# Проверка Tauri CLI
$tauriInstalled = npm list @tauri-apps/cli 2>$null
if ($LASTEXITCODE -ne 0) {
    Print-Warning "Installing Tauri CLI..."
    npm install --save-dev @tauri-apps/cli @tauri-apps/api
    Print-Status "Tauri CLI installed"
} else {
    Print-Status "Tauri CLI installed"
}

Write-Host ""

# ========================================
# 2. Проверка структуры проекта
# ========================================
Write-Host "🔍 Step 2/5: Checking project structure..." -ForegroundColor Cyan

# Проверка src-tauri
if (-not (Test-Path "src-tauri" -PathType Container)) {
    Print-Error "src-tauri directory not found!"
    exit 1
}
Print-Status "src-tauri directory exists"

# Проверка конфигурации
if (-not (Test-Path "src-tauri\tauri.conf.json" -PathType Leaf)) {
    Print-Error "tauri.conf.json not found!"
    exit 1
}
Print-Status "tauri.conf.json exists"

# Проверка bundle identifier
$tauriConfig = Get-Content "src-tauri\tauri.conf.json" -Raw | ConvertFrom-Json
$bundleId = $tauriConfig.identifier

if (-not $bundleId -or $bundleId -eq "com.tauri.dev") {
    Print-Warning "Default bundle identifier detected!"
    Print-Info "Consider updating identifier in tauri.conf.json"
} else {
    Print-Status "Bundle identifier: $bundleId"
}

Write-Host ""

# ========================================
# 3. Установка зависимостей
# ========================================
Write-Host "📥 Step 3/5: Installing dependencies..." -ForegroundColor Cyan

Print-Info "Installing npm dependencies..."
npm install

if ($LASTEXITCODE -ne 0) {
    Print-Error "Failed to install npm dependencies!"
    exit 1
}
Print-Status "npm dependencies installed"

Write-Host ""

# ========================================
# 4. Сборка приложения
# ========================================
Write-Host "🏗️  Step 4/5: Building application..." -ForegroundColor Cyan

Print-Info "This may take several minutes..."
Print-Info "Building for: $Platform-$Arch"

npm run tauri build

if ($LASTEXITCODE -ne 0) {
    Print-Error "Build failed!"
    exit 1
}

Write-Host ""
Print-Status "Build completed successfully!"

Write-Host ""

# ========================================
# 5. Поиск и отображение результатов
# ========================================
Write-Host "📦 Step 5/5: Locating build artifacts..." -ForegroundColor Cyan

$bundlePath = "src-tauri\target\release\bundle"

if (Test-Path $bundlePath) {
    Print-Status "Build artifacts found in: $bundlePath"
    Write-Host ""
    
    # Ищем .msi файл
    $msiFiles = Get-ChildItem -Path "$bundlePath\msi" -Filter "*.msi" -Recurse -ErrorAction SilentlyContinue
    if ($msiFiles) {
        Write-Host "📦 MSI Installer:" -ForegroundColor Green
        foreach ($msi in $msiFiles) {
            $size = "{0:N2} MB" -f ($msi.Length / 1MB)
            Write-Host "   - $($msi.Name) ($size)" -ForegroundColor White
            Write-Host "     $($msi.FullName)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Ищем .exe файл
    $exeFiles = Get-ChildItem -Path "$bundlePath\nsis" -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue
    if ($exeFiles) {
        Write-Host "📦 NSIS Installer:" -ForegroundColor Green
        foreach ($exe in $exeFiles) {
            $size = "{0:N2} MB" -f ($exe.Length / 1MB)
            Write-Host "   - $($exe.Name) ($size)" -ForegroundColor White
            Write-Host "     $($exe.FullName)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
} else {
    Print-Warning "Build artifacts directory not found"
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "✅ Build process completed!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Опциональный дополнительный шаг — копирование в release/windows
$releaseDir = Join-Path $PSScriptRoot "..\release\windows"
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
}

Write-Host "📋 Copying artifacts to release directory..." -ForegroundColor Cyan
if ($msiFiles) {
    Copy-Item -Path $msiFiles[0].FullName -Destination $releaseDir -Force
    Print-Status "MSI copied to: $releaseDir"
}
if ($exeFiles) {
    Copy-Item -Path $exeFiles[0].FullName -Destination $releaseDir -Force
    Print-Status "NSIS installer copied to: $releaseDir"
}

Write-Host ""
Write-Host "🎉 All done! Check the release folder:" -ForegroundColor Green
Write-Host "   $releaseDir" -ForegroundColor White