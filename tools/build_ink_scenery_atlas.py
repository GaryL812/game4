"""Pack the scenery supplied in jiarui. Requires Pillow with WebP support."""
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
SIZE = (1536, 1024)


def smooth(start, end, value):
    t = max(0.0, min(1.0, (value - start) / (end - start)))
    return t * t * (3.0 - 2.0 * t)


def prepare(source, kind, size):
    source.thumbnail((size[0] - 12, size[1] - 12), Image.Resampling.LANCZOS)
    if source.getchannel("A").getextrema()[0] < 255:
        return source

    width, height = source.size
    pixels = []
    for i, (r, g, b, _) in enumerate(source.getdata()):
        x, y = (i % width) / (width - 1), (i // width) / (height - 1)
        light = (r * .25 + g * .61 + b * .14) / 255
        if kind == "mist":
            fade = smooth(0, .15, min(x, 1 - x)) * smooth(0, .25, min(y, 1 - y))
            alpha = fade * (.16 + smooth(.015, .32, 1 - light) * .57)
            pixels.append((min(255, r + 23), min(255, g + 20), min(255, b + 15), round(alpha * 255)))
            continue

        # Remove the baked paper (and the pale checkerboard on the waterfall).
        # A narrow mask retains the white water as it passes between the rocks.
        cutoff = .915 if kind == "falls" else .968
        pigment = smooth(.014, .67, max(0, cutoff - light))
        alpha = max(pigment, min(1, max(0, cutoff - light) * 1.55))
        if kind == "falls":
            center = .495 - max(0, y - .28) * .075
            water = (1 - smooth(.09, .19, abs(x - center))) * smooth(.23, .35, y)
            water *= 1 - smooth(.73, .96, y)
            alpha = max(alpha, water * .80)
        fade = smooth(0, .038, min(x, 1 - x)) * smooth(0, .06, min(y, 1 - y))
        # Solve for the ink color on its own so an opaque paper fringe is not
        # reintroduced when the atlas is sampled on the in-game background.
        ink = [round(max(0, min(255, (c - cutoff * 255 * (1 - alpha)) / max(.001, alpha)))) for c in (r, g, b)]
        pixels.append((*ink, round(alpha * fade * 255)))
    source.putdata(pixels)
    return source


def main():
    atlas = Image.new("RGBA", SIZE)
    regions = [
        ("群山2D图.png", "mountains", (0, 0), (1024, 512), None),
        ("云雾2D图.png", "mist", (0, 512), (1024, 512), None),
        ("瀑布2D图.png", "falls", (1024, 0), (512, 512), None),
        ("竹子2D图.png", "bamboo", (1024, 512), (256, 512), (0, .46)),
        ("竹子2D图.png", "bamboo", (1280, 512), (256, 512), (.54, 1)),
    ]
    for name, kind, (x, y), size, crop in regions:
        with Image.open(ROOT / "jiarui" / name) as image:
            source = image.convert("RGBA")
        if crop:
            source = source.crop((round(crop[0] * source.width), 0, round(crop[1] * source.width), source.height))
        tile = prepare(source, kind, size)
        atlas.paste(tile, (x + (size[0] - tile.width) // 2, y + (size[1] - tile.height) // 2))
    output = ROOT / "assets" / "textures" / "ink_scenery.webp"
    atlas.save(output, "WEBP", quality=86, alpha_quality=100, method=6)
    print(f"{output.name}: {output.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
