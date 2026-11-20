extends RefCounted
class_name Hearth20TavernCraft
## Meter-scaled architecture; rigid source poses; shared spatial material batches.
const ROOT="res://hearth20/room_craft/"
var room: Hearth20TavernRoom
var poses={}
var rng=RandomNumberGenerator.new()
var mesh_cache={}
var planks=[]
var fixtures=[]
var windows=[]
func build(target: Hearth20TavernRoom) -> void:
	room=target;rng.seed=201811;poses=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"furniture_poses.json"))
	room.ceiling_height=6.05;room.set_meta("crafted_room",true)
	room.materials.floor=_material("wood-006",0,Color("#b9a38d"))
	room.materials.timber=_material("wood-006",1,Color("#5c4436"))
	room.materials.stone=_material("limestone",2,Color("#d1c8b7"))
	room.materials.mortar=room._solid(Color("#3a3631"),0.,.98)
	room._boundary("Floor",Vector3(0,-.095,0),Vector3(16.5,.18,16.5),"mortar")
	room._boundary("Ceiling",Vector3(0,6.15,0),Vector3(16.5,.20,16.5),"timber")
	_floor()
	# Aperture centers are on real wall planes; dimensions are meters.
	var front=[{"u":4.8,"base":1.65,"width":1.65,"height":2.65}]
	var east=[{"u":-3.8,"base":1.65,"width":1.65,"height":2.65},{"u":3.8,"base":1.65,"width":1.65,"height":2.65}]
	var west=[{"u":-3.8,"base":1.65,"width":1.65,"height":2.65},{"u":3.8,"base":1.65,"width":1.65,"height":2.65}]
	_wall("Front",Vector3(0,0,-8),0.,front)
	_wall("Rear",Vector3(0,0,8),PI,[])
	_wall("East",Vector3(8,0,0),-PI/2,east)
	_wall("West",Vector3(-8,0,0),PI/2,west)
	_structure()
	_banner("tarrasque",Vector3(-2.65,5.24,-7.68),0.,1.1,2.2)
	_banner("tiamat",Vector3(2.2,5.24,-7.68),0.,1.1,2.2)
	_banner("vecna",Vector3(-3.4,4.85,7.68),PI,1.15,2.3)
	_banner("strahd",Vector3(3.4,4.85,7.68),PI,1.15,2.3)
	# Native models are straightened with a rigid rotation and ONE scale value.
	# Position from their actual resulting depth, not an arbitrary thin target box.
	var fire=_against("fireplace",Vector3(-4.9,.004,-8),0.,2.8)
	var fire_depth: float=fire.get_meta("actual_dimensions").z
	var hearth=Vector3(-4.9,.40,-8+fire_depth*.76)
	room._fire_particles(hearth,false);room._fire_particles(hearth+Vector3(0,.55,-.10),true)
	var warmth=OmniLight3D.new();warmth.name="HearthWarmth";warmth.position=hearth+Vector3(0,.8,.4);warmth.light_color=Color("#ffb66e");warmth.light_energy=2.8;warmth.omni_range=6.5;warmth.shadow_enabled=true;warmth.shadow_bias=.035;room.add_child(warmth)
	# Chimney is genuine masonry continuing into the ceiling.
	_bevel(Vector3(-4.9,4.42,-7.73),Vector3(1.45,3.26,.52),.035,"stone")
	var bar=_against("bar",Vector3(-.5,.004,-8),0.,1.1)
	_against("wood_shelve",Vector3(-.5,1.45,-8),0.,2.0)
	for x in [-1.4,.4]:_prop("bar_stool",Vector3(x,.004,-5.8),.72)
	for x in [-1.35,-.80,-.25,.32]:_on("bottle",bar,Vector3(x,0,-7.15),.32)
	_on("bowl",bar,Vector3(-.55,0,-6.93),.14)
	_against("bench",Vector3(4.8,.004,-8),0.,1.06)
	_prop("small_bar_table",Vector3(4.8,.004,-5.95),.78)
	_against("door",Vector3(0,.004,8),PI,2.9)
	for side in [-1,1]:
		var yaw=-side*PI/2
		var cabinet=_against("cabinet",Vector3(side*8.,.004,.1),yaw,.94)
		for z in [-.45,.1,.65]:_on("bottle",cabinet,Vector3(side*7.52,0,z),.29)
		_against("bench",Vector3(side*4.4,.004,8),PI,1.06)
		_prop("small_bar_table",Vector3(side*4.4,.004,6.1),.78)
		for z in [-6.6,.0,6.5]:room._generated_sconce(Vector3(side*7.72,2.35,z),yaw)
		_against("shield",Vector3(side*2.0,3.35,8),PI,.85)
	var ambient=OmniLight3D.new();ambient.name="SoftTableBounce";ambient.position=Vector3(0,3.8,1.);ambient.light_color=Color("#d6b587");ambient.light_energy=.65;ambient.omni_range=11.;room.add_child(ambient)
	room._finish_batches()
	room.set_meta("fully_enclosed",true);room.set_meta("modeled_front",true)
	room.set_meta("uses_generated_backdrop",false)
	room.set_meta("floor_planks",planks);room.set_meta("furniture_fits",fixtures);room.set_meta("window_apertures",windows)
	var atmosphere=Hearth20RoomAtmosphere.new();atmosphere.name="WindowAtmosphere";room.add_child(atmosphere);atmosphere.setup(room,windows)
	var exterior=Hearth20WindowWorldView.new();exterior.name="WindowWorld";room.add_child(exterior);exterior.setup(room)

func _material(id: String,mode: int,tint: Color) -> ShaderMaterial:
	var m=ShaderMaterial.new();m.shader=load(ROOT+"surface.gdshader")
	for channel in ["albedo","normal","roughness","height"]:m.set_shader_parameter(channel+"_map",load(ROOT+id+"/"+channel+".png"))
	m.set_shader_parameter("kind",mode);m.set_shader_parameter("tint",tint);return m

func _floor() -> void:
	var x=-8.
	while x<7.99:
		var width=minf(rng.randf_range(.25,.34),8.-x);var z=-8.
		while z<7.99:
			var length_value=minf(rng.randf_range(1.45,3.1),8.-z)
			var height=rng.randf_range(-.0025,.0025)
			var yaw=rng.randf_range(-.0006,.0006)
			var at=Vector3(x+width*.5,-.022+height,z+length_value*.5)
			var dim=Vector3(maxf(.01,width-.005),.045,maxf(.01,length_value-.006))
			_bevel(at,dim,.0045,"floor",Vector3(0,yaw,0),rng.randf_range(.88,1.07))
			planks.append({"center":at,"size":dim,"surface_height":at.y+.0225,"yaw":yaw,"bevel":.0045})
			z+=length_value
		x+=width

func _wall(label: String,origin: Vector3,yaw: float,openings: Array) -> void:
	var basis=Basis(Vector3.UP,yaw)
	# Full enclosure collision behind the apertures; invisible collision cannot
	# block rendering or sunlight. Visible masonry is actually cut around them.
	var body=StaticBody3D.new();body.name=label+"Wall";body.collision_layer=Hearth20TavernRoom.BOUNDARY_LAYER;body.collision_mask=0;body.transform=Transform3D(basis,origin);room.add_child(body)
	var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(16.4,6.2,.30);collider.shape=shape;collider.position.y=3.;body.add_child(collider)
	var row_height=6.05/14.
	for row in 14:
		var bottom=row*row_height;var top=bottom+row_height;var u=-8.
		while u<7.99:
			var end=minf(8.,u+rng.randf_range(.65,1.12));var intervals=[[u,end]]
			for op in openings:
				if top<=float(op.base) or bottom>=float(op.base)+float(op.height):continue
				# Keep cut masonry below a sill that crosses a brick course.
				# Removing the full course left a 22 cm gap under the wooden sill.
				if bottom<float(op.base):
					var lo=maxf(u,float(op.u)-float(op.width)*.5)
					var hi=minf(end,float(op.u)+float(op.width)*.5)
					if hi-lo>.035:
						var infill_at=origin+basis*Vector3((lo+hi)*.5,(bottom+float(op.base))*.5,-.04)
						_bevel(infill_at,Vector3(hi-lo-.012,float(op.base)-bottom-.013,.26),.013,"stone",Vector3(0,yaw,0),rng.randf_range(.92,1.04))
				# Circular arch, with the surround covering the course discretization.
				var radius=float(op.width)*.5;var cap=float(op.base)+float(op.height)-radius
				var rel=maxf(0.,bottom-cap)
				var half=sqrt(maxf(0.,radius*radius-rel*rel))
				intervals=_subtract(intervals,float(op.u)-half,float(op.u)+half)
			for span in intervals:
				if span[1]-span[0]<.035:continue
				var depth=rng.randf_range(.21,.27);var at=origin+basis*Vector3((span[0]+span[1])*.5,(bottom+top)*.5,-.04)
				_bevel(at,Vector3(span[1]-span[0]-.012,row_height-.013,depth),.013,"stone",Vector3(0,yaw,0),rng.randf_range(.88,1.08))
			u=end
	for op in openings:_window(origin,basis,yaw,op)

func _subtract(intervals: Array,lo: float,hi: float) -> Array:
	var result=[]
	for span in intervals:
		if hi<=span[0] or lo>=span[1]:result.append(span);continue
		if lo>span[0]:result.append([span[0],lo])
		if hi<span[1]:result.append([hi,span[1]])
	return result

func _window(origin: Vector3,basis: Basis,yaw: float,op: Dictionary) -> void:
	var w=float(op.width);var h=float(op.height);var base=float(op.base);var u=float(op.u);var cap=base+h-w*.5
	var center=origin+basis*Vector3(u,base+h*.5,0)
	windows.append({"center":center,"normal":basis*Vector3.FORWARD*-1.,"width":w,"height":h,"yaw":yaw})
	# True jambs and deep sill; their inner edges are at the aperture boundary.
	for sign_value in [-1,1]:
		_bevel(origin+basis*Vector3(u+sign_value*(w*.5+.075),(base+cap)*.5,.03),Vector3(.15,cap-base+.10,.42),.012,"timber",Vector3(0,yaw,0))
	_bevel(origin+basis*Vector3(u,base-.065,.14),Vector3(w+.42,.13,.62),.018,"timber",Vector3(0,yaw,0))
	for i in 12:
		var angle=(float(i)+.5)*PI/12.
		var at=Vector3(u+cos(angle)*(w*.5+.075),cap+sin(angle)*(w*.5+.075),.035)
		_bevel(origin+basis*at,Vector3(.15,(w*.5+.075)*PI/12.+.018,.42),.008,"timber",Vector3(0,yaw,angle))
	# Close the stepped brick-course gaps above each circular arch with actual
	# stone spandrels. Nothing outside the glass aperture opens into a black void.
	var fill=SurfaceTool.new();fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	for half in 2:
		var corner=Vector3(w*.5 if half==0 else -w*.5,cap+w*.5+.01,.095)
		for segment in 12:
			var a=(float(half)*.5+float(segment)/24.)*PI
			var b=a+PI/24.
			var p=Vector3(cos(a)*w*.5,cap+sin(a)*w*.5,.095)
			var q=Vector3(cos(b)*w*.5,cap+sin(b)*w*.5,.095)
			for tri in [[corner,p,q],[corner-Vector3(0,0,.26),q-Vector3(0,0,.26),p-Vector3(0,0,.26)]]:
				for v in tri:fill.set_normal(Vector3.BACK if v.z>0. else Vector3.FORWARD);fill.set_uv(Vector2(v.x/w+.5,(v.y-cap)/w));fill.add_vertex(v)
	fill.generate_normals();room._merge(fill.commit(),origin+basis*Vector3(u,0,0),basis,"stone",Color(.96,.96,.96))
	# Sky panes are opaque, unshadowed geometry behind the opening, not an
	# emissive rectangle pasted onto a closed wall.
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline=[Vector3(-w*.5,0,0),Vector3(w*.5,0,0),Vector3(w*.5,cap-base,0)]
	for i in range(1,17):
		var a=float(i)*PI/16.;outline.append(Vector3(cos(a)*w*.5,cap-base+sin(a)*w*.5,0))
	for i in range(1,outline.size()-1):
		for p in [outline[0],outline[i],outline[i+1]]:st.set_uv(Vector2(p.x/w+.5,1.-p.y/h));st.add_vertex(p)
	st.generate_normals();var pane=MeshInstance3D.new();pane.name="RecessedSkyPane";pane.mesh=st.commit();pane.material_override=load(ROOT+"window_sky.tres");pane.transform=Transform3D(basis,origin+basis*Vector3(u,base,-.17));pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;room.add_child(pane)
	# Physical mullions produce the same divisions in direct light and god rays.
	_bevel(origin+basis*Vector3(u,base+h*.5,.035),Vector3(.042,h,.07),.004,"timber",Vector3(0,yaw,0))
	for level in [.36,.69]:_bevel(origin+basis*Vector3(u,base+h*level,.035),Vector3(w,.042,.07),.004,"timber",Vector3(0,yaw,0))

func _structure() -> void:
	for side in [-1,1]:
		for z in [-7.82,-.0,7.82]:_bevel(Vector3(side*7.81,3.02,z),Vector3(.26,6.04,.26),.018,"timber")
		for y in [.15,5.79]:_bevel(Vector3(side*7.81,y,0),Vector3(.24,.26,15.8),.018,"timber")
	for z in [-7.82,7.82]:
		for y in [.15,5.79]:_bevel(Vector3(0,y,z),Vector3(15.9,.26,.24),.018,"timber")
	for z in [-6.,-2.,2.,6.]:
		_bevel(Vector3(0,5.9,z),Vector3(16.,.28,.28),.018,"timber")
		for side in [-1,1]:_bevel(Vector3(side*7.4,5.38,z),Vector3(1.18,.18,.18),.012,"timber",Vector3(0,0,side*PI/4))
	for x in [-5.4,-2.7,0.,2.7,5.4]:_bevel(Vector3(x,6.02,0),Vector3(.14,.12,16.),.008,"timber")

func _banner(id: String,at: Vector3,yaw: float,w: float,h: float) -> void:
	var holder=Node3D.new();holder.name="BossBanner_"+id;holder.position=at;holder.rotation.y=yaw;room.add_child(holder)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns=18;var rows=32
	for y in rows:
		for x in columns:
			for delta in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(1,0)]:
				var uv=Vector2(float(x+delta.x)/columns,float(y+delta.y)/rows)
				var fold=sin(uv.x*TAU*3.)*.022*sin(uv.y*PI*.5)
				var hem=.12*abs(uv.x*2.-1.)*pow(uv.y,12.)
				st.set_uv(uv);st.add_vertex(Vector3((uv.x-.5)*w,-uv.y*h+hem,fold))
	st.generate_normals();st.index();st.generate_tangents()
	var cloth=MeshInstance3D.new();cloth.name="WovenCloth";cloth.mesh=st.commit();holder.add_child(cloth)
	var material_value=ShaderMaterial.new();material_value.shader=load(ROOT+"banner.gdshader");material_value.set_shader_parameter("art",load(ROOT+"banners/"+id+".png"));material_value.set_shader_parameter("phase",rng.randf_range(0.,TAU));cloth.material_override=material_value
	var basis=Basis(Vector3.UP,yaw)
	var rod=CylinderMesh.new();rod.top_radius=.018;rod.bottom_radius=.018;rod.height=w+.22;rod.radial_segments=12
	room._merge(rod,at+Vector3(0,.045,0),basis*Basis(Vector3.FORWARD,PI/2),"brass")
	for side in [-1,1]:
		_bevel(at+basis*Vector3(side*(w*.5+.11),.045,0),Vector3(.065,.065,.065),.012,"brass",Vector3(0,yaw,0))
		_bevel(at+basis*Vector3(side*(w*.5-.05),.045,-.14),Vector3(.06,.12,.32),.008,"iron",Vector3(0,yaw,0))
		var ring=TorusMesh.new();ring.inner_radius=.026;ring.outer_radius=.038;ring.rings=12;ring.ring_segments=8
		room._merge(ring,at+basis*Vector3(side*(w*.5-.1),.004,0),basis*Basis(Vector3.FORWARD,PI/2),"brass")
	holder.set_meta("boss",id);holder.set_meta("physical_cloth",true)

func _prop(id: String,at: Vector3,height: float,yaw=0.) -> Node3D:
	if not Hearth20GeneratedModels.available(id):return null
	var record=poses[id];var extent=Hearth20GeneratedModels.vector(record.bounds.size);var minimum=Hearth20GeneratedModels.vector(record.bounds.min)
	var axes=record.orientation_basis;var rotation=Basis(Hearth20GeneratedModels.vector(axes[0]),Hearth20GeneratedModels.vector(axes[1]),Hearth20GeneratedModels.vector(axes[2]))
	var scale_value=height/extent.y;var model=Hearth20GeneratedModels.raw(id)
	model.transform=Transform3D(rotation*scale_value,-(minimum+extent*Vector3(.5,0,.5))*scale_value)
	var holder=Node3D.new();holder.name="Crafted_"+id;holder.position=at;holder.rotation.y=yaw;holder.add_child(model);room.add_child(holder)
	holder.set_meta("generated_model",id);holder.set_meta("actual_dimensions",extent*scale_value);holder.set_meta("uniform_scale",scale_value)
	Hearth20GeneratedModels.shadows(model,true)
	fixtures.append({"id":id,"position":at,"dimensions":extent*scale_value,"uniform_scale":scale_value,"horizontal_correction_degrees":record.horizontal_correction_degrees})
	return holder

func _against(id: String,wall_point: Vector3,yaw: float,height: float) -> Node3D:
	var result=_prop(id,wall_point,height,yaw)
	if result==null:return null
	var depth: float=result.get_meta("actual_dimensions").z
	result.position+=Basis(Vector3.UP,yaw)*Vector3(0,0,depth*.5+.025)
	# Allow for the modeled stone face and the projecting ground-level skirting.
	var clearance=.32 if wall_point.y<.10 else .12
	result.position+=Basis(Vector3.UP,yaw)*Vector3(0,0,clearance-.025)
	fixtures[-1].position=result.position
	result.set_meta("wall_clearance",clearance);return result

func _on(id: String,support: Node3D,at: Vector3,height: float) -> void:
	# This uniform-fit prop shares the existing exact triangle support query.
	var extent=Hearth20GeneratedModels.vector(poses[id].bounds.size)
	var y=-INF
	for mesh in support.find_children("*","MeshInstance3D",true,false):
		var inverse=mesh.global_transform.affine_inverse();var ray=inverse*room.to_global(Vector3(at.x,7.,at.z));var direction=(inverse.basis*Vector3.DOWN).normalized()
		for surface in mesh.mesh.get_surface_count():
			var a=mesh.mesh.surface_get_arrays(surface);var v=a[Mesh.ARRAY_VERTEX];var idx=a[Mesh.ARRAY_INDEX]
			for i in range(0,idx.size(),3):
				var hit=Geometry3D.ray_intersects_triangle(ray,direction,v[idx[i]],v[idx[i+1]],v[idx[i+2]])
				if hit!=null:y=maxf(y,room.to_local(mesh.to_global(hit)).y)
	if not is_finite(y):return
	at.y=y+.002
	var result=_prop(id,at,height);result.set_meta("rests_on_surface",true)

func _bevel(at: Vector3,dim: Vector3,b: float,key: String,rotation=Vector3.ZERO,shade=1.) -> void:
	var cache_key=str(dim)+":"+str(b)
	if not mesh_cache.has(cache_key):mesh_cache[cache_key]=_beveled_box(dim,b)
	room._merge(mesh_cache[cache_key],at,Basis.from_euler(rotation),key,Color(shade,shade,shade))

func _beveled_box(dim: Vector3,amount: float) -> ArrayMesh:
	var h=dim*.5;var b=minf(amount,minf(h.x,minf(h.y,h.z))*.8);var inner=h-Vector3.ONE*b
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var a=(axis+1)%3;var c=(axis+2)%3
		for sign_value in [-1.,1.]:
			var points=[];var normal=Vector3.ZERO;normal[axis]=sign_value
			for signs in [[-1.,-1.],[1.,-1.],[1.,1.],[-1.,1.]]:
				var p=Vector3.ZERO;p[axis]=h[axis]*sign_value;p[a]=inner[a]*signs[0];p[c]=inner[c]*signs[1];points.append(p)
			_quad(st,points,normal,dim)
	for along in 3:
		var a=(along+1)%3;var c=(along+2)%3
		for sa in [-1.,1.]:
			for sc in [-1.,1.]:
				var points=[];var normal=Vector3.ZERO;normal[a]=sa;normal[c]=sc
				for end in [-1.,1.]:
					for outer in [a,c]:
						var p=Vector3.ZERO;p[along]=inner[along]*end;p[a]=(h[a] if outer==a else inner[a])*sa;p[c]=(h[c] if outer==c else inner[c])*sc;points.append(p)
				_quad(st,[points[0],points[1],points[3],points[2]],normal.normalized(),dim)
	for sx in [-1.,1.]:
		for sy in [-1.,1.]:
			for sz in [-1.,1.]:
				var sign_value=Vector3(sx,sy,sz);var points=[]
				for axis in 3:
					var p=inner*sign_value;p[axis]=h[axis]*sign_value[axis];points.append(p)
				_tri(st,points,sign_value.normalized(),dim)
	st.index();return st.commit()

func _quad(st: SurfaceTool,p: Array,n: Vector3,dim: Vector3) -> void:
	_tri(st,[p[0],p[1],p[2]],n,dim);_tri(st,[p[0],p[2],p[3]],n,dim)
func _tri(st: SurfaceTool,p: Array,n: Vector3,dim: Vector3) -> void:
	if (p[1]-p[0]).cross(p[2]-p[0]).dot(n)>0.:p=[p[0],p[2],p[1]]
	var dominant=n.abs().max_axis_index()
	for v in p:
		var uv=Vector2(v.x/dim.x,v.z/dim.z) if dominant==1 else Vector2(v.x/dim.x,v.y/dim.y) if dominant==2 else Vector2(v.z/dim.z,v.y/dim.y)
		st.set_normal(n);st.set_uv(uv+Vector2(.5,.5));st.add_vertex(v)
