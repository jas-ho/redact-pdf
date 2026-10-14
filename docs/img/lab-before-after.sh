#!/usr/bin/env bash
# Regenerate docs/img/lab-before-after.png: top of page 1 of examples/sample-lab-input.pdf
# beside the top of page 1 of examples/sample-lab-output.redacted.pdf (made with --pdf).
set -euo pipefail
cd "$(dirname "$0")/../.."
uv run --quiet --with pypdfium2 --with pillow python - <<'PY'
import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageFont

def top(path, frac):
    im = pdfium.PdfDocument(path)[0].render(scale=2.2).to_pil()
    return im.crop((0, 0, im.width, int(im.height * frac)))

a, b = top("examples/sample-lab-input.pdf", 0.30), top("examples/sample-lab-output.redacted.pdf", 0.36)
pad, head = 30, 70
out = Image.new("RGB", (a.width + b.width + 3 * pad, max(a.height, b.height) + head + pad), "white")
d = ImageDraw.Draw(out)
try:
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 34)
except OSError:
    font = ImageFont.load_default()
for x, img, label in ((pad, a, "sample-lab-input.pdf"),
                      (2 * pad + a.width, b, "sample-lab-output.redacted.pdf (--pdf)")):
    d.text((x, 18), label, fill="black", font=font)
    out.paste(img, (x, head))
    d.rectangle((x, head, x + img.width, head + img.height), outline=(180, 180, 180))
out.save("docs/img/lab-before-after.png", optimize=True)
PY
