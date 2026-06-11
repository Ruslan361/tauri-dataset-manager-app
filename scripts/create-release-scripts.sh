#!/bin/bash
set -e

echo "================================================"
echo "📝 Creating Release Scripts"
echo "================================================"
echo ""

RELEASE_DIR="../release/linux"

# Проверка что release существует
if [ ! -d "$RELEASE_DIR" ]; then
    echo "❌ Release directory not found!"
    echo "Please run build script first"
    exit 1
fi

# ========================================
# 1. Скрипт установки зависимостей
# ========================================
echo "Creating install script..."

cat > "$RELEASE_DIR/install.sh" << 'INSTALL'
#!/bin/bash
set -e

echo "================================================"
echo "🔧 Installing Dataset Manager Dependencies"
echo "================================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Проверка backend директории
if [ ! -d "backend" ]; then
    print_error "Backend directory not found!"
    exit 1
fi

cd backend

# Проверка/Установка uv
echo "Checking uv..."
if ! command -v uv &> /dev/null; then
    print_info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    
    # Добавляем uv в PATH для текущей сессии
    export PATH="$HOME/.cargo/bin:$PATH"
    
    if command -v uv &> /dev/null; then
        print_status "uv installed"
    else
        print_error "Failed to install uv"
        echo "Please install manually: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
else
    print_status "uv $(uv --version | cut -d' ' -f2)"
fi

echo ""

# Установка зависимостей
echo "Installing Python dependencies..."
print_info "This may take a few minutes..."
echo ""

# uv sync создаст .venv и установит все зависимости
uv sync

if [ $? -eq 0 ]; then
    echo ""
    print_status "Dependencies installed successfully!"
    echo ""
    echo "Virtual environment created at: backend/.venv"
    echo ""
else
    echo ""
    print_error "Failed to install dependencies!"
    echo ""
    echo "Try manually:"
    echo "  cd backend"
    echo "  uv sync"
    exit 1
fi

cd ..

echo "================================================"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo "================================================"
echo ""
echo "To start the application:"
echo "  ./start.sh"
echo ""
INSTALL

chmod +x "$RELEASE_DIR/install.sh"
echo "✓ Created install.sh"

# ========================================
# 2. Главный скрипт запуска
# ========================================
echo "Creating start script..."

cat > "$RELEASE_DIR/start.sh" << 'START'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "================================================"
echo "🚀 Dataset Manager"
echo "================================================"
echo ""

# Проверка что зависимости установлены
if [ ! -d "backend/.venv" ]; then
    print_error "Dependencies not installed!"
    echo ""
    echo "Please run first:"
    echo "  ./install.sh"
    echo ""
    exit 1
fi

# Проверка исполняемого файла
if [ ! -f "dataset-manager" ]; then
    print_error "Application executable not found!"
    echo ""
    echo "Expected: $SCRIPT_DIR/dataset-manager"
    exit 1
fi

# PID файл для backend
BACKEND_PID_FILE="/tmp/dataset-manager-backend-$USER.pid"
BACKEND_LOG="$HOME/.local/share/dataset-manager/backend.log"

# Создаем директорию для логов
mkdir -p "$(dirname "$BACKEND_LOG")"

# Функция проверки backend
check_backend() {
    curl -s http://127.0.0.1:8000/health &>/dev/null
    return $?
}

# Функция запуска backend
start_backend() {
    print_info "Starting backend..."
    
    cd backend
    
    # Запускаем backend в фоне
    .venv/bin/python main.py > "$BACKEND_LOG" 2>&1 &
    BACKEND_PID=$!
    
    # Сохраняем PID
    echo $BACKEND_PID > "$BACKEND_PID_FILE"
    
    cd ..
    
    # Ждем запуска backend (максимум 15 секунд)
    print_info "Waiting for backend to start..."
    for i in {1..15}; do
        if check_backend; then
            print_status "Backend started (PID: $BACKEND_PID)"
            echo ""
            return 0
        fi
        echo -n "."
        sleep 1
    done
    
    echo ""
    print_warning "Backend is taking longer to start..."
    print_info "Check logs: $BACKEND_LOG"
    echo ""
    return 1
}

# Функция остановки backend
stop_backend() {
    if [ -f "$BACKEND_PID_FILE" ]; then
        BACKEND_PID=$(cat "$BACKEND_PID_FILE")
        
        # Проверяем что процесс еще существует
        if kill -0 $BACKEND_PID 2>/dev/null; then
            print_info "Stopping backend (PID: $BACKEND_PID)..."
            kill $BACKEND_PID 2>/dev/null || true
            
            # Ждем завершения (макс 5 сек)
            for i in {1..5}; do
                if ! kill -0 $BACKEND_PID 2>/dev/null; then
                    break
                fi
                sleep 1
            done
            
            # Если не завершился, принудительно
            if kill -0 $BACKEND_PID 2>/dev/null; then
                print_warning "Force killing backend..."
                kill -9 $BACKEND_PID 2>/dev/null || true
            fi
        fi
        
        rm -f "$BACKEND_PID_FILE"
    fi
}

# Cleanup функция
cleanup() {
    echo ""
    stop_backend
    print_status "Cleanup complete"
}

# Устанавливаем trap для cleanup
trap cleanup EXIT INT TERM

# Проверяем, запущен ли уже backend
if check_backend; then
    print_status "Backend already running at http://127.0.0.1:8000"
    echo ""
    
    # Проверяем наш ли это процесс
    if [ -f "$BACKEND_PID_FILE" ]; then
        EXISTING_PID=$(cat "$BACKEND_PID_FILE")
        print_info "Existing backend PID: $EXISTING_PID"
    else
        print_warning "Backend started by another instance"
        # Создаем пустой PID файл чтобы не останавливать чужой процесс
        touch "$BACKEND_PID_FILE"
    fi
    echo ""
else
    # Запускаем backend
    start_backend
    
    if ! check_backend; then
        print_error "Backend failed to start!"
        print_info "Check logs: $BACKEND_LOG"
        echo ""
        echo "Last 10 lines of log:"
        tail -n 10 "$BACKEND_LOG" 2>/dev/null || echo "No logs available"
        exit 1
    fi
fi

# Запускаем GUI приложение
print_info "Starting GUI application..."
echo ""
echo "Backend API: http://127.0.0.1:8000"
echo "Backend logs: $BACKEND_LOG"
echo ""

./dataset-manager "$@"

# После закрытия GUI - cleanup сработает автоматически через trap
START

chmod +x "$RELEASE_DIR/start.sh"
echo "✓ Created start.sh"

# ========================================
# 3. Скрипт только для backend
# ========================================
echo "Creating backend-only script..."

cat > "$RELEASE_DIR/start-backend-only.sh" << 'BACKEND_ONLY'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/backend"

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================"
echo "🐍 Dataset Manager Backend"
echo "================================================"
echo ""

# Проверка venv
if [ ! -d ".venv" ]; then
    echo "❌ Virtual environment not found!"
    echo ""
    echo "Please run: ../install.sh"
    exit 1
fi

echo -e "${BLUE}ℹ${NC} Starting backend server..."
echo -e "${GREEN}✓${NC} API will be available at: http://127.0.0.1:8000"
echo -e "${GREEN}✓${NC} Docs: http://127.0.0.1:8000/docs"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Запускаем backend
.venv/bin/python main.py
BACKEND_ONLY

chmod +x "$RELEASE_DIR/start-backend-only.sh"
echo "✓ Created start-backend-only.sh"

# ========================================
# 4. README
# ========================================
echo "Creating README..."

cat > "$RELEASE_DIR/README.md" << 'README'
# Dataset Manager - Portable Application

## 🚀 Quick Start

### 1. Install Dependencies

```bash
./install.sh
