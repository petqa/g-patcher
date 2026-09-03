#!/usr/bin/env bash
set -e

PLIST_LABEL="com.antigravity.autopatch"
PLIST_FILE="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
BIN_LINK="$HOME/.local/bin/g-patcher"
GEMINI_LINK="$HOME/.gemini/scripts/patch-agy.py"

echo "==> Удаление g-patcher для пользователя: $(whoami)..."

# 1. Выгрузка launchd демона
if [ -f "$PLIST_FILE" ] || [ -L "$PLIST_FILE" ]; then
    echo "  [→] Выгрузка LaunchAgent..."
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    rm -f "$PLIST_FILE"
    echo "  [✓] LaunchAgent удален: $PLIST_FILE"
fi

# 2. Удаление симлинков
rm -f "$BIN_LINK"
rm -f "$GEMINI_LINK"
echo "  [✓] Симлинки удалены."

# 3. Чистка ~/.zshrc
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    echo "  [→] Очистка функций из $ZSHRC..."
    sed -i '' '/# Auto-patch agy binary/,+4d' "$ZSHRC" 2>/dev/null || true
    echo "  [✓] ~/.zshrc очищен."
fi

echo ""
echo "g-patcher успешно удален."
