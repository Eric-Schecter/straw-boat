#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/web
if [ ! -f .export_templates/web_nothreads_release.zip ]; then
  python3 tools/fetch_web_template.py
fi
godot --headless --editor --import --quit
godot --headless --export-release Web build/web/index.html
cp assets/fonts/OFL.txt build/web/FONT-LICENSE.txt
cp assets/favicon.svg assets/favicon.png build/web/
python3 - <<'PY'
from pathlib import Path
import zipfile
with zipfile.ZipFile('build/Strawboat-Web.zip','w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(Path('build/web').iterdir()):
        if p.is_file(): z.write(p,p.name)
PY
