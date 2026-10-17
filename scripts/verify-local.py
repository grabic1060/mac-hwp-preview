#!/usr/bin/env python3
"""GUI-session integration checks. --system also registers and calls Quick Look extensions."""
import argparse,datetime,hashlib,json,pathlib,shutil,subprocess,uuid
root=pathlib.Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser();parser.add_argument('--system',action='store_true');args=parser.parse_args()
out=root/'.build/verification';out.mkdir(parents=True,exist_ok=True)
app=root/'.build/app/HWP Preview.app';assets=app/'Contents/PlugIns/Preview.appex/Contents/Resources/Web'
probe=root/'.build/swift/debug/web-probe'
results=[]
def run(command):
    result=subprocess.run([str(x) for x in command],cwd=root,capture_output=True,text=True,timeout=50)
    if result.returncode:raise RuntimeError(result.stderr[-1500:] or result.stdout[-1500:])
    return result.stdout
for name,ext,pages,images in [('book','hwp',2,3),('form','hwpx',10,0),('image','hwpx',5,5)]:
    source=root/f'.build/fixtures/{name}.{ext}';before=hashlib.sha256(source.read_bytes()).hexdigest()
    for check in ['page-checks.js','image-checks.js']:
        output=run([probe,assets,source,out/f'{name}.png',root/'scripts'/check])
        metrics=json.loads(output.splitlines()[0])
        assert (metrics['pages'],metrics['rendered'],metrics['images'],metrics['imageFailures'])==(pages,pages,images,0)
        results.append({'document':name,'check':check,'passed':True,'metrics':metrics})
    assert before==hashlib.sha256(source.read_bytes()).hexdigest()
run([probe,assets,root/'.build/fixtures/form.hwpx',out/'worker.png',root/'scripts/worker-checks.js'])
run([root/'.build/swift/debug/lifecycle-probe',assets,root/'.build/fixtures/form.hwpx'])
if args.system:
    run(['bash',root/'scripts/register-app.sh',app])
    for name in ['thumbnail','preview-host','preview-panel']:
        run(['xcrun','swiftc','-module-cache-path',root/'.build/module-cache',root/f'scripts/{name}-probe.swift','-o',root/f'.build/{name}-probe'])
    for name,ext in [('book','hwp'),('form','hwpx')]:
        source=out/f'{name}-{uuid.uuid4()}.{ext}';shutil.copy2(root/f'.build/fixtures/{name}.{ext}',source)
        try:
            output=run([root/'.build/thumbnail-probe',source,out/f'{name}-thumbnail.png'])
            assert 'representationType=2' in output
            for mode in ['preview-host','preview-panel']:
                started=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                hostOutput=run([root/f'.build/{mode}-probe',source])
                observedUntil=next(line.split('=',1)[1] for line in hostOutput.splitlines() if line.startswith('observedUntil='))
                logs=run(['/usr/bin/log','show','--start',started,'--end',observedUntil,'--style','compact','--predicate','(subsystem == "org.hwp-preview" AND category == "preview") OR eventMessage CONTAINS "View service terminated while display bundle was loaded"'])
                assert 'WASM preview complete' in logs, 'System preview completion not observed'
                assert 'View service terminated while display bundle was loaded' not in logs, 'Remote preview disconnected while visible'
                assert 'WASM preview failed' not in logs, 'Preview failed while visible'
            results.append({'document':name,'check':'system Quick Look thumbnail and preview dispatch','passed':True})
        finally:source.unlink(missing_ok=True)
(out/'results.json').write_text(json.dumps({'fidelityVerified':False,'results':results,'workerCancellation':True,'nativeLifecycle':True},indent=2)+'\n')
print(f'Local integration checks passed; {out / "results.json"}')
