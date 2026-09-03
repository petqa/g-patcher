#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_SCRIPT="$SCRIPT_DIR/patch.py"
GEMINI_LINK="$HOME/.gemini/scripts/patch-agy.py"
BIN_LINK="$HOME/.local/bin/g-patcher"
PLIST_LABEL="ru.petqa.agy-autopatch"
PLIST_LOCAL="$SCRIPT_DIR/${PLIST_LABEL}.plist"
PLIST_LINK="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
AGY_BIN="${1:-$HOME/.local/bin/agy}"

echo "==> Установка g-patcher (через симлинки)..."

# 1. Права на исполнение
chmod +x "$PATCH_SCRIPT"

# 2. Создание симлинков на скрипт патчера
mkdir -p "$HOME/.gemini/scripts"
mkdir -p "$HOME/.local/bin"

ln -sf "$PATCH_SCRIPT" "$GEMINI_LINK"
echo "  [✓] Симлинк создан: $GEMINI_LINK -> $PATCH_SCRIPT"

ln -sf "$PATCH_SCRIPT" "$BIN_LINK"
echo "  [✓] Симлинк в PATH: $BIN_LINK -> $PATCH_SCRIPT"

# 3. Патчим текущий бинарник agy (если он существует)
if [ -f "$AGY_BIN" ]; then
    echo "  [→] Проверка и патч текущего бинарника: $AGY_BIN"
    python3 "$PATCH_SCRIPT" "$AGY_BIN"
else
    echo "  [i] Бинарник $AGY_BIN не найден, пропуск начального патча."
fi

# 4. Настройка launchd через симлинк на plist (только для macOS)
if [ "$(uname)" = "Darwin" ]; then
    echo "  [→] Настройка фонового демона macOS launchd (WatchPaths)..."
    mkdir -p "$HOME/Library/LaunchAgents"
    mkdir -p "$HOME/.gemini/antigravity-cli/log"

    # Генерируем plist в папке репозитория
    cat <<EOF > "$PLIST_LOCAL"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>${GEMINI_LINK}</string>
        <string>--silent</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>${AGY_BIN}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.gemini/antigravity-cli/log/agy-autopatch.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.gemini/antigravity-cli/log/agy-autopatch.log</string>
</dict>
</plist>
EOF

    # Симлинкаем plist в LaunchAgents
    ln -sf "$PLIST_LOCAL" "$PLIST_LINK"
    echo "  [✓] Симлинк plist: $PLIST_LINK -> $PLIST_LOCAL"

    launchctl unload "$PLIST_LINK" 2>/dev/null || true
    launchctl load "$PLIST_LINK"
    echo "  [✓] LaunchAgent запущен: $PLIST_LABEL"
fi

# 5. Функция-гард в ~/.zshrc
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    if ! grep -q "patch-agy.py" "$ZSHRC" && ! grep -q "g-patcher" "$ZSHRC"; then
        echo "  [→] Добавление функции agy в $ZSHRC..."
        cat <<'EOF' >> "$ZSHRC"

# Auto-patch agy binary for location eligibility (g-patcher)
agy() {
    ~/.local/bin/g-patcher --silent 2>/dev/null
    command agy "$@"
}
EOF
        echo "  [✓] Функция добавлена в $ZSHRC"
    else
        echo "  [✓] Функция agy уже настроена в $ZSHRC"
    fi
fi

echo ""
echo "🎉 Установка через симлинки успешно завершена!"
echo "Теперь любые изменения в $SCRIPT_DIR сразу активны в системе."
