#!/usr/bin/env python3
from pathlib import Path
import re
import sys

def signature(text: str):
    lines = text.splitlines()
    return {
        "h2": sum(1 for line in lines if line.startswith("## ")),
        "h3": sum(1 for line in lines if line.startswith("### ")),
        "fences": sum(1 for line in lines if line.startswith("```")),
        "tables": sum(1 for line in lines if line.startswith("|---")),
        "numbered": sum(1 for line in lines if re.match(r"^\d+\. ", line)),
        "commands": sum(1 for line in lines if line.startswith(("su -c ", "adb ", "./", "sha256sum "))),
    }

en = Path("README.md").read_text(encoding="utf-8")
ru = Path("README_RU.md").read_text(encoding="utf-8")

sig_en = signature(en)
sig_ru = signature(ru)

if sig_en != sig_ru:
    print(f"README structure mismatch: EN={sig_en}, RU={sig_ru}", file=sys.stderr)
    raise SystemExit(1)

required_en = "Russian</a> · <a href=\"https://github.com/lolokeksu/F2FS-Guardian/releases\">Release</a> · <a href=\"SECURITY.md\">Security"
required_ru = "English</a> · <a href=\"https://github.com/lolokeksu/F2FS-Guardian/releases\">Релизы</a> · <a href=\"https://github.com/lolokeksu/F2FS-Guardian/issues\">Проблема</a> · <a href=\"SECURITY.md\">Безопасность"

if required_en not in en:
    print("English navigation is incorrect", file=sys.stderr)
    raise SystemExit(1)

if required_ru not in ru:
    print("Russian navigation is incorrect", file=sys.stderr)
    raise SystemExit(1)

if "docs/assets/banner.svg" not in en or "docs/assets/banner.svg" not in ru:
    print("SVG banner is missing", file=sys.stderr)
    raise SystemExit(1)

print("PASS: README.md and README_RU.md have matching structure and content scope")
print(sig_en)
