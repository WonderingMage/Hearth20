"""Inventory delivered GLBs and stage the three licensed kits, without editing originals."""
from pathlib import Path, PurePosixPath
import argparse, hashlib, io, json, shutil, struct, zipfile
from PIL import Image

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--source',type=Path,default=root.parents[1]/'generated models')
parser.add_argument('--out',type=Path,default=root/'qa/generated-models')
args=parser.parse_args(); source=args.source.resolve(); out=args.out.resolve()
assert source.is_dir() and out!=source
out.mkdir(parents=True,exist_ok=True)

def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def record(path,name=None):
    binary=b''
    if path.suffix=='.glb':
        data=path.read_bytes();magic,version,length=struct.unpack_from('<III',data)
        assert magic==0x46546c67 and version==2 and length==len(data),path
        cursor=12
        while cursor<len(data):
            size,kind=struct.unpack_from('<II',data,cursor);cursor+=8
            chunk=data[cursor:cursor+size];cursor+=size
            if kind==0x4e4f534a:g=json.loads(chunk)
            elif kind==0x004e4942:binary=chunk
    else:g=json.loads(path.read_text(encoding='utf-8'))
    triangles=0;vertices=0;bounds=[]
    for mesh in g.get('meshes',[]):
        for part in mesh['primitives']:
            assert part.get('mode',4)==4, 'Only static triangle lists are supported'
            position=g['accessors'][part['attributes']['POSITION']]
            vertices+=position['count'];bounds.append([position.get('min'),position.get('max')])
            triangles+=g['accessors'][part['indices']]['count']//3 if 'indices' in part else position['count']//3
    images=[]
    for image in g.get('images',[]):
        if 'bufferView' in image:
            view=g['bufferViews'][image['bufferView']];start=view.get('byteOffset',0);data=binary[start:start+view['byteLength']]
        elif 'uri' in image:
            relative=PurePosixPath(image['uri'])
            assert not relative.is_absolute() and '..' not in relative.parts
            data=path.parent.joinpath(*relative.parts).read_bytes()
        else:continue
        with Image.open(io.BytesIO(data)) as picture:images.append({'bytes':len(data),'dimensions':list(picture.size)})
    return {'name':name or path.name,'source':str(path),'bytes':path.stat().st_size,'sha256':sha(path),'triangles':triangles,'vertices':vertices,'bounds':bounds,'images':images,'nodes':len(g.get('nodes',[])),'meshes':len(g.get('meshes',[])),'materials':len(g.get('materials',[])),'animations':len(g.get('animations',[])),'skins':len(g.get('skins',[]))}

models=[record(path) for path in sorted(source.glob('*.glb'))]
kits={'stylized_low-poly_wooden_beam.zip':'kit_beam','stylized_modular_stonewalls.zip':'kit_stone','tileable_stylized_wooden_floor_texture.zip':'kit_floor'}
archives=[]
for name,id in kits.items():
    archive=source/name; destination=(out/id).resolve()
    assert destination.is_relative_to(out) and destination!=out
    destination.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        entries=[]
        for entry in z.infolist():
            path=PurePosixPath(entry.filename.replace('\\','/'))
            assert not path.is_absolute() and '..' not in path.parts and not any(':' in p for p in path.parts)
            target=destination.joinpath(*path.parts).resolve()
            assert target.is_relative_to(destination)
            if entry.is_dir():target.mkdir(parents=True,exist_ok=True);continue
            target.parent.mkdir(parents=True,exist_ok=True)
            with z.open(entry) as reader,target.open('wb') as writer:shutil.copyfileobj(reader,writer)
            entries.append({'name':entry.filename,'bytes':entry.file_size})
    models.append(record(destination/'scene.gltf',id+'.gltf'))
    archives.append({'name':name,'sha256':sha(archive),'entries':entries})
(out/'inventory.json').write_text(json.dumps({'models':models,'archives':archives},indent=2),encoding='utf-8')
print(json.dumps({'glbs':len(models)-len(kits),'kits':len(kits),'original_triangles':sum(m['triangles'] for m in models),'inventory':str(out/'inventory.json')},indent=2))
