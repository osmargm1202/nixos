"""Minimal RFB 3.8 client for test-owned, SSH-protected Unix endpoints only."""
import socket
import struct


class Client:
    def __init__(self,path):
        self.socket=socket.socket(socket.AF_UNIX)
        self.socket.settimeout(10)
        self.socket.connect(str(path))
        version=self.read(12)
        assert version==b'RFB 003.008\n',version
        self.socket.sendall(version)
        methods=self.read(self.read(1)[0]);assert 1 in methods,methods
        self.socket.sendall(b'\x01')
        assert self.read(4)==b'\0\0\0\0'
        self.socket.sendall(b'\x01')
        self.width,self.height=struct.unpack('>HH',self.read(4))
        self.pixel_format=self.read(16)
        self.name=self.read(struct.unpack('>I',self.read(4))[0]).decode(errors='replace')
    def read(self,size):
        result=b''
        while len(result)<size:
            part=self.socket.recv(size-len(result))
            if not part:raise EOFError('RFB connection closed')
            result+=part
        return result
    def frame(self):
        fmt=struct.pack('>BBBBHHHBBBxxx',32,24,0,1,255,255,255,16,8,0)
        self.socket.sendall(b'\0\0\0\0'+fmt)
        self.socket.sendall(struct.pack('>BBHi',2,0,1,0))
        w,h=min(128,self.width),min(128,self.height)
        self.socket.sendall(struct.pack('>BBHHHH',3,0,(self.width-w)//2,(self.height-h)//2,w,h))
        assert self.read(1)==b'\0'
        _,count=struct.unpack('>BH',self.read(3))
        pixels=b''
        for _ in range(count):
            x,y,rw,rh,encoding=struct.unpack('>HHHHi',self.read(12))
            assert encoding==0,(x,y,rw,rh,encoding)
            pixels+=self.read(rw*rh*4)
        assert pixels,'no framebuffer data'
        return pixels
    def key(self,keysym):
        for down in (1,0):self.socket.sendall(struct.pack('>BBHI',4,down,0,keysym))
    def close(self):
        self.socket.close()
