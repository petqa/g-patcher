# ⚡ g-patcher

Автоматический патчер для **Antigravity CLI (`agy`)**, снимающий ошибку региональных ограничений:

```text
Eligibility check failed: Your current account is not eligible for Antigravity, because it is not currently available in your location.
```

---

## 💡 Как это работает

Внутри скомпилированного Go-бинаря `agy` зашита проверка региона (`isEligible`). 
Патчер находит байтовую сигнатуру машинного кода и подменяет инструкцию ветвления:

* **ARM64 (Apple Silicon):** `ldrb w1, [x0, #8]` (`\x01\x20\x40\x39`) заменяется на `movz w1, #1` (`\x21\x00\x80\x52`), заставляя проверку всегда возвращать `true`.
* **x86_64 (Intel):** `cmp byte [rax+8], 0` заменяется на `test rax, rax; nop`.
* **macOS Ad-hoc Code Signing:** после модификации бинарника накладывается ad-hoc цифровая подпись (`codesign --force --sign -`), предотвращая аварийное завершение процесса ядром macOS.

---

## 🚀 Быстрый старт (Автоматизация навсегда)

Чтобы патч накатывался **автоматически при каждом обновлении** `agy`:

```bash
git clone git@github.com:petqa/g-patcher.git
cd g-patcher
chmod +x install.sh patch.py
./install.sh
```

### Что делает инсталлер:
1. Копирует скрипт в `~/.gemini/scripts/patch-agy.py`.
2. Пропатчивает текущий бинарник `~/.local/bin/agy`.
3. Создает системный сервис **macOS `launchd`** (`ru.petqa.agy-autopatch.plist`) с директивой `WatchPaths`. Как только `agy` обновляется (перезаписывается на диске), `launchd` мгновенно запускает патчер в фоне.
4. Добавляет функцию-гард в `~/.zshrc`:
   ```bash
   agy() {
       ~/.gemini/scripts/patch-agy.py --silent 2>/dev/null
       command agy "$@"
   }
   ```

---

## 🛠 Ручной запуск

Если нужно просто разово пропатчить бинарник:

```bash
# Патч дефолтного бинарника (~/.local/bin/agy или из PATH)
python3 patch.py

# Патч произвольного пути к agy
python3 patch.py /path/to/agy

# Тихий режим (для скриптов)
python3 patch.py --silent
```

---

## 🔍 Проверка работы

Выполните команду в терминале:

```bash
agy --print "ping"
# Ожидаемый ответ: pong! How can I help you today?
```

Если ответ получен без ошибок `Eligibility check failed` — всё работает штатно!
