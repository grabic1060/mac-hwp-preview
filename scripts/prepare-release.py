#!/usr/bin/env python3
"""Notarize, staple, and sign a local update feed. Never publishes to a server."""
import argparse, hashlib, json, pathlib, plistlib, shutil, subprocess
from release_config import https_url
root = pathlib.Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
mode = parser.add_mutually_exclusive_group(required=True)
mode.add_argument('--allow-unnotarized', action='store_true', help='Prepare an adhoc development update without Apple notarization')
mode.add_argument('--notary-profile', help='Existing notarytool Keychain profile name; never a password')
parser.add_argument('--download-url-prefix', required=True)
args = parser.parse_args()
prefix = https_url(args.download_url_prefix)
if not prefix.endswith('/'): parser.error('Download URL prefix must end with /')
app = root/'.build/app/HWP Preview.app'
info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
https_url(info['SUFeedURL'])
subprocess.run(['codesign','--verify','--deep','--strict',str(app)], check=True)
signature = subprocess.run(['codesign','-d','--verbose=4',str(app)], capture_output=True,text=True,check=True).stderr
if not args.allow_unnotarized and ('Authority=Developer ID Application:' not in signature or 'runtime' not in signature):
    raise SystemExit('Release requires Developer ID signing and Hardened Runtime')
account = 'org.hwp-preview.app'
public = subprocess.check_output([str(root/'.build/sparkle/bin/generate_keys'),'--account',account,'-p'],text=True).strip()
if public != info['SUPublicEDKey']: raise SystemExit('App update public key does not match signing Keychain account')
version = info['HWPPreviewVersion']
arch = json.loads((app/'Contents/Resources/BuildInfo.json').read_text())['architecture']
out = root/'.build/distribution'/f'{version}-{arch}'
out.mkdir(parents=True,exist_ok=False)
archive = out/f'HWP-Preview-{version}-macOS-{arch}.zip'
def zip_app():
    if archive.exists(): archive.unlink()
    subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(app),str(archive)],check=True)
zip_app()
# Apple submission is explicit only when this script is invoked.
if not args.allow_unnotarized:
    result = subprocess.run(['xcrun','notarytool','submit',str(archive),'--keychain-profile',args.notary_profile,'--wait','--output-format','json'],capture_output=True,text=True,check=True)
    report = json.loads(result.stdout)
    (out/'notarization.json').write_text(json.dumps(report,indent=2)+'\n')
    if report.get('status') != 'Accepted': raise SystemExit('Notarization not accepted; inspect notarization.json and notarytool log')
    subprocess.run(['xcrun','stapler','staple',str(app)],check=True)
    subprocess.run(['xcrun','stapler','validate',str(app)],check=True)
    subprocess.run(['spctl','--assess','--type','execute','--verbose=2',str(app)],check=True)
zip_app() # Stapled bytes must be archived before Sparkle signing.
archive.with_suffix('.zip.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n')
subprocess.run([str(root/'.build/sparkle/bin/generate_appcast'),'--account',account,'--maximum-deltas','0','--download-url-prefix',prefix,'-o',str(out/'appcast.xml'),str(out)],check=True)
shutil.copytree(app,out/app.name,symlinks=True)
print(f'App, archive and signed update enclosure prepared locally (notarized={not args.allow_unnotarized}): {out}')
