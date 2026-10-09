from pathlib import Path
import struct,hashlib
def resources(path):
    data=Path(path).read_bytes();base=struct.unpack_from('<Q',data,24)[0];pos=struct.unpack_from('<Q',data,32)[0]
    count=struct.unpack_from('<I',data,pos)[0];pos+=4;result={}
    for index in range(count):
        length=struct.unpack_from('<I',data,pos)[0];pos+=4
        name=data[pos:pos+length].decode().rstrip('\0');pos+=length
        offset,size=struct.unpack_from('<QQ',data,pos);pos+=16
        md5=data[pos:pos+16].hex();pos+=20
        resource=data[base+offset:base+offset+size]
        assert hashlib.md5(resource).hexdigest()==md5,name
        result[name]=resource
    assert pos==len(data)
    return result
