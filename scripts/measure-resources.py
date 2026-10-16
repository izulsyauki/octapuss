"""Sample one explicitly selected Octapuss process; never records pointer/app activity."""
import argparse
import json
import pathlib
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--pid", type=int, required=True)
parser.add_argument("--seconds", type=int, default=10)
parser.add_argument("--label", required=True)
parser.add_argument("--output", type=pathlib.Path, required=True)
args = parser.parse_args()
if args.pid <= 0 or not 2 <= args.seconds <= 60:
    parser.error("Use a positive PID and a duration from 2 to 60 seconds")

def sample():
    executable = subprocess.check_output(["ps", "-p", str(args.pid), "-o", "comm="], text=True).strip()
    if pathlib.Path(executable).name != "OctapussProof":
        raise RuntimeError("Selected process is not the Octapuss app")
    values = subprocess.check_output(["ps", "-p", str(args.pid), "-o", "time=,rss="], text=True).split()
    components = [float(part) for part in values[0].split(":")]
    cpu_seconds = 0.0
    for part in components:
        cpu_seconds = cpu_seconds * 60 + part
    return {"wall_seconds": time.monotonic(), "cpu_seconds": cpu_seconds, "rss_kib": int(values[1])}

samples = [sample()]
for _ in range(args.seconds):
    time.sleep(1)
    samples.append(sample())
elapsed = samples[-1]["wall_seconds"] - samples[0]["wall_seconds"]
result = {
    "label": args.label,
    "pid": args.pid,
    "duration_seconds": round(elapsed, 3),
    "cpu_percent_one_core": round(100 * (samples[-1]["cpu_seconds"] - samples[0]["cpu_seconds"]) / elapsed, 3),
    "rss_start_mib": round(samples[0]["rss_kib"] / 1024, 3),
    "rss_end_mib": round(samples[-1]["rss_kib"] / 1024, 3),
    "rss_peak_mib": round(max(s["rss_kib"] for s in samples) / 1024, 3),
    "sample_count": len(samples),
}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result))
