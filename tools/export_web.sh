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
cp assets/strawboat-cover-v1.png build/web/cover.png
cp assets/audio/menu-hover.wav build/web/hover.wav
cp assets/audio/menu-press.wav build/web/press.wav
python3 - <<'PY'
from pathlib import Path
import zipfile
import hashlib
import json
web = Path('build/web')
pack = web / 'index.pck'
name = 'game-' + hashlib.sha256(pack.read_bytes()).hexdigest()[:12] + '.pck'
for old in web.glob('game-*.pck'):
    old.unlink()
pack.rename(web / name)
html = web / 'index.html'
source = html.read_text()
source = source.replace('const canvas=', 'config.mainPack=' + json.dumps(name) + ';\nconst canvas=', 1)
html.write_text(source)
with zipfile.ZipFile('build/Strawboat-Web.zip','w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(Path('build/web').iterdir()):
        if p.is_file(): z.write(p,p.name)
PY
