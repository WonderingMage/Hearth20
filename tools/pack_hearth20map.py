"""Create a self-contained .hearth20map from map.json and referenced raster assets.

python pack_hearth20map.py MyMap/map.json --out MyMap.hearth20map
Standard-library only. The source folder and images are never modified.
"""
from pathlib import Path
import argparse,copy,hashlib,json,math,re,struct,zipfile

MAX_PACKAGE=64*1024**2;MAX_MANIFEST=262144
PATH=re.compile(r'assets/[a-z0-9][a-z0-9_-]{0,63}\.(png|jpg|jpeg)\Z')
IDENTIFIER=re.compile(r'[A-Za-z_][A-Za-z0-9_-]{0,95}\Z')
ROOT_KEYS={'format','version','id','title','description','credits','grid','background','walls','doors','windows','lights','foreground','environment','entry_points'}

def number(value,low,high,integer=False):
    return type(value) in (int,float) and math.isfinite(value) and low<=value<=high and (not integer or value==int(value))
def keys(value,allowed):return isinstance(value,dict) and not (set(value)-set(allowed))
def require(ok,note):
    if not ok:raise ValueError(note)
def no_duplicates(pairs):
    result={}
    for key,value in pairs:
        require(key not in result,'Duplicate JSON key: '+key);result[key]=value
    return result
def json_load(path):
    require(path.stat().st_size<=MAX_MANIFEST,'Manifest exceeds 262144 bytes.')
    return json.loads(path.read_text(encoding='utf-8-sig'),object_pairs_hook=no_duplicates,parse_constant=lambda s:(_ for _ in ()).throw(ValueError('Nonfinite JSON number: '+s)))
def dimensions(data):
    if data.startswith(b'\x89PNG\r\n\x1a\n') and len(data)>=33 and data[12:16]==b'IHDR':return struct.unpack_from('>II',data,16),'png'
    if data.startswith(b'\xff\xd8\xff'):
        i=2
        while i+1<len(data):
            if data[i]!=255:i+=1;continue
            while i<len(data) and data[i]==255:i+=1
            if i>=len(data):break
            marker=data[i];i+=1
            if marker in (0xd9,0xda):break
            if marker in (0xd8,1) or 0xd0<=marker<=0xd7:continue
            if i+2>len(data):break
            length=struct.unpack_from('>H',data,i)[0]
            if length<2 or i+length>len(data):break
            if marker in (0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf) and length>=7:
                height,width=struct.unpack_from('>HH',data,i+3);return (width,height),'jpeg'
            i+=length
    raise ValueError('Referenced image has no supported PNG/JPEG header.')

def prepare(manifest,folder):
    m=copy.deepcopy(manifest);folder=Path(folder).resolve();assets={}
    require(keys(m,ROOT_KEYS) and m.get('format')=='hearth20-map' and number(m.get('version'),1,1,True),'Use format hearth20-map, version 1 and documented root fields.')
    require(isinstance(m.get('id'),str) and IDENTIFIER.fullmatch(m['id']) and isinstance(m.get('title'),str) and 0<len(m['title'].strip())<=96,'Give the map a valid ID and title.')
    for key,limit in [('description',2000),('credits',4000)]:
        require(isinstance(m.get(key,''),str) and len(m.get(key,''))<=limit,'Invalid '+key+' text length/type.')
    grid=m.get('grid');require(keys(grid,{'width_cells','height_cells','feet_per_cell'}),'Invalid grid fields.')
    require(number(grid.get('width_cells'),1,256,True) and number(grid.get('height_cells'),1,256,True) and number(grid.get('feet_per_cell'),.01,1000),'Invalid grid dimensions/scale.')
    w,h=grid['width_cells'],grid['height_cells']
    def point(p):return keys(p,{'x','y'}) and len(p)==2 and number(p.get('x'),0,w) and number(p.get('y'),0,h)
    def image(record,foreground=False):
        require(keys(record,{'path','sha256'}) and isinstance(record.get('path'),str) and PATH.fullmatch(record['path']),'Image path must be assets/lowercase-slug.png, .jpg or .jpeg.')
        path=(folder/record['path']).resolve();require(folder in path.parents,'An asset resolves outside the authoring folder.')
        require(path.is_file() and 0<path.stat().st_size<=(8 if foreground else 40)*1024**2,'Missing or oversized image: '+record['path'])
        data=path.read_bytes();(pw,ph),kind=dimensions(data)
        require(pw>0 and ph>0 and max(pw,ph)<=(2048 if foreground else 16384) and pw*ph<=(4194304 if foreground else 67108864),'Image dimensions exceed the supported limit.')
        require(not foreground or kind=='png','Foreground objects must be transparent PNGs.')
        digest=hashlib.sha256(data).hexdigest()
        require('sha256' not in record or record['sha256']==digest,'Stale image checksum: '+record['path'])
        record['sha256']=digest;assets[record['path']]=data
        return pw,ph
    pw,ph=image(m.get('background'));require(abs(ph-h*(pw/w))<=.01,'Background pixel aspect ratio must match complete square grid cells.')
    ids=set();windows={};annotation_count=0
    def unique(record):
        require(isinstance(record,dict) and isinstance(record.get('id'),str) and IDENTIFIER.fullmatch(record['id']) and record['id'] not in ids,'Invalid or duplicate object ID.')
        ids.add(record['id'])
    for collection in ('walls','doors','windows','lights','foreground','entry_points'):
        require(isinstance(m.get(collection,[]),list),collection+' must be an array.')
    for collection in ('walls','doors','windows'):
        for record in m.get(collection,[]):
            require(keys(record,{'id','a','b','open'} if collection=='doors' else {'id','a','b'}),'Unknown segment field.');unique(record)
            require(point(record.get('a')) and point(record.get('b')) and math.dist((record['a']['x'],record['a']['y']),(record['b']['x'],record['b']['y']))>=.001,'Invalid segment endpoints.')
            require(type(record.get('open',False)) is bool,'Door open must be a boolean.')
            if collection=='windows':windows[record['id']]=record
            annotation_count+=1
    for light in m.get('lights',[]):
        require(keys(light,{'id','position','source_type','bright_feet','dim_feet','light_color','angle_degrees','spread_degrees','ray_strength','enabled','window_id','window_height','sill_height'}),'Unknown light field.');unique(light)
        require(point(light.get('position')) and light.get('source_type','torch') in ('torch','brazier','window','sunlight','moonlight','crystal'),'Invalid light position/type.')
        require(type(light.get('enabled',True)) is bool and isinstance(light.get('light_color','#ffcd8e'),str) and re.fullmatch(r'#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?',light.get('light_color','#ffcd8e')),'Invalid light enable/color.')
        for key,low,high,default in [('bright_feet',0,1000,20),('dim_feet',0,1000,20),('angle_degrees',-360,360,0),('spread_degrees',1,360,360),('ray_strength',0,1,.55),('window_height',.1,100,7),('sill_height',.1,100,3)]:
            require(number(light.get(key,default),low,high),'Invalid light value: '+key)
        if light.get('source_type')=='window':
            require(isinstance(light.get('window_id'),str),'Window light needs a string window_id.')
            window=windows.get(light.get('window_id'));require(window is not None,'Window light needs a known window_id.')
            a,b=window['a'],window['b'];center=((a['x']+b['x'])/2,(a['y']+b['y'])/2);p=light['position']
            require(math.dist((p['x'],p['y']),center)<=1.5,'Window light must be within 1.5 cells of the aperture midpoint.')
            dx,dy=b['x']-a['x'],b['y']-a['y'];angle=math.radians(light.get('angle_degrees',0))
            require(abs((-dy*math.cos(angle)+dx*math.sin(angle))/math.hypot(dx,dy))>=.5,'Window light direction must cross its aperture.')
        annotation_count+=1
    require(annotation_count<=256,'At most 256 walls, doors, windows and lights in total.')
    require(len(m.get('foreground',[]))<=64,'At most 64 foreground objects.')
    for record in m.get('foreground',[]):
        require(keys(record,{'id','name','image','position','width_cells','height_cells','rotation_degrees'}),'Unknown foreground field.');unique(record)
        require(isinstance(record.get('name'),str) and len(record['name'])<=64 and point(record.get('position')),'Invalid foreground name/position.')
        require(number(record.get('width_cells'),.1,64) and number(record.get('height_cells'),.1,64) and number(record.get('rotation_degrees',0),-360,360),'Invalid foreground extent/rotation.')
        image(record.get('image'),True)
        angle=math.radians(record.get('rotation_degrees',0));c,s=abs(math.cos(angle)),abs(math.sin(angle))
        ex=(c*record['width_cells']+s*record['height_cells'])/2;ey=(s*record['width_cells']+c*record['height_cells'])/2;p=record['position']
        require(ex<=p['x']<=w-ex and ey<=p['y']<=h-ey,'Rotated foreground footprint leaves the map.')
    env=m.get('environment',{});require(keys(env,{'dynamic_lighting','ambient_light','outdoor','natural_light','roof_rects'}),'Unknown environment field.')
    for key in ('dynamic_lighting','outdoor'):require(type(env.get(key,True if key=='dynamic_lighting' else False)) is bool,'Environment flags must be booleans.')
    require(env.get('ambient_light','dark') in ('bright','dim','dark'),'Invalid ambient light level.')
    natural=env.get('natural_light',{});require(keys(natural,{'time_hours','north_degrees','sun_intensity','moon_intensity','haze','exposure'}),'Unknown natural-light field.')
    for key,value in natural.items():require(number(value,0,24 if key=='time_hours' else 360 if key=='north_degrees' else 1 if key=='haze' else 3),'Natural-light value is out of range: '+key)
    roofs=env.get('roof_rects',[]);require(isinstance(roofs,list) and len(roofs)<=64,'At most 64 roof rectangles.')
    for roof in roofs:
        require(keys(roof,{'x','y','width','height'}) and len(roof)==4 and all(number(roof.get(k),0,w if k in ('x','width') else h) for k in ('x','y','width','height')) and roof['width']>0 and roof['height']>0 and roof['x']+roof['width']<=w and roof['y']+roof['height']<=h,'Invalid roof rectangle.')
    starts=m.get('entry_points',[]);require(1<=len(starts)<=16,'Provide 1 to 16 entry points.')
    positions=set()
    for p in starts:
        require(point(p) and p['x']<w and p['y']<h and p['x']%1==.5 and p['y']%1==.5 and (p['x'],p['y']) not in positions,'Entry points must be distinct square centers.')
        positions.add((p['x'],p['y']))
    encoded=json.dumps(m,ensure_ascii=False,allow_nan=False,indent=2).encode('utf-8')
    require(len(encoded)<=MAX_MANIFEST and len(assets)+1<=66 and len(encoded)+sum(map(len,assets.values()))+16384<=MAX_PACKAGE,'Package exceeds its manifest/asset/64 MiB budget.')
    return m,encoded,assets

def build(manifest,folder,output):
    output=Path(output);require(output.suffix.lower()=='.hearth20map','Output must end in .hearth20map.')
    m,encoded,assets=prepare(manifest,folder)
    with output.open('xb') as stream:
        with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_STORED,allowZip64=False) as archive:
            archive.writestr('map.json',encoded)
            for path,data in sorted(assets.items()):archive.writestr(path,data)
    return {'file':str(output.resolve()),'title':m['title'],'grid':m['grid'],'objects':{key:len(m.get(key,[])) for key in ('walls','doors','windows','lights','foreground')},'bytes':output.stat().st_size,'sha256':hashlib.sha256(output.read_bytes()).hexdigest()}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('manifest',type=Path);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
    try:result=build(json_load(args.manifest),args.manifest.resolve().parent,args.out)
    except (OSError,ValueError,RecursionError,zipfile.BadZipFile) as error:parser.error(str(error))
    print(json.dumps(result,indent=2))
if __name__=='__main__':main()
