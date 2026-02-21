# create-release-scripts.ps1
# Creates installation and run scripts for Windows release

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "📝 Creating Release Scripts for Windows" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$releaseDir = Join-Path $PSScriptRoot "..\release\windows"

# Проверка что release существует
if (-not (Test-Path $releaseDir)) {
    Write-Host "❌ Release directory not found!" -ForegroundColor Red
    Write-Host "Please run build-tauri.ps1 first" -ForegroundColor Yellow
    exit 1
}

# ========================================
# 1. Скрипт установки зависимостей (install.ps1)
# ========================================
Write-Host "Creating install.ps1..." -ForegroundColor Cyan

$installScript = @'
# install.ps1
# Installs Dataset Manager Dependencies on Windows

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "🔧 Installing Dataset Manager Dependencies" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Функции
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

# Проверка backend директории
if (-not (Test-Path "backend" -PathType Container)) {
    Print-Error "Backend directory not found!"
    exit 1
}

Set-Location "backend"

# Проверка Python
Write-Host "Checking Python..." -ForegroundColor Cyan
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Print-Error "Python 3 not found!"
    Write-Host ""
    Write-Host "Please install Python 3.10+ from:" -ForegroundColor Yellow
    Write-Host "  https://www.python.org/downloads/" -ForegroundColor White
    Write-Host ""
    Write-Host "During installation, make sure to:" -ForegroundColor Yellow
    Write-Host "  ✓ Check 'Add Python to PATH'" -ForegroundColor White
    Write-Host "  ✓ Check 'Install pip'" -ForegroundColor White
    exit 1
}

$pythonVersion = python --version
Print-Status $pythonVersion

Write-Host ""

# Проверка/Установка uv
Write-Host "Checking uv..." -ForegroundColor Cyan
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Print-Info "Installing uv..."
    
    # Установка uv через PowerShell
    irm https://astral.sh/uv/install.ps1 | iex
    
    # Обновляем PATH для текущей сессии
    $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
    
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Print-Status "uv installed"
    } else {
        Print-Error "Failed to install uv"
        Write-Host "Please install manually:" -ForegroundColor Yellow
        Write-Host "  irm https://astral.sh/uv/install.ps1 | iex" -ForegroundColor White
        exit 1
    }
} else {
    $uvVersion = (uv --version).Split()[1]
    Print-Status "uv $uvVersion"
}

Write-Host ""

# Установка зависимостей
Write-Host "Installing Python dependencies..." -ForegroundColor Cyan
Print-Info "This may take a few minutes..."
Write-Host ""

# uv sync создаст .venv и установит все зависимости
uv sync

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Print-Status "Dependencies installed successfully!"
    Write-Host ""
    Write-Host "Virtual environment created at: backend\.venv" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host ""
    Print-Error "Failed to install dependencies!"
    Write-Host ""
    Write-Host "Try manually:" -ForegroundColor Yellow
    Write-Host "  cd backend" -ForegroundColor White
    Write-Host "  uv sync" -ForegroundColor White
    exit 1
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "✅ Installation completed!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run the backend: .\run-backend.ps1" -ForegroundColor White
Write-Host "  2. Launch the app: .\run-app.ps1" -ForegroundColor White
Write-Host ""
'@

Set-Content -Path "$releaseDir\install.ps1" -Value $installScript -Encoding UTF8
Write-Host "✓ install.ps1 created" -ForegroundColor Green

# ========================================
# 2. Скрипт запуска backend (run-backend.ps1)
# ========================================
Write-Host "Creating run-backend.ps1..." -ForegroundColor Cyan

$runBackendScript = @'
# run-backend.ps1
# Starts the Dataset Manager backend server

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "🚀 Starting Dataset Manager Backend" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$scriptDir\backend"

# Проверка virtual environment
if (-not (Test-Path ".venv" -PathType Container)) {
    Write-Host "❌ Virtual environment not found!" -ForegroundColor Red
    Write-Host "Please run install.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Активируем virtual environment и запускаем backend
Write-Host "Starting backend server..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

& ".venv\Scripts\Activate.ps1"
uv run python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
'@

Set-Content -Path "$releaseDir\run-backend.ps1" -Value $runBackendScript -Encoding UTF8
Write-Host "✓ run-backend.ps1 created" -ForegroundColor Green

# ========================================
# 3. Скрипт запуска приложения (run-app.ps1)
# ========================================
Write-Host "Creating run-app.ps1..." -ForegroundColor Cyan

$runAppScript = @'
# run-app.ps1
# Launches the Dataset Manager application

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "🚀 Launching Dataset Manager" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Ищем .exe файл приложения
$appExe = Get-ChildItem -Path $scriptDir -Filter "*.exe" -File | 
          Where-Object { $_.Name -notlike "*-setup.exe" } |
          Select-Object -First 1

if ($appExe) {
    Write-Host "Starting application: $($appExe.Name)" -ForegroundColor Green
    Start-Process -FilePath $appExe.FullName
} else {
    Write-Host "❌ Application executable not found!" -ForegroundColor Red
    Write-Host "Looking for .msi installer instead..." -ForegroundColor Yellow
    
    $msiFile = Get-ChildItem -Path $scriptDir -Filter "*.msi" -File | Select-Object -First 1
    
    if ($msiFile) {
        Write-Host "Found installer: $($msiFile.Name)" -ForegroundColor Green
        Write-Host "Please install the application first by running:" -ForegroundColor Yellow
        Write-Host "  Start-Process msiexec.exe -ArgumentList '/i `"$($msiFile.FullName)`"'" -ForegroundColor White
    } else {
        Write-Host "No executable or installer found in release directory" -ForegroundColor Red
    }
}
'@

Set-Content -Path "$releaseDir\run-app.ps1" -Value $runAppScript -Encoding UTF8
Write-Host "✓ run-app.ps1 created" -ForegroundColor Green

# ========================================
# 4. README для Windows
# ========================================
Write-Host "Creating README-WINDOWS.md..." -ForegroundColor Cyan

$readmeContent = @'
# Dataset Manager - Windows Release

## 📋 System Requirements

- Windows 10/11 (64-bit)
- Python 3.10 or higher
- 4 GB RAM minimum
- 500 MB free disk space

## 🚀 Quick Start

### 1. Install Dependencies

```powershell
.\install.ps1