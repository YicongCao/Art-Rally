#!/usr/bin/env python3
"""Tile stage art captures into one review sheet.

Usage: art_contact_sheet.py OUT.png COLUMNS IMAGE [IMAGE ...]
"""
import sys
from PIL import Image


def main() -> None:
    out, columns, paths = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
    tiles = [Image.open(path).convert("RGB").resize((640, 360)) for path in paths]
    rows = (len(tiles) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * 640, rows * 360), "black")
    for index, tile in enumerate(tiles):
        sheet.paste(tile, ((index % columns) * 640, (index // columns) * 360))
    sheet.save(out)


if __name__ == "__main__":
    main()
