#!/usr/bin/env python3
"""Objective image metrics for stage art review.

Usage: art_metrics.py DIRECTORY STAGE [STAGE ...]
Reads DIRECTORY/<stage>-chase-*.png produced by stage_art_capture.gd and prints
one JSON object per stage with the mean of each metric across chase frames.
"""
import glob
import json
import sys

import numpy as np
from PIL import Image


def metrics(path: str) -> dict:
    rgb = np.asarray(Image.open(path).convert("RGB").resize((640, 360)), dtype=np.float32) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
    # Sky: bright, blue-dominant or very light pixels in the upper frame.
    sky = (b > r + 0.04) & (b > 0.45)
    height = luma.shape[0]
    lower = slice(int(height * 0.45), height)
    # Detail: share of strong luminance edges below the horizon band.
    gx = np.abs(np.diff(luma[lower], axis=1))[:-1, :]
    gy = np.abs(np.diff(luma[lower], axis=0))[:, :-1]
    edges = float(((gx + gy) > 0.06).mean())
    # Hasler-Suesstrunk colourfulness.
    rg, yb = r - g, 0.5 * (r + g) - b
    colourful = float(np.sqrt(rg.std() ** 2 + yb.std() ** 2) + 0.3 * np.sqrt(rg.mean() ** 2 + yb.mean() ** 2))
    # Hue spread across 12 bins of saturated pixels: palettes with several families score higher.
    maxc, minc = rgb.max(axis=2), rgb.min(axis=2)
    sat = (maxc - minc) / np.maximum(maxc, 1e-4)
    hue = np.zeros_like(maxc)
    delta = np.maximum(maxc - minc, 1e-4)
    hue = np.where(maxc == r, ((g - b) / delta) % 6, hue)
    hue = np.where(maxc == g, (b - r) / delta + 2, hue)
    hue = np.where(maxc == b, (r - g) / delta + 4, hue)
    mask = sat > 0.25
    histogram = np.bincount((hue[mask] * 2).astype(int).clip(0, 11), minlength=12).astype(np.float64)
    histogram /= max(histogram.sum(), 1)
    hue_families = int((histogram > 0.04).sum())
    return {
        "contrast": float(luma.std()),
        "ground_detail": edges,
        "colourfulness": colourful,
        "hue_families": hue_families,
        "sky_fraction": float(sky.mean()),
    }


def main() -> None:
    directory, stages = sys.argv[1], sys.argv[2:]
    for stage in stages:
        frames = [metrics(path) for path in sorted(glob.glob(f"{directory}/{stage}-chase-*.png"))]
        summary = {key: round(float(np.mean([frame[key] for frame in frames])), 4) for key in frames[0]}
        summary["minimum_ground_detail"] = round(min(frame["ground_detail"] for frame in frames), 4)
        print(json.dumps({"stage": stage, "frames": len(frames), **summary}))


if __name__ == "__main__":
    main()
