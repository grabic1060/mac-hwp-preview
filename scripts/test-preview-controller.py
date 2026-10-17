#!/usr/bin/env python3
import pathlib,plistlib,shutil,subprocess,os
root=pathlib.Path(__file__).resolve().parent.parent
app=root/'.build/controller-probe.app/Contents'
(app/'MacOS').mkdir(parents=True,exist_ok=True)
(app/'Resources').mkdir(exist_ok=True)
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable':'probe','CFBundleIdentifier':'org.hwp-preview.controller-probe','CFBundlePackageType':'APPL'}))
shutil.copytree(root/'.build/app/HWP Preview.app/Contents/PlugIns/Preview.appex/Contents/Resources/Web',app/'Resources/Web',dirs_exist_ok=True)
subprocess.run(['xcrun','swiftc','-swift-version','5','-parse-as-library','-module-cache-path',str(root/'.build/module-cache'),'-I',str(root/'Sources/CZlib'),*[str(p) for p in sorted((root/'Sources/HWPPreviewCore').glob('*.swift'))],str(root/'Extensions/Preview/PreviewController.swift'),str(root/'scripts/preview-controller-probe.swift'),'-o',str(app/'MacOS/probe')],check=True)
for name in ['book.hwp','form.hwpx']:
    subprocess.run([str(app/'MacOS/probe'),str(root/'.build/fixtures'/name)],check=True,timeout=45)
