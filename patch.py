#!/usr/bin/env python3
"""
g-patcher: Автоматический байт-патчер для Antigravity CLI (agy).
Снимает региональные ограничения ("Eligibility check failed: Your current account is not eligible for Antigravity...").
Поддерживает macOS ARM64 (Apple Silicon) и x86_64 (Intel).
"""

import os
import sys
import re
import shutil
import subprocess

DEFAULT_AGY_PATH = os.path.expanduser("~/.local/bin/agy")

# ARM64 Gate:
#   cbnz x1,error ; cbz x0,eligible ; ldrb w1,[x0,#8] ; tbnz w1,#0,eligible
#   bl failure_builder
# Подменяет ldrb w1,[x0,#8] (\x01\x20\x40\x39) на movz w1,#1 (\x21\x00\x80\x52)
SIG_ARM64 = rb"...\xb5...\xb4\x01\x20\x40\x39...\x37"
PAT_ARM64 = rb"...\xb5...\xb4\x21\x00\x80\x52...\x37"
FIX_ARM64 = b"\x21\x00\x80\x52"
OFFSET_ARM64 = 8

# x86_64 Gate:
#   test rax,rax ; je eligible ; cmp byte[rax+8],0 ; jne eligible ; call failure_builder
# Подменяет cmp byte[rax+8],0 (\x80\x78\x08\x00) на test rax,rax; nop (\x48\x85\xc0\x90)
SIG_X64 = rb"\x48\x85\xc0\x0f\x84....\x80\x78\x08\x00\x0f\x85...."
PAT_X64 = rb"\x48\x85\xc0\x0f\x84....\x48\x85\xc0\x90\x0f\x85...."
FIX_X64 = b"\x48\x85\xc0\x90"
OFFSET_X64 = 9


def find_agy_binary():
    # 1. PATH lookup
    w = shutil.which("agy")
    if w and os.path.isfile(w):
        return os.path.abspath(w)

    # 2. Стандартные пути
    candidates = [
        DEFAULT_AGY_PATH,
        os.path.expanduser("~/bin/agy"),
        "/usr/local/bin/agy",
        "/opt/antigravity/bin/agy",
    ]
    for c in candidates:
        if os.path.isfile(c):
            return os.path.abspath(c)

    return DEFAULT_AGY_PATH


def patch_binary(path, silent=False):
    if not os.path.isfile(path):
        if not silent:
            print(f"[!] Бинарник не найден: {path}", file=sys.stderr)
        return False

    with open(path, "rb") as f:
        data = f.read()

    # Проверка ARM64
    if re.search(PAT_ARM64, data, re.S):
        if not silent:
            print(f"[*] {path} уже пропатчен (ARM64).")
        return True

    matches_arm64 = list(re.finditer(SIG_ARM64, data, re.S))
    if matches_arm64:
        if not silent:
            print(f"[*] Найдено {len(matches_arm64)} ARM64 eligibility gate(s). Патчим...")
        bdata = bytearray(data)
        for m in matches_arm64:
            off = m.start() + OFFSET_ARM64
            bdata[off : off + len(FIX_ARM64)] = FIX_ARM64

        tmp_path = f"{path}.tmp.{os.getpid()}"
        with open(tmp_path, "wb") as f:
            f.write(bdata)
        os.chmod(tmp_path, 0o755)
        os.replace(tmp_path, path)

        # Ad-hoc codesign на macOS обязателен после правки байтов
        if sys.platform == "darwin":
            subprocess.run(
                ["codesign", "--force", "--sign", "-", path],
                check=True,
                capture_output=True,
            )

        if not silent:
            print(f"[+] Успешно пропатчен и переподписан: {path} (ARM64)")
        return True

    # Проверка x86_64
    if re.search(PAT_X64, data, re.S):
        if not silent:
            print(f"[*] {path} уже пропатчен (x86_64).")
        return True

    matches_x64 = list(re.finditer(SIG_X64, data, re.S))
    if matches_x64:
        if not silent:
            print(f"[*] Найдено {len(matches_x64)} x86_64 eligibility gate(s). Патчим...")
        bdata = bytearray(data)
        for m in matches_x64:
            off = m.start() + OFFSET_X64
            bdata[off : off + len(FIX_X64)] = FIX_X64

        tmp_path = f"{path}.tmp.{os.getpid()}"
        with open(tmp_path, "wb") as f:
            f.write(bdata)
        os.chmod(tmp_path, 0o755)
        os.replace(tmp_path, path)

        if sys.platform == "darwin":
            subprocess.run(
                ["codesign", "--force", "--sign", "-", path],
                check=True,
                capture_output=True,
            )

        if not silent:
            print(f"[+] Успешно пропатчен и переподписан: {path} (x86_64)")
        return True

    if not silent:
        print("[!] Сигнатура проверки региона не найдена (неподдерживаемый билд?).", file=sys.stderr)
    return False


if __name__ == "__main__":
    silent = "--silent" in sys.argv or "-q" in sys.argv
    target = None

    for arg in sys.argv[1:]:
        if not arg.startswith("-"):
            target = os.path.abspath(os.path.expanduser(arg))
            break

    if not target:
        target = find_agy_binary()

    success = patch_binary(target, silent=silent)
    sys.exit(0 if success else 1)
