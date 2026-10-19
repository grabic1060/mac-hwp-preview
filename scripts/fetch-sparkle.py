#!/usr/bin/env python3
"""Fetch the pinned official binary distribution; verify before extraction."""
import hashlib, pathlib, subprocess, urllib.request
root = pathlib.Path(__file__).resolve().parent.parent
version = '2.10.0'
sha256 = 'c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c'
out = root / '.build/sparkle'
out.mkdir(parents=True, exist_ok=True)
archive = out / f'Sparkle-{version}.tar.xz'
if not archive.exists():
    urllib.request.urlretrieve(f'https://github.com/sparkle-project/Sparkle/releases/download/{version}/{archive.name}', archive)
if hashlib.sha256(archive.read_bytes()).hexdigest() != sha256:
    raise SystemExit('Sparkle archive checksum mismatch; remove the archive and retry')
subprocess.run(['tar', '-xf', str(archive), '-C', str(out)], check=True)
print(out / 'Sparkle.framework')
