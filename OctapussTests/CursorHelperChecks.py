"""Check packaged helper behavior without writing any system cursor registrations."""
import json
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import time
import uuid

app = pathlib.Path(sys.argv[1])
bundle = app / "Contents/Helpers/OctapussCursorHelper.app"
helper = bundle / "Contents/MacOS/OctapussCursorHelper"
with (bundle / "Contents/Info.plist").open("rb") as source:
    info = plistlib.load(source)
assert info["LSBackgroundOnly"] is True
assert info["CFBundleIdentifier"] == "dev.octapuss.cursorhelper"

def run(*arguments, status=0):
    result = subprocess.run([str(helper), *arguments], capture_output=True, text=True, timeout=20)
    assert result.returncode == status, (arguments, result.returncode, result.stdout, result.stderr)
    return result.stdout

assert "prohibited activation, no windows" in run("--cursor-helper-check")
run(status=64)
run("--invalid-helper-command", status=64)
snapshots = json.loads(run("--cursor-read-many", "com.apple.coregraphics.Arrow"))
assert len(snapshots) == 1 and snapshots[0]["name"] == "com.apple.coregraphics.Arrow"
assert snapshots[0]["images"]

with tempfile.TemporaryDirectory(prefix="octapuss-helper-check-") as directory:
    journal = pathlib.Path(directory) / "session.json"
    session = str(uuid.uuid4()).upper()
    ready = pathlib.Path(str(journal) + ".ready-" + session)
    worker = subprocess.Popen([str(helper), "--cursor-watchdog", str(journal), session],
                              stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        deadline = time.monotonic() + 10
        while not ready.exists() and time.monotonic() < deadline and worker.poll() is None:
            time.sleep(0.02)
        assert ready.exists(), "Background watchdog did not acknowledge readiness"
        worker.stdin.close()
        assert worker.wait(timeout=20) == 0, worker.stderr.read().decode()
        assert not journal.exists()
    finally:
        if worker.poll() is None:
            worker.kill()
            worker.wait()
print("Packaged helper checks passed: background policy, no windows, invalid arguments, registry read, watchdog readiness and clean exit.")
