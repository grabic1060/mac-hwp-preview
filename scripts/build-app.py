#!/usr/bin/env python3
"""Build native app extensions with Xcode's Swift compiler; no project generator required."""
import os, pathlib, plistlib, shutil, subprocess, time
root = pathlib.Path(__file__).resolve().parent.parent
os.chdir(root)
out = root / '.build' / 'app'
app = out / 'HWP Preview.app'
core = root / 'Sources/HWPPreviewCore/Renderer.swift'
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
                CFBundleVersion='6', CFBundleShortVersionString='0.1.0',
                CFBundlePackageType='XPC!' if extension else 'APPL',
                LSMinimumSystemVersion='14.0')
    if extension: info['NSExtension'] = extension
    plist(contents / 'Info.plist', info)
    return contents

types = ['org.hwp-preview.hwp', 'org.hwp-preview.hwpx', 'com.hancom.hwp', 'com.hancom.hwpx', 'org.libreoffice.hwp-document']
appc = bundle(app, 'HWPPreview', 'org.hwp-preview.app')
info = plistlib.loads((appc/'Info.plist').read_bytes())
info['NSPrincipalClass'] = 'NSApplication'
info['UTImportedTypeDeclarations'] = [dict(UTTypeIdentifier=types[i], UTTypeDescription=ext.upper()+' Document',
    UTTypeConformsTo=['public.data'], UTTypeTagSpecification={'public.filename-extension':[ext],
    'public.mime-type':mime}) for i,ext,mime in [(0,'hwp','application/x-hwp'),(1,'hwpx','application/hwp+zip')]]
info['CFBundleDocumentTypes'] = [dict(CFBundleTypeRole='Viewer', LSHandlerRank='Alternate', LSItemContentTypes=types)]
plist(appc/'Info.plist',info)
flags = ['-swift-version','5','-target',os.uname().machine+'-apple-macosx14.0',
         '-module-cache-path',str(root/'.build/module-cache'),'-O']
run('xcrun','swiftc',*flags,'App/main.swift','-o',appc/'MacOS/HWPPreview')
for name, point, principal, source in [
    ('Preview','com.apple.quicklook.preview','PreviewController','Extensions/Preview/PreviewController.swift'),
    ('Thumbnail','com.apple.quicklook.thumbnail','ThumbnailProvider','Extensions/Thumbnail/ThumbnailProvider.swift')]:
    attrs = dict(QLSupportedContentTypes=types)
    if name == 'Thumbnail': attrs['QLThumbnailMinimumDimension'] = 0
    c = bundle(appc/'PlugIns'/f'{name}.appex',name,'org.hwp-preview.app.'+name.lower(),
               dict(NSExtensionPointIdentifier=point,NSExtensionPrincipalClass=principal,NSExtensionAttributes=attrs))
    run('xcrun','swiftc',*flags,'-parse-as-library','-application-extension',core,root/'Sources/HWPPreviewCore/WebRenderer.swift',source,
        '-Xlinker','-e','-Xlinker','_NSExtensionMain','-o',c/'MacOS'/name)
    web = c/'Resources/Web'
    shutil.copytree(root/'Resources/Web',web)
    for filename in ['rhwp.js','rhwp_bg.wasm','LICENSE']:
        shutil.copy2(root/'.build/wasm/package'/filename,web/filename)
    ent = out/'extension.entitlements'
    plist(ent,{'com.apple.security.app-sandbox':True,'com.apple.security.files.user-selected.read-only':True,'com.apple.security.network.client':True})
    run('codesign','--force','--sign','-','--entitlements',ent,c.parent)
run('codesign','--force','--sign','-',app)
run('codesign','--verify','--deep','--strict',app)
print(app)
