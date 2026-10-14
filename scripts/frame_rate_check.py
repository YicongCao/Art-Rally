#!/usr/bin/env python3
"""Run the same physics-tick input trace under three virtual render rates."""
import json
import pathlib
import subprocess
import sys

engine, root = sys.argv[1:]
results = {}
for fps in (30, 60, 120):
    run = subprocess.run(
        [engine, "--headless", "--path", root, "--fixed-fps", str(fps),
         "--script", "res://tests/frame_rate_probe.gd"],
        capture_output=True, text=True, timeout=60, check=True,
    )
    output = run.stdout + run.stderr
    if "ERROR:" in output:
        raise RuntimeError(output)
    lines = [line for line in output.splitlines() if line.startswith("FRAME_PROBE: ")]
    if len(lines) != 1:
        raise RuntimeError(output)
    results[fps] = json.loads(lines[0].split(": ", 1)[1])
baseline = results[120]
for fps, sample in results.items():
    for key, reference in baseline.items():
        relative_error = abs(sample[key] - reference) / max(abs(reference), 0.001)
        if relative_error >= 0.01:
            raise AssertionError(f"{fps} FPS {key}: {relative_error:.2%} deviation")
print(json.dumps(results, indent=2))
pathlib.Path(root, "logs", "frame_rate_metrics.json").write_text(json.dumps(results, indent=2) + "\n")
print("FRAME RATE CHECK PASSED: 30/60/120 FPS within 1%")
