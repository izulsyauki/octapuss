#!/usr/bin/env python3
"""Check architectural boundaries and Xcode/CLI source parity without launching the app."""

import collections
import json
import pathlib
import plistlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def check() -> list[str]:
    errors = []
    sources = {str(path.relative_to(ROOT)) for path in (ROOT / "Octapuss").rglob("*.swift")}
    project = json.loads(subprocess.check_output([
        "plutil", "-convert", "json", "-o", "-", str(ROOT / "Octapuss.xcodeproj/project.pbxproj")
    ], text=True))
    objects = project["objects"]
    target = next(obj for obj in objects.values() if obj.get("isa") == "PBXNativeTarget" and obj["name"] == "Octapuss")
    compiled = []
    for phase_id in target["buildPhases"]:
        phase = objects[phase_id]
        if phase["isa"] == "PBXSourcesBuildPhase":
            compiled.extend(objects[objects[item]["fileRef"]]["path"] for item in phase["files"])
    for path, count in collections.Counter(compiled).items():
        if count != 1:
            errors.append(f"Xcode compiles {path} {count} times")
    for path in sorted(sources - set(compiled)):
        errors.append(f"Source missing from Xcode target: {path}")
    for path in sorted(set(compiled) - sources):
        errors.append(f"Xcode refers to missing source: {path}")

    for path in sorted(sources):
        text = (ROOT / path).read_text()
        imports = set(re.findall(r"^import (\w+)", text, re.MULTILINE))
        if path.startswith("Octapuss/Models/"):
            if imports - {"Foundation"}:
                errors.append(f"Models must remain independent of UI/platform frameworks: {path}")
            if re.search(r"\b(AppStore|UserDefaults|SystemCursorSession|SystemCursorAPI|AppPalette)\b", text):
                errors.append(f"Model depends on application or infrastructure: {path}")
        if path.startswith(("Octapuss/Platform/", "Octapuss/Persistence/")) and "SwiftUI" in imports:
            errors.append(f"Infrastructure must not depend on SwiftUI: {path}")
        if path.startswith("Octapuss/Features/"):
            if re.search(r"\b(SystemCursorAPI|SystemCursorSession|CursorJournal|CursorFileDecoder|FileManager)\b", text):
                errors.append(f"View bypasses application ownership: {path}")
        if path == "Octapuss/Application/AppStore.swift":
            if re.search(r"\b(NSOpenPanel|CursorFileDecoder|FileManager)\b", text):
                errors.append("AppStore must delegate native panels, file decoding and disk access")

    info_path = "Octapuss/Resources/Info.plist"
    with (ROOT / info_path).open("rb") as stream:
        executable = plistlib.load(stream)["CFBundleExecutable"]
    configurations = objects[target["buildConfigurationList"]]["buildConfigurations"]
    for config_id in configurations:
        config = objects[config_id]
        settings = config["buildSettings"]
        if settings.get("INFOPLIST_FILE") != info_path or settings.get("EXECUTABLE_NAME") != executable:
            errors.append(f"{config['name']}: app plist/executable differs from the local builder")
    return errors


def main() -> int:
    try:
        errors = check()
    except (OSError, KeyError, ValueError, StopIteration, subprocess.CalledProcessError) as error:
        print(f"Architecture check could not inspect the project: {error}", file=sys.stderr)
        return 1
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Architecture checks passed: model isolation, UI boundaries, Xcode/CLI source parity and app executable.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
