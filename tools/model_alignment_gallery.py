from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]/'qa/generated-models/alignment'
names=sorted(path.name.removesuffix('-front.png') for path in root.glob('*-front.png'))
for start in range(0,len(names),12):
    canvas=Image.new('RGB',(1380,1040),'#22272a');draw=ImageDraw.Draw(canvas)
    for i,name in enumerate(names[start:start+12]):
        x=(i%3)*460;y=(i//3)*260;draw.text((x+8,y+6),name,fill='white')
        for j,view in enumerate(['front','side']):
            pic=Image.open(root/(name+'-'+view+'.png')).convert('RGB');pic.thumbnail((228,228));canvas.paste(pic,(x+j*230,y+26))
    canvas.save(root/('gallery-'+str(start//12+1)+'.jpg'),quality=94)
