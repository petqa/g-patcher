# ⚡ g-patcher

Универсальный автоматический патчер для экосистемы **Google Antigravity**, снимающий ошибку региональных ограничений:

```text
Eligibility check failed: Your current account is not eligible for Antigravity, because it is not currently available in your location.
```

Ядро и байтовые сигнатуры основаны на опенсорсном проекте [open-antigravity-patcher](https://github.com/AvenCores/open-antigravity-patcher).

---

## 📦 Поддерживаемые компоненты

`g-patcher` автоматически находит и патчит всё, что установлено в системе:

1. **Antigravity CLI (`agy`)** — машинный байт-патч проверки `isEligible` (ARM64 / x86_64) + ad-hoc `codesign`.
2. **Antigravity 2.0 (`language_server`)** — байт-патч `hasValidAuth=true` бинарника языкового сервера внутри приложения `Antigravity.app`.
3. **Antigravity IDE (`main.js`)** — Electron-патч `isGoogleInternal -> true` + очистка кэша + переподпись бандла.
4. **VS Code / Cursor / Windsurf Extensions** — патч `extension.js` (отключение сброса бинарника и проверки каналов) + патч встроенных бинарников.

---

## 🚀 Быстрый старт (Установка через симлинки)

Установка привязывает репозиторий к системе через **симлинки**, динамически настраивая пути для текущего пользователя:

```bash
git clone git@github.com:petqa/g-patcher.git
cd g-patcher
chmod +x install.sh uninstall.sh patch.py
./install.sh
```

### Что делает инсталлер:
1. **Глобальная команда в PATH:** создаёт симлинк `~/.local/bin/g-patcher` на скрипт репозитория.
2. **Автоматическое сканирование:** сразу же проверяет и патчит все установленные компоненты.
3. **Системный фоновый демон macOS (`launchd`):**
   * Создаёт LaunchAgent `~/Library/LaunchAgents/com.antigravity.autopatch.plist` с директивой `WatchPaths`.
   * Отслеживает изменения бинарников (`~/.local/bin/agy`, `language_server` и др.).
   * **При любом обновлении бинарников** демон мгновенно накатывает патч в фоне за 10 мс.
4. **Страховка в `~/.zshrc`:**
   ```bash
   agy() {
       ~/.local/bin/g-patcher --silent 2>/dev/null
       command agy "$@"
   }
   ```

---

## 🛠 Использование CLI (`g-patcher`)

После установки команда `g-patcher` доступна из любого места:

```bash
# Проверить статус всех компонентов (что установлено и пропатчено)
g-patcher --status

# Автоматически пропатчить все найденные компоненты
g-patcher

# Для компонентов в /Applications (если требуется root):
sudo g-patcher

# Открыть оригинальное интерактивное TUI-меню из апстрима:
g-patcher -i

# Пропатчить конкретный файл или приложение:
g-patcher /path/to/agy
g-patcher /Applications/Antigravity.app

# Тихий режим (для cron / скриптов):
g-patcher --silent
```

---

## 🧹 Удаление

Чисто выгружает сервис `launchd`, удаляет симлинки и убирает функции из `~/.zshrc`:

```bash
./uninstall.sh
```
