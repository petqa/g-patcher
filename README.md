# ⚡ g-patcher

Автоматический байт-патчер для **Antigravity CLI (`agy`)**, снимающий ошибку региональных ограничений:

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

## 🚀 Быстрый старт (Установка через симлинки)

Установка связывает репозиторий с системой через **симлинки**, поэтому любые обновления кода (`git pull` или локальные правки) сразу применяются без повторной инсталляции:

```bash
git clone git@github.com:petqa/g-patcher.git
cd g-patcher
chmod +x install.sh uninstall.sh patch.py
./install.sh
```

### Что настраивает инсталлер:
1. **Симлинки на скрипт:**
   * `~/.local/bin/g-patcher` → `$REPO_DIR/patch.py` (утилита доступна глобально в терминале).
   * `~/.gemini/scripts/patch-agy.py` → `$REPO_DIR/patch.py`.
2. **Системный фоновый демон macOS (`launchd`):**
   * Создает симлинк `~/Library/LaunchAgents/ru.petqa.agy-autopatch.plist` → `$REPO_DIR/ru.petqa.agy-autopatch.plist`.
   * Следит через директиву `WatchPaths` за файлом `~/.local/bin/agy`.
   * **Как только `agy` обновляется или перезаписывается**, `launchd` автоматически вызывает патчер в фоне за ~10 мс.
3. **Функция-гард в `~/.zshrc`:**
   ```bash
   agy() {
       ~/.local/bin/g-patcher --silent 2>/dev/null
       command agy "$@"
   }
   ```
   Страховка для интерактивного шелла: если вы только что обновили CLI и сразу запустили `agy`, бинарник проверяется прямо перед стартом.

---

## 🛠 Использование CLI (`g-patcher`)

После установки команда `g-patcher` доступна глобально:

```bash
# Проверить и пропатчить дефолтный бинарник (~/.local/bin/agy или из PATH)
g-patcher

# Пропатчить конкретный файл
g-patcher /path/to/agy

# Тихий режим (для cron / скриптов)
g-patcher --silent
```

---

## 🧹 Удаление

Чтобы снять симлинки и выгрузить сервис `launchd`:

```bash
./uninstall.sh
```
