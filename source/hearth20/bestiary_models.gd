extends RefCounted
class_name Hearth20BestiaryModels
## Original colored 3D sculptures of twenty 2014 fifth-edition creatures.
## Geometry is authored here; no third-party meshes, images or private books ship.
const IDS := ["adult-red-dragon","beholder","mind-flayer","owlbear","mimic","gelatinous-cube","goblin","orc","kobold","troll","ogre","skeleton","zombie","wraith","giant-spider","basilisk","rust-monster","carrion-crawler","purple-worm","gibbering-mouther"]
const SKIN := """
shader_type spatial;
render_mode cull_back;
uniform vec4 pigment : source_color=vec4(.5,.2,.1,1);
uniform float grain=1.0;
uniform float metal=0.0;
varying vec3 local;
float hash(vec3 p){p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){local=VERTEX;}
void fragment(){
 float n=noise(local*13.0)+noise(local*43.0)*.28;
 float mottling=noise(local*3.7);
 ALBEDO=pigment.rgb*(.77+.18*n+.10*mottling);
 ROUGHNESS=clamp(.58+grain*.18-n*.11,.18,.95);
 METALLIC=metal;
 NORMAL=normalize(NORMAL+vec3(noise(local*37.0)-.5,noise(local*37.0+7.0)-.5,noise(local*37.0+17.0)-.5)*grain*.065);
}
"""
static var skin_shader: Shader
var root: Node3D
var sculpt: Node3D
var materials: Dictionary={}
var rng:=RandomNumberGenerator.new()

static func build(id: String) -> Node3D:
	if id not in IDS: return null
	var maker:=Hearth20BestiaryModels.new()
	maker.rng.seed=IDS.find(id)*73471+57
	maker.root=Hearth20BestiaryActor.new(); maker.root.name=id.to_pascal_case()
	maker.root.set_meta("compendium_creature",id)
	maker.sculpt=Node3D.new(); maker.sculpt.name="Sculpt"; maker.sculpt.set_meta("idle_motion","hover" if id in ["beholder","wraith","mind-flayer"] else "breath"); maker.root.add_child(maker.sculpt)
	match id:
		"adult-red-dragon": maker.dragon()
		"beholder": maker.beholder()
		"mind-flayer": maker.humanoid("mind-flayer")
		"owlbear": maker.owlbear()
		"mimic": maker.mimic()
		"gelatinous-cube": maker.cube()
		"goblin","orc","kobold","troll","ogre","zombie": maker.humanoid(id)
		"skeleton": maker.skeleton()
		"wraith": maker.wraith()
		"giant-spider": maker.spider()
		"basilisk": maker.basilisk()
		"rust-monster": maker.rust_monster()
		"carrion-crawler": maker.crawler()
		"purple-worm": maker.worm()
		"gibbering-mouther": maker.mouther()
	maker._own(maker.root,maker.root)
	return maker.root

func _own(node: Node, owner_root: Node) -> void:
	if node!=owner_root: node.owner=owner_root
	for child in node.get_children(): _own(child,owner_root)

func mat(hex: String, grain: float=1.0, metal: float=0.0) -> Material:
	var key:=hex+str(grain)+str(metal)
	if materials.has(key): return materials[key]
	if skin_shader==null: skin_shader=Shader.new(); skin_shader.code=SKIN
	var material:=ShaderMaterial.new(); material.shader=skin_shader
	material.set_shader_parameter("pigment",Color(hex)); material.set_shader_parameter("grain",grain); material.set_shader_parameter("metal",metal)
	materials[key]=material; return material

func node(parent: Node3D=null, motion: String="") -> Node3D:
	var part:=Node3D.new(); (parent if parent!=null else sculpt).add_child(part)
	if not motion.is_empty(): part.set_meta("idle_motion",motion)
	return part

func mesh(shape: Mesh, at: Vector3, material: Material, parent: Node3D=null) -> MeshInstance3D:
	var instance:=MeshInstance3D.new(); instance.mesh=shape; instance.material_override=material; instance.position=at
	(parent if parent!=null else sculpt).add_child(instance)
	return instance

func orb(at: Vector3, scale: Vector3, material: Material, parent: Node3D=null) -> MeshInstance3D:
	var sphere:=SphereMesh.new(); sphere.radial_segments=32; sphere.rings=20; sphere.radius=1; sphere.height=2
	var instance:=mesh(sphere,at,material,parent); instance.scale=scale; return instance

func box(at: Vector3, size: Vector3, material: Material, parent: Node3D=null) -> MeshInstance3D:
	var shape:=BoxMesh.new(); shape.size=size
	return mesh(shape,at,material,parent)

func tube(points: Array, widths: Array, material: Material, parent: Node3D=null, sides: int=12) -> MeshInstance3D:
	var smooth_points: Array=[]; var smooth_widths: Array=[]
	for segment in range(points.size()-1):
		var p0: Vector3=points[maxi(0,segment-1)]; var p1: Vector3=points[segment]; var p2: Vector3=points[segment+1]; var p3: Vector3=points[mini(points.size()-1,segment+2)]
		for step in 6:
			var t:=float(step)/6.0
			smooth_points.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
			smooth_widths.append(lerpf(float(widths[mini(segment,widths.size()-1)]),float(widths[mini(segment+1,widths.size()-1)]),t))
	smooth_points.append(points[-1]); smooth_widths.append(widths[-1])
	points=smooth_points; widths=smooth_widths
	var vertices:=PackedVector3Array(); var normals:=PackedVector3Array(); var indices:=PackedInt32Array()
	var previous_lateral:=Vector3.ZERO
	for i in points.size():
		var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var lateral: Vector3=(previous_lateral-tangent*previous_lateral.dot(tangent)).normalized() if i>0 else tangent.cross(Vector3.UP if absf(tangent.y)<.90 else Vector3.RIGHT).normalized()
		previous_lateral=lateral
		var vertical:=tangent.cross(lateral).normalized()
		for j in sides:
			var radial:=lateral*cos(float(j)*TAU/sides)+vertical*sin(float(j)*TAU/sides)
			vertices.append(points[i]+radial*maxf(.002,float(widths[mini(i,widths.size()-1)]))); normals.append(radial)
			if i>0:
				var a: int=(i-1)*sides+j; var b: int=(i-1)*sides+(j+1)%sides; var c: int=i*sides+j; var d: int=i*sides+(j+1)%sides
				indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_INDEX]=indices
	var shape:=ArrayMesh.new(); shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh(shape,Vector3.ZERO,material,parent)

func spike(a: Vector3, b: Vector3, radius: float, material: Material, parent: Node3D=null) -> void:
	tube([a,a.lerp(b,.55)+Vector3(0,.015,0),b],[radius,radius*.48,.002],material,parent)

func eye(at: Vector3, size: float, iris: String="#d9b65a", parent: Node3D=null, normal: Vector3=Vector3.FORWARD*-1) -> void:
	var socket:=node(parent); socket.position=at; socket.basis=Basis.looking_at(-normal,Vector3.UP if absf(normal.y)<.95 else Vector3.RIGHT)
	orb(Vector3.ZERO,Vector3(size,size*.78,size*.58),mat("#ded6ad",.3),socket)
	var pupil:=node(socket,"eye")
	orb(Vector3(0,0,size*.50),Vector3(size*.55,size*.57,size*.10),mat(iris,.1),pupil)
	orb(Vector3(0,0,size*.59),Vector3(size*.17,size*.41,size*.035),mat("#080b09",.1),pupil)
	orb(Vector3(-size*.16,size*.19,size*.63),Vector3.ONE*size*.10,mat("#fff5db",.0),pupil)

func mouth(at: Vector3, width: float, height: float, parent: Node3D=null) -> void:
	var jaw:=node(parent,"jaw"); jaw.position=at
	orb(Vector3.ZERO,Vector3(width,height,.10),mat("#17090c"),jaw)
	var gum:=mat("#733140")
	for i in 12:
		var angle:=float(i)/11.0*PI
		var x:=cos(angle)*width*.90; var y:=sin(angle)*height*.80
		orb(Vector3(x,y,.035),Vector3(width*.10,height*.16,.055),gum,jaw)
		spike(Vector3(x,y,.12),Vector3(x*.92,y-height*.42,.17),width*.065,mat("#ded5b4",.3),jaw)
		spike(Vector3(x,-y,.10),Vector3(x*.93,-y+height*.38,.16),width*.055,mat("#e9ddbd",.3),jaw)

func limb(points: Array, widths: Array, skin: Material, parent: Node3D=null) -> void:
	tube(points,widths,skin,parent,16)
	for i in range(1,points.size()-1): orb(points[i],Vector3.ONE*float(widths[mini(i,widths.size()-1)])*1.03,skin,parent)

func paw(at: Vector3, size: float, skin: Material, parent: Node3D=null) -> void:
	orb(at,Vector3(size,size*.52,size*1.25),skin,parent)
	for i in 3:
		var p:=at+Vector3((float(i)-1)*size*.5,-size*.15,size*.8)
		spike(p,p+Vector3(0,-size*.15,size*.7),size*.12,mat("#e4d6b8",.25),parent)

func fur(center: Vector3, radii: Vector3, color: String, count: int=600) -> void:
	var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var z:=rng.randf_range(-1,1); var angle:=rng.randf()*TAU
		var normal:=Vector3(sqrt(1-z*z)*cos(angle),z,sqrt(1-z*z)*sin(angle))
		var point:=center+normal*radii
		var side:=normal.cross(Vector3.RIGHT).normalized()*.013
		for p in [point-side,point+normal*rng.randf_range(.03,.085)+Vector3(0,-.025,0),point+side]:
			st.set_normal(normal); st.add_vertex(p)
	mesh(st.commit(),Vector3.ZERO,mat(color))

func beholder() -> void:
	var skin:=mat("#7a5745",1.3); var ridge:=mat("#9b7955")
	orb(Vector3(0,1.15,0),Vector3(1,.91,.85),skin)
	for i in 95:
		var n:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		orb(Vector3(0,1.15,0)+n*Vector3(.94,.84,.78),Vector3.ONE*rng.randf_range(.045,.12),ridge)
	eye(Vector3(0,1.40,.76),.47,"#e9a44b")
	mouth(Vector3(0,.71,.70),.66,.29)
	for i in 10:
		var angle:=PI*.10+float(i)/9.0*PI*.80
		var side:=1.0 if i%2==0 else -1.0
		var origin:=Vector3(cos(angle)*.82,1.15+sin(angle)*.62,-.08+side*.2)
		var tip:=Vector3(cos(angle)*(1.15+float(i%3)*.12),1.15+sin(angle)*1.55,.06+side*.3)
		var stalk:=node(null,"tendril")
		tube([origin,origin.lerp(tip,.4)+Vector3(side*.18,.12,0),tip],[.13,.09,.055],skin,stalk)
		eye(tip,.16,"#d9c15c",stalk)

func dragon() -> void:
	var red:=mat("#9c3027",1.25); var dark:=mat("#5b201f"); var horn:=mat("#d7b88d",.6)
	orb(Vector3(0,1.1,-.1),Vector3(.68,.77,1.02),red)
	limb([Vector3(0,1.2,.55),Vector3(0,1.80,1.05),Vector3(0,2.25,1.25)],[.39,.30,.22],red)
	orb(Vector3(0,2.30,1.45),Vector3(.37,.32,.57),red)
	orb(Vector3(0,2.14,1.66),Vector3(.29,.12,.43),dark)
	for side in [-1.0,1.0]:
		eye(Vector3(side*.28,2.39,1.69),.10,"#f3bf45")
		spike(Vector3(side*.23,2.54,1.22),Vector3(side*.47,2.92,.83),.12,horn)
		orb(Vector3(side*.16,2.36,1.96),Vector3(.055,.04,.025),mat("#1b1112"))
		for z in [-.70,.58]:
			limb([Vector3(side*.45,1.1,z),Vector3(side*.72,.57,z+.2),Vector3(side*.77,.20,z+.28)],[.28,.20,.15],red)
			paw(Vector3(side*.78,.15,z+.42),.22,red)
		wing(side,red,mat("#783127",.5),horn)
	for i in 10:
		orb(Vector3(0,1.05+float(i)*.11,.77+float(i)*.055),Vector3(.27-float(i)*.012,.08,.10),mat("#ce9953"))
	var tail: Array=[]; var widths: Array=[]
	for i in 20:
		var t:=float(i)/19
		tail.append(Vector3(sin(t*PI)*.78,1.0-t*.75,-.7-t*2.5)); widths.append(.36*(1-t)+.005)
	tube(tail,widths,red)
	for i in 16:
		var t:=float(i)/15
		var p:=Vector3(sin(maxf(t-.35,0)*PI)*.6,1.9-t*.9,.8-t*3.4)
		spike(p,p+Vector3(0,.20*(1-t)+.08,-.09),.085*(1-t)+.02,horn)
	for i in 11:
		var p:=Vector3((float(i)-5)*.046,2.18,1.98)
		spike(p,p+Vector3(0,-.07,0),.018,horn)

func wing(side: float, bone: Material, membrane: Material, ivory: Material) -> void:
	var w:=node(null,"wing")
	var base:=Vector3(side*.40,1.65,-.10)
	var elbow:=Vector3(side*1.35,2.15,-.12)
	var fingers: Array=[Vector3(side*2.75,2.65,-.45),Vector3(side*2.42,1.65,-.92),Vector3(side*1.85,1.10,-1.30),Vector3(side*.85,1.0,-1.18)]
	tube([base,elbow,fingers[0]],[.17,.11,.025],bone,w)
	for tip in fingers: tube([elbow,elbow.lerp(tip,.5)+Vector3(0,.06,0),tip],[.075,.04,.005],bone,w)
	for i in 3:
		var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in 10:
			var t0:=float(row)/10; var t1:=float(row+1)/10
			for col in 10:
				var u0:=float(col)/10; var u1:=float(col+1)/10
				var corners: Array=[]
				for uv in [Vector2(t0,u0),Vector2(t1,u0),Vector2(t1,u1),Vector2(t0,u1)]:
					var edge: Vector3=Vector3(fingers[i]).lerp(fingers[i+1],uv.y)
					var point:=elbow.lerp(edge,uv.x)
					point.y-=sin(uv.x*PI)*sin(uv.y*PI)*.20
					corners.append(point)
				for k in [0,1,2,0,2,3,2,1,0,3,2,0]: st.add_vertex(corners[k])
		st.generate_normals(); mesh(st.commit(),Vector3.ZERO,membrane,w)
	spike(elbow,elbow+Vector3(side*.06,.29,.08),.07,ivory,w)

func owlbear() -> void:
	var brown:=mat("#66492e",1.8); var tan:=mat("#c1a56b",1.4)
	orb(Vector3(0,.86,-.15),Vector3(.67,.73,.95),brown); fur(Vector3(0,.86,-.15),Vector3(.65,.71,.94),"#7b5a37",1700)
	for side in [-1.0,1.0]:
		for z in [-.65,.60]:
			limb([Vector3(side*.43,.91,z),Vector3(side*.52,.47,z+.1),Vector3(side*.53,.15,z+.23)],[.25,.22,.16],brown)
			paw(Vector3(side*.54,.13,z+.34),.25,brown)
	orb(Vector3(0,1.37,.76),Vector3(.63,.62,.48),tan)
	for side in [-1.0,1.0]:
		orb(Vector3(side*.25,1.48,1.10),Vector3(.26,.31,.11),mat("#e0c995"))
		eye(Vector3(side*.25,1.49,1.20),.15,"#d8a937")
		spike(Vector3(side*.39,1.78,.81),Vector3(side*.55,2.12,.83),.13,brown)
	tube([Vector3(0,1.40,1.13),Vector3(0,1.27,1.39),Vector3(0,1.10,1.36)],[.16,.14,.006],mat("#38322a"))
	for i in 12:
		var a:=float(i)/12*TAU; spike(Vector3(cos(a)*.50,1.38+sin(a)*.51,1.02),Vector3(cos(a)*.58,1.38+sin(a)*.60,.96),.055,brown)

func humanoid(kind: String) -> void:
	var palette: Dictionary={"goblin":"#71834a","orc":"#6c7652","kobold":"#a45135","troll":"#657d56","ogre":"#a18363","zombie":"#7e9589","mind-flayer":"#8c718b"}
	var skin:=mat(palette[kind],1.3)
	var cloth:=mat("#493b31",1.6); var leather:=mat("#362b24"); var iron:=mat("#757675",.25,.65); var bone:=mat("#daceb1",.4)
	var heavy:=kind in ["troll","ogre","orc"]
	var tall:=1.25 if kind=="troll" else 1.0
	var width:=.49 if kind=="ogre" else .36 if heavy else .27
	var leg_y:=.72*tall
	var torso_y:=1.18*tall
	orb(Vector3(0,torso_y,0),Vector3(width,.54*tall,.27 if heavy else .21),skin)
	if kind=="ogre": orb(Vector3(0,1.12,.12),Vector3(.48,.43,.34),skin)
	for side in [-1.0,1.0]:
		limb([Vector3(side*width*.58,leg_y,0),Vector3(side*width*.78,.42*tall,.06),Vector3(side*width*.82,.12,.02)],[.18 if heavy else .12,.13 if heavy else .09,.09],skin)
		orb(Vector3(side*width*.82,.10,.15),Vector3(.15,.10,.27),leather if kind not in ["troll","zombie","kobold"] else skin)
		var shoulder:=Vector3(side*width*.95,1.52*tall,0)
		var elbow:=Vector3(side*(width+.21),1.03*tall,.06)
		var wrist:=Vector3(side*(width+.30),(.64 if kind=="troll" else .91)*tall,.21)
		limb([shoulder,elbow,wrist],[.20 if heavy else .13,.15 if heavy else .09,.09 if heavy else .065],skin)
		orb(wrist,Vector3(.13,.17,.08),skin)
		for finger in 4:
			var p:=wrist+Vector3((float(finger)-1.5)*.049,-.08,.05)
			tube([p,p+Vector3(0,-.13,.05),p+Vector3(side*.015,-.19,.08)],[.027,.019,.007],skin)
	var head_at:=Vector3(0,1.89*tall,.015)
	var big_head:=1.28 if kind in ["goblin","kobold"] else 1.0
	orb(head_at,Vector3(.27*big_head,.31,.25*big_head),skin)
	orb(head_at+Vector3(0,-.14,.08),Vector3(.24,.17,.24),skin)
	if kind in ["goblin","orc","troll"]:
		for side in [-1.0,1.0]:
			tube([head_at+Vector3(side*.22,.01,0),head_at+Vector3(side*.38,.05,.02),head_at+Vector3(side*.55,.16,-.04)],[.11,.10,.003],skin)
	if kind!="mind-flayer":
		for side in [-1.0,1.0]:
			eye(head_at+Vector3(side*.12,.04,.245),.064,"#e9b45c" if kind!="zombie" else "#cbce82")
			orb(head_at+Vector3(side*.13,.12,.22),Vector3(.15,.06,.07),skin)
		orb(head_at+Vector3(0,-.035,.26),Vector3(.075,.10,.095),skin)
		mouth(head_at+Vector3(0,-.17,.25),.17,.065)
		if kind in ["orc","ogre","troll"]:
			for side in [-1.0,1.0]: spike(head_at+Vector3(side*.13,-.20,.28),head_at+Vector3(side*.17,-.03,.33),.035,bone)
	if kind=="mind-flayer":
		robe(sculpt,mat("#29243b",1.4),Vector3(0,.90,0),.55,.86)
		for side in [-1.0,1.0]:
			eye(head_at+Vector3(side*.13,.04,.23),.065,"#ded5ba")
			spike(Vector3(side*.25,1.55,0),Vector3(side*.48,1.88,-.12),.18,mat("#4a405f",.5,.4))
		for i in 4:
			var x: float=(float(i)-1.5)*.10
			var tentacle:=node(null,"tendril")
			tube([head_at+Vector3(x,-.10,.24),head_at+Vector3(x*1.6,-.30,.37),head_at+Vector3(x*1.9,-.58,.43),head_at+Vector3(x*1.4,-.67,.62)],[.075,.063,.038,.003],skin,tentacle,16)
		for i in 8: orb(Vector3(0,1.18+float(i)*.055,.31),Vector3(.025,.025,.01),mat("#c2a366",.2,.6))
	elif kind=="kobold":
		orb(head_at+Vector3(0,-.09,.28),Vector3(.20,.13,.32),skin)
		for side in [-1.0,1.0]: spike(head_at+Vector3(side*.18,.19,0),head_at+Vector3(side*.28,.42,-.10),.075,bone)
		tube([Vector3(0,.77,-.12),Vector3(.28,.45,-.50),Vector3(.63,.36,-.84),Vector3(.73,.42,-1.05)],[.16,.10,.06,.003],skin)
		spike(Vector3(.56,.15,.31),Vector3(.56,2.65,.31),.032,mat("#725333"))
		spike(Vector3(.56,2.65,.31),Vector3(.56,2.96,.31),.075,iron)
	elif kind=="troll":
		orb(head_at+Vector3(0,-.07,.28),Vector3(.09,.20,.12),skin)
		for i in 44:
			var n:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
			orb(Vector3(0,torso_y,0)+n*Vector3(width,.52*tall,.26),Vector3.ONE*rng.randf_range(.025,.055),mat("#7b8853"))
	elif kind=="zombie":
		for i in 7:
			var p:=Vector3(rng.randf_range(-.2,.2),rng.randf_range(.96,1.50),.22)
			tube([p,p+Vector3(.08,.03,.01)],[.018,.012],mat("#7a3d43"))
		robe(sculpt,mat("#455967",1.8),Vector3(0,.62,0),.32,.30)
	else:
		robe(sculpt,cloth,Vector3(0,.66,0),width*1.12,.32)
		box(Vector3(0,.92,.01),Vector3(width*2+.03,.10,.50),leather)
		box(Vector3(0,.92,.28),Vector3(.13,.12,.035),mat("#b19a61",.3,.6))
		if kind in ["orc","goblin"]:
			orb(Vector3(0,1.27,-.03),Vector3(width*1.02,.41,.24),leather)
			for side in [-1.0,1.0]:
				orb(Vector3(side*width,1.52,.0),Vector3(.24,.14,.22),iron)
				for j in 3: spike(Vector3(side*width,1.60,float(j)*.10-.1),Vector3(side*(width+.06),1.82,float(j)*.10-.1),.035,bone)
		if kind=="ogre":
			tube([Vector3(.8,.42,.3),Vector3(.82,1.2,.3),Vector3(.82,1.85,.3)],[.075,.15,.23],mat("#66513a",1.5))
			for i in 9:
				var a:=float(i)*2.39996; var p:=Vector3(.82+cos(a)*.21,1.3+float(i%3)*.17,.3+sin(a)*.21)
				spike(p,p+Vector3(cos(a)*.09,0,sin(a)*.09),.035,iron)
		else:
			spike(Vector3(.66,.50,.33),Vector3(.66,1.32,.33),.035,mat("#60432a"))
			box(Vector3(.80,1.34,.33),Vector3(.32,.32,.075),iron)

func robe(parent: Node3D, material: Material, center: Vector3, radius: float, height: float) -> void:
	var shape:=CylinderMesh.new(); shape.top_radius=radius*.62; shape.bottom_radius=radius; shape.height=height*2; shape.radial_segments=24
	mesh(shape,center,material,parent)
	for i in 20:
		var a:=float(i)/20*TAU
		tube([center+Vector3(cos(a)*radius*.62,height,sin(a)*radius*.62),center+Vector3(cos(a)*radius*.82,0,sin(a)*radius*.82),center+Vector3(cos(a)*radius,-height,sin(a)*radius)],[.016,.023,.03],material,parent,8)

func skeleton() -> void:
	var bone:=mat("#c8b98f",.8); var joint:=mat("#9a8c6d")
	for side in [-1.0,1.0]:
		limb([Vector3(side*.15,.85,0),Vector3(side*.20,.47,.03),Vector3(side*.19,.10,0)],[.075,.06,.05],bone)
		orb(Vector3(side*.20,.08,.13),Vector3(.09,.05,.23),bone)
		limb([Vector3(side*.25,1.53,0),Vector3(side*.45,1.17,.02),Vector3(side*.53,.92,.13)],[.065,.05,.035],bone)
		for i in 4: tube([Vector3(side*.53+(float(i)-1.5)*.025,.92,.13),Vector3(side*.55+(float(i)-1.5)*.034,.74,.19)],[.014,.008],bone)
	tube([Vector3(0,.82,0),Vector3(0,1.1,-.02),Vector3(0,1.5,0),Vector3(0,1.72,0)],[.09,.07,.06,.045],bone)
	for i in 8:
		var y:=1.13+float(i)*.055; var radius:=.23-sin(float(i)/8*PI)*-.04
		for side in [-1.0,1.0]:
			var points: Array=[]
			for j in 12:
				var a:=float(j)/11*PI*.95
				points.append(Vector3(side*sin(a)*radius,y-cos(a)*.035,-cos(a)*.15))
			tube(points,[.018],bone)
	orb(Vector3(0,.83,0),Vector3(.22,.11,.12),bone)
	orb(Vector3(0,1.88,.02),Vector3(.23,.27,.20),bone)
	orb(Vector3(0,1.72,.12),Vector3(.17,.08,.12),bone)
	for side in [-1.0,1.0]: orb(Vector3(side*.09,1.91,.19),Vector3(.075,.085,.035),mat("#211d19"))
	orb(Vector3(0,1.80,.21),Vector3(.035,.05,.015),joint)
	for i in 8: box(Vector3((float(i)-3.5)*.033,1.73,.235),Vector3(.025,.045,.02),bone)
	tube([Vector3(.52,.75,.2),Vector3(.52,1.05,.2)],[.035],mat("#6a4b33"))
	spike(Vector3(.52,1.05,.2),Vector3(.52,2.0,.2),.065,mat("#8d9695",.2,.75))

func mimic() -> void:
	var wood:=mat("#775035",1.7); var iron:=mat("#6c6660",.3,.65); var gum:=mat("#713342")
	box(Vector3(0,.45,0),Vector3(1.7,.8,1.1),wood)
	for i in 6: box(Vector3((float(i)-2.5)*.28,.50,.565),Vector3(.255,.70,.045),mat("#815b3b" if i%2 else "#65462f"))
	for side in [-1.0,1.0]:
		box(Vector3(side*.68,.46,.58),Vector3(.10,.85,.045),iron)
		for y in [.15,.45,.75]: orb(Vector3(side*.68,y,.615),Vector3.ONE*.035,mat("#bcaa77",.3,.6))
	box(Vector3(0,.91,.04),Vector3(1.62,.20,1.06),mat("#170e11"))
	var lid:=node(null,"jaw"); lid.position=Vector3(0,.92,-.50); lid.rotation.x=deg_to_rad(-32)
	for i in 12:
		var angle:=float(i)/11*PI
		var y:=sin(angle)*.42
		box(Vector3(0,y,-.02+cos(angle)*.55),Vector3(1.72,.115,.14),wood,lid)
	for side in [-1.0,1.0]:
		tube([Vector3(side*.67,0,-.57),Vector3(side*.67,.36,-.3),Vector3(side*.67,.42,0),Vector3(side*.67,.30,.40),Vector3(side*.67,0,.54)],[.055],iron,lid)
	for i in 13:
		var x: float=(float(i)-6)*.115
		spike(Vector3(x,.87,.56),Vector3(x,.87+.22+rng.randf()*.10,.56),.055,mat("#e7d7ad"))
		spike(Vector3(x,0,.48),Vector3(x,-.25-rng.randf()*.06,.52),.05,mat("#d9c6a2"),lid)
	tube([Vector3(0,.93,.30),Vector3(.10,.84,.85),Vector3(.25,.48,1.20),Vector3(.43,.24,1.22)],[.18,.16,.12,.06],gum)
	eye(Vector3(-.46,.66,.60),.12,"#d5bb55"); eye(Vector3(.46,.66,.60),.12,"#d5bb55")

func cube() -> void:
	var gel:=StandardMaterial3D.new(); gel.albedo_color=Color(.24,.72,.59,.30); gel.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; gel.roughness=.16; gel.cull_mode=BaseMaterial3D.CULL_DISABLED
	var surface:=BoxMesh.new(); surface.size=Vector3(1.8,1.8,1.8); surface.subdivide_width=12; surface.subdivide_height=12; surface.subdivide_depth=12
	var jelly:=ShaderMaterial.new(); var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode cull_disabled,depth_prepass_alpha; uniform vec4 jelly : source_color=vec4(.18,.7,.56,.32); varying vec3 p; void vertex(){p=VERTEX;VERTEX+=NORMAL*sin(VERTEX.y*4.0+VERTEX.x*3.0+TIME*1.3)*.025;} void fragment(){float rim=pow(1.0-abs(dot(NORMAL,VIEW)),3.0);ALBEDO=jelly.rgb+rim*.17;ROUGHNESS=.15;ALPHA=jelly.a+rim*.30;}"
	jelly.shader=shader; mesh(surface,Vector3(0,1,0),jelly)
	for i in 18: orb(Vector3(rng.randf_range(-.75,.75),rng.randf_range(.3,1.8),rng.randf_range(-.75,.75)),Vector3.ONE*rng.randf_range(.02,.065),gel)
	orb(Vector3(-.23,.93,.15),Vector3(.20,.24,.18),mat("#c9c3a3"))
	for side in [-1.0,1.0]: orb(Vector3(-.23+side*.08,.96,.32),Vector3(.06,.07,.025),mat("#373b31"))
	tube([Vector3(.28,.32,-.13),Vector3(.10,.98,-.1),Vector3(.43,1.42,.2)],[.055,.045,.025],mat("#bdb597"))
	for i in 10: orb(Vector3(rng.randf_range(-.65,.65),.17,rng.randf_range(-.65,.65)),Vector3(.07,.016,.07),mat("#c1a35c",.3,.7))

func wraith() -> void:
	var cloth:=mat("#36434f",1.5); var dark:=mat("#171e26")
	robe(sculpt,cloth,Vector3(0,.92,0),.62,.66)
	for i in 18:
		var a:=float(i)/18*TAU; var h:=rng.randf_range(.15,.45)
		tube([Vector3(cos(a)*.50,.50,sin(a)*.50),Vector3(cos(a)*.64,.25,sin(a)*.64),Vector3(cos(a+.3)*.7,-h,sin(a+.3)*.7)],[.08,.055,.002],cloth,node(null,"tendril"))
	orb(Vector3(0,1.83,.01),Vector3(.29,.35,.27),cloth)
	orb(Vector3(0,1.86,.24),Vector3(.19,.24,.045),dark)
	for side in [-1.0,1.0]:
		orb(Vector3(side*.08,1.91,.29),Vector3(.045,.022,.012),mat("#95c9be",.0))
		limb([Vector3(side*.27,1.55,0),Vector3(side*.56,1.35,.17),Vector3(side*.75,1.10,.41)],[.17,.11,.05],cloth)
		for i in 4: tube([Vector3(side*.75+(float(i)-1.5)*.035,1.1,.41),Vector3(side*.78+(float(i)-1.5)*.06,.94,.56),Vector3(side*.79+(float(i)-1.5)*.06,.93,.65)],[.025,.018,.003],mat("#799b9c"))

func spider() -> void:
	var shell:=mat("#443733",1.6); var legs:=mat("#594133"); var joint:=mat("#9b7050")
	orb(Vector3(0,.77,-.46),Vector3(.67,.54,.84),shell)
	orb(Vector3(0,.66,.50),Vector3(.38,.31,.44),legs)
	for i in 7:
		var t:=float(i)/6
		orb(Vector3(0,1.21-sin(t*PI)*.035,-1.02+t*1.07),Vector3(.31-.16*absf(t-.5),.045,.065),joint)
	for side in [-1.0,1.0]:
		for i in 4:
			var z: float=-.25+float(i)*.25
			limb([Vector3(side*.28,.65,z),Vector3(side*.90,1.0,z+(float(i)-1.5)*.31),Vector3(side*1.40,.09,z+(float(i)-1.5)*.70)],[.09,.065,.02],legs)
		for i in 4: eye(Vector3(side*(.07+float(i%2)*.13),.66+float(i/2)*.12,.89),.055,"#b54e35")
		tube([Vector3(side*.15,.51,.81),Vector3(side*.18,.32,1.05),Vector3(side*.08,.22,1.07)],[.08,.055,.003],mat("#8e7351"))
	fur(Vector3(0,.77,-.46),Vector3(.66,.53,.84),"#6c5744",850)

func basilisk() -> void:
	var skin:=mat("#6c7866",1.5); var plates:=mat("#b0a576")
	orb(Vector3(0,.56,-.16),Vector3(.47,.42,1.0),skin)
	orb(Vector3(0,.62,.90),Vector3(.41,.27,.53),skin)
	for side in [-1.0,1.0]:
		eye(Vector3(side*.27,.77,1.16),.09,"#d9b53f")
		for i in 4:
			var z: float=-.80+float(i)*.48
			limb([Vector3(side*.31,.51,z),Vector3(side*.65,.35,z+.06),Vector3(side*.75,.10,z+.23)],[.16,.11,.06],skin)
			paw(Vector3(side*.77,.08,z+.33),.11,skin)
	tube([Vector3(0,.56,-.85),Vector3(.18,.36,-1.48),Vector3(.38,.20,-1.9),Vector3(.59,.17,-2.2)],[.31,.20,.10,.003],skin)
	for i in 18:
		var z: float=-1.55+float(i)*.17
		var base:=Vector3(0,.68+sin((z+1.6)*1.1)*.30,z)
		spike(base,base+Vector3(0,.18+sin(float(i))*.06,-.08),.085,plates)
	for i in 60:
		var p:=Vector3(rng.randf_range(-.35,.35),rng.randf_range(.74,.9),rng.randf_range(-.8,.7))
		orb(p,Vector3(.065,.025,.10),mat("#7d896f"))

func rust_monster() -> void:
	var rust:=mat("#a96137",1.8); var plates:=mat("#ba854f"); var dark:=mat("#4d3b2c")
	orb(Vector3(0,.64,-.20),Vector3(.54,.48,.86),rust)
	for i in 7:
		var z: float=-.88+float(i)*.22
		orb(Vector3(0,.86,z),Vector3(.52,.30,.17),plates)
	orb(Vector3(0,.59,.79),Vector3(.32,.26,.37),rust)
	for side in [-1.0,1.0]:
		for z in [-.56,.45]:
			limb([Vector3(side*.39,.58,z),Vector3(side*.63,.31,z+.11),Vector3(side*.67,.08,z+.30)],[.13,.10,.045],rust)
			eye(Vector3(side*.21,.70,1.05),.05,"#302b1a")
		var tip:=Vector3(side*.48,.76,1.95)
		tube([Vector3(side*.16,.65,1.01),Vector3(side*.29,.91,1.44),tip],[.06,.035,.018],plates,node(null,"tendril"))
		for i in 9:
			var z: float=1.52+float(i)*.05
			spike(Vector3(side*.38,.84,z),Vector3(side*(.38+.12*sin(float(i)/9*PI)),.89,z+.06),.018,plates)
	tube([Vector3(0,.59,-.81),Vector3(0,.39,-1.35),Vector3(0,.46,-1.93)],[.18,.11,.04],rust)
	for i in 11: spike(Vector3(0,.46,-1.92),Vector3((float(i)-5)*.07,.50,-2.19),.03,dark)

func crawler() -> void:
	var hide:=mat("#7e9560",1.5); var belly:=mat("#a8a979")
	for i in 10:
		var z: float=-1.22+float(i)*.25
		var radius:=.26+sin(float(i)/10*PI)*.14
		orb(Vector3(0,.43,z),Vector3(radius,.32,.24),hide if i%2 else belly)
		for side in [-1.0,1.0]: limb([Vector3(side*radius,.36,z),Vector3(side*(radius+.22),.22,z+.07),Vector3(side*(radius+.24),.07,z+.20)],[.045,.03,.008],hide)
	orb(Vector3(0,.54,1.05),Vector3(.34,.35,.35),hide)
	mouth(Vector3(0,.48,1.36),.22,.18)
	for i in 8:
		var a:=float(i)/8*TAU
		var start:=Vector3(cos(a)*.23,.53+sin(a)*.24,1.28)
		var tip:=start+Vector3(cos(a)*.40,sin(a)*.30,.68)
		tube([start,start.lerp(tip,.5)+Vector3(0,.12,0),tip,tip+Vector3(-cos(a)*.15,-.08,.17)],[.065,.05,.029,.003],mat("#a6ad7c"),node(null,"tendril"),14)

func worm() -> void:
	var purple:=mat("#79506b",1.6); var ridge:=mat("#a8738a"); var bone:=mat("#d6b998",.6)
	var path: Array=[]
	for i in 35:
		var t:=float(i)/34
		path.append(Vector3(sin(t*TAU*.75)*.74,.22+pow(t,2.1)*2.55,cos(t*TAU*.75)*.76))
	var radii: Array=[]
	for i in path.size(): radii.append(.16+sin(float(i)/float(path.size())*PI*.82)*.36)
	tube(path,radii,purple,null,24)
	for i in range(2,path.size()-2):
		var direction: Vector3=(path[i+1]-path[i-1]).normalized()
		var hoop:=TorusMesh.new(); hoop.inner_radius=float(radii[i])*.83; hoop.outer_radius=float(radii[i])*1.03; hoop.rings=20; hoop.ring_segments=8
		var ring_mesh:=mesh(hoop,path[i],ridge); ring_mesh.quaternion=Quaternion(Vector3.UP,direction)
	var top: Vector3=path[-1]; var forward: Vector3=(path[-1]-path[-2]).normalized()
	var head:=node(); head.position=top; head.basis=Basis.looking_at(-forward,Vector3.RIGHT)
	orb(Vector3.ZERO,Vector3(.55,.55,.15),purple,head)
	orb(Vector3(0,0,.14),Vector3(.43,.43,.045),mat("#22101e"),head)
	for row in 3:
		for i in 18:
			var a:=float(i)/18*TAU+float(row)*.08; var r:=.43-float(row)*.11
			spike(Vector3(cos(a)*r,sin(a)*r,.20),Vector3(cos(a)*(r-.11),sin(a)*(r-.11),.28),.038,bone,head)
	spike(path[0],path[0]+Vector3(-.18,.34,.38),.14,bone)

func mouther() -> void:
	var flesh:=mat("#8d6f61",1.7)
	orb(Vector3(0,.52,0),Vector3(.81,.50,.71),flesh)
	for i in 20:
		var p:=Vector3(rng.randf_range(-.65,.65),rng.randf_range(.28,.82),rng.randf_range(-.52,.52))
		orb(p,Vector3(rng.randf_range(.20,.35),rng.randf_range(.18,.35),rng.randf_range(.16,.34)),flesh)
	for i in 36:
		var angle:=float(i)*2.39996; var y:=rng.randf_range(.23,.98)
		var normal:=Vector3(cos(angle),rng.randf_range(.1,.5),sin(angle)).normalized()
		var point:=Vector3(0,.48,0)+normal*Vector3(.72,.49,.63)
		point.y=y
		eye(point,rng.randf_range(.055,.12),"#c5ad71",null,normal)
	for i in 7:
		var group:=node(); var angle:=float(i)/7*TAU
		group.position=Vector3(cos(angle)*.62,.40+float(i%2)*.30,sin(angle)*.61)
		group.basis=Basis.looking_at(-Vector3(cos(angle),.18,sin(angle)).normalized(),Vector3.UP)
		mouth(Vector3.ZERO,.19,.13,group)
	for i in 6:
		var a:=float(i)/6*TAU
		tube([Vector3(cos(a)*.45,.25,sin(a)*.45),Vector3(cos(a+.15)*.80,.14,sin(a+.15)*.80),Vector3(cos(a+.35)*1.06,.10,sin(a+.35)*1.06)],[.13,.075,.003],flesh,node(null,"tendril"))
