extends RefCounted
class_name Hearth20GeneratedModels
## Trusted bundled static scenes, prepared offline from the user's originals.
const MANIFEST="res://hearth20/generated_models/manifest.json"
const ACTIVE=["room","table","side_table","menu","map_handle","casino_handle","ceiling_hole","map_frame","candle","goblet","purse_bag","dragon_coin","wood_coin","dice_cup","lizard_table","plate","potato_chip","potato_fry","food","bar","bar_stool","bench","bottle","bowl","cabinet","door","fireplace","large_window","small_window","small_bar_table","wall_candle","wood_shelve","shield","kit_floor","kit_stone","kit_beam"]
static var catalog={}
static var cache={}
static var material_cache={}
static var finish_cache={}
static func prepare(tree: SceneTree,progress: Callable=Callable()) -> void:
	if catalog.is_empty() and FileAccess.file_exists(MANIFEST):catalog=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)).get("models",{})
	for i in ACTIVE.size():
		var id=ACTIVE[i]
		if catalog.has(id) and not cache.has(id):
			var path=str(catalog[id].path);var error=ResourceLoader.load_threaded_request(path,"PackedScene")
			if error in [OK,ERR_BUSY]:
				while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await tree.process_frame
				if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED:cache[id]=ResourceLoader.load_threaded_get(path)
		if progress.is_valid():progress.call(i+1,ACTIVE.size())
		await tree.process_frame
static func available(id: String) -> bool:return cache.has(id)
static func vector(values: Array) -> Vector3:return Vector3(float(values[0]),float(values[1]),float(values[2]))
static func make(id: String,dimensions: Vector3,centered=false) -> Node3D:
	if not available(id):return null
	var record: Dictionary=catalog[id];var model: Node3D=cache[id].instantiate();var rotation=Basis.IDENTITY
	if record.has("orientation_basis"):
		var axes=record.orientation_basis;rotation=Basis(vector(axes[0]),vector(axes[1]),vector(axes[2]))
	var box: Dictionary=record.get("oriented_bounds",record.bounds);var minimum=vector(box.min);var extent=vector(box.size)
	var fit=dimensions/extent.max(Vector3.ONE*.00001);var anchor=minimum+extent*Vector3(.5,.5 if centered else 0.,.5)
	model.transform=Transform3D(Basis.from_scale(fit)*rotation,-anchor*fit)
	_finish(model,id)
	var holder=Node3D.new();holder.name="Generated_"+id;holder.set_meta("generated_model",id);holder.set_meta("target_dimensions",dimensions);holder.add_child(model);return holder
static func _finish(model: Node3D,id: String) -> void:
	if id not in ["map_paper","table","kit_beam"]:return
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var source=mesh.get_active_material(i)
			if not source is StandardMaterial3D:continue
			var key=id+":"+str(source.get_instance_id())
			if not finish_cache.has(key):
				var mat=source.duplicate() as StandardMaterial3D
				if id=="map_paper":mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(.86,.84,.79);mat.metallic=0.
				elif id=="kit_beam":mat.metallic=0.;mat.roughness=.95;mat.normal_scale=.45;mat.albedo_color=Color(.44,.39,.34)
				elif id=="table":mat.metallic*=.65;mat.roughness_texture=null;mat.roughness=.74;mat.albedo_color=Color(.88,.86,.83)
				finish_cache[key]=mat
			mesh.set_surface_override_material(i,finish_cache[key])
static func raw(id: String) -> Node3D:
	if not available(id):return null
	var model: Node3D=cache[id].instantiate();model.set_meta("generated_model",id);return model
static func surface(id: String) -> StandardMaterial3D:
	if material_cache.has(id):return material_cache[id]
	if not available(id):return null
	var model: Node3D=cache[id].instantiate();var result: StandardMaterial3D
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh!=null and mesh.mesh.get_surface_count()>0:result=mesh.get_active_material(0);break
	if result!=null:material_cache[id]=result
	model.free();return result
static func part(id: String,dimensions: Vector3,index=0) -> Node3D:
	if not available(id):return null
	var original: Node3D=cache[id].instantiate();var meshes=original.find_children("*","MeshInstance3D",true,false)
	if index>=meshes.size():original.free();return null
	var source: MeshInstance3D=meshes[index];var transform=source.transform;var parent=source.get_parent()
	while parent is Node3D:transform=parent.transform*transform;parent=parent.get_parent()
	var box=transform*source.mesh.get_aabb();var scale_value=dimensions/box.size.max(Vector3.ONE*.00001);var anchor=box.position+box.size*Vector3(.5,0,.5)
	var mesh=MeshInstance3D.new();mesh.mesh=source.mesh;mesh.material_override=source.material_override;mesh.transform=Transform3D(Basis.from_scale(scale_value),-anchor*scale_value)*transform
	var holder=Node3D.new();holder.name="Generated_"+id+"_part";holder.set_meta("generated_model",id);holder.add_child(mesh);original.free();return holder
static func shadows(node: Node,enabled: bool) -> void:
	if node is GeometryInstance3D:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():shadows(child,enabled)
