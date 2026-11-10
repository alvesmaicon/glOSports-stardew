#!/usr/bin/env python3
"""The app's own icon, before the game's title logo takes its place (import.sh): app/icon.png, 240x160 like the
icon made from the game, on the same sky. Pixel art drawn at 1/4 size and scaled up. Needs Pillow.
  tools/icon.py [out.png]
"""
import math
import sys
from PIL import Image

W, H, S = 60, 40, 4
img = Image.new("RGB", (W, H))
px = img.load()
for y in range(H):
    t = y / (H - 1)
    for x in range(W):
        px[x, y] = (int(64 + t * 62), int(120 + t * 66), int(222 + t * 20))

def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c

# sun and two clouds
for y in range(4, 13):
    for x in range(44, 53):
        if (x - 48) ** 2 + (y - 8) ** 2 <= 16:
            put(x, y, (255, 222, 98) if (x - 48) ** 2 + (y - 8) ** 2 <= 9 else (255, 236, 160))
for cx, cy in ((10, 7), (28, 4)):
    for dx, dy, w in ((0, 1, 9), (2, 0, 5), (1, 2, 7)):
        for i in range(w):
            put(cx + dx + i, cy + dy, (250, 252, 255))

# far hill, near hill
for x in range(W):
    far = int(22 + 4 * math.sin(x / 9.0 + 0.6))
    near = int(27 + 3 * math.sin(x / 7.0 + 2.2))
    for y in range(far, H):
        put(x, y, (92, 170, 76))
    for y in range(near, H):
        put(x, y, (70, 146, 58) if (x + y) % 7 else (60, 132, 50))

# tilled rows and a sprout
for r in range(3):
    y = 31 + r * 3
    for x in range(8 + r * 2, 52 - r * 2):
        put(x, y, (122, 82, 48))
        put(x, y + 1, (98, 64, 38))
sx, sy = 29, 30
for y in range(sy - 6, sy + 1):
    put(sx, y, (96, 196, 70))
for dx, dy in ((-1, -4), (-2, -5), (-3, -5), (-2, -4), (1, -6), (2, -7), (3, -7), (2, -6)):
    put(sx + dx, sy + dy, (130, 222, 92))

img.resize((W * S, H * S), Image.NEAREST).save(sys.argv[1] if len(sys.argv) > 1 else "app/icon.png", optimize=True)
