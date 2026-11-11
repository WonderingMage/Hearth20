"""Embed Hearth20 grid scale in a PNG without decoding/re-encoding its pixels.

Usage: python stamp_map.py map.png --width-cells 32 --height-cells 24 --feet-per-cell 5
The output defaults to map.hearth20.png. Existing files are never overwritten.
"""
from pathlib import Path
import argparse, json, math, struct, zlib

SIGNATURE=b'\x89PNG\r\n\x1a\n'
KEY=b'Hearth20.Map\0'

def chunks(data):
    if not data.startswith(SIGNATURE):raise ValueError('Use a PNG image; JPEG files cannot carry this PNG record.')
    offset=8;count=0
    while offset+12<=len(data):
        count+=1
        if count>8192:raise ValueError('Too many PNG chunks.')
        length=struct.unpack_from('>I',data,offset)[0];end=offset+length+12
        if end>len(data):raise ValueError('Truncated PNG chunk.')
        kind=data[offset+4:offset+8];payload=data[offset+8:end-4]
        if zlib.crc32(kind+payload)&0xffffffff!=struct.unpack_from('>I',data,end-4)[0]:raise ValueError('PNG chunk checksum mismatch.')
        yield kind,payload,data[offset:end]
        offset=end
        if kind==b'IEND':
            if offset!=len(data):raise ValueError('Unexpected data after PNG end.')
            return
    raise ValueError('Missing PNG end chunk.')

def stamp(data,width_cells,height_cells=None,feet_per_cell=5.0):
    if len(data)>40*1024**2:raise ValueError('Map exceeds 40 MiB.')
    records=list(chunks(data))
    if not records or records[0][0]!=b'IHDR' or len(records[0][1])!=13:raise ValueError('Invalid PNG image header.')
    width,height=struct.unpack_from('>II',records[0][1])
    if not 1<=width<=16384 or not 1<=height<=16384 or width*height>67108864:raise ValueError('Unsupported map pixel dimensions.')
    if not isinstance(width_cells,int) or not 1<=width_cells<=256:raise ValueError('Map width must be 1 to 256 cells.')
    derived_height=math.ceil(height/(width/width_cells))
    if not 1<=derived_height<=256:raise ValueError('Map height must be 1 to 256 cells at the chosen scale.')
    if height_cells is not None and height_cells!=derived_height:raise ValueError(f'Image aspect ratio requires {derived_height} height cells at this width.')
    if not math.isfinite(feet_per_cell) or not 0<feet_per_cell<=1000:raise ValueError('Feet per cell must be finite and greater than 0, up to 1000.')
    metadata={'schema':1,'width_cells':width_cells,'height_cells':derived_height,'feet_per_cell':feet_per_cell,'pixel_width':width,'pixel_height':height}
    payload=KEY+json.dumps(metadata,separators=(',',':'),allow_nan=False).encode('ascii')
    chunk=struct.pack('>I',len(payload))+b'tEXt'+payload+struct.pack('>I',zlib.crc32(b'tEXt'+payload)&0xffffffff)
    output=bytearray(SIGNATURE)
    for kind,payload,raw in records:
        if kind in (b'tEXt',b'iTXt',b'zTXt') and payload.startswith(KEY):continue
        output.extend(raw)
        if kind==b'IHDR':output.extend(chunk)
    if len(output)>40*1024**2:raise ValueError('Stamped map exceeds 40 MiB.')
    # IDAT chunks remain byte-identical, preserving every image pixel.
    assert [p for k,p,_ in records if k==b'IDAT']==[p for k,p,_ in chunks(output) if k==b'IDAT']
    return bytes(output),metadata

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input',type=Path);parser.add_argument('--width-cells',type=int,required=True)
    parser.add_argument('--height-cells',type=int);parser.add_argument('--feet-per-cell',type=float,default=5)
    parser.add_argument('--out',type=Path)
    args=parser.parse_args();output=args.out or args.input.with_name(args.input.stem+'.hearth20.png')
    try:
        if output.exists() or output.resolve()==args.input.resolve():raise ValueError('Choose a new output path; existing images are never overwritten.')
        if args.input.stat().st_size>40*1024**2:raise ValueError('Map exceeds 40 MiB.')
        data,metadata=stamp(args.input.read_bytes(),args.width_cells,args.height_cells,args.feet_per_cell)
        with output.open('xb') as file:file.write(data)
    except (ValueError,OSError) as error:parser.error(str(error))
    print(json.dumps({'file':str(output.resolve()),'grid':metadata,'pixels_unchanged':True},indent=2))

if __name__=='__main__':main()
