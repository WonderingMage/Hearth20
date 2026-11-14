"""Fit contact planes, not whole-body PCA, to level the delivered static props.

Godot's horizontal plane is XZ (Y is up). Original GLBs are read-only.
The resulting rigid transforms preserve every vertex, UV and material.
"""
from pathlib import Path
import os
os.environ['OPENBLAS_NUM_THREADS']='1'
import json,struct
import numpy as np
root=Path(__file__).resolve().parents[1];qa=root/'qa/generated-models';source=root.parents[1]/'generated models'
poses=json.loads((qa/'poses.json').read_text());out=qa/'alignment';out.mkdir(exist_ok=True)
if not (out/'poses-before.json').exists():(out/'poses-before.json').write_text(json.dumps(poses,indent=2))
# Hanging handles, wall crests, food and the reconstructed room do not stand on
# a base. Their authored/reviewed mounting orientations must stay intact.
grounded={'table','side_table','small_bar_table','bar_stool','bar','bench','bottle','bowl','cabinet','candle','dice_cup','fireplace','goblet','mug','purse_bag','plate','map_frame','lizard_table','door','large_window','small_window','wood_shelve','menu'}
report={}
for name in sorted(grounded):
    path=qa/('clean-'+name+'.glb')
    if not path.exists():path=source/(name+'.glb')
    data=path.read_bytes();cursor=12
    while cursor<len(data):
        length,kind=struct.unpack_from('<II',data,cursor);cursor+=8
        if kind==0x4e4f534a:g=json.loads(data[cursor:cursor+length])
        elif kind==0x004e4942:binary=memoryview(data)[cursor:cursor+length]
        cursor+=length
    part=g['meshes'][0]['primitives'][0]
    def access(index):
        a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];width={'VEC3':3,'SCALAR':1}[a['type']];dtype=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']])
        return np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dtype.itemsize*width),dtype.itemsize))
    p=access(part['attributes']['POSITION']).astype('f8');tri=access(part['indices']).reshape(-1,3)
    record=poses.get(name,{})
    old=np.array(record.get('unleveled_orientation_basis',record.get('orientation_basis',np.eye(3)))).T
    points=p@old.T;used=np.unique(tri);vertices=points[used];extent=np.ptp(vertices,axis=0);height=extent[1];epsilon=max(height*.012,min(extent)*.025)
    faces=points[tri];cross=np.cross(faces[:,1]-faces[:,0],faces[:,2]-faces[:,0]);area=np.linalg.norm(cross,axis=1)/2
    normals=cross/np.maximum(2*area[:,None],1e-14);normals[normals[:,1]<0]*=-1
    centers=faces.mean(axis=1);minimum=vertices[:,1].min()
    eligible=np.flatnonzero((normals[:,1]>.82)&(centers[:,1]<minimum+height*.24)&(area>1e-12))
    candidates=[np.array([0.,1.,0.])]
    candidates.extend(normals[eligible[np.argsort(area[eligible])[-96:]]])
    low=vertices[vertices[:,1]<minimum+height*.23];rng=np.random.default_rng(11014)
    if len(low)>=3:
        samples=low[rng.integers(len(low),size=(256,3))];n=np.cross(samples[:,1]-samples[:,0],samples[:,2]-samples[:,0]);n/=np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-14);n[n[:,1]<0]*=-1
        candidates.extend(n[n[:,1]>.88])
    def score(n):
        distances=vertices@n;floor=distances.min();mask=distances<floor+epsilon
        contact=vertices[mask];coverage=np.prod(np.ptp(contact[:,[0,2]],axis=0)/np.maximum(extent[[0,2]],1e-8))
        face_distance=faces@n-floor;plane_area=area[np.max(face_distance,axis=1)<epsilon].sum()/max(extent[0]*extent[2],1e-8)
        return coverage*(.15+np.sqrt(mask.mean()))+min(plane_area,1.)*2.-(1.-n[1])*.025
    normal=max(candidates,key=score);baseline=score(np.array([0.,1.,0.]));best=score(normal)
    # Avoid rotating an already sound base for an insignificant tessellation fit.
    if best<baseline*1.045+1e-6:normal=np.array([0.,1.,0.])
    # Refine the detected support plane with all its nearby contact vertices.
    for _ in range(2):
        d=vertices@normal;contact=vertices[d<d.min()+epsilon]
        if len(contact)<8:break
        centered=contact-contact.mean(axis=0);_,v=np.linalg.eigh(centered.T@centered);next_normal=v[:,0]
        if next_normal[1]<0:next_normal=-next_normal
        if next_normal[1]>.82 and score(next_normal)>=score(normal)*.98:normal=next_normal
    angle=float(np.degrees(np.arccos(np.clip(normal[1],-1,1))))
    axis=np.cross(normal,[0.,1.,0.]);s=np.linalg.norm(axis)
    if s<1e-8:correction=np.eye(3)
    else:
        k=np.array([[0,-axis[2],axis[1]],[axis[2],0,-axis[0]],[-axis[1],axis[0],0]])
        correction=np.eye(3)+k+k@k*((1-normal[1])/(s*s))
    rotation=correction@old;oriented=p[used]@rotation.T
    # Persist actual base-plane diagnostics for import QA and future replacements.
    final_d=oriented[:,1];contact=oriented[final_d<final_d.min()+epsilon]
    center=contact.mean(axis=0);_,v=np.linalg.eigh((contact-center).T@(contact-center));measured=v[:,0]
    if measured[1]<0:measured=-measured
    poses[name]={'orientation_basis':rotation.T.tolist(),'unleveled_orientation_basis':old.T.tolist(),'oriented_bounds':{'min':oriented.min(axis=0).tolist(),'size':np.ptp(oriented,axis=0).tolist()},'base_alignment':{'method':'lower contact-plane fit','correction_degrees':angle,'contact_tolerance':epsilon,'normal':measured.tolist(),'contact_count':len(contact)}}
    report[name]={'correction_degrees':round(angle,3),'before_score':round(baseline,4),'after_score':round(score(normal),4),'base_normal':measured.tolist(),'contact_count':len(contact)}
(qa/'poses.json').write_text(json.dumps(poses,indent=2));(out/'base-planes.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:round(v['correction_degrees'],2) for k,v in report.items()},indent=2))
