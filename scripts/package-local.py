#!/usr/bin/env python3
import hashlib,json,pathlib,plistlib,subprocess,zipfile
root=pathlib.Path(__file__).resolve().parent.parent
version=(root/'VERSION').read_text().strip();app=root/'.build/app/HWP Preview.app'
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info['HWPPreviewVersion']==version, 'Rebuild app for the current version'
assert f'## {version}' in (root/'CHANGELOG.md').read_text(), 'Missing changelog'
assert '-alpha.' in version, 'Only development archives are supported by this script'
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
out=root/'.build/releases';out.mkdir(parents=True,exist_ok=True)
archive=out/f'HWP-Preview-{version}-macOS-{json.loads((app/"Contents/Resources/BuildInfo.json").read_text())["architecture"]}.zip'
subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(app),str(archive)],check=True)
with zipfile.ZipFile(archive) as z:
    assert not any(n.lower().endswith(('.hwp','.hwpx','.pdf')) for n in z.namelist()), 'Evaluation file leaked into archive'
    assert any(n.endswith('RHWP-LICENSE.txt') for n in z.namelist()), 'Missing engine license'
checksum=hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix('.zip.sha256').write_text(checksum+'  '+archive.name+'\n')
print(archive)
