#!/usr/bin/env python3
import concurrent.futures, hashlib, json, pathlib, subprocess, urllib.parse
root=pathlib.Path(__file__).resolve().parent.parent
manifest=json.loads((root/'Tests/Corpus/manifest.json').read_text())
out=root/'.build/corpus';out.mkdir(parents=True,exist_ok=True)
def fetch(item):
    destination=out/(item['id']+pathlib.Path(item['path']).suffix)
    def valid():
        if not destination.exists():return False
        data=destination.read_bytes()
        return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==item['gitBlobSha1']
    if not valid():
        url='https://raw.githubusercontent.com/edwardkim/rhwp/'+manifest['upstreamTag']+'/'+urllib.parse.quote(item['path'])
        subprocess.run(['curl','-fLsS','--retry','2',url,'-o',str(destination)],check=True)
    if not valid():raise RuntimeError('Fixture hash mismatch: '+item['id'])
    return item['id']
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    results=list(pool.map(fetch,manifest['documents']))
print('Verified local corpus:',len(results),'documents')
