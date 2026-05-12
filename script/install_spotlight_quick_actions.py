#!/usr/bin/env python3
import json
import pathlib
import plistlib
import re
import shutil
import subprocess

APP_PATH = pathlib.Path("/Applications/iThinkQ.app")
RUNNER = APP_PATH / "Contents/Helpers/iThinkQQuickAction"
OLD_RUNNERS = (
    "/Applications/ThinkQ.app/Contents/Helpers/ThinkQQuickAction",
    "/Applications/IThinkQ.app/Contents/Helpers/IThinkQQuickAction",
)
DESTINATION = pathlib.Path("/Applications")


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\\''") + "'"


def remove_existing_quick_action_apps() -> None:
    runner_markers = (str(RUNNER), *OLD_RUNNERS)
    for app_path in DESTINATION.glob("Turn O*.app"):
        try:
            script = subprocess.check_output(["osadecompile", str(app_path)], text=True, stderr=subprocess.DEVNULL)
        except subprocess.SubprocessError:
            continue
        if any(marker in script for marker in runner_markers):
            shutil.rmtree(app_path)
            subprocess.run(["mdimport", str(DESTINATION)], check=False)


def main() -> None:
    if not RUNNER.exists():
        raise SystemExit(f"Missing quick-action runner: {RUNNER}")

    exported = subprocess.check_output(["defaults", "export", "com.xavier.ithinkq", "-"])
    preferences = plistlib.loads(exported)
    raw = preferences.get("device.customizations")
    customizations = json.loads(raw.decode()) if raw else {}

    created = []
    remove_existing_quick_action_apps()
    for device_id, customization in customizations.items():
        if not customization.get("quickActionsEnabled"):
            continue
        name = customization.get("alias") or "iThinkQ Device"
        safe_name = re.sub(r"[:/\\]+", "-", name).strip() or "iThinkQ Device"
        for state, verb in (("on", "Turn On"), ("off", "Turn Off")):
            app_path = DESTINATION / f"{verb} {safe_name}.app"
            command = " ".join([
                shell_quote(str(RUNNER)),
                "--device",
                shell_quote(device_id),
                "--state",
                shell_quote(state),
            ])
            script = f'do shell script {json.dumps(command)}\n'
            if app_path.exists():
                shutil.rmtree(app_path)
            subprocess.check_call(["osacompile", "-o", str(app_path), "-e", script])
            subprocess.check_call(["codesign", "--force", "--deep", "--sign", "-", str(app_path)])
            subprocess.run(["mdimport", str(app_path)], check=False)
            created.append(app_path)

    if not created:
        print("No enabled quick-action devices found.")
        return
    for app_path in created:
        print(app_path)


if __name__ == "__main__":
    main()
