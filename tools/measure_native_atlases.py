"""Measure sprite bounds and write atlas coordinates; never change image pixels."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / "godot/assets/images"


def components(alpha):
    parent, boxes, areas, previous = [], [], [], []

    def root(n):
        while parent[n] != n:
            parent[n] = parent[parent[n]]
            n = parent[n]
        return n

    for y, row in enumerate(alpha):
        edges = np.flatnonzero(np.diff(np.pad(row.astype(np.int8), (1, 1))))
        current = []
        for x0, x1 in edges.reshape(-1, 2):
            n = len(parent)
            parent.append(n)
            boxes.append([int(x0), y, int(x1), y + 1])
            areas.append(int(x1 - x0))
            current.append((int(x0), int(x1), n))
            for p0, p1, p in previous:
                if p1 < x0:
                    continue
                if p0 > x1:
                    break
                r, v = root(p), root(n)
                if r != v:
                    parent[r] = v
                    b, c = boxes[v], boxes[r]
                    boxes[v] = [min(b[0], c[0]), min(b[1], c[1]), max(b[2], c[2]), max(b[3], c[3])]
                    areas[v] += areas[r]
        previous = current
    return [(box, areas[i]) for i, box in enumerate(boxes) if parent[i] == i and areas[i] > 1800]


def measure(name, columns, rows):
    image = Image.open(IMAGES / (name + ".png"))
    if image.mode != "RGBA":
        raise ValueError(f"Atlas has no alpha: {name}")
    slots = {}
    for box, area in components(np.asarray(image)[:, :, 3] > 127):
        x0, y0, x1, y1 = box
        c = min(columns - 1, int((x0 + x1) * columns / (2 * image.width)))
        r = min(rows - 1, int((y0 + y1) * rows / (2 * image.height)))
        if (r, c) not in slots or area > slots[r, c][1]:
            slots[r, c] = box, area
    if len(slots) != columns * rows:
        raise ValueError(f"Expected {columns * rows} isolated figures in {name}, got {len(slots)}")
    result = []
    for r in range(rows):
        frames = []
        for c in range(columns):
            (x0, y0, x1, y1), _ = slots[r, c]
            x0, y0 = max(0, x0 - 2), max(0, y0 - 2)
            x1, y1 = min(image.width, x1 + 2), min(image.height, y1 + 2)
            frames.append([x0, y0, x1 - x0, y1 - y0])
        result.append({"frames": frames, "canvas": [max(f[2] for f in frames), max(f[3] for f in frames)]})
    return result


if __name__ == "__main__":
    atlas = {"enemy-print-v2": measure("enemy-print-v2", 6, 5)}
    atlas["boss-print"] = measure("boss-print", 6, 4)
    atlas["market-props-print"] = measure("market-props-print", 4, 3)
    atlas["campaign-props-print-v2"] = measure("campaign-props-print-v2", 4, 3)
    atlas["chapter-icons-print"] = measure("chapter-icons-print", 4, 3)
    for character in ("keeper", "swordswoman", "alchemist"):
        name = character + "-cast-print"
        groups = measure(name, 3, 2)
        frames = groups[0]["frames"] + groups[1]["frames"]
        atlas[name] = [{"frames": frames, "canvas": [max(f[2] for f in frames), max(f[3] for f in frames)]}]
    target = ROOT / "godot/assets/data/atlas_regions.json"
    target.write_text(json.dumps(atlas, indent=2), encoding="utf-8")
    print("Measured 108 complete figures; wrote", target)
