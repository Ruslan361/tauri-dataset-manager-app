#!/bin/bash
set -e

echo "================================================"
echo "🔨 Building Tauri Desktop Application"
echo "================================================"
echo ""

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для печати статуса
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

# Определяем платформу
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

print_info "Platform: $PLATFORM"
print_info "Architecture: $ARCH"
echo ""

# Переходим в директорию frontend
cd ../frontend

# ========================================
# 1. Проверка зависимостей
# ========================================
echo "📦 Step 1/5: Checking dependencies..."

# Проверка Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js not found!"
    exit 1
fi
print_status "Node.js $(node --version)"

# Проверка npm
if ! command -v npm &> /dev/null; then
    print_error "npm not found!"
    exit 1
fi
print_status "npm $(npm --version)"

# Проверка Rust
if ! command -v rustc &> /dev/null; then
    print_error "Rust not found!"
    print_warning "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi
print_status "Rust $(rustc --version | cut -d' ' -f2)"

# Проверка Cargo
if ! command -v cargo &> /dev/null; then
    print_error "Cargo not found!"
    exit 1
fi
print_status "Cargo $(cargo --version | cut -d' ' -f2)"

# Проверка Tauri CLI
if ! npm list @tauri-apps/cli &>/dev/null; then
    print_warning "Installing Tauri CLI..."
    npm install --save-dev @tauri-apps/cli @tauri-apps/api
    print_status "Tauri CLI installed"
else
    print_status "Tauri CLI installed"
fi

echo ""

# ========================================
# 2. Проверка структуры проекта
# ========================================
echo "🔍 Step 2/5: Checking project structure..."

# Проверка src-tauri
if [ ! -d "src-tauri" ]; then
    print_error "src-tauri directory not found!"
    exit 1
fi
print_status "src-tauri directory exists"

# Проверка конфигурации
if [ ! -f "src-tauri/tauri.conf.json" ]; then
    print_error "tauri.conf.json not found!"
    exit 1
fi

# Проверка bundle identifier
IDENTIFIER=$(grep -o '"identifier":[[:space:]]*"[^"]*"' src-tauri/tauri.conf.json | cut -d'"' -f4)
if [ "$IDENTIFIER" == "com.tauri.dev" ]; then
    print_error "Bundle identifier is still default (com.tauri.dev)"
    print_warning "Please change it in src-tauri/tauri.conf.json"
    exit 1
fi
print_status "Bundle identifier: $IDENTIFIER"

# Проверка иконки
if [ ! -f "src-tauri/icons/icon.png" ]; then
    print_warning "Icon not found, creating placeholder..."
    mkdir -p src-tauri/icons
    if command -v convert &> /dev/null; then
        convert -size 512x512 xc:blue -pointsize 100 -fill white \
          -gravity center -annotate +0+0 "DM" src-tauri/icons/icon.png
        print_status "Placeholder icon created"
    else
        wget -q -O src-tauri/icons/icon.png https://via.placeholder.com/512 || \
        curl -s -o src-tauri/icons/icon.png https://via.placeholder.com/512 || \
        print_warning "Could not create icon automatically"
    fi
else
    print_status "Icon exists"
fi

echo ""

# ========================================
# 3. Установка зависимостей
# ========================================
echo "📥 Step 3/5: Installing dependencies..."

if [ ! -d "node_modules" ]; then
    print_info "Installing npm packages..."
    npm install
    print_status "npm packages installed"
else
    print_status "npm packages already installed"
fi

echo ""

# ========================================
# 4. Сборка frontend
# ========================================
echo "🎨 Step 4/5: Building frontend..."

# Удаляем старый dist
if [ -d "dist" ]; then
    rm -rf dist
    print_info "Cleaned old dist directory"
fi

# Собираем
print_info "Running: npm run build"
npm run build

# Проверяем, что dist создан
if [ ! -d "dist" ]; then
    print_error "Frontend build failed: dist directory not created"
    exit 1
fi
print_status "Frontend built"

DIST_SIZE=$(du -sh dist 2>/dev/null | cut -f1)
print_info "Frontend size: $DIST_SIZE"

echo ""

# ========================================
# 5. Сборка Tauri
# ========================================
echo "🔨 Step 5/5: Building Tauri application..."

# Параметры сборки
BUILD_MODE="${1:-release}"  # release или debug
BUILD_TARGET="${2:-all}"     # all, deb, appimage, msi, dmg, app

if [ "$BUILD_MODE" == "debug" ]; then
    print_info "Building in DEBUG mode (faster, larger size)..."
    npm run tauri build -- --debug
else
    print_info "Building in RELEASE mode (slower, optimized)..."
    npm run tauri build
fi

print_status "Tauri application built"

echo ""

# ========================================
# 6. Поиск и отображение результатов
# ========================================
echo "================================================"
echo "📊 Build Results"
echo "================================================"
echo ""

if [ "$BUILD_MODE" == "debug" ]; then
    TARGET_DIR="src-tauri/target/debug"
    BUNDLE_DIR="src-tauri/target/debug/bundle"
else
    TARGET_DIR="src-tauri/target/release"
    BUNDLE_DIR="src-tauri/target/release/bundle"
fi

# Исполняемый файл
if [[ "$PLATFORM" == "linux" ]]; then
    EXEC_FILE=$(find "$TARGET_DIR" -maxdepth 1 -type f -executable -name "*dataset*" 2>/dev/null | head -1)
    if [ -n "$EXEC_FILE" ]; then
        EXEC_SIZE=$(du -sh "$EXEC_FILE" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✓${NC} Executable: $EXEC_FILE ($EXEC_SIZE)"
    fi
elif [[ "$PLATFORM" == "darwin" ]]; then
    EXEC_FILE=$(find "$TARGET_DIR" -maxdepth 1 -type f -perm +111 -name "*dataset*" 2>/dev/null | head -1)
    if [ -n "$EXEC_FILE" ]; then
        EXEC_SIZE=$(du -sh "$EXEC_FILE" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✓${NC} Executable: $EXEC_FILE ($EXEC_SIZE)"
    fi
fi

echo ""

# Пакеты/Установщики
if [ -d "$BUNDLE_DIR" ]; then
    echo "📦 Bundles:"
    
    # Linux
    if [ -d "$BUNDLE_DIR/deb" ]; then
        for deb in "$BUNDLE_DIR/deb"/*.deb; do
            if [ -f "$deb" ]; then
                SIZE=$(du -sh "$deb" 2>/dev/null | cut -f1)
                echo -e "  ${GREEN}✓${NC} .deb: $deb ($SIZE)"
            fi
        done
    fi
    
    if [ -d "$BUNDLE_DIR/appimage" ]; then
        for appimage in "$BUNDLE_DIR/appimage"/*.AppImage; do
            if [ -f "$appimage" ]; then
                SIZE=$(du -sh "$appimage" 2>/dev/null | cut -f1)
                echo -e "  ${GREEN}✓${NC} AppImage: $appimage ($SIZE)"
                chmod +x "$appimage"
            fi
        done
    fi
    
    # macOS
    if [ -d "$BUNDLE_DIR/macos" ]; then
        for app in "$BUNDLE_DIR/macos"/*.app; do
            if [ -d "$app" ]; then
                SIZE=$(du -sh "$app" 2>/dev/null | cut -f1)
                echo -e "  ${GREEN}✓${NC} .app: $app ($SIZE)"
            fi
        done
    fi
    
    if [ -d "$BUNDLE_DIR/dmg" ]; then
        for dmg in "$BUNDLE_DIR/dmg"/*.dmg; do
            if [ -f "$dmg" ]; then
                SIZE=$(du -sh "$dmg" 2>/dev/null | cut -f1)
                echo -e "  ${GREEN}✓${NC} .dmg: $dmg ($SIZE)"
            fi
        done
    fi
else
    print_warning "No bundles found in $BUNDLE_DIR"
fi

echo ""

# Общий размер
if [ -d "$TARGET_DIR" ]; then
    TOTAL_SIZE=$(du -sh "$TARGET_DIR" 2>/dev/null | cut -f1)
    echo "💾 Total build size: $TOTAL_SIZE"
fi

echo ""
echo "================================================"
echo -e "${GREEN}✅ Build Complete!${NC}"
echo "================================================"
echo ""

if [ -n "$EXEC_FILE" ]; then
    echo "To run the application:"
    echo "  $EXEC_FILE"
    echo ""
fi

# Создаем директорию для релиза
RELEASE_DIR="../release"
if [ -d "$TARGET_DIR" ]; then
    echo "Copying builds to release directory..."
    mkdir -p "$RELEASE_DIR"
    
    if [[ "$PLATFORM" == "linux" ]]; then
        # Копируем только исполняемый файл
        TAURI_BIN=$(find "$TARGET_DIR" -maxdepth 1 -type f -executable -name "app" 2>/dev/null | head -1)
        mkdir "$RELEASE_DIR/linux"
        if [ -n "$TAURI_BIN" ]; then
            cp "$TAURI_BIN" "$RELEASE_DIR/linux/dataset-manager"
            chmod +x "$RELEASE_DIR/linux/dataset-manager"
            echo "  ✓ Copied dataset-manager executable"
        else
            print_warning "Executable not found"
        fi
        
    elif [[ "$PLATFORM" == "darwin" ]]; then
        # Для macOS копируем .app bundle
        TAURI_APP=$(find "$TARGET_DIR" -maxdepth 1 -type f -perm +111 -name "app" 2>/dev/null | head -1)
        mkdir "$RELEASE_DIR/darwin"
        if [ -n "$TAURI_APP" ]; then
            cp "$TAURI_APP" "$RELEASE_DIR/darwin/dataset-manager"
            chmod +x "$RELEASE_DIR/darwin/dataset-manager"
            echo "  ✓ Copied dataset-manager executable"
        fi
        
    elif [[ "$PLATFORM" == "mingw"* ]] || [[ "$PLATFORM" == "msys"* ]]; then
        # Для Windows
        mkdir "$RELEASE_DIR/windows"
        if [ -f "$TARGET_DIR/windows/app.exe" ]; then
            cp "$TARGET_DIR/windows/dataset-manager.exe" "$RELEASE_DIR/"
            echo "  ✓ Copied dataset-manager.exe"
        fi
    fi
    
    if [ "$(ls -A $RELEASE_DIR 2>/dev/null)" ]; then
        echo ""
        echo "Release files in: $RELEASE_DIR"
        ls -lh "$RELEASE_DIR"
    fi
fi


# Возвращаемся в корень проекта
cd ..

echo ""
