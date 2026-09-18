#!/usr/bin/env python3
"""Compile this project's simple string catalog for the direct swiftc build.

Xcode compiles the same catalog natively. Reject unsupported variation/plural
entries instead of silently losing translations. No third-party dependencies.
"""
import json
from pathlib import Path
import sys


def compile_catalog(source, destination):
    catalog = json.loads(Path(source).read_text(encoding="utf-8"))
    translations = {"en": {}, "nl": {}}
    for key, entry in catalog["strings"].items():
        for language in translations:
            unit = entry["localizations"][language]["stringUnit"]
            if unit["state"] != "translated":
                raise ValueError(f"Untranslated entry: {language}: {key}")
            translations[language][key] = unit["value"]
    for language, entries in translations.items():
        folder = Path(destination) / f"{language}.lproj"
        folder.mkdir(parents=True, exist_ok=True)
        lines = [f"{json.dumps(key, ensure_ascii=False)} = {json.dumps(value, ensure_ascii=False)};"
                 for key, value in sorted(entries.items())]
        (folder / "Localizable.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(catalog["strings"])


if __name__ == "__main__":
    count = compile_catalog(sys.argv[1], sys.argv[2])
    print(f"Compiled {count} strings in English and Dutch")
