extends RefCounted
## The authored room is static. Gameplay props and cameras keep their existing world coordinates.
const SUN_DIRECTION := Vector3(.200,-.180,-.964)
const DUST_MOTES := preload("dust_motes.gdshader")
const WINDOWS := [
	{"name":"Main","center":Vector3(-1,2.17,6.935),"normal":Vector3.FORWARD,"width":1.34,"height":1.28,"arch_rise":0.},
	{"name":"Entry","center":Vector3(-5.05,1.579,6.881),"normal":Vector3.FORWARD,"width":1.63,"height":1.138,"arch_rise":.778},
	{"name":"Kitchen","center":Vector3(-9.497,2.045,3.79),"normal":Vector3.RIGHT,"width":.948,"height":.99,"arch_rise":.50},
]

static func build(room, scene: PackedScene) -> void:
	var furnished_room := scene.instantiate() as Node3D
	furnished_room.name="StorybookLivingRoom"
	room.add_child(furnished_room)
	room.ceiling_height=3.68
	room.set_meta("storybook_room",true)
	room.set_meta("crafted_room",true)
	room.set_meta("fully_enclosed",true)
	room.set_meta("modeled_front",true)
	room.set_meta("uses_generated_backdrop",false)
	room.set_meta("window_apertures",WINDOWS)
	for mesh in furnished_room.find_children("*","MeshInstance3D",true,false):
		if mesh.name=="FireGlow":
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.mesh.surface_get_material(surface)
			if material!=null and material.resource_name=="Beam Dark":
				room.materials["timber"]=material
	# Navigation still uses the fixed seat. Keep the enclosing physics query separate from the detailed visual mesh.
	room._collision_boundary("Floor",Vector3(-.76,-1.16,0),Vector3(17.4,.20,14.32))
	room._collision_boundary("Ceiling",Vector3(-.76,3.95,0),Vector3(17.4,.20,14.32))
	room._collision_boundary("FrontWall",Vector3(-.76,1.39,-6.98),Vector3(17.4,4.95,.36))
	room._collision_boundary("RearWall",Vector3(-.76,1.39,6.98),Vector3(17.4,4.95,.36))
	room._collision_boundary("EastWall",Vector3(7.98,1.39,0),Vector3(.36,4.95,14.32))
	room._collision_boundary("WestWall",Vector3(-9.42,1.39,0),Vector3(.16,4.95,14.32))
	for aperture in WINDOWS:
		_add_pane(room,aperture)
	var banners := Hearth20TavernCraft.new()
	banners.room=room
	banners.rng.seed=201811
	banners._banner("tarrasque",Vector3(7.73,3.00,-4.72),-PI/2,.97,1.68)
	banners._banner("tiamat",Vector3(7.73,3.00,-1.95),-PI/2,.97,1.68)
	banners._banner("vecna",Vector3(7.73,3.00,2.88),-PI/2,.97,1.68)
	banners._banner("strahd",Vector3(-7.73,3.05,.07),PI/2,.97,1.68)
	room._finish_batches()
	room._fire_particles(Vector3(-6.44,.69,-3.65),false)
	# Pools follow visible fixtures, with a soft falloff into the ceiling and shelf recesses.
	_lamp(room,"KitchenLamp",Vector3(-8.76,2.18,3.25),Color("#ffe0af"),.66,4.3)
	_lamp(room,"HearthWarmth",Vector3(-6.25,.83,-3.65),Color("#ffa45b"),1.40,4.3,true)
	_lamp(room,"HearthBounce",Vector3(-5.87,1.12,-3.67),Color("#ffb071"),.37,3.0)
	_lamp(room,"ChandelierLamp",Vector3(0,2.77,-1.85),Color("#ffdbab"),1.55,7.0,true)
	_lamp(room,"LibraryLamp",Vector3(.24,2.16,6.44),Color("#ffd7a2"),.55,4.25)
	_lamp(room,"BrewerLamp",Vector3(1.58,1.33,-5.07),Color("#ffd1a0"),.39,3.15)
	var atmosphere := Hearth20RoomAtmosphere.new()
	atmosphere.name="WindowAtmosphere"
	room.add_child(atmosphere)
	atmosphere.setup(room,WINDOWS,SUN_DIRECTION)
	var dust := _dust()
	atmosphere.add_child(dust)
	atmosphere.storybook_dust=dust
	var exterior := Hearth20WindowWorldView.new()
	exterior.name="WindowWorld"
	room.add_child(exterior)
	exterior.setup(room)

static func _add_pane(room: Node3D, aperture: Dictionary) -> void:
	var half_width: float=aperture.width*.5
	var half_height: float=aperture.height*.5
	var outline := PackedVector2Array([Vector2(-half_width,-half_height),Vector2(half_width,-half_height)])
	if aperture.arch_rise>0.:
		for step in 29:
			var arc := PI*step/28.
			outline.append(Vector2(half_width*cos(arc),half_height-aperture.arch_rise*(1.-sin(arc))))
	else:
		outline.append(Vector2(half_width,half_height))
		outline.append(Vector2(-half_width,half_height))
	var normal: Vector3=aperture.normal
	var across := normal.cross(Vector3.UP)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for edge in outline.size():
		surface.add_vertex(Vector3.ZERO)
		for point in [outline[edge],outline[(edge+1)%outline.size()]]:
			surface.add_vertex(across*point.x+Vector3.UP*point.y)
	var pane := MeshInstance3D.new()
	pane.name="RecessedSkyPane"+aperture.name
	pane.mesh=surface.commit()
	pane.position=aperture.center
	pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(pane)

static func _lamp(room: Node3D, label: String, point: Vector3, tint: Color, energy: float, radius: float, shadows := false) -> void:
	var light := OmniLight3D.new()
	light.name=label
	light.position=point
	light.light_color=tint
	light.light_energy=energy
	light.light_specular=.16
	light.omni_range=radius
	light.omni_attenuation=1.42
	light.shadow_enabled=shadows
	light.shadow_normal_bias=.49
	light.shadow_blur=1.8
	room.add_child(light)

static func _dust() -> MultiMeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader=DUST_MOTES
	var quad := QuadMesh.new()
	quad.size=Vector2.ONE
	quad.material=material
	var particles := MultiMesh.new()
	particles.transform_format=MultiMesh.TRANSFORM_3D
	particles.use_custom_data=true
	particles.mesh=quad
	particles.instance_count=150
	var rng := RandomNumberGenerator.new()
	rng.seed=2941
	for i in particles.instance_count:
		var travel := rng.randf_range(.35,5.8)
		var point: Vector3=WINDOWS[0].center
		point+=SUN_DIRECTION*travel+Vector3(rng.randf_range(-.55,.55),rng.randf_range(-.49,.49),0.)
		var opacity := rng.randf_range(.36,.78)
		if i>=112:
			point=Vector3(rng.randf_range(-6.2,6.2),rng.randf_range(.95,3.12),rng.randf_range(-5.6,6.1))
			opacity*=.46
		particles.set_instance_transform(i,Transform3D(Basis.IDENTITY,point))
		particles.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),opacity))
	particles.custom_aabb=AABB(Vector3(-6.55,.1,-5.9),Vector3(13.1,3.3,13.0))
	var dust := MultiMeshInstance3D.new()
	dust.name="DustMotes"
	dust.multimesh=particles
	dust.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return dust
