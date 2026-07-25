#!/usr/bin/env python3
"""Regenerate launcher icons from the existing Plane mark.

The mark only ever existed as a 192px Android bitmap, and iOS was still
shipping the stock Flutter logo. Rather than redraw it, this lifts the mark out
of that bitmap as a mask and re-renders everything from it.

The mark is two-tone with straight edges, so scaling it up with NEAREST keeps
those edges exactly straight, and coming back down with LANCZOS is what
anti-aliases them. Resampling the original directly would soften every edge
instead.

    tool/gen_launcher_icons.py
"""

import json
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(
    ROOT, 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png')

# Sampled from the source: the near-black the mark has always sat on.
BACKGROUND = (1, 20, 30, 255)
MARK = (255, 255, 255, 255)

# Working resolution. Every output is downsampled from here, so this has to
# stay comfortably above the largest one — the 1024 iOS icon is composed at 4x
# before it is reduced, and anything below that leaves the source's own 192px
# stair-stepping visible on the diagonals instead of averaging it away.
WORK = 4096

ANDROID_DENSITIES = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}

# Adaptive foregrounds are 108dp canvases; the art has to stay inside the
# centre 66dp or a round mask will clip it.
ADAPTIVE_DENSITIES = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
}


def extract_mark():
    """The mark as a high-resolution alpha mask, cropped to its own bounds."""
    src = Image.open(SOURCE).convert('RGBA')
    w, h = src.size
    px = src.load()

    mask = Image.new('L', (w, h), 0)
    mpx = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            mpx[x, y] = 255 if (a > 128 and r > 150 and g > 150) else 0

    mask = mask.crop(mask.getbbox())
    # NEAREST first: the edges are straight lines, and this keeps them that way.
    scale = max(1, WORK // max(mask.size))
    return mask.resize(
        (mask.width * scale, mask.height * scale), Image.NEAREST)


def compose(mark, size, coverage, background):
    """Mark centred on a square, occupying `coverage` of the width."""
    canvas = Image.new('RGBA', (size, size), background)

    target_w = int(round(size * coverage))
    target_h = int(round(mark.height * target_w / mark.width))
    scaled = mark.resize((target_w, target_h), Image.LANCZOS)

    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    layer.paste(
        Image.new('RGBA', scaled.size, MARK),
        ((size - target_w) // 2, (size - target_h) // 2),
        scaled,
    )
    return Image.alpha_composite(canvas, layer)


def rounded(image, radius_ratio=0.22):
    """Legacy launchers draw the bitmap as-is, so it carries its own corners."""
    size = image.width
    radius = int(size * radius_ratio)
    mask = Image.new('L', (size, size), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(image, (0, 0), mask)
    return out


def write(path, image):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print('  ', os.path.relpath(path, ROOT))


def main():
    mark = extract_mark()
    print(f'mark lifted at {mark.width}x{mark.height}')

    print('android legacy:')
    for density, size in ANDROID_DENSITIES.items():
        icon = rounded(compose(mark, size * 4, 0.62, BACKGROUND)) \
            .resize((size, size), Image.LANCZOS)
        write(os.path.join(
            ROOT, f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'),
            icon)

    print('android adaptive foreground:')
    for density, size in ADAPTIVE_DENSITIES.items():
        # 0.42 of a 108dp canvas lands the mark inside the 66dp safe zone with
        # room to spare, which is what keeps a circular mask from clipping it.
        fg = compose(mark, size, 0.42, (0, 0, 0, 0))
        write(os.path.join(
            ROOT,
            f'android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png'),
            fg)

    print('ios:')
    appicon = os.path.join(
        ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
    with open(os.path.join(appicon, 'Contents.json')) as fh:
        contents = json.load(fh)

    # iOS masks the corners itself and rejects transparency, so these stay
    # square and opaque.
    for entry in contents['images']:
        filename = entry.get('filename')
        if not filename:
            continue
        pt = float(entry['size'].split('x')[0])
        scale = int(entry['scale'].rstrip('x'))
        size = int(round(pt * scale))
        icon = compose(mark, size * 4, 0.62, BACKGROUND) \
            .resize((size, size), Image.LANCZOS).convert('RGB')
        write(os.path.join(appicon, filename), icon)


if __name__ == '__main__':
    main()
