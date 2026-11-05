extends Node3D
class_name Hearth20CasinoLizard
## The supplied95-bone colored lizard keeps its authored idle and walking clips.
var model: Node3D
var normalization: Node3D
var player: AnimationPlayer
var walk=""
var idle=""
var walk_seconds=.0
var walk_duration=.0
var wait_seconds=.0
var start=Vector3.ZERO
var finish=Vector3.ZERO
var pace_count=0
var total_paces=0
var gait_started=false
var forward_rotation=0.
func setup(packed: PackedScene) -> void:
	normalization=Node3D.new();add_child(normalization);model=packed.instantiate();normalization.add_child(model);model.hide();set_process(false)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for index in mesh.mesh.get_surface_count():
			var original=mesh.get_active_material(index)
			if original is StandardMaterial3D:
				var natural=original.duplicate();natural.metallic=0.;natural.roughness=maxf(.65,natural.roughness);natural.clearcoat_enabled=false;mesh.set_surface_override_material(index,natural)
	for candidate in model.find_children("*","AnimationPlayer",true,false):
		player=candidate
		for animation_name in player.get_animation_list():
			if "walk" in str(animation_name).to_lower():walk=animation_name
			if "idle" in str(animation_name).to_lower():idle=animation_name
		if not walk.is_empty():break
	if player!=null:
		if not walk.is_empty():player.get_animation(walk).loop_mode=Animation.LOOP_LINEAR
		if not idle.is_empty():player.play(idle);player.advance(0.)
func normalize_model(length=.27) -> void:
	var bounds=measure(model);var size_value=bounds.size;var factor=length/maxf(.001,maxf(size_value.x,size_value.z))
	var eyes=Vector3.ZERO;var count=0
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name) in ["Object_105","Object_107"]:
			eyes+=mesh_bounds(model,mesh).get_center();count+=1
	if count>0:
		var direction=eyes/float(count)-bounds.get_center();direction.y=0
		if direction.length_squared()>.001:forward_rotation=PI-atan2(direction.x,direction.z)
	normalization.scale=Vector3.ONE*factor;normalization.position=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*factor
	# Rotation belongs to the miniature's wrapper, leaving skeleton tracks intact.
	rotation.y=forward_rotation;model.show()
static func mesh_bounds(root_node: Node3D, mesh: MeshInstance3D) -> AABB:
	var geometry: Mesh=mesh.mesh
	if mesh.skin!=null and mesh.get_skin_reference()!=null:geometry=mesh.bake_mesh_from_current_skeleton_pose()
	return (root_node.get_parent().global_transform.affine_inverse()*mesh.global_transform)*geometry.get_aabb()
static func measure(root_node: Node3D) -> AABB:
	var result=AABB();var found=false
	for mesh in root_node.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:continue
		var box=mesh_bounds(root_node,mesh);result=result.merge(box) if found else box;found=true
	return result
func walk_paces(paces: int, destination: Vector3, delay=.0) -> void:
	start=position;finish=destination;pace_count=clampi(paces,1,4);total_paces+=pace_count;walk_duration=pace_count*.40;walk_seconds=0.;wait_seconds=delay;gait_started=false;set_process(true)
func snap_to(destination: Vector3) -> void:
	position=destination;walk_seconds=walk_duration;gait_started=false;set_process(false)
	if player!=null and not idle.is_empty():player.speed_scale=1.;player.play(idle,.10)
func _process(delta: float) -> void:
	if wait_seconds>0:wait_seconds-=delta;return
	if not gait_started:
		gait_started=true
		if player!=null and not walk.is_empty():player.speed_scale=player.get_animation(walk).length/.40;player.play(walk,.06);player.seek(0.,true)
	walk_seconds=minf(walk_duration,walk_seconds+delta);var t=walk_seconds/maxf(.001,walk_duration);position=start.lerp(finish,t)
	if walk_seconds>=walk_duration:snap_to(finish)
