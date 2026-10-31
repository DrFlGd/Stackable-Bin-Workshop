#!/usr/bin/env python3
"""Render every part-to-part intersection of stackable_bin.scad and fail if
any two parts overlap.

Usage: python3 tools/fit_check.py [path/to/stackable_bin.scad]
"""
import os
import re
import subprocess
import sys
import tempfile

SCAD = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "stackable_bin.scad")
PRESETS = ["S", "M", "L"]
LID_ANGLES = [0, 30, 60, 90, 140]
MAX_OVERLAP_MM3 = 0.5  # surfaces that only touch can leave slivers


def stl_volume(path):
    verts = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("vertex"):
                verts.append(tuple(map(float, line.split()[1:])))
    vol = 0.0
    for a, b, c in zip(verts[0::3], verts[1::3], verts[2::3]):
        vol += (a[0] * (b[1] * c[2] - b[2] * c[1])
                - a[1] * (b[0] * c[2] - b[2] * c[0])
                + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6
    return abs(vol)


def run(defines):
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "overlap.stl")
        cmd = ["openscad", "-o", out, "--export-format", "asciistl",
               "-D", 'output="fit_check"']
        for k, v in defines.items():
            cmd += ["-D", f"{k}={v}"]
        cmd.append(SCAD)
        proc = subprocess.run(cmd, capture_output=True, text=True)
        log = proc.stdout + proc.stderr
        if "top level object is empty" in log:
            return 0.0, log
        if proc.returncode != 0 or not os.path.exists(out):
            raise RuntimeError(f"openscad failed for {defines}:\n{log}")
        return stl_volume(out), log


def main():
    failures = 0
    for preset in PRESETS:
        base = {"preset": f'"{preset}"', "include_lid": "true"}
        cases = [dict(base, lid_open_angle=a) for a in LID_ANGLES]
        _, log = run(dict(base, fit_stacked="true"))
        limit = int(re.search(r"stacked_lid_limit = (\d+)", log).group(1))
        cases += [dict(base, fit_stacked="true", lid_open_angle=a)
                  for a in (0, limit)]
        # Every optional part at once: catch rail, label holder, dividers.
        full = dict(base, include_label="true", divider_cols=2, divider_rows=1)
        cases += [dict(full, lid_open_angle=a) for a in (0, 90)]
        cases += [dict(full, fit_stacked="true", lid_open_angle=0)]
        for case in cases:
            vol, _ = run(case)
            ok = vol <= MAX_OVERLAP_MM3
            failures += not ok
            label = ", ".join(f"{k}={v}" for k, v in case.items())
            print(f"{'ok  ' if ok else 'FAIL'} {label}: overlap {vol:.2f} mm3")
    if failures:
        print(f"{failures} case(s) have overlapping parts")
        sys.exit(1)


if __name__ == "__main__":
    main()
