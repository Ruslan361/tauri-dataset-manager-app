# ========================================
# Копирование Backend в Release
# ========================================
cd ..

echo ""
echo "📂 Copying backend to release..."

RELEASE_DIR="release/linux"
mkdir -p "$RELEASE_DIR"

if [ ! -d "backend" ]; then
    print_error "Backend directory not found!"
    exit 1
fi

# Удаляем старый backend в release если есть
if [ -d "$RELEASE_DIR/backend" ]; then
    print_warning "Removing old backend from release..."
    rm -rf "$RELEASE_DIR/backend"
fi

# Копируем backend
if command -v rsync &> /dev/null; then
    print_info "Using rsync to copy backend..."
    rsync -av \
        --exclude='.venv' \
        --exclude='__pycache__' \
        --exclude='.pytest_cache' \
        --exclude='.mypy_cache' \
        --exclude='.ruff_cache' \
        --exclude='dist' \
        --exclude='build' \
        --exclude='*.spec' \
        --exclude='.git' \
        --exclude='*.pyc' \
        --exclude='*.pyo' \
        --exclude='*.egg-info' \
        backend/ "$RELEASE_DIR/backend/"
else
    print_info "Using cp to copy backend..."
    cp -r backend "$RELEASE_DIR/"
    
    # Очистка
    print_info "Cleaning unnecessary files..."
    rm -rf "$RELEASE_DIR/backend/.venv"
    rm -rf "$RELEASE_DIR/backend/__pycache__"
    rm -rf "$RELEASE_DIR/backend/.pytest_cache"
    rm -rf "$RELEASE_DIR/backend/.mypy_cache"
    rm -rf "$RELEASE_DIR/backend/.ruff_cache"
    rm -rf "$RELEASE_DIR/backend/dist"
    rm -rf "$RELEASE_DIR/backend/build"
    rm -f "$RELEASE_DIR/backend"/*.spec
    find "$RELEASE_DIR/backend" -type f -name "*.pyc" -delete 2>/dev/null || true
    find "$RELEASE_DIR/backend" -type f -name "*.pyo" -delete 2>/dev/null || true
    find "$RELEASE_DIR/backend" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$RELEASE_DIR/backend" -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
fi

# Проверяем что скопировалось
BACKEND_SIZE=$(du -sh "$RELEASE_DIR/backend" 2>/dev/null | cut -f1)
print_status "Backend copied ($BACKEND_SIZE)"

# Показываем структуру
print_info "Backend structure:"
ls -lh "$RELEASE_DIR/backend" | head -10

echo ""
