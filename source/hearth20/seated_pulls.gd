extends Node3D
class_name Hearth20SeatedPulls
## DM-only input is handled by the seated shell; these are shared visual objects.
var handles={}
var cords={}
var rest_y=2.83
var ceiling_y=4.72
func setup(table: Hearth20CasinoTable) -> void:
	ceiling_y=table.room.ceiling_height-.12
	var steel=StandardMaterial3D.new();steel.albedo_color=Color("#6c7379");steel.metallic=.94;steel.roughness=.29
	var black=StandardMaterial3D.new();black.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;black.albedo_color=Color.BLACK
	var rope=StandardMaterial3D.new();rope.albedo_color=Color("#8d7046");rope.roughness=.96
	var engraving=StandardMaterial3D.new();engraving.albedo_color=Color("#d4b071");engraving.metallic=.35;engraving.roughness=.67
	var handle_wood=ShaderMaterial.new();var wood_shader=Shader.new();wood_shader.code="""
shader_type spatial;
render_mode cull_disabled;
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
void fragment(){
 float grain=sin(local_point.y*290.+sin(atan(local_point.z,local_point.x)*13.+local_point.y*7.)*3.);
 float pores=sin(local_point.y*1410.+local_point.x*500.)*sin(local_point.z*2100.+local_point.y*310.);
 ALBEDO=mix(vec3(.16,.065,.022),vec3(.43,.22,.075),.52+.18*grain+.045*pores);
 ROUGHNESS=.63+.10*grain;METALLIC=0.;
}
""";handle_wood.shader=wood_shader
	var reading_light=OmniLight3D.new();reading_light.position=Vector3(0,3.15,.75);reading_light.omni_range=1.25;reading_light.light_energy=1.1;reading_light.light_color=Color("#ffe4bc");add_child(reading_light)
	for mode in ["map","casino"]:
		var x=-.24 if mode=="map" else .24
		var hole=MeshInstance3D.new();var disk=CylinderMesh.new();disk.top_radius=.13;disk.bottom_radius=.13;disk.height=.035;disk.radial_segments=48;hole.mesh=disk;hole.material_override=black;hole.position=Vector3(x,ceiling_y+.045,0);add_child(hole)
		var mount=Hearth20GeneratedModels.make("ceiling_hole",Vector3(.31,.065,.31),true)
		if mount!=null:mount.position=Vector3(x,ceiling_y+.024,0);mount.rotation.z=PI;add_child(mount)
		else:
			var ring=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=.12;torus.outer_radius=.155;torus.rings=40;torus.ring_segments=12;ring.mesh=torus;ring.material_override=steel;ring.position=Vector3(x,ceiling_y+.024,0);add_child(ring)
		var throat=MeshInstance3D.new();var tube=CylinderMesh.new();tube.top_radius=.122;tube.bottom_radius=.122;tube.height=.30;tube.radial_segments=32;throat.mesh=tube;throat.material_override=black;throat.position=Vector3(x,ceiling_y+.18,0);add_child(throat)
		var cord=MeshInstance3D.new();cord.mesh=_braid(ceiling_y-rest_y);cord.material_override=rope;cord.position=Vector3(x,ceiling_y,0);add_child(cord);cords[mode]=cord
		var grip=Node3D.new();grip.position=Vector3(x,rest_y,0);add_child(grip);handles[mode]=grip
		var crafted=Hearth20GeneratedModels.make("map_handle" if mode=="map" else "casino_handle",Vector3(.14,.40,.13),true)
		if crafted!=null:grip.add_child(crafted)
		else:
			var rod=MeshInstance3D.new();rod.name="TurnedCarpentersGrip";rod.mesh=_turned_grip();rod.material_override=handle_wood;grip.add_child(rod)
			var ferrule=MeshInstance3D.new();var collar=CylinderMesh.new();collar.top_radius=.027;collar.bottom_radius=.030;collar.height=.033;collar.radial_segments=32;ferrule.mesh=collar;ferrule.material_override=table.bronze;ferrule.position.y=.183;grip.add_child(ferrule)
		var words=TextMesh.new();words.text="MAP" if mode=="map" else "CASINO";words.font=Hearth20Design.font(true);words.font_size=64;words.pixel_size=.00047 if mode=="map" else .00028;words.depth=.001;words.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;words.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var label=MeshInstance3D.new();label.mesh=words;label.material_override=engraving;label.position=Vector3(0,-.079,.074)-words.get_aabb().get_center();grip.add_child(label)
		# Inlaid board grid / fanned cards give each wooden pull a distinct engraving.
		for i in 3:
			if mode=="map":
				for vertical in [false,true]:
					var stroke=table._bevel(Vector3(.064,.0025,.0015) if not vertical else Vector3(.0025,.064,.0015),.0005,engraving);stroke.position=Vector3((i-1)*.031 if vertical else 0,.005+(i-1)*.031 if not vertical else .005,.074);grip.add_child(stroke)
			else:
				var card=table._bevel(Vector3(.035,.055,.002),.003,engraving);card.position=Vector3((i-1)*.018,.015,.074+i*.001);card.rotation.z=(i-1)*-.28;grip.add_child(card)
func _turned_grip() -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(0)
	for ring in 48:
		for side in 40:
			for corner in [[ring,side],[ring+1,side],[ring+1,side+1],[ring,side],[ring+1,side+1],[ring,side+1]]:
				var t=float(corner[0])/48.;var angle=float(corner[1])/40.*TAU
				# A narrow ferrule flows into a broad, rounded tool-handle butt.
				var radius=.024+.046*pow(maxf(0.,sin(PI*t)),.7)*smoothstep(0.,.55,t)
				st.set_uv(Vector2(angle/TAU,t));st.add_vertex(Vector3(sin(angle)*radius,.20-.40*t,cos(angle)*radius))
	st.generate_normals();return st.commit()
func _braid(length_value: float) -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in 3:
		for step in 96:
			for side in 6:
				for spec in [[step,side],[step+1,side+1],[step+1,side],[step,side],[step,side+1],[step+1,side+1]]:
					var t=float(spec[0])/96.;var twist=t*TAU*23+strand*TAU/3.;var angle=float(spec[1])/6.*TAU;var n=Vector3(cos(angle),0,sin(angle));st.set_normal(n);st.set_uv(Vector2(t*length_value*12,float(spec[1])/6.));st.add_vertex(Vector3(cos(twist)*.012,-t*length_value,sin(twist)*.012)+n*.009)
	return st.commit()
func pull(mode: String, amount: float) -> void:
	if not handles.has(mode):return
	amount=clampf(amount,0,.38);handles[mode].position.y=rest_y-amount;cords[mode].scale.y=(ceiling_y-rest_y+amount)/(ceiling_y-rest_y)
func hit(camera: Camera3D, screen: Vector2) -> String:
	for mode in handles:
		if camera.is_position_behind(handles[mode].global_position):continue
		var center=camera.unproject_position(handles[mode].global_position)
		if center.distance_to(screen)<maxf(32.,camera.unproject_position(handles[mode].global_position+Vector3(.085,0,0)).distance_to(center)):return mode
	return ""
