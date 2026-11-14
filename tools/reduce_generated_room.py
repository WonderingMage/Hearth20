"""Reduce a pixel-grid depth mesh without changing its image-space UV mapping."""
from pathlib import Path
import json,struct,hashlib
import numpy as np
root=Path(__file__).resolve().parents[1]
source=Path(r'C:\Users\fstre\Desktop\Hearth20 Development\generated models\room.glb')
out=root/'qa/generated-models';out.mkdir(parents=True,exist_ok=True)
b=source.read_bytes();o=12
while o<len(b):
    n,t=struct.unpack_from('<II',b,o);o+=8
    if t==0x4e4f534a:g=json.loads(b[o:o+n])
    if t==0x004e4942:binary=memoryview(b)[o:o+n]
    o+=n
part=g['meshes'][0]['primitives'][0]
def access(i):
    a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];w={'VEC2':2,'VEC3':3,'SCALAR':1}[a['type']];dt=np.dtype('<f4' if a['componentType']==5126 else '<u4')
    return np.ndarray((a['count'],w),dtype=dt,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dt.itemsize*w),dt.itemsize))
uv=access(part['attributes']['TEXCOORD_0']);positions=access(part['attributes']['POSITION'])
w,h=2048,1143;pixels=np.rint(uv*np.array([w-1,h-1])).astype(np.int64)
assert np.max(np.abs(uv*np.array([w-1,h-1])-pixels))<.001
grid=np.full((h,w),-1,dtype=np.int64);grid[pixels[:,1],pixels[:,0]]=np.arange(len(uv))
step=4;xs=np.unique(np.r_[np.arange(0,w,step),w-1]);ys=np.unique(np.r_[np.arange(0,h,step),h-1]);sampled=grid[np.ix_(ys,xs)]
a=sampled[:-1,:-1].ravel();b1=sampled[:-1,1:].ravel();c=sampled[1:,:-1].ravel();d=sampled[1:,1:].ravel()
# Preserve the original camera-facing winding. Invalid silhouette pixels remain
# unconnected rather than bridging a missing region with stretched triangles.
reference=access(part['indices']).reshape(-1,3);first=reference[0];reference_cross=np.cross(positions[first[1]]-positions[first[0]],positions[first[2]]-positions[first[0]])
tri=np.concatenate([np.stack([a,c,b1],axis=1),np.stack([b1,c,d],axis=1)]);tri=tri[np.all(tri>=0,axis=1)]
q=tri[0];new_cross=np.cross(positions[q[1]]-positions[q[0]],positions[q[2]]-positions[q[0]])
if np.dot(reference_cross,new_cross)<0:tri=tri[:,[0,2,1]]
used,indices=np.unique(tri,return_inverse=True);p=positions[used].astype('<f4');u=uv[used].astype('<f4');idx=indices.reshape(-1).astype('<u4')
blob=bytearray();views=[]
def append(data):
    while len(blob)%4:blob.append(0)
    views.append({'buffer':0,'byteOffset':len(blob),'byteLength':len(data)});blob.extend(data);return len(views)-1
pv=append(p.tobytes());uvv=append(u.tobytes());iv=append(idx.tobytes())
image=g['images'][0];v=g['bufferViews'][image['bufferView']];imageview=append(binary[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']])
new={'asset':{'version':'2.0','generator':'Hearth20 pixel-grid room reduction; original retained'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'name':'GeneratedRoomBackdrop','mesh':0}],'meshes':[{'primitives':[{'attributes':{'POSITION':0,'TEXCOORD_0':1},'indices':2,'material':0}]}],'materials':g['materials'],'textures':g['textures'],'images':[{'mimeType':image['mimeType'],'bufferView':imageview}],'bufferViews':views,'accessors':[{'bufferView':pv,'componentType':5126,'count':len(p),'type':'VEC3','min':p.min(axis=0).tolist(),'max':p.max(axis=0).tolist()},{'bufferView':uvv,'componentType':5126,'count':len(u),'type':'VEC2'},{'bufferView':iv,'componentType':5125,'count':len(idx),'type':'SCALAR'}],'buffers':[{'byteLength':len(blob)}]}
if 'samplers' in g:new['samplers']=g['samplers']
j=json.dumps(new,separators=(',',':')).encode();j+=b' '*((-len(j))%4);blob+=b'\0'*((-len(blob))%4)
result=struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(blob))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(blob),0x004e4942)+blob
target=out/'room-reduced.glb';target.write_bytes(result)
sample=np.arange(0,len(positions),97);depth=-positions[sample,2]
ux=np.linalg.lstsq(np.c_[positions[sample,0]/depth,np.ones(len(sample))],uv[sample,0],rcond=None)[0]
vy=np.linalg.lstsq(np.c_[positions[sample,1]/depth,np.ones(len(sample))],uv[sample,1],rcond=None)[0]
report={'original_triangles':len(reference),'runtime_triangles':len(idx)//3,'reduction_percent':100*(1-(len(idx)//3)/len(reference)),'vertices':len(p),'original_bytes':source.stat().st_size,'reduced_bytes':len(result),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'pixel_step':step,'texture_pixels_unchanged':True,'projection':[float(ux[0]),float(vy[0]),float(ux[1]),float(vy[1])]}
(out/'room-reduction.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2))
