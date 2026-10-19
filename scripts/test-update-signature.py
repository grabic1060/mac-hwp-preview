#!/usr/bin/env python3
"""Verify Sparkle integrity handling with a disposable, deliberately non-secret test seed."""
import base64, pathlib, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parent.parent
tool=root/'.build/sparkle/bin/sign_update'
with tempfile.TemporaryDirectory(prefix='hwp-update-signature-') as folder:
    folder=pathlib.Path(folder); key=folder/'test-key'; payload=folder/'update.zip'
    key.write_bytes(base64.b64encode(bytes(range(32))))
    key.chmod(0o600)
    payload.write_bytes(b'local update integrity fixture')
    signature=subprocess.check_output([str(tool),'--ed-key-file',str(key),'-p',str(payload)],text=True).strip()
    subprocess.run([str(tool),'--ed-key-file',str(key),'--verify',str(payload),signature],check=True)
    payload.write_bytes(b'tampered update')
    result=subprocess.run([str(tool),'--ed-key-file',str(key),'--verify',str(payload),signature],capture_output=True,text=True)
    assert result.returncode != 0, 'Tampered payload accepted'
print('PASS: test signature accepted; tampered bytes rejected (disposable test key)')
