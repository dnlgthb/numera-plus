"""
Limpia los sprites del mago removiendo el fondo gris claro ~RGB(230,230,233).
Usa flood-fill basado en color desde los bordes de la imagen para detectar
todos los píxeles del fondo, incluyendo los opacos.
Luego aplica defringe para suavizar los bordes.
"""
import os
import shutil
from collections import deque
from PIL import Image
import numpy as np

SPRITES_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
BACKUP_DIR = os.path.join(SPRITES_DIR, 'backup')

SPRITE_FILES = [
    'mage_idle.png',
    'mage_casting.png',
    'mage_hit.png',
    'mage_defeated.png',
    'mage_victory.png',
    'mage_victory2.png',
]

BG_COLOR = np.array([230, 230, 233], dtype=np.float64)
COLOR_TOLERANCE = 30
DEFRINGE_TOLERANCE = 45


def is_bg_color(r, g, b, a, tolerance=COLOR_TOLERANCE):
    """Check if a pixel's color is close to the background gray."""
    if a == 0:
        return True
    diff = abs(float(r) - BG_COLOR[0]) + abs(float(g) - BG_COLOR[1]) + abs(float(b) - BG_COLOR[2])
    return diff < tolerance


def flood_fill_bg(data):
    """Flood fill from all edges to find connected background pixels."""
    h, w = data.shape[:2]
    bg_mask = np.zeros((h, w), dtype=bool)
    visited = np.zeros((h, w), dtype=bool)
    queue = deque()

    # Seed with all edge pixels that are either transparent or bg-colored
    for x in range(w):
        for y in [0, h - 1]:
            r, g, b, a = data[y, x]
            if is_bg_color(r, g, b, a):
                queue.append((y, x))
    for y in range(h):
        for x in [0, w - 1]:
            r, g, b, a = data[y, x]
            if is_bg_color(r, g, b, a):
                queue.append((y, x))

    while queue:
        y, x = queue.popleft()
        if y < 0 or y >= h or x < 0 or x >= w:
            continue
        if visited[y, x]:
            continue
        visited[y, x] = True

        r, g, b, a = data[y, x]
        if is_bg_color(r, g, b, a):
            bg_mask[y, x] = True
            queue.append((y - 1, x))
            queue.append((y + 1, x))
            queue.append((y, x - 1))
            queue.append((y, x + 1))

    return bg_mask


def defringe(data, bg_mask):
    """Remove halo: pixels at the border of bg that blend character+background."""
    h, w = data.shape[:2]
    result = data.copy()

    # Find pixels that are NOT background but border background pixels
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if bg_mask[y, x]:
                continue
            a = result[y, x, 3]
            if a == 0:
                continue

            # Check if borders a background pixel
            borders_bg = (bg_mask[y-1, x] or bg_mask[y+1, x] or
                          bg_mask[y, x-1] or bg_mask[y, x+1])
            if not borders_bg:
                continue

            r, g, b = float(result[y, x, 0]), float(result[y, x, 1]), float(result[y, x, 2])
            brightness = r * 0.299 + g * 0.587 + b * 0.114

            # Very bright border pixels -> likely background bleed
            if brightness > 210:
                result[y, x, 3] = 0
            elif brightness > 180:
                # Make semi-transparent for smooth edge
                result[y, x, 3] = int(a * 0.4)
            elif brightness > 150:
                result[y, x, 3] = int(a * 0.7)

    return result


def second_pass_defringe(data, original_bg_mask):
    """Second pass: now that some pixels were made transparent, check new borders."""
    h, w = data.shape[:2]
    result = data.copy()

    for y in range(1, h - 1):
        for x in range(1, w - 1):
            a = result[y, x, 3]
            if a == 0:
                continue

            # Check if borders a now-transparent pixel
            borders_transparent = (result[y-1, x, 3] == 0 or result[y+1, x, 3] == 0 or
                                   result[y, x-1, 3] == 0 or result[y, x+1, 3] == 0)
            if not borders_transparent:
                continue

            r, g, b = float(result[y, x, 0]), float(result[y, x, 1]), float(result[y, x, 2])
            brightness = r * 0.299 + g * 0.587 + b * 0.114

            if brightness > 220:
                result[y, x, 3] = 0
            elif brightness > 200:
                result[y, x, 3] = int(a * 0.3)

    return result


def clean_sprite(img_path, output_path):
    img = Image.open(img_path).convert('RGBA')
    data = np.array(img, dtype=np.uint8)

    # Step 1: Flood fill from edges to find all connected background
    bg_mask = flood_fill_bg(data)
    data[bg_mask, 3] = 0

    # Step 2: Defringe - clean halo pixels at character border
    data = defringe(data, bg_mask)

    # Step 3: Second pass defringe (catches pixels exposed by first pass)
    data = second_pass_defringe(data, bg_mask)

    # Step 4: Clean isolated bright pixels
    h, w = data.shape[:2]
    alpha = data[:, :, 3].copy()
    for y in range(2, h - 2):
        for x in range(2, w - 2):
            if alpha[y, x] == 0 or alpha[y, x] == 255:
                continue
            # Count transparent neighbors in 5x5
            patch_alpha = alpha[y-2:y+3, x-2:x+3]
            if np.sum(patch_alpha == 0) > 15:
                data[y, x, 3] = 0

    result = Image.fromarray(data, 'RGBA')
    result.save(output_path, 'PNG', optimize=True)


def main():
    os.makedirs(BACKUP_DIR, exist_ok=True)

    for filename in SPRITE_FILES:
        src = os.path.join(BACKUP_DIR, filename)
        dst = os.path.join(SPRITES_DIR, filename)

        if not os.path.exists(src):
            src = dst
            if not os.path.exists(src):
                print(f"  SKIP: {filename}")
                continue
            shutil.copy2(src, os.path.join(BACKUP_DIR, filename))
            print(f"  Backup: {filename}")

        print(f"  Cleaning: {filename}...", end=' ', flush=True)
        clean_sprite(src, dst)
        print("OK")

    print("\nDone!")


if __name__ == '__main__':
    main()
