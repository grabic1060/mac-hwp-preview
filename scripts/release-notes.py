#!/usr/bin/env python3
"""Validate tag/version and produce user-facing notes before releasing."""
import pathlib,re,sys
root=pathlib.Path(__file__).resolve().parent.parent
version=(root/'VERSION').read_text().strip()
if len(sys.argv)!=2 or sys.argv[1] != 'v'+version or not re.fullmatch(r'\d+\.\d+\.\d+(?:-alpha\.\d+)?',version):
    raise SystemExit('Tag must match VERSION (vMAJOR.MINOR.PATCH or -alpha.N)')
if not (root/'BUILD_NUMBER').read_text().strip().isdigit(): raise SystemExit('Invalid BUILD_NUMBER')
changelog=(root/'CHANGELOG.md').read_text()
match=re.search(r'^## '+re.escape(version)+r' — [^\n]+\n(.*?)(?=^## |\Z)',changelog,re.M|re.S)
if not match: raise SystemExit('Missing version changelog')
print('# HWP Preview '+sys.argv[1]+'\n\n'+match.group(1).strip()+'\n\n'+(root/'release/INSTALL.md').read_text())
