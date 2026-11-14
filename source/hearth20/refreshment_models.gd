extends RefCounted
class_name Hearth20RefreshmentModels
static var cache={}
static func prepare(id: String,tree: SceneTree) -> PackedScene:
	var path=Hearth20RefreshmentCatalog.model_path(id)
	if cache.has(path):return cache[path]
	var result=ResourceLoader.load_threaded_request(path,"PackedScene")
	if result not in [OK,ERR_BUSY]:return null
	while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await tree.process_frame
	if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:return null
	var packed=ResourceLoader.load_threaded_get(path);cache[path]=packed
	while cache.size()>4:cache.erase(cache.keys()[0])
	return packed
static func make(id: String,packed: PackedScene) -> Node3D:
	var source=packed.instantiate();var content: Node3D=source
	var selector=str(Hearth20RefreshmentCatalog.DRINKS.get(id,{}).get("node",""))
	if not selector.is_empty():
		var found=source.find_child(selector,true,false)
		if found==null:source.free();return null
		var transform=found.transform;var parent=found.get_parent()
		while parent is Node3D:transform=parent.transform*transform;parent=parent.get_parent()
		content=found.duplicate();content.transform=transform;source.free()
	var holder=Node3D.new();holder.name="Serving_"+id;holder.add_child(content)
	var bounds=_bounds(content,Transform3D.IDENTITY);var size_value=.25
	if Hearth20RefreshmentCatalog.DRINKS.has(id):size_value=float(Hearth20RefreshmentCatalog.DRINKS[id].height)/maxf(.0001,bounds.size.y)
	else:size_value=(.29 if id=="sausage_big" else .24)/maxf(.0001,maxf(bounds.size.y,maxf(bounds.size.x,bounds.size.z)))
	var offset=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	content.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size_value),-offset*size_value)*content.transform
	var fitted=_bounds(content,Transform3D.IDENTITY)
	holder.set_meta("item_id",id);holder.set_meta("bounds",fitted)
	if Hearth20RefreshmentCatalog.DRINKS.has(id):
		# A contact point on the near lip, rather than the base/pivot of the cup.
		# Beer includes its handle in the bounds, so its lip is a little inboard.
		var lip=fitted.get_center();lip.y=fitted.end.y-.005;lip.z+=fitted.size.z*.30
		holder.set_meta("drink_lip",lip)
	return holder
static func _bounds(node: Node3D,parent: Transform3D) -> AABB:
	var transform=parent*node.transform;var box=AABB();var started=false
	if node is MeshInstance3D and node.mesh!=null:box=transform*node.mesh.get_aabb();started=true
	for child in node.get_children():
		if not child is Node3D:continue
		var next=_bounds(child,transform)
		if next.size.length_squared()<.0000001:continue
		box=box.merge(next) if started else next;started=true
	return box
