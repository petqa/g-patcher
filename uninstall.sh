#!/usr/bin/env bash
set -e

PLIST_LABEL="ru.petqa.agy-autopatch"
PLIST_LINK="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
GEMINI_LINK="$HOME/.gemini/scripts/patch-agy.py"
BIN_LINK="$HOME/.local/bin/g-patcher"

echo "==> Удаление g-patcher..."

# 1. Выгружаем launchd агент
if [ -f "$PLIST_LINK" ] || [ -L "$PLIST_LINK" ]; then
    echo "  [→] Выгрузка LaunchAgent..."
    launchctl unload "$PLIST_LINK" 2>/dev/null || true
    rm -f "$PLIST_LINK"
    echo "  [✓] LaunchAgent удален: $PLIST_LINK"
fi

# 2. Удаляем симлинки
rm -f "$GEMINI_LINK"
rm -f "$BIN_LINK"
echo "  [✓] Симлинки удалены."

echo ""
echo "g-patcher успешно удален."
echo "(Если вы хотите убрать функцию agy() из ~/.zshrc, удалите её вручную)."
