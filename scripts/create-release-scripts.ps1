# create-release-scripts.ps1
# Creates installation and run scripts for Windows release

$ErrorActionPreference = "Stop"

# Создаем объект кодировки UTF-8 с обязательным добавлением BOM ($true)
$utf8BOM = New-Object System.Text.UTF8Encoding($true)

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

Set-Location ..

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "✅ Installation completed!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To start the application:" -ForegroundColor Cyan
Write-Host "  .\start.ps1" -ForegroundColor White
Write-Host ""
'@

# Используем .NET класс для гарантии сохранения файла с BOM
$installPath = Join-Path $releaseDir "install.ps1"
[System.IO.File]::WriteAllText($installPath, $installScript, $utf8BOM)
Write-Host "✓ install.ps1 created" -ForegroundColor Green

# ========================================
# 2. Главный скрипт запуска (start.ps1)
# ========================================
Write-Host "Creating start.ps1..." -ForegroundColor Cyan

$startScript = @'
# start.ps1
# Starts Dataset Manager application with backend

$ErrorActionPreference = "Stop"

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

function Print-Warning {
    param([string]$Message)
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "🚀 Dataset Manager" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Проверка зависимостей
if (-not (Test-Path "backend\.venv")) {
    Print-Error "Dependencies not installed!"
    Write-Host ""
    Write-Host "Please run first:" -ForegroundColor Yellow
    Write-Host "  .\install.ps1" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Проверка executable
if (-not (Test-Path "dataset-manager.exe")) {
    Print-Error "Application executable not found!"
    Write-Host ""
    Write-Host "Expected: $scriptDir\dataset-manager.exe" -ForegroundColor Yellow
    exit 1
}

# PID файл для backend
$backendPidFile = "$env:TEMP\dataset-manager-backend-$env:USERNAME.pid"

# РАЗДЕЛЯЕМ ЛОГИ: один для stdout, другой для stderr
$backendLog = "$env:LOCALAPPDATA\dataset-manager\backend.log"
$backendErrorLog = "$env:LOCALAPPDATA\dataset-manager\backend-error.log"

# Создаем директорию для логов
New-Item -ItemType Directory -Path (Split-Path $backendLog) -Force -ErrorAction SilentlyContinue | Out-Null

# Функция проверки backend (ТЕПЕРЬ ПРОВЕРЯЕМ ТОЛЬКО ПОРТ 8000)
function Test-Backend {
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect("127.0.0.1", 8000)
        $tcpClient.Close()
        return $true
    } catch {
        return $false
    }
}

# Функция запуска backend
function Start-Backend {
    Print-Info "Starting backend..."
    
    Set-Location "backend"
    
    # Запускаем backend в фоне, направляя логи в разные файлы
    $processInfo = Start-Process -FilePath ".venv\Scripts\python.exe" -ArgumentList "main.py" -WindowStyle Hidden -RedirectStandardOutput $backendLog -RedirectStandardError $backendErrorLog -PassThru
    
    $backendPid = $processInfo.Id
    Set-Content -Path $backendPidFile -Value $backendPid
    
    Set-Location ..
    
    # Ждем запуска backend (максимум 15 секунд)
    Print-Info "Waiting for backend to start..."
    for ($i = 1; $i -le 15; $i++) {
        if (Test-Backend) {
            Print-Status "Backend started (PID: $backendPid)"
            Write-Host ""
            return $true
        }
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 1
    }
    
    Write-Host ""
    Print-Warning "Backend is taking longer to start..."
    Print-Info "Check logs: $backendErrorLog"
    Write-Host ""
    return $false
}

# Функция остановки backend
function Stop-Backend {
    if (Test-Path $backendPidFile) {
        $backendPid = Get-Content $backendPidFile
        
        try {
            $process = Get-Process -Id $backendPid -ErrorAction SilentlyContinue
            if ($process) {
                Print-Info "Stopping backend (PID: $backendPid)..."
                Stop-Process -Id $backendPid -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
        } catch {
            # Process already stopped
        }
        
        Remove-Item $backendPidFile -Force -ErrorAction SilentlyContinue
    }
}

# Cleanup при выходе
$cleanup = {
    Write-Host ""
    Stop-Backend
    Print-Status "Cleanup complete"
}

# Регистрируем cleanup
Register-EngineEvent PowerShell.Exiting -Action $cleanup | Out-Null

# Проверяем, запущен ли уже backend
if (Test-Backend) {
    Print-Status "Backend already running at http://127.0.0.1:8000"
    Write-Host ""
    
    if (Test-Path $backendPidFile) {
        $existingPid = Get-Content $backendPidFile
        Print-Info "Existing backend PID: $existingPid"
    } else {
        Print-Warning "Backend started by another instance"
        Set-Content -Path $backendPidFile -Value "0"
    }
    Write-Host ""
} else {
    # Запускаем backend
    $started = Start-Backend
    
    if (-not $started -or -not (Test-Backend)) {
        Print-Error "Backend failed to start!"
        Print-Info "Check logs: $backendErrorLog"
        Write-Host ""
        
        # Сначала проверяем лог ошибок
        if (Test-Path $backendErrorLog) {
            Write-Host "Last 10 lines of error log:" -ForegroundColor Yellow
            Get-Content $backendErrorLog -Tail 10
        } elseif (Test-Path $backendLog) {
            Write-Host "Last 10 lines of stdout log:" -ForegroundColor Yellow
            Get-Content $backendLog -Tail 10
        }
        exit 1
    }
}

# Запускаем GUI приложение
Print-Info "Starting GUI application..."
Write-Host ""
Write-Host "Backend API: http://127.0.0.1:8000" -ForegroundColor Green
Write-Host "Backend logs: $backendLog and $backendErrorLog" -ForegroundColor Gray
Write-Host ""

# Запускаем приложение и ждем его завершения
$app = Start-Process -FilePath ".\dataset-manager.exe" -PassThru
$app.WaitForExit()

# После закрытия GUI останавливаем backend
Stop-Backend
'@

$startPath = Join-Path $releaseDir "start.ps1"
[System.IO.File]::WriteAllText($startPath, $startScript, $utf8BOM)
Write-Host "✓ start.ps1 created" -ForegroundColor Green

# ========================================
# 3. Скрипт только для backend (start-backend-only.ps1)
# ========================================
Write-Host "Creating start-backend-only.ps1..." -ForegroundColor Cyan

$backendOnlyScript = @'
# start-backend-only.ps1
# Starts only the Dataset Manager backend server

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location "$scriptDir\backend"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "🐍 Dataset Manager Backend" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Проверка venv
if (-not (Test-Path ".venv")) {
    Write-Host "❌ Virtual environment not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run: ..\install.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "ℹ Starting backend server..." -ForegroundColor Blue
Write-Host "✓ API will be available at: http://127.0.0.1:8000" -ForegroundColor Green
Write-Host "✓ Docs: http://127.0.0.1:8000/docs" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

# Запускаем backend
& ".venv\Scripts\python.exe" main.py
'@

$backendOnlyPath = Join-Path $releaseDir "start-backend-only.ps1"
[System.IO.File]::WriteAllText($backendOnlyPath, $backendOnlyScript, $utf8BOM)
Write-Host "✓ start-backend-only.ps1 created" -ForegroundColor Green

# ========================================
# 4. README для Windows
# ========================================
Write-Host "Creating README.md..." -ForegroundColor Cyan

$readmeContent = @"
# Dataset Manager - Portable Application (Windows)

## 📋 System Requirements

- Windows 10/11 (64-bit)
- Python 3.10 or higher
- 4 GB RAM minimum
- 500 MB free disk space

## 🚀 Quick Start

### 1. Install Dependencies

```powershell
.\install.ps1
"@

$readmePath = Join-Path $releaseDir "README.md"
[System.IO.File]::WriteAllText($readmePath, $readmeContent, $utf8BOM)
Write-Host "✓ README.md created" -ForegroundColor Green


Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "✅ All release scripts created!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Release directory: $releaseDir" -ForegroundColor White
Write-Host ""

# Успешное завершение
exit 0