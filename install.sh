#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_SCRIPT="$SCRIPT_DIR/patch.py"
BIN_DIR="$HOME/.local/bin"
BIN_LINK="$BIN_DIR/g-patcher"
PLIST_LABEL="com.antigravity.autopatch"
PLIST_FILE="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

echo "==> Установка g-patcher для пользователя: $(whoami)..."

# 1. Права на исполнение
chmod +x "$PATCH_SCRIPT"

# 2. Создание глобального симлинка в PATH
mkdir -p "$BIN_DIR"
ln -sf "$PATCH_SCRIPT" "$BIN_LINK"
echo "  [✓] Симлинк в PATH: $BIN_LINK -> $PATCH_SCRIPT"

# Симлинк для gemini scripts (обратная совместимость)
mkdir -p "$HOME/.gemini/scripts"
ln -sf "$PATCH_SCRIPT" "$HOME/.gemini/scripts/patch-agy.py"

# 3. Запуск авто-патча прямо сейчас (находит все компоненты в системе)
echo "  [→] Сканирование и патч компонентов Antigravity в системе..."
python3 "$PATCH_SCRIPT" || true

# 4. Настройка launchd через WatchPaths (только для macOS)
if [ "$(uname)" = "Darwin" ]; then
    echo "  [→] Настройка фонового демона macOS launchd (WatchPaths)..."
    mkdir -p "$HOME/Library/LaunchAgents"
    mkdir -p "$HOME/.gemini/antigravity-cli/log"

    # Собираем список путей для отслеживания
    WATCH_PATHS=()
    [ -f "$HOME/.local/bin/agy" ] && WATCH_PATHS+=("$HOME/.local/bin/agy")
    [ -f "/Applications/Antigravity.app/Contents/Resources/bin/language_server" ] && WATCH_PATHS+=("/Applications/Antigravity.app/Contents/Resources/bin/language_server")

    if [ ${#WATCH_PATHS[@]} -eq 0 ]; then
        WATCH_PATHS+=("$HOME/.local/bin/agy")
    fi

    WATCH_XML=""
    for wp in "${WATCH_PATHS[@]}"; do
        WATCH_XML="${WATCH_XML}        <string>${wp}</string>\n"
    done

    cat <<EOF > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>${BIN_LINK}</string>
        <string>--silent</string>
    </array>
    <key>WatchPaths</key>
    <array>
$(printf "$WATCH_XML")    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.gemini/antigravity-cli/log/agy-autopatch.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.gemini/antigravity-cli/log/agy-autopatch.log</string>
</dict>
</plist>
EOF

    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"
    echo "  [✓] LaunchAgent запущен: $PLIST_LABEL"
fi

# 5. Функция-гард в ~/.zshrc
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    if ! grep -q "g-patcher" "$ZSHRC"; then
        echo "  [→] Добавление функции agy в $ZSHRC..."
        cat <<'EOF' >> "$ZSHRC"

# Auto-patch agy binary for location eligibility (g-patcher)
agy() {
    ~/.local/bin/g-patcher --silent 2>/dev/null
    command agy "$@"
}
EOF
        echo "  [✓] Функция agy добавлена в $ZSHRC"
    else
        echo "  [✓] Функция agy уже настроена в $ZSHRC"
    fi
fi

echo ""
echo "🎉 Установка успешно завершена для пользователя $(whoami)!"
