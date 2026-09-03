#!/usr/bin/env python3
"""
g-patcher: Автоматический мульти-компонентный патчер для экосистемы Antigravity.
Базируется на логике open-antigravity-patcher.

Поддерживаемые компоненты:
1. Antigravity CLI (agy)
2. Antigravity 2.0 (language_server)
3. Antigravity IDE (Electron main.js)
4. Antigravity VS Code / Cursor Extension (extension.js)
"""

import os
import sys

# Добавляем корень репозитория в sys.path для импорта модулей patcher
REPO_DIR = os.path.dirname(os.path.abspath(__file__))
if REPO_DIR not in sys.path:
    sys.path.insert(0, REPO_DIR)

from patcher.agy.discovery import find_agy_binary, resolve_agy_path
from patcher.agy.patcher import get_status as get_agy_status, do_patch_agy
from patcher.manager.discovery import find_manager_binary, resolve_manager_path
from patcher.manager.patcher import get_status as get_mgr_status, do_patch_manager
from patcher.ide.discovery import find_install_root, find_main_js, resolve_target_path as resolve_ide_path
from patcher.ide.patcher import is_already_patched as is_ide_patched, do_patch as do_patch_ide
from patcher.vscode.discovery import find_extension_js, resolve_extension_path
from patcher.vscode.patcher import is_already_patched as is_vscode_patched, do_patch_vscode


def print_status(component, path, status, silent=False):
    if silent:
        return
    status_icon = "✓" if status == "patched" else ("✗" if status == "unpatched" else "?")
    print(f"[{status_icon}] {component}: {status} ({path})")


def patch_component(name, path, get_status_fn, do_patch_fn, silent=False):
    if not path or not os.path.exists(path):
        return False

    status, _ = get_status_fn(path) if callable(get_status_fn) else (get_status_fn, None)

    if status == "patched":
        if not silent:
            print(f"[*] {name}: уже пропатчен ({path})")
        return True
    elif status == "unpatched":
        if not silent:
            print(f"[→] {name}: найден непопатченный ({path}), патчим...")
        try:
            do_patch_fn(path)
            return True
        except PermissionError:
            if not silent:
                print(f"[!] Недостаточно прав для {name} ({path}). Попробуйте: sudo g-patcher", file=sys.stderr)
            return False
        except Exception as e:
            if not silent:
                if "Operation not permitted" in str(e) or "Permission denied" in str(e):
                    print(f"[!] Недостаточно прав для {name} ({path}). Попробуйте: sudo g-patcher", file=sys.stderr)
                else:
                    print(f"[!] Ошибка патча {name}: {e}", file=sys.stderr)
            return False
    else:
        if not silent:
            print(f"[?] {name}: неизвестный статус ({path})")
        return False


def run_auto_patch(silent=False):
    found_any = False

    # 1. Antigravity CLI (agy)
    agy = find_agy_binary()
    if agy and os.path.isfile(agy):
        found_any = True
        patch_component("Antigravity CLI (agy)", agy, get_agy_status, do_patch_agy, silent=silent)

    # 2. Antigravity 2.0 (language_server)
    mgr = find_manager_binary()
    if mgr and os.path.isfile(mgr):
        found_any = True
        patch_component("Antigravity 2.0 (language_server)", mgr, get_mgr_status, do_patch_manager, silent=silent)

    # 3. Antigravity IDE (main.js)
    ide_root = find_install_root()
    ide_main = find_main_js(ide_root) if ide_root else ""
    if ide_main and os.path.isfile(ide_main):
        found_any = True
        def get_ide_status_wrapper(p):
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            return "patched" if is_ide_patched(content) else "unpatched"
        patch_component("Antigravity IDE (main.js)", ide_main, get_ide_status_wrapper, do_patch_ide, silent=silent)

    # 4. Antigravity VS Code Extension
    ext_js = find_extension_js()
    if ext_js and os.path.isfile(ext_js):
        found_any = True
        def get_vscode_status_wrapper(p):
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            return "patched" if is_vscode_patched(content) else "unpatched"
        patch_component("VS Code Extension", ext_js, get_vscode_status_wrapper, do_patch_vscode, silent=silent)

    if not found_any and not silent:
        print("[!] Компоненты Antigravity не найдены в стандартных путях системы.")


def run_status_check():
    print("==> Проверка компонентов Antigravity в системе:\n")

    # CLI
    agy = find_agy_binary()
    if agy:
        st, _ = get_agy_status(agy)
        print_status("Antigravity CLI (agy)", agy, st)
    else:
        print("[-] Antigravity CLI (agy): не найден")

    # Manager
    mgr = find_manager_binary()
    if mgr:
        st, _ = get_mgr_status(mgr)
        print_status("Antigravity 2.0 (language_server)", mgr, st)
    else:
        print("[-] Antigravity 2.0 (language_server): не найден")

    # IDE
    ide_root = find_install_root()
    ide_main = find_main_js(ide_root) if ide_root else ""
    if ide_main:
        with open(ide_main, "r", encoding="utf-8", errors="ignore") as f:
            st = "patched" if is_ide_patched(f.read()) else "unpatched"
        print_status("Antigravity IDE (main.js)", ide_main, st)
    else:
        print("[-] Antigravity IDE (main.js): не найден")

    # VS Code Extension
    ext_js = find_extension_js()
    if ext_js:
        with open(ext_js, "r", encoding="utf-8", errors="ignore") as f:
            st = "patched" if is_vscode_patched(f.read()) else "unpatched"
        print_status("VS Code Extension", ext_js, st)
    else:
        print("[-] VS Code Extension: не найдено")


def main():
    args = sys.argv[1:]
    silent = "--silent" in args or "-q" in args

    if "--status" in args or "-s" in args:
        run_status_check()
        return

    if "--interactive" in args or "-i" in args:
        from patcher.cli import run_cli
        run_cli()
        return

    # Если указан конкретный путь:
    custom_target = None
    for a in args:
        if not a.startswith("-"):
            custom_target = os.path.abspath(os.path.expanduser(a))
            break

    if custom_target:
        if not os.path.exists(custom_target):
            print(f"[!] Файл или каталог не найден: {custom_target}", file=sys.stderr)
            sys.exit(1)

        # Авто-определение типа цели
        name = os.path.basename(custom_target).lower()
        if name.startswith("agy") or name.startswith("antigravity"):
            do_patch_agy(custom_target)
        elif name.startswith("language_server"):
            do_patch_manager(custom_target)
        elif name == "main.js" or custom_target.endswith(".app"):
            resolved = resolve_ide_path(custom_target)
            if resolved:
                do_patch_ide(resolved)
            else:
                print(f"[!] Не удалось найти main.js в {custom_target}", file=sys.stderr)
        elif name == "extension.js":
            do_patch_vscode(custom_target)
        else:
            # Пробуем как agy бинарник
            do_patch_agy(custom_target)
        return

    # По умолчанию — сканируем и патчим все обнаруженные компоненты
    run_auto_patch(silent=silent)


if __name__ == "__main__":
    main()
