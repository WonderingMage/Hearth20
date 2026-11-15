"""Original bold expression masks and a separate iris layer for A/B eye treatments."""
from pathlib import Path
import math
root=Path(__file__).resolve().parents[1];items=[];irises=[]
def ellipse(x,y=128,rx=28,ry=38):return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}"/>'
def stroke(d,width=12):return f'<path d="{d}" fill="none" stroke="white" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'
def iris(x=80,y=130,rx=16,ry=23):return ellipse(x,y,rx,ry)
def pair_iris(y=130,rx=16,ry=23):return iris(80,y,rx,ry)+iris(176,y,rx,ry)
def add(art,pupils=''):items.append(art);irises.append(pupils)
add(ellipse(80)+ellipse(176),pair_iris())
add(ellipse(80,rx=31,ry=31)+ellipse(176,rx=31,ry=31),pair_iris(rx=19,ry=20))
add(ellipse(80,rx=9,ry=12)+ellipse(176,rx=9,ry=12),pair_iris(rx=4,ry=6))
add(ellipse(80,rx=33,ry=42)+ellipse(176,rx=33,ry=42)+stroke('M50 76 Q80 60 110 76 M146 76 Q176 60 206 76',8),pair_iris(y=132,rx=15,ry=24))
add('<path d="M50 120 H110 Q108 159 80 159 Q52 159 50 120 M146 120 H206 Q204 159 176 159 Q148 159 146 120"/>',pair_iris(y=132,rx=18,ry=25))
add('<path d="M49 105 Q79 111 111 127 Q105 159 78 153 Q52 149 49 105 M145 127 Q177 111 207 105 Q204 149 178 153 Q151 159 145 127"/>',pair_iris(y=133,rx=17,ry=23))
add('<path d="M49 123 Q80 117 109 101 Q112 148 82 157 Q55 158 49 123 M147 101 Q176 117 207 123 Q201 158 174 157 Q144 148 147 101"/>'+stroke('M51 100 Q78 96 105 81 M151 81 Q178 96 205 100',8),pair_iris(y=132,rx=16,ry=22))
add(stroke('M50 145 Q80 92 110 145 M146 145 Q176 92 206 145',15))
add(ellipse(80)+stroke('M147 143 Q176 101 205 143',14),iris())
stars=''
for cx in (80,176):
    points=[]
    for i in range(10):
        a=-math.pi/2+i*math.pi/5;r=36 if i%2==0 else 16;points.append(f'{cx+math.cos(a)*r:.2f},{128+math.sin(a)*r:.2f}')
    stars+='<polygon points="'+' '.join(points)+'"/>'
add(stars)
add(''.join(f'<path d="M{x} 160 C{x-58} 124 {x-22} 78 {x} 109 C{x+22} 78 {x+58} 124 {x} 160"/>' for x in (80,176)))
spirals=''
for cx in (80,176):
    points=[]
    for i in range(100):
        t=i/99.;a=t*math.pi*4.5;r=2+31*t;points.append(f'{cx+math.cos(a)*r:.2f},{128+math.sin(a)*r:.2f}')
    spirals+='<polyline points="'+' '.join(points)+'" fill="none" stroke="white" stroke-width="10" stroke-linecap="round"/>'
add(spirals)
add(ellipse(80,rx=29,ry=31)+ellipse(176,rx=29,ry=31)+stroke('M59 155 L51 168 M79 160 L79 179 M99 154 L109 167 M155 155 L147 168 M175 160 L175 179 M195 154 L205 167',9),pair_iris(rx=18,ry=21))
add(stroke('M57 105 L103 151 M103 105 L57 151 M153 105 L199 151 M199 105 L153 151',15))
add(ellipse(77,122,34,40)+ellipse(180,139,17,23),iris(83,130,14,20)+iris(177,142,7,10))
add(''.join(f'<path d="M{x-35} 128 Q{x} 83 {x+35} 128 Q{x} 173 {x-35} 128"/>' for x in (80,176)),pair_iris(rx=10,ry=27))
add('<path d="M48 134 Q48 87 80 87 Q112 87 112 134 Z M144 134 Q144 87 176 87 Q208 87 208 134 Z"/>',pair_iris(y=130,rx=18,ry=23))
add(ellipse(80,rx=30,ry=34)+ellipse(176,rx=30,ry=34)+stroke('M47 91 L40 81 M111 95 L119 85 M143 91 L136 81 M207 95 L215 85',7),pair_iris(rx=18,ry=23)+''.join(f'<ellipse cx="{x-8}" cy="113" rx="9" ry="11" fill="black"/>' for x in (80,176)))
add('<path d="M49 118 Q80 111 111 118 Q117 128 111 139 Q80 146 49 139 Q43 128 49 118 M145 118 Q176 111 207 118 Q213 128 207 139 Q176 146 145 139 Q139 128 145 118"/>',pair_iris(y=129,rx=15,ry=23))
add(ellipse(80,rx=28,ry=34)+ellipse(176,rx=28,ry=34)+'<path d="M48 151 C31 171 32 184 45 184 C60 184 62 171 48 151 M208 151 C194 171 196 184 209 184 C224 184 226 171 208 151"/>',pair_iris(rx=16,ry=23))
def atlas(parts):
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1280" viewBox="0 0 1024 1280">'
    for i,art in enumerate(parts):svg+=f'<g fill="white" transform="translate({i%4*256},{i//4*256})">{art}</g>'
    return svg+'</svg>'
(root/'source/hearth20/wizard_eye_atlas.svg').write_text(atlas(items))
(root/'source/hearth20/wizard_eye_irises.svg').write_text(atlas(irises))
print('Authored 20 pupil-free expression masks and optional cartoon irises.')
