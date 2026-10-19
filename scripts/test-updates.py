#!/usr/bin/env python3
"""Exercise the real Sparkle parser/version comparison on a loopback fixture server."""
import http.server, pathlib, plistlib, shutil, subprocess, threading, uuid
root = pathlib.Path(__file__).resolve().parent.parent
class Handler(http.server.BaseHTTPRequestHandler):
    payload = b''
    def do_GET(self):
        self.send_response(200); self.send_header('Content-Type','application/rss+xml'); self.end_headers(); self.wfile.write(self.payload)
    def log_message(self,*args): pass
server = http.server.HTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
out=root/'.build/update-probe.app/Contents'; (out/'MacOS').mkdir(parents=True,exist_ok=True)
frameworks=out/'Frameworks'; frameworks.mkdir(exist_ok=True)
framework=frameworks/'Sparkle.framework'
if framework.exists(): shutil.rmtree(framework)
shutil.copytree(root/'.build/app/HWP Preview.app/Contents/Frameworks/Sparkle.framework',framework,symlinks=True)
url=f'http://127.0.0.1:{server.server_port}'
# HTTP is permitted only in this disposable test bundle; production config requires HTTPS.
info={'CFBundleIdentifier':'org.hwp-preview.update-probe.'+uuid.uuid4().hex,'CFBundleExecutable':'probe','CFBundleVersion':'10','CFBundleShortVersionString':'0.1.0','CFBundlePackageType':'APPL','SUFeedURL':url+'/appcast.xml','SUPublicEDKey':'m2FtgM4lOJUKfyZeRQiNxKEMxEIWsoXmVMst1WjXwUg=','SUEnableAutomaticChecks':False,'NSAppTransportSecurity':{'NSAllowsLocalNetworking':True}}
(out/'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['xcrun','swiftc','-module-cache-path',str(root/'.build/module-cache'),'-F',str(frameworks),'-framework','Sparkle','-Xlinker','-rpath','-Xlinker','@executable_path/../Frameworks',str(root/'scripts/update-probe.swift'),'-o',str(out/'MacOS/probe')],check=True)
try:
    for version,expect in [('11','found:11'),('10','current'),('9','current'),(None,'error')]:
        Handler.payload=(f'<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>Test</title><item><title>Test</title><sparkle:version>{version}</sparkle:version><enclosure url="{url}/update.zip" length="100" type="application/octet-stream" /></item></channel></rss>'.encode() if version else b'not xml')
        subprocess.run([str(out/'MacOS/probe'),expect],check=True,timeout=25)
finally: server.shutdown()
print('PASS: newer/equal/older/malformed feed through Sparkle')
