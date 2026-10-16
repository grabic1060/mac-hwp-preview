#!/usr/bin/env python3
import hashlib,json,pathlib,subprocess,sys,time
root=pathlib.Path(__file__).resolve().parent.parent
assets=root/'.build/app/HWP Preview.app/Contents/PlugIns/Preview.appex/Contents/Resources/Web'
manifest=json.loads((root/'Tests/Corpus/manifest.json').read_text())
out=root/'.build/corpus-results';out.mkdir(parents=True,exist_ok=True)
results=[]
for item in manifest['documents']:
    source=root/'.build/corpus'/(item['id']+pathlib.Path(item['path']).suffix)
    before=hashlib.sha256(source.read_bytes()).hexdigest();started=time.monotonic()
    try:
        result=subprocess.run([str(root/'.build/swift/debug/web-probe'),str(assets),str(source),str(out/(item['id']+'.png'))],capture_output=True,text=True,timeout=40)
        metrics=next((json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')),None)
        ok=result.returncode==0 and metrics is not None and metrics['pages']==metrics['rendered'] and metrics['imageFailures']==0
        entry={'id':item['id'],'passed':ok,'metrics':metrics,'error':result.stderr.strip()[-500:] if not ok else ''}
    except subprocess.TimeoutExpired: entry={'id':item['id'],'passed':False,'error':'process deadline'}
    entry['unchanged']=before==hashlib.sha256(source.read_bytes()).hexdigest();entry['passed'] &= entry['unchanged']
    entry['wallSeconds']=round(time.monotonic()-started,3);results.append(entry)
    (out/'results.json').write_text(json.dumps({'kind':'functional smoke; fidelity unverified','results':results},ensure_ascii=False,indent=2)+'\n')
    print(item['id'], 'PASS' if entry['passed'] else 'FAIL', flush=True)
passed=sum(r['passed'] for r in results)
print(f'Passed {passed}/{len(results)}; report: {out / "results.json"}')
sys.exit(0 if passed==len(results) else 1)
