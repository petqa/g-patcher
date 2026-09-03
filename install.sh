#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.gemini/scripts"
TARGET_SCRIPT="$INSTALL_DIR/patch-agy.py"
PLIST_LABEL="ru.petqa.agy-autopatch"
PLIST_FILE="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
AGY_BIN="${1:-$HOME/.local/bin/agy}"

echo "==> Установка g-patcher..."

# 1. Копируем скрипт в ~/.gemini/scripts
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/patch.py" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"
echo "  [✓] Скрипт установлен: $TARGET_SCRIPT"

# 2. Накладываем патч прямо сейчас
if [ -f "$AGY_BIN" ]; then
    echo "  [→] Патчим текущий бинарник: $AGY_BIN"
    python3 "$TARGET_SCRIPT" "$AGY_BIN"
else
    echo "  [i] Бинарник $AGY_BIN пока не найден, пропуск начального патча."
fi

# 3. Настраиваем системный демон launchd (macOS)
if [ "$(uname)" = "Darwin" ]; then
    echo "  [→] Настройка фонового отслеживания launchd (WatchPaths)..."
    mkdir -p "$HOME/Library/LaunchAgents"
    mkdir -p "$HOME/.gemini/antigravity-cli/log"

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
        <string>${TARGET_SCRIPT}</string>
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

    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"
    echo "  [✓] LaunchAgent активирован: $PLIST_FILE"
fi

# 4. Проверка ~/.zshrc
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    if ! grep -q "patch-agy.py" "$ZSHRC"; then
        echo "  [→] Добавление функции-гарда в $ZSHRC..."
        cat <<'EOF' >> "$ZSHRC"

# Auto-patch agy binary for location eligibility (g-patcher)
agy() {
    ~/.gemini/scripts/patch-agy.py --silent 2>/dev/null
    command agy "$@"
}
EOF
        echo "  [✓] Функция agy добавлена в $ZSHRC"
    else
        echo "  [✓] Функция agy уже есть в $ZSHRC"
    fi
fi

echo ""
echo "🎉 Установка завершена!"
echo "Теперь при любом обновлении agy бинарник будет пропатчен автоматически."
