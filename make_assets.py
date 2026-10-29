#!/usr/bin/env python3
"""Regenerates the showcase images in assets/ from raw renderouts.

Usage:
    swift build -c release
    ./.build/release/PCCat --render-tests ./renderout
    python3 make_assets.py

Requires: Pillow (pip install pillow)
"""

import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "renderout")
ASSETS = os.path.join(HERE, "assets")


def load(name, size=(256, 256)):
    return Image.open(os.path.join(OUT, f"{name}.png")).convert("RGB").resize(size, Image.LANCZOS)


def save(img, name):
    img.save(os.path.join(ASSETS, name), "PNG", optimize=True)
    print(f"  {name}  {img.size[0]}x{img.size[1]}")


def card_grid(images, cols, cell, radius=26):
    """Tiles images into rounded white cards on a soft background."""
    gap = max(14, cell // 16)
    rows = (len(images) + cols - 1) // cols
    W = cols * cell + (cols + 1) * gap
    H = rows * cell + (rows + 1) * gap
    canvas = Image.new("RGB", (W, H), (240, 241, 246))

    for i, im in enumerate(images):
        r, c = divmod(i, cols)
        x = gap + c * (cell + gap)
        y = gap + r * (cell + gap)

        card = Image.new("RGB", (cell, cell), (253, 253, 255))
        mask = Image.new("L", (cell, cell), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, cell - 1, cell - 1], radius=radius, fill=255)

        inset = 12
        im2 = im.resize((cell - inset * 2, cell - inset * 2), Image.LANCZOS)
        inner = Image.new("L", im2.size, 0)
        ImageDraw.Draw(inner).rounded_rectangle(
            [0, 0, im2.size[0] - 1, im2.size[1] - 1], radius=radius - 6, fill=255
        )
        card.paste(im2, (inset, inset), inner)
        canvas.paste(card, (x, y), mask)

    return canvas


def main():
    os.makedirs(ASSETS, exist_ok=True)
    print("rendered assets ->", ASSETS)
    save(load("pose-sitting", (600, 600)), "hero.png")

    species = [load(f"species-{s}") for s in
               ["tuxedo", "ginger", "tabby", "siamese", "calico", "midnight", "cream", "snow"]]
    save(card_grid(species, 4, 240), "species.png")

    poses = [load(f"pose-{p}") for p in
             ["standing", "sitting", "sleeping", "stretching", "playful"]]
    save(card_grid(poses, 5, 220), "poses.png")

    accessories = [load(f"accessory-{a}") for a in
                   ["scarf", "collar", "beanie", "glasses", "bowtie", "crown", "none"]]
    save(card_grid(accessories, 7, 190), "accessories.png")


if __name__ == "__main__":
    main()
