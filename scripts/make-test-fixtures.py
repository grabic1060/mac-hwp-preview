#!/usr/bin/env python3
"""Own structural fixtures; deliberately not full documents or layout oracles."""
import io, pathlib, struct, zipfile
out = pathlib.Path(__file__).resolve().parent.parent / 'Tests/HWPPreviewCoreTests/Fixtures'
out.mkdir(parents=True, exist_ok=True)
def put(name, data): (out / name).write_bytes(data)
def archive(manifest='<manifest/>', extra=None, compression=zipfile.ZIP_STORED):
    result = io.BytesIO()
    entries = {'mimetype':'application/hwp+zip', 'Contents/content.hpf':'<package/>', 'META-INF/manifest.xml':manifest}
    entries.update(extra or {})
    with zipfile.ZipFile(result,'w',compression=compression) as z:
        for name, value in entries.items():
            info = zipfile.ZipInfo(name, date_time=(2026,1,1,0,0,0)); info.compress_type=compression
            z.writestr(info,value)
    return result.getvalue()
put('stored.hwpx', archive())
put('deflate.hwpx', archive(compression=zipfile.ZIP_DEFLATED))
put('protected.hwpx', archive('<manifest><encryption-data/></manifest>'))
put('doctype.hwpx', archive('<!DOCTYPE manifest [<!ENTITY x "secret">]><manifest>&x;</manifest>'))
put('deep.hwpx', archive('<a>'*129+'</a>'*129))
put('traversal.hwpx', archive(extra={'../escape':'x'}))
base = bytearray(archive()); central=base.index(b'PK\x01\x02')
crc=bytearray(base); crc[central+16] ^= 1; put('crc.hwpx',crc)
size=bytearray(base); struct.pack_into('<I',size,central+24,100*1024*1024); put('bomb.hwpx',size)
flag=bytearray(base); struct.pack_into('<H',flag,central+8,1); put('encrypted.hwpx',flag)
put('truncated.hwpx',base[:-10])
# CFB v3: FAT, directory, mini-FAT, mini stream with one FileHeader.
def compound(flags=1):
    data=bytearray(512*5)
    def u16(offset,value): struct.pack_into('<H',data,offset,value)
    def u32(offset,value): struct.pack_into('<I',data,offset,value)
    data[:8]=bytes.fromhex('d0cf11e0a1b11ae1')
    for off,val in [(24,0x3e),(26,3),(28,0xfffe),(30,9),(32,6)]: u16(off,val)
    for off,val in [(44,1),(48,1),(56,4096),(60,2),(64,1),(68,0xfffffffe)]:u32(off,val)
    for off in range(76,512,4):u32(off,0xffffffff)
    u32(76,0)
    for off in range(512,1024,4):u32(off,0xffffffff)
    for i,val in enumerate([0xfffffffd,0xfffffffe,0xfffffffe,0xfffffffe]):u32(512+i*4,val)
    for index,name,kind,start,length in [(0,'Root Entry',5,3,256),(1,'FileHeader',2,0,256)]:
        off=1024+index*128; encoded=(name+'\0').encode('utf-16le');data[off:off+len(encoded)]=encoded
        u16(off+64,len(encoded));data[off+66]=kind;data[off+67]=1
        for x in [68,72,76]:u32(off+x,0xffffffff)
        u32(off+116,start);u32(off+120,length)
    for off in range(1536,2048,4):u32(off,0xffffffff)
    for i,val in enumerate([1,2,3,0xfffffffe]):u32(1536+i*4,val)
    data[2048:2065]=b'HWP Document File';u32(2080,0x05000300);u32(2084,flags)
    return data
put('header.hwp',compound())
for name,flag in [('password',2),('distribution',4),('drm',16),('certificate',256),('certificate-drm',1024),('privacy',8192)]:put(name+'.hwp',compound(flag))
cycle=compound();struct.pack_into('<I',cycle,516,1);put('cycle.hwp',cycle)
mini=compound();struct.pack_into('<I',mini,1536,0);put('mini-cycle.hwp',mini)
