import struct
class BinaryResource:
    def __init__(self,data):
        self.data=data;self.pos=4
        assert data[:4]==b'RSRC'
        assert self.number('I')==self.number('I')==0
        self.version=[self.number('I') for _ in range(3)]
        self.type=self.string();self.metadata_offset=self.number('Q');self.flags=self.number('I');self.uid=self.number('Q')
        assert self.flags==3
        self.reserved=[self.number('I') for _ in range(11)]
        self.strings=[self.string() for _ in range(self.number('I'))]
        self.external=[{'type':self.string(),'path':self.string(),'uid':self.number('Q')} for _ in range(self.number('I'))]
        self.internal=[{'path':self.string(),'offset':self.number('Q')} for _ in range(self.number('I'))]
    def number(self,format):
        value=struct.unpack_from('<'+format,self.data,self.pos)[0];self.pos+=struct.calcsize(format);return value
    def string(self):
        size=self.number('I');value=self.data[self.pos:self.pos+size].decode().rstrip('\0');self.pos+=size;return value
    def variant(self):
        kind=self.number('I')
        if kind==1:return None
        if kind==2:return bool(self.number('I'))
        if kind==3:return self.number('i')
        if kind==4:return self.number('f')
        if kind==5:return self.string()
        if kind==24:
            objtype=self.number('I');assert objtype==3
            return {'external_index':self.number('I')}
        if kind==26:
            result={}
            for _ in range(self.number('I')&0x7fffffff):
                key=self.variant();result[key]=self.variant()
            return result
        if kind==30:return [self.variant() for _ in range(self.number('I')&0x7fffffff)]
        if kind==32:return [self.number('i') for _ in range(self.number('I'))]
        if kind==34:return [self.string() for _ in range(self.number('I'))]
        raise ValueError((kind,self.pos))
    def parse(self):
        resources=[]
        for resource in self.internal:
            assert self.pos==resource['offset']
            resource_type=self.string();props={}
            for _ in range(self.number('I')):
                name=self.strings[self.number('I')];props[name]=self.variant()
            resources.append({'type':resource_type,'properties':props})
        assert self.data[self.pos:]==b'RSRC'
        return {'version':self.version,'type':self.type,'flags':self.flags,'uid':self.uid,'reserved':self.reserved,'strings':self.strings,'external':self.external,'internal':self.internal,'resources':resources}
