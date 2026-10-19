#!/usr/bin/env python3
"""Build native app extensions with Xcode's Swift compiler; no project generator required."""
import os, pathlib, plistlib, shutil, subprocess, json, re, argparse
from release_config import update_config, developer_id
from wasm_limits import cap_memory
root = pathlib.Path(__file__).resolve().parent.parent
os.chdir(root)
parser = argparse.ArgumentParser()
parser.add_argument('--release', action='store_true')
parser.add_argument('--identity', help='Developer ID Application name or SHA-1 fingerprint in Keychain')
parser.add_argument('--update-config', type=pathlib.Path, default=root/'release/update-config.json', help='JSON containing feed_url and public_ed_key (public values only)')
args = parser.parse_args()
updates = update_config(json.loads(args.update_config.read_text()) if args.update_config else {})
identity = '-'
if args.release:
    if not updates or not args.identity:
        parser.error('--release requires --identity and --update-config')
    identity = developer_id(args.identity, subprocess.check_output(['security','find-identity','-v','-p','codesigning'], text=True))
elif args.identity:
    parser.error('--identity requires --release; development builds use adhoc signing')
sparkle = root/'.build/sparkle/Sparkle.framework'
if not sparkle.is_dir(): raise SystemExit('Run python3 scripts/fetch-sparkle.py first')

def sign(path, entitlements=None):
    command = ['codesign', '--force', '--sign', identity]
    if args.release: command += ['--options', 'runtime', '--timestamp']
    if entitlements: command += ['--entitlements', str(entitlements)]
    subprocess.run(command + [str(path)], check=True)

version = (root/'VERSION').read_text().strip()
build_number = (root/'BUILD_NUMBER').read_text().strip()
if not re.fullmatch(r'\d+\.\d+\.\d+(?:-alpha\.\d+)?',version) or not build_number.isdigit():
    raise SystemExit('Invalid VERSION or BUILD_NUMBER')
out = root / '.build' / 'app'
app = out / 'HWP Preview.app'
engine = root / '.build/wasm/package/rhwp_bg.wasm'
if not engine.is_file():
    raise SystemExit('Run scripts/fetch-wasm.sh first')
if app.exists(): shutil.rmtree(app)

def plist(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(value))

def run(*args): subprocess.run([str(x) for x in args], check=True)

def bundle(path, name, ident, extension=None):
    contents = path / 'Contents'
    (contents / 'MacOS').mkdir(parents=True)
    (contents / 'Resources').mkdir()
    info = dict(CFBundleIdentifier=ident, CFBundleName=name, CFBundleExecutable=name,
                CFBundleVersion=build_number, CFBundleShortVersionString=version.split('-')[0], HWPPreviewVersion=version,
                CFBundlePackageType='XPC!' if extension else 'APPL',
                LSMinimumSystemVersion='14.0')
    if extension: info['NSExtension'] = extension
    plist(contents / 'Info.plist', info)
    return contents

types = ['org.hwp-preview.hwp', 'org.hwp-preview.hwpx', 'com.hancom.hwp', 'com.hancom.hwpx', 'org.libreoffice.hwp-document']
appc = bundle(app, 'HWPPreview', 'org.hwp-preview.app')
info = plistlib.loads((appc/'Info.plist').read_bytes())
info['NSPrincipalClass'] = 'NSApplication'
info.update(updates)
info['UTImportedTypeDeclarations'] = [dict(UTTypeIdentifier=types[i], UTTypeDescription=ext.upper()+' Document',
    UTTypeConformsTo=['public.data'], UTTypeTagSpecification={'public.filename-extension':[ext],
    'public.mime-type':mime}) for i,ext,mime in [(0,'hwp','application/x-hwp'),(1,'hwpx','application/hwp+zip')]]
info['CFBundleDocumentTypes'] = [dict(CFBundleTypeRole='Viewer', LSHandlerRank='Alternate', LSItemContentTypes=types)]
plist(appc/'Info.plist',info)
flags = ['-swift-version','5','-target',os.uname().machine+'-apple-macosx14.0',
         '-module-cache-path',str(root/'.build/module-cache'),'-O']
framework = appc/'Frameworks/Sparkle.framework'
framework.parent.mkdir()
shutil.copytree(sparkle, framework, symlinks=True)
# The host app is not sandboxed; Quick Look extensions remain sandboxed.
# Sparkle's on-demand installer remains, but no login item/launch agent is installed.
shutil.rmtree(framework/'Versions/B/XPCServices')
sign(framework/'Versions/B/Autoupdate')
sign(framework/'Versions/B/Updater.app')
sign(framework)
run('xcrun','swiftc',*flags,*sorted((root/'App').glob('*.swift')),
    '-F',appc/'Frameworks','-framework','Sparkle','-Xlinker','-rpath','-Xlinker','@executable_path/../Frameworks',
    '-o',appc/'MacOS/HWPPreview')
for name, point, principal, source in [
    ('Preview','com.apple.quicklook.preview','PreviewController','Extensions/Preview/PreviewController.swift'),
    ('Thumbnail','com.apple.quicklook.thumbnail','ThumbnailProvider','Extensions/Thumbnail/ThumbnailProvider.swift')]:
    attrs = dict(QLSupportedContentTypes=types)
    if name == 'Thumbnail': attrs['QLThumbnailMinimumDimension'] = 0
    c = bundle(appc/'PlugIns'/f'{name}.appex',name,'org.hwp-preview.app.'+name.lower(),
               dict(NSExtensionPointIdentifier=point,NSExtensionPrincipalClass=principal,NSExtensionAttributes=attrs))
    run('xcrun','swiftc',*flags,'-parse-as-library','-application-extension',*sorted((root/'Sources/HWPPreviewCore').glob('*.swift')),source,'-I',root/'Sources/CZlib',
        '-Xlinker','-e','-Xlinker','_NSExtensionMain','-o',c/'MacOS'/name)
    web = c/'Resources/Web'
    shutil.copytree(root/'Resources/Web',web)
    for filename in ['rhwp.js','rhwp_bg.wasm','LICENSE']:
        shutil.copy2(root/'.build/wasm/package'/filename,web/filename)
    (web/'rhwp_bg.wasm').write_bytes(cap_memory((web/'rhwp_bg.wasm').read_bytes()))
    ent = out/'extension.entitlements'
    plist(ent,{'com.apple.security.app-sandbox':True,'com.apple.security.files.user-selected.read-only':True,'com.apple.security.network.client':True})
    sign(c.parent, ent)
shutil.copytree(root/'ThirdParty',appc/'Resources/ThirdParty')
shutil.copy2(root/'THIRD_PARTY_NOTICES.md',appc/'Resources/THIRD_PARTY_NOTICES.md')
shutil.copy2(root/'LICENSE',appc/'Resources/LICENSE')
(appc/'Resources/BuildInfo.json').write_text(json.dumps({'version':version,'build':build_number,'engine':'@rhwp/core@0.8.7','wasmMaximumBytes':256*1024*1024,'architecture':os.uname().machine,'sparkle':'2.10.0','releaseStatus':'developer-id-signed-not-notarized' if args.release else 'development-only'},indent=2)+'\n')
sign(app)
run('codesign','--verify','--deep','--strict',app)
print(app)
