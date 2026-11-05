extends Node3D
class_name Hearth20FxActor3D
var ribbons: Array[Hearth20FxRibbon3D]=[]
var accent: MeshInstance3D
var smoke_cap: MeshInstance3D
var crown: MeshInstance3D
var event: Dictionary
var element:="Fire"
var kind:="explode"
var count:=128
var cloud: MultiMeshInstance3D
var embers: MultiMeshInstance3D
var rng:=RandomNumberGenerator.new()
var seeds: Array=[]
var rings: Array=[]
var shell: MeshInstance3D
var core: MeshInstance3D
var volume: MeshInstance3D
var volume_material: ShaderMaterial
var light: OmniLight3D
var tint: Color
var light_power:=0.0
var darkness:=0.0
var age:=0.0
var phase:=0.0
var liquid_sheet: MeshInstance3D
var sheet_material: ShaderMaterial
const SHEET:="""
shader_type spatial; render_mode cull_disabled,blend_mix;
uniform vec4 tint:source_color;uniform float age=0.;uniform float opacity=.85;uniform float ripples=.03;uniform bool blood=false;
varying vec3 local_point;
void vertex(){float a=atan(VERTEX.z,VERTEX.x);float warp=.86+.07*sin(a*7.)+.045*sin(a*13.+1.7)+.025*sin(a*23.);VERTEX.xz*=warp;local_point=VERTEX;}
void fragment(){
 vec2 p=local_point.xz;float wave=sin(dot(p,vec2(15,8))+age*3.)*.4+sin(dot(p,vec2(8,-17))-age*4.)*.28;
 wave+=sin(length(p-vec2(sin(age),cos(age))*.15)*38.-age*9.)*.13;
 ALBEDO=tint.rgb*(blood?.24:.24)+vec3(max(0.,wave)*ripples*.12);
 NORMAL=normalize(NORMAL+vec3(dFdx(wave),dFdy(wave),0.)*(blood?.35:1.2));ROUGHNESS=blood?.075:.11;SPECULAR=.95;METALLIC=.035;CLEARCOAT=.95;CLEARCOAT_ROUGHNESS=.06;ALPHA=opacity;
}
"""
static func profile(material_name: String) -> Array:
	return {"Fire":[2.8,0.0],"Holy":[2.3,0.0],"Acid":[.85,0.0],"Frost":[1.1,0.0],"Magic":[1.7,0.0],"Charm":[.8,0.0],"Water":[.15,0.0],"Slime":[.25,0.0],"Death":[.0,.8],"Smoke":[0.0,.32],"Blood":[0.0,0.0]}.get(material_name,[1.0,0.0])
func setup(value: Dictionary) -> void:
	event=value; element=Hearth20BoardTools.fx_material(event); kind=str(event.get("effect","rocket")); tint=Color(event.get("color","#ff682b")); rng.seed=int(event.get("seed",1)); count=clampi(int(event.get("density",48))*4,64,512)
	var powers: Array=profile(element); light_power=powers[0]; darkness=powers[1]
	var material:=StandardMaterial3D.new(); material.albedo_color=tint.darkened(.45) if element=="Blood" else tint; material.vertex_color_use_as_albedo=true; material.roughness=.12 if element in ["Water","Blood","Slime","Acid"] else .3; material.metallic=.5 if element in ["Holy","Frost","Magic"] else .05
	material.clearcoat_enabled=element in ["Blood","Water","Slime","Acid"]; material.clearcoat=.9
	if element in ["Smoke","Death"]: material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.albedo_color.a=.08
	material.emission_enabled=light_power>.2; material.emission=tint; material.emission_energy_multiplier=light_power*.10
	var mesh: Mesh
	if element in ["Holy","Magic"]:
		var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in Hearth20DiceModel.shape(8 if element=="Holy" else 20):
			for vertex in [face.vertices[0],face.vertices[2],face.vertices[1]]:
				surface.set_normal(face.normal); surface.add_vertex(vertex*Vector3(.045,.17 if element=="Holy" else .075,.045))
		mesh=surface.commit()
	elif element=="Frost":
		var crystal:=CylinderMesh.new(); crystal.radial_segments=6; crystal.rings=1; crystal.top_radius=0; crystal.bottom_radius=.045; crystal.height=.29; mesh=crystal
	elif element=="Charm": mesh=_heart_mesh()
	else:
		var sphere:=SphereMesh.new(); sphere.radius=.035 if element in ["Blood","Water","Fire"] else .065; sphere.height=sphere.radius*2; sphere.radial_segments=16; sphere.rings=8; mesh=sphere
	cloud=_instances(mesh,material,count); add_child(cloud)
	var spark_material:=StandardMaterial3D.new(); spark_material.albedo_color=tint.lightened(.2); spark_material.emission_enabled=true; spark_material.emission=tint.lightened(.3); spark_material.emission_energy_multiplier=.45
	var needle:=CylinderMesh.new(); needle.top_radius=.009; needle.bottom_radius=.004; needle.height=.16; needle.radial_segments=4; needle.rings=1
	embers=_instances(needle,spark_material,96 if element in ["Fire","Holy","Magic","Frost"] else 32); add_child(embers)
	embers.visible=element in ["Fire","Holy","Magic","Frost","Charm","Acid"]
	cloud.visible=element!="Fire"
	if element in ["Blood","Water","Slime","Acid"]:
		liquid_sheet=MeshInstance3D.new(); var puddle:=SphereMesh.new(); puddle.radius=1; puddle.height=2; puddle.radial_segments=96; puddle.rings=24; liquid_sheet.mesh=puddle
		var shader:=Shader.new(); shader.code=SHEET; sheet_material=ShaderMaterial.new(); sheet_material.shader=shader; sheet_material.set_shader_parameter("tint",tint); sheet_material.set_shader_parameter("opacity",.42 if element=="Water" else .94 if element=="Blood" else .86); liquid_sheet.material_override=sheet_material; liquid_sheet.position.y=.012; add_child(liquid_sheet)
		sheet_material.set_shader_parameter("ripples",.008 if element=="Blood" else .08 if element=="Water" else .03);sheet_material.set_shader_parameter("blood",element=="Blood")
	for i in count: seeds.append(Vector4(rng.randf()*TAU,rng.randf(),rng.randf(),rng.randf()*TAU))
	if element in ["Fire","Smoke","Death","Acid","Blood"]:
		volume=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3.ONE*2; volume.mesh=box; volume.position.y=2.0 if element=="Fire" else 1.3
		volume_material=Hearth20FxVolume.material(tint if element!="Smoke" else Color("#798087"),element!="Fire"); volume_material.render_priority=1;volume.material_override=volume_material; add_child(volume)
	var ring_count:=4 if element=="Magic" else 2 if element=="Holy" else 2 if kind in ["nova","shield","pooling","bubbling","glow"] else 0
	for i in ring_count:
		var ring:=MeshInstance3D.new(); var torus:=TorusMesh.new(); torus.inner_radius=.74; torus.outer_radius=.755 if element in ["Holy","Magic","Frost"] else .78; torus.rings=72; torus.ring_segments=8; ring.mesh=torus; ring.material_override=spark_material if light_power>.2 else material; add_child(ring); rings.append(ring)
	if kind=="shield":
		shell=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=.85; sphere.height=1.7; sphere.radial_segments=64; sphere.rings=32; shell.mesh=sphere
		var shader:=Shader.new(); shader.code="shader_type spatial; render_mode unshaded,cull_disabled,depth_draw_never; uniform vec4 tint:source_color; uniform float time=0.; void fragment(){float rim=pow(1.-abs(dot(NORMAL,VIEW)),2.);float lattice=pow(abs(sin(UV.x*75.+time)*sin(UV.y*50.-time*.5)),18.);ALBEDO=tint.rgb*.85;ALPHA=clamp(rim*.30+lattice*.32,.0,.65);}"
		var shell_material:=ShaderMaterial.new(); shell_material.shader=shader; shell_material.set_shader_parameter("tint",tint); shell.material_override=shell_material; add_child(shell)
	if kind in ["rocket","missile","bomb"]:
		core=MeshInstance3D.new(); var body:=SphereMesh.new(); body.radius=.26; body.height=.52;body.radial_segments=48;body.rings=24; core.mesh=body; core.material_override=Hearth20FxSurfaces.core_material(tint); add_child(core)
	var wet:=element in ["Blood","Water","Slime","Acid"]
	var trail_style:=0 if kind in ["rocket","missile","bomb"] else 3 if kind in ["beam","breath"] else 2 if wet else 1 if element in ["Holy","Magic","Death","Charm"] else 4 if element in ["Fire","Smoke","Frost"] else 5
	var amount:=0 if element=="Smoke" or kind=="pooling" else 7 if wet else 5 if trail_style in [0,1,3] else 4
	for i in amount:
		var ribbon:=Hearth20FxRibbon3D.new();add_child(ribbon);ribbon.setup(tint,trail_style,float(i)/amount+float(int(event.get("seed",1))%19)*.021,.025 if wet else .021 if element=="Fire" else .009,wet);ribbon.fx_material.set_shader_parameter("cyclic",kind not in ["explode","splatter","burst","nova","bomb","rocket"]);ribbons.append(ribbon)
	if wet and kind in ["explode","splatter","burst","nova","bomb","rocket"]:
		crown=Hearth20FxSurfaces.crown(tint,element=="Blood");crown.position.y=.035;add_child(crown)
	if element in ["Holy","Magic","Death","Frost"] or (not wet and kind in ["explode","nova","burst","bomb","rocket"]):
		accent=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2.ONE*3;plane.subdivide_width=1;plane.subdivide_depth=1;accent.mesh=plane;accent.position.y=.022
		var mode:=2 if element=="Death" else 0 if element in ["Holy","Magic"] else 3 if element=="Frost" else 1
		accent.material_override=Hearth20FxSurfaces.material(tint,mode);add_child(accent)
	if element=="Fire":
		smoke_cap=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3.ONE*2;smoke_cap.mesh=box;smoke_cap.material_override=Hearth20FxVolume.material(Color("#4d4138"),true);smoke_cap.material_override.render_priority=-1;smoke_cap.position.y=2.6;add_child(smoke_cap)
	light=OmniLight3D.new(); light.light_color=tint; light.omni_range=5; light.light_energy=light_power; add_child(light)
func _instances(mesh: Mesh, material: Material, amount: int) -> MultiMeshInstance3D:
	var instance:=MultiMeshInstance3D.new(); var multi:=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D; multi.use_colors=true; multi.mesh=mesh; multi.instance_count=amount; instance.multimesh=multi; instance.material_override=material;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; return instance
func _heart_mesh() -> ArrayMesh:
	var contour:=PackedVector2Array()
	for i in 48:
		var t:=float(i)/48*TAU; contour.append(Vector2(pow(sin(t),3),-(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t))/16)*.16)
	var triangles:=Geometry2D.triangulate_polygon(contour); var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		for i in range(0,triangles.size(),3):
			for j in ([0,1,2] if side==1 else [2,1,0]):
				var p:=contour[triangles[i+j]]; surface.set_normal(Vector3(0,0,side)); surface.add_vertex(Vector3(p.x,-p.y,side*.045))
	for i in contour.size():
		var a:=contour[i]; var b:=contour[(i+1)%contour.size()]
		for p in [Vector3(a.x,-a.y,-.045),Vector3(b.x,-b.y,-.045),Vector3(a.x,-a.y,.045),Vector3(a.x,-a.y,.045),Vector3(b.x,-b.y,-.045),Vector3(b.x,-b.y,.045)]: surface.add_vertex(p)
	surface.generate_normals(); return surface.commit()
func animate(now: int, source_delta: Vector2) -> void:
	age=maxf(0,float(now-int(event.started_usec))/1000000.0); var travel:=float(event.travel_usec)/1000000.0; var duration:=maxf(.01,float(event.impact_duration_usec)/1000000.0); phase=clampf((age-travel)/duration,0,1)
	var flight:=travel>0 and age<travel; var fade:=minf(1,age*12)*minf(1,(1-phase)*4); var burst:=kind in ["explode","nova","burst","bomb","rocket","splatter"] and not flight
	for i in count:
		var seed: Vector4=seeds[i]; var angle:=seed.x+age*.4; var cycle:=fposmod(age*(.7 if element in ["Slime","Blood","Water"] else 1.2)+seed.y,1.0); var radial:=Vector3(cos(angle),0,sin(angle)); var pos:=Vector3.ZERO; var stretch:=Vector3.ONE
		if kind in ["beam","breath"]:
			var along:=cycle; var spread: float=(.12 if kind=="beam" else along*.9); pos=Vector3(source_delta.x*(1-along),0,source_delta.y*(1-along))+radial*spread*(.3+seed.z); pos.y=.15+sin(angle+age*4)*spread
		elif kind=="shield" or element in ["Holy","Magic","Charm"] and not burst:
			var vertical:=seed.z*2-1; var radius:=.8*sqrt(maxf(0,1-vertical*vertical)); pos=radial*radius; pos.y=vertical*.8+.65; stretch*=.55+sin(cycle*PI)*.65
			if element in ["Holy","Frost"]: stretch*=.16+seed.y*.65; pos.y+=sin(age+seed.w)*.08
		elif kind in ["pooling","bubbling"] or element in ["Water","Blood","Slime","Acid"]:
			var speed: float=1.7 if element in ["Water","Blood"] else .7
			var t: float=maxf(0,age-travel-seed.y*.27) if burst else cycle
			var velocity: float=.6+seed.y*2.4
			pos=radial*(.04+t*speed*(.2+seed.z)); pos.y=maxf(.012,velocity*t-2.6*t*t)
			if kind=="pooling": pos=radial*sqrt(seed.z)*.8; pos.y=.02+sin(cycle*PI)*.04
			var landed:=velocity*t-2.6*t*t<0
			stretch=Vector3(1,.12 if landed else 1.5,1)*(.25+seed.z*.85)*maxf(0,1-t*.44)
			if element in ["Slime","Acid"]: stretch*=1.7
		elif burst:
			var t:=phase; pos=radial*(.15+t*(1.1+seed.y*1.4)); pos.y=maxf(.03,(seed.z*2.8+1)*t-3.2*t*t); stretch=Vector3(.55,1.6,.55)*(1-t*.7)
		else:
			pos=radial*(.15+cycle*.35)*(1-cycle*.5); pos.y=cycle*(1.8+seed.z*.7); pos.x+=sin(pos.y*4+age*3+seed.w)*cycle*.16; stretch=Vector3(.65,2.4,.65)*(1-cycle*.75)
		var rotation:=Vector3(seed.w+age*(1+seed.y),seed.x+age,seed.w-age*.7)
		if element in ["Fire","Smoke","Death"]: rotation=Vector3(0,seed.w,0)
		if element in ["Blood","Water","Slime","Acid"]: rotation=Vector3(0,seed.w,0)
		var transform:=Transform3D(Basis.from_euler(rotation).scaled(stretch*fade),pos)
		cloud.multimesh.set_instance_transform(i,transform); cloud.multimesh.set_instance_color(i,Color.WHITE.lerp(Color(.5,.5,.5,1),seed.z*.4))
	for i in embers.multimesh.instance_count:
		var seed: Vector4=seeds[i%count]; var t:=fposmod(age*.75+seed.y,1.0); var p:=Vector3(cos(seed.x+age)*(.3+t),t*(2.5+seed.z),sin(seed.x+age)*(.3+t)); var scale:=Vector3.ONE*(1-t)*fade
		embers.multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(age+seed.x,0,seed.w)).scaled(scale),p))
	for i in rings.size():
		var ring: MeshInstance3D=rings[i]; var radius: float=(.18+phase*1.5) if burst else .8+sin(age*2+i)*.04; ring.scale=Vector3.ONE*radius*fade; ring.position.y=.03 if element in ["Blood","Water","Acid","Slime"] or burst else .6
		if element in ["Holy","Magic"]: ring.rotation=Vector3(age*.6+i*.8,age*.3,i*.9+sin(age)*.3)
	if volume!=null:
		volume_material.set_shader_parameter("age",age); volume_material.set_shader_parameter("strength",fade*(.38 if element=="Blood" else 1.2)*(1.-smoothstep(.45,1.8,age-travel) if element=="Fire" and burst else 1.)); volume.scale=(Vector3(.65,2.0,.65) if element=="Fire" else Vector3(.95,1.35,.95))*(.5+phase*1.2 if burst else 1.0)
	if shell!=null: shell.material_override.set_shader_parameter("time",age); shell.scale=Vector3.ONE*fade; shell.position.y=.45
	if core!=null: core.material_override.set_shader_parameter("age",age);core.visible=flight or kind=="bomb" and phase<.2; core.rotation=Vector3(age*2,age,age*1.4); core.position.y=.2+sin(phase*PI)*.5
	for ribbon in ribbons:ribbon.animate(age,phase,travel,source_delta,fade*(.22 if element=="Fire" and ribbon.style==4 else .4 if element=="Death" else 1.))
	if crown!=null:
		crown.visible=not flight;crown.material_override.set_shader_parameter("age",age-travel);crown.material_override.set_shader_parameter("strength",fade);crown.scale=Vector3(1,.4 if element=="Blood" else .65 if element in ["Slime","Acid"] else 1.,1)
	if accent!=null:
		accent.material_override.set_shader_parameter("age",age);accent.material_override.set_shader_parameter("phase",phase);accent.material_override.set_shader_parameter("strength",fade*.7);accent.scale=Vector3.ONE*(1.+phase*.65 if burst else 1.);accent.rotation.y=sin(age*.4)*.08
	if smoke_cap!=null:
		smoke_cap.material_override.set_shader_parameter("age",age*.8);smoke_cap.material_override.set_shader_parameter("strength",fade*.5*smoothstep(.1,.7,age-travel));smoke_cap.scale=(Vector3(.9,.65,.9)*(1.+phase*1.8) if burst else Vector3(.52,1.1,.52));smoke_cap.position.y=.6+phase*.7 if burst else 2.6;smoke_cap.visible=not flight
	if volume!=null and kind in ["beam","breath"]:
		var axis:=Vector3(source_delta.x,0,source_delta.y);volume.position=axis*.5+Vector3(0,.16,0);volume.basis=Basis(Quaternion(Vector3.UP,axis.normalized() if axis.length()>.01 else Vector3.UP)).scaled(Vector3(.32,maxf(.2,axis.length()*.5),.32));volume_material.set_shader_parameter("shape_mode",1 if kind=="beam" else 0)
	elif volume!=null and element=="Fire" and burst:volume.scale=Vector3.ONE*(.55+phase*2.4);volume.position.y=.6;volume_material.set_shader_parameter("shape_mode",2)
	elif volume!=null and element=="Death":volume.scale=Vector3(1,.48,1);volume.position.y=.45
	elif volume!=null and flight:volume.scale=Vector3(.25,.5,.25);volume.position.y=.2
	light.light_energy=light_power*.19*fade*(.85+sin(age*23)*.09+sin(age*37)*.06); light.position.y=.65
	if liquid_sheet!=null:
		var spread:=clampf((age-travel)*.6,.02,1.2); liquid_sheet.scale=Vector3(spread,.025,spread)*fade; liquid_sheet.rotation.y=age*.15
		sheet_material.set_shader_parameter("age",age)
