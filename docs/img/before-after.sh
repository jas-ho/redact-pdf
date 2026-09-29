#!/usr/bin/env bash
# Regenerate docs/img/before-after.png: typst excerpt of examples/sample-contract.typ
# (narrow page, intro + table only) beside the matching lines of examples/sample-contract.md.
# The Markdown side is hand-copied into before-after.html; update it if the sample output changes.
set -euo pipefail
cd "$(dirname "$0")"; tmp=$(mktemp -d)
awk '/^== 1\./{s=1} /^== 3\./{s=0} /^== 4\./{s=1} !s' ../../examples/sample-contract.typ |
  sed 's/#set page(paper: "a4", margin: 2cm)/#set page(width: 10.2cm, height: auto, margin: (x: 0.6cm, y: 0.5cm))/' > "$tmp/excerpt.typ"
typst compile "$tmp/excerpt.typ" "$tmp/left.png" --ppi 400
cp before-after.html "$tmp/"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=880,600 --screenshot="$tmp/shot.png" "file://$tmp/before-after.html" 2>/dev/null
magick "$tmp/shot.png" -trim +repage -bordercolor white -border 24 before-after.png
