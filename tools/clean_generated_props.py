"""Remove identified disconnected artifacts; derive flat-prop orientation."""
from pathlib import Path
import json,struct,copy
import numpy as np
root=Path(__file__).resolve().parents[1];source=root.parents[1]/'generated models';qa=root/'qa/generated-models'
flat={'table','small_bar_table','map_frame','map_paper','lizard_table','plate','ceiling_hole','dragon_coin','wood_coin','potato_chip','potato_fry','ComfyUI_00056'}
portrait={'menu','shield','door','small_window','map_handle','casino_handle'}
landscape={'large_window'}
upright={'bar_stool'}
keep_counts={'map_paper':1,'map_frame':1,'lizard_table':1,'potato_chip':1,'bar':1,'bottle':1,'wood_coin':1}
poses={};cleanup={}
for name in sorted(flat|portrait|landscape|upright|keep_counts.keys()):
    data=(source/(name+'.glb')).read_bytes();o=12
    while o<len(data):
        n,t=struct.unpack_from('<II',data,o);o+=8
        if t==0x4e4f534a:g=json.loads(data[o:o+n])
        if t==0x004e4942:binary=memoryview(data)[o:o+n]
        o+=n
    part=g['meshes'][0]['primitives'][0]
    def access(i):
        a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];w={'VEC2':2,'VEC3':3,'VEC4':4,'SCALAR':1}[a['type']];dt=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']])
        return np.ndarray((a['count'],w),dtype=dt,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dt.itemsize*w),dt.itemsize))
    attrs={k:access(v) for k,v in part['attributes'].items()};p=attrs['POSITION'];tri=access(part['indices']).reshape(-1,3).astype('i8')
    area=np.linalg.norm(np.cross(p[tri[:,1]]-p[tri[:,0]],p[tri[:,2]]-p[tri[:,0]]),axis=1)/2
    trimmed=0
    if name in {'bar','wood_coin'}:
        # Fused stray loops are not separate components. Find the broad structural
        # base among parallel face planes, then remove geometry below that plane.
        faces=p[tri];cross=np.cross(faces[:,1]-faces[:,0],faces[:,2]-faces[:,0]);normal=cross/np.maximum(2*area[:,None],1e-12)
        expected=np.array([0.,1.,0.])
        if name=='wood_coin':
            middle=faces.mean(axis=1);center=np.average(middle,weights=area,axis=0);d=middle-center;_,axes=np.linalg.eigh((d.T*area)@d/area.sum());expected=axes[:,0]
            if (expected[1] if abs(expected[1])>.1 else expected[2])<0:expected=-expected
        normal[(normal@expected)<0]*=-1
        candidates=normal[((normal@expected)>.55)&(area>np.quantile(area,.70))]
        if len(candidates)>128:candidates=candidates[np.linspace(0,len(candidates)-1,128).astype(int)]
        up=max(candidates,key=lambda n:float(area[(normal@n)>.985].sum()))
        parallel=(normal@up)>.985;up=np.average(normal[parallel],weights=area[parallel],axis=0);up/=np.linalg.norm(up)
        projected=p@up;centers=projected[tri].mean(axis=1);tolerance=np.ptp(projected)*.012
        offsets=centers[parallel];weights=area[parallel]
        strength=np.array([weights[np.abs(offsets-value)<tolerance].sum() for value in offsets])
        supported=offsets[strength>strength.max()*.28];floor=float(supported.min())
        plane_faces=parallel&(np.abs(centers-floor)<tolerance);floor=float(np.average(centers[plane_faces],weights=area[plane_faces]))
        keep=projected[tri].max(axis=1)>=floor-tolerance
        trimmed=int((~keep).sum());tri=tri[keep]
        p=p.copy();under=projected<floor;p[under]+=(floor-projected[under])[:,None]*up
        attrs['POSITION']=p;area=np.linalg.norm(np.cross(p[tri[:,1]]-p[tri[:,0]],p[tri[:,2]]-p[tri[:,0]]),axis=1)/2
        valid=area>1e-10;trimmed+=int((~valid).sum());tri=tri[valid];area=area[valid]
    if name in keep_counts:
        _,inv=np.unique(np.rint(p*1e5).astype('i8'),axis=0,return_inverse=True);parents=list(range(int(inv.max())+1));weight=[1]*len(parents)
        def find(a):
            while parents[a]!=a:parents[a]=parents[parents[a]];a=parents[a]
            return a
        def union(a,b):
            a=find(a);b=find(b)
            if a==b:return
            if weight[a]<weight[b]:a,b=b,a
            parents[b]=a;weight[a]+=weight[b]
        for a,b,c in inv[tri].tolist():union(a,b);union(a,c)
        r=np.array([find(i) for i in inv]);f=r[tri[:,0]];ids=np.unique(f);ordered=sorted(ids,key=lambda v:-float(area[f==v].sum()));mask=np.isin(f,ordered[:keep_counts[name]])
        cleanup[name]={'original_triangles':int(g['accessors'][part['indices']]['count'])//3,'clean_triangles':int(mask.sum()),'removed_components':max(0,len(ids)-keep_counts[name]),'trimmed_below_base':trimmed};tri=tri[mask];area=area[mask]
        used,indices=np.unique(tri,return_inverse=True);blob=bytearray();views=[];accessors=[];newpart={'attributes':{},'material':part.get('material',0)}
        def put(raw):
            while len(blob)%4:blob.append(0)
            views.append({'buffer':0,'byteOffset':len(blob),'byteLength':len(raw)});blob.extend(raw);return len(views)-1
        for k,values in attrs.items():
            a=copy.deepcopy(g['accessors'][part['attributes'][k]]);a.pop('byteOffset',None);a.pop('min',None);a.pop('max',None);a['bufferView']=put(values[used].tobytes());a['count']=len(used)
            if k=='POSITION':a.update(min=values[used].min(axis=0).tolist(),max=values[used].max(axis=0).tolist())
            newpart['attributes'][k]=len(accessors);accessors.append(a)
        newpart['indices']=len(accessors);accessors.append({'bufferView':put(indices.reshape(-1).astype('<u4').tobytes()),'componentType':5125,'count':indices.size,'type':'SCALAR'})
        images=[]
        for image in g['images']:
            old=g['bufferViews'][image['bufferView']];im=copy.deepcopy(image);im['bufferView']=put(binary[old.get('byteOffset',0):old.get('byteOffset',0)+old['byteLength']]);images.append(im)
        output=copy.deepcopy(g);output['meshes']=[{'name':name,'primitives':[newpart]}];output['accessors']=accessors;output['bufferViews']=views;output['buffers']=[{'byteLength':len(blob)}];output['images']=images
        j=json.dumps(output,separators=(',',':')).encode();j+=b' '*((-len(j))%4);blob+=b'\0'*((-len(blob))%4)
        result=struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(blob))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(blob),0x004e4942)+blob
        (qa/('clean-'+name+'.glb')).write_bytes(result)
    if name in flat|portrait|landscape|upright:
        middle=p[tri].mean(axis=1);center=np.average(middle,weights=area,axis=0);d=middle-center;values,v=np.linalg.eigh((d.T*area)@d/area.sum());u=v[:,-1];normal=v[:,0]
        if (normal[1] if abs(normal[1])>.1 else normal[2])<0:normal=-normal
        if u[0]<0:u=-u
        z=np.cross(u,normal);rotation=np.stack([u,normal,z])
        if name=='small_bar_table':
            # A pedestal table's smallest covariance axis is horizontal, unlike
            # a thin tabletop. Choose the authored near-vertical principal axis.
            normal=v[:,np.argmax(np.abs(v[1]))]
            if normal[1]<0:normal=-normal
            right=np.cross(normal,np.array([0.,0.,1.]));right/=np.linalg.norm(right)
            rotation=np.stack([right,normal,np.cross(right,normal)])
        if name in upright:
            up=v[:,np.argmax(np.abs(v[1]))]
            if up[1]<0:up=-up
            right=np.cross(up,np.array([0.,0.,1.]));right/=np.linalg.norm(right)
            rotation=np.stack([right,up,np.cross(right,up)])
        if name in portrait|landscape:
            if normal[2]<0:normal=-normal
            if name in portrait:
                if u[1]<0:u=-u
                right=np.cross(u,normal);rotation=np.stack([right,u,normal])
            else:
                if u[0]<0:u=-u
                up=np.cross(normal,u);rotation=np.stack([u,up,normal])
        if name=='ComfyUI_00056':rotation=np.array([[0,0,1],[0,1,0],[-1,0,0]])@rotation
        oriented=p[np.unique(tri)]@rotation.T
        poses[name]={'orientation_basis':rotation.T.tolist(),'oriented_bounds':{'min':oriented.min(axis=0).tolist(),'size':(oriented.max(axis=0)-oriented.min(axis=0)).tolist()}}
(qa/'prop-cleanup.json').write_text(json.dumps(cleanup,indent=2),encoding='utf-8');(qa/'poses.json').write_text(json.dumps(poses,indent=2),encoding='utf-8')
print(json.dumps(cleanup,indent=2))
