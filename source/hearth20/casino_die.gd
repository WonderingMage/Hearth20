extends Node3D
class_name Hearth20CasinoDie
## Original gilded polyhedra: soul glass for Ord; green stone for the lizard race.
var sides=8
var value=1
var theme="soul"
var body: Node3D
var shell_material: ShaderMaterial
var detached_mist=false
var number: Hearth20DiceNumeral
var soul_motion: Hearth20SoulMotion
var soul_tick=-1
var mist: MeshInstance3D
var age=0.
var rolling=false
var final_rotation=Quaternion.IDENTITY
var start_rotation=Quaternion.IDENTITY
var resting=Vector3.ZERO
var hovered=false
var target_scale=.23
var aura: MeshInstance3D
var reveal_elapsed=-1.
var placed=false
var ice: MeshInstance3D
var render_active=true
var threaded_motion=false
func setup(sides_value: int, result: int, style="soul") -> void:
	sides=sides_value;value=clampi(result,1,sides);theme=style;body=Node3D.new();add_child(body)
	var crafted=Hearth20CathedralDie.build(sides);var faces=crafted.faces
	var shell=MeshInstance3D.new();shell.name="BeveledGlazing";shell.mesh=crafted.glass;shell_material=_shell();shell.material_override=shell_material;body.add_child(shell)
	var frame=MeshInstance3D.new();frame.name="ForgedCathedralCame";frame.mesh=crafted.frame;frame.material_override=Hearth20CathedralDie.brass_material();body.add_child(frame)
	set_meta("frame_vertices",crafted.frame.surface_get_array_len(0));set_meta("glass_vertices",crafted.glass.surface_get_array_len(0))
	if theme=="soul":
		mist=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3.ONE*2;mist.mesh=box;mist.material_override=Hearth20CasinoSoulVolume.material(faces);mist.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;body.add_child(mist)
	var face=faces[value-1];number=Hearth20DiceNumeral.new();number.name="RevealedResult";number.setup(str(value),.60 if sides==6 else .53,.74 if sides==6 else .60)
	number.position=face.center+face.normal*.028;number.basis=Basis.looking_at(face.normal,Vector3.RIGHT if absf(face.normal.y)>.98 else Vector3.UP,true);body.add_child(number)
	if theme=="soul":
		soul_motion=Hearth20SoulMotion.new();soul_motion.setup(faces,value-1);soul_motion.glyph_anchors=Hearth20SoulReveal.glyph_anchors(number.mesh)
		number.material_override=Hearth20SoulReveal.numeral_material();number.hide();aura=Hearth20SoulReveal.aura(face,number.basis);body.add_child(aura);ice=Hearth20DiceIce.build(sides);body.add_child(ice)
		shell_material.set_shader_parameter("result_normal",face.normal);_animate_souls()

	body.set_meta("result_basis",number.basis);body.set_meta("result_normal",face.normal);body.set_meta("result_value",value);body.set_meta("face_count",sides);set_meta("theme",theme);scale=Vector3.ONE*target_scale
func _shell() -> ShaderMaterial:
	var shader=Shader.new()
	if theme=="soul":return Hearth20CathedralDie.glass_material(sides)
	shader.code="""shader_type spatial;varying vec3 p;void vertex(){p=VERTEX;}void fragment(){float vein=pow(.5+.5*sin((p.x+p.z*.8)*18.+sin(p.y*13.)*2.),10.);ALBEDO=mix(vec3(.018,.105,.052),vec3(.18,.40,.16),vein*.65+.2);METALLIC=.13;ROUGHNESS=.22;CLEARCOAT=.65;CLEARCOAT_ROUGHNESS=.15;}"""
	var material=ShaderMaterial.new();material.shader=shader;material.render_priority=3 if theme=="soul" else 0;return material
func place(at: Vector3, camera: Camera3D, animate_roll=false) -> void:
	resting=at;position=at;var basis: Basis=body.get_meta("result_basis");final_rotation=Quaternion(camera.global_basis*basis.inverse())
	age=0.;rolling=animate_roll;placed=true;reveal_elapsed=-1.;number.visible=theme!="soul" and not animate_roll
	if not animate_roll:body.quaternion=final_rotation
func _process(delta: float) -> void:
	age+=delta
	if not render_active:
		if rolling and age>=Hearth20SoulReveal.ROLL_SECONDS:rolling=false;body.quaternion=final_rotation;reveal_elapsed=maxf(0.,age-Hearth20SoulReveal.ROLL_SECONDS)
		elif not rolling:reveal_elapsed=maxf(0.,reveal_elapsed)+delta
		return
	if rolling:
		var t=clampf(age/Hearth20SoulReveal.ROLL_SECONDS,0,1);body.quaternion=Quaternion.from_euler(Vector3(age*9.,age*13.,age*11.)).slerp(final_rotation,smoothstep(.45,1.,t));position=resting+Vector3(0,absf(sin(t*PI*3.))*pow(1.-t,1.7)*.32,0)
		if t>=1.:rolling=false;number.visible=theme!="soul";body.quaternion=final_rotation
	if theme=="soul" and placed:
		if not rolling and reveal_elapsed<0.:reveal_elapsed=0.
		elif not rolling:reveal_elapsed+=delta
		var effect=Hearth20SoulReveal.envelope(reveal_elapsed)
		number.visible=effect.formation>.001;number.material_override.set_shader_parameter("formation",effect.formation)
		aura.material_override.set_shader_parameter("flash",effect.flash);aura.material_override.set_shader_parameter("rays",effect.rays);aura.material_override.set_shader_parameter("age",age)
		shell_material.set_shader_parameter("reveal_glow",effect.flash)
	if mist!=null and not threaded_motion and floori(age*30.)!=soul_tick:_animate_souls()
	var desired=target_scale*(1.5 if hovered else 1.);scale=scale.lerp(Vector3.ONE*desired,minf(1.,delta*10.))
	if not rolling:position=position.lerp(resting+Vector3(0,.10 if hovered else 0,.13 if hovered else 0),minf(1.,delta*10.))
	if number.visible:number.scale=Vector3.ONE*(1.+sin(age*2.)*.012)
	if detached_mist and is_instance_valid(mist):mist.global_transform=body.global_transform

func attach_scene_buffers(room: Texture2D, spirits: Texture2D, spirit_world: Node3D) -> void:
	if theme!="soul" or mist==null:return
	shell_material.set_shader_parameter("room",room);shell_material.set_shader_parameter("souls",spirits);shell_material.set_shader_parameter("has_buffers",true)
	mist.reparent(spirit_world);mist.global_transform=body.global_transform;detached_mist=true
	var inner_frame=MeshInstance3D.new();inner_frame.name="TransmittedCame";inner_frame.mesh=Hearth20CathedralDie.build(sides).frame;inner_frame.material_override=Hearth20CathedralDie.brass_material();mist.add_child(inner_frame)
func _exit_tree() -> void:
	if detached_mist and is_instance_valid(mist):mist.queue_free()

func _animate_souls() -> void:
	if soul_motion==null:return
	apply_soul_frame(soul_motion.frame(age,reveal_elapsed),age)
func apply_soul_frame(frame: Dictionary,stamp: float) -> void:
	if not is_instance_valid(mist):return
	soul_tick=floori(stamp*30.);Hearth20CasinoSoulVolume.animate(mist.material_override,frame,stamp)
	shell_material.set_shader_parameter("soul_contacts",frame.contacts)
	ice.material_override.set_shader_parameter("growth",.45+.55*smoothstep(0.,6.5,age))
