extends SceneTree
var output="res://hearth20/generated_models"
var qa=""
var texture_cache={}
var texture_bytes=0
func _initialize() -> void:call_deferred("run")
func texture(source: Texture2D,limit: int,kind: int) -> Texture2D:
	if source==null:return null
	var key=str(source.get_instance_id())+":"+str(kind)
	if texture_cache.has(key):return texture_cache[key]
	var image=source.get_image()
	if image==null or image.is_empty():return source
	if image.is_compressed():image.decompress()
	var ratio=minf(1.,float(limit)/maxi(image.get_width(),image.get_height()))
	if ratio<1.:image.resize(maxi(4,roundi(image.get_width()*ratio)),maxi(4,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps(kind==Image.COMPRESS_SOURCE_NORMAL)
	var error=image.compress(Image.COMPRESS_S3TC,kind)
	if error!=OK:push_error("Texture compression failed "+str(error))
	texture_bytes+=image.get_data_size();var result=ImageTexture.create_from_image(image);texture_cache[key]=result;return result
func material(mat: Material,limit: int,room: bool) -> Material:
	if not mat is StandardMaterial3D:return mat
	var copy=mat.duplicate() as StandardMaterial3D
	for slot in [BaseMaterial3D.TEXTURE_ALBEDO,BaseMaterial3D.TEXTURE_METALLIC,BaseMaterial3D.TEXTURE_ROUGHNESS,BaseMaterial3D.TEXTURE_NORMAL,BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION]:
		var kind=Image.COMPRESS_SOURCE_SRGB if slot==BaseMaterial3D.TEXTURE_ALBEDO else Image.COMPRESS_SOURCE_NORMAL if slot==BaseMaterial3D.TEXTURE_NORMAL else Image.COMPRESS_SOURCE_GENERIC
		copy.set_texture(slot,texture(mat.get_texture(slot),limit,kind))
	copy.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if room:copy.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;copy.cull_mode=BaseMaterial3D.CULL_DISABLED
	return copy
func compact(arrays: Array,indices: PackedInt32Array) -> Array:
	var mapping={};var used=PackedInt32Array();var next=PackedInt32Array();next.resize(indices.size())
	for i in indices.size():
		var old=indices[i]
		if not mapping.has(old):mapping[old]=used.size();used.append(old)
		next[i]=mapping[old]
	var result=[];result.resize(Mesh.ARRAY_MAX)
	for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
		if arrays[slot]==null or arrays[slot].is_empty():continue
		var values=arrays[slot];var chosen=values.duplicate();chosen.clear()
		for index in used:
			if slot==Mesh.ARRAY_TANGENT:
				for k in 4:chosen.append(values[index*4+k])
			else:chosen.append(values[index])
		result[slot]=chosen
	result[Mesh.ARRAY_INDEX]=next;return result
func bounds(node: Node3D,parent: Transform3D) -> AABB:
	var transform=parent*node.transform;var box=AABB();var started=false
	if node is MeshInstance3D and node.mesh!=null:box=transform*node.mesh.get_aabb();started=true
	for child in node.get_children():
		if child is Node3D:
			var next=bounds(child,transform)
			if next.size.length_squared()>0.:box=box.merge(next) if started else next;started=true
	return box
func run() -> void:
	qa=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var inventory=JSON.parse_string(FileAccess.get_file_as_string(qa.path_join("inventory.json")));var records={};var selected=OS.get_cmdline_user_args().slice(1)
	if not selected.is_empty() and FileAccess.file_exists(output.path_join("manifest.json")):records=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("manifest.json"))).models
	for record in inventory.models:
		var id=str(record.name).get_basename();var path=str(record.source)
		if not selected.is_empty() and not id in selected:continue
		if id=="room":path=qa.path_join("room-reduced.glb")
		elif FileAccess.file_exists(qa.path_join("clean-"+id+".glb")):path=qa.path_join("clean-"+id+".glb")
		texture_cache.clear();texture_bytes=0
		var document=GLTFDocument.new();var state=GLTFState.new();var error=document.append_from_file(path,state)
		if error!=OK:push_error("Could not import "+id+": "+str(error));quit(1);return
		var root_model=document.generate_scene(state);root_model.name="Generated_"+id;var triangle_count=0;var lod_note=[]
		for node in root_model.find_children("*","MeshInstance3D",true,false):
			var replacement=ArrayMesh.new()
			for surface in node.mesh.get_surface_count():
				var arrays=node.mesh.surface_get_arrays(surface);var chosen: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				# Static kits may carry custom color/UV channels with import-only
				# encoding flags. This runtime path only needs standard attributes.
				for slot in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:arrays[slot]=null
				if id=="table" and chosen.size()/3>75000:
					var importer=ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays);importer.generate_lods(25.,60.,[])
					var best=absi(chosen.size()/3-60000)
					for lod in importer.get_surface_lod_count(0):
						var candidate=importer.get_surface_lod_indices(0,lod);lod_note.append(candidate.size()/3)
						if candidate.size()/3>=25000 and absi(candidate.size()/3-60000)<best:chosen=candidate;best=absi(candidate.size()/3-60000)
					arrays=compact(arrays,chosen)
				var limit=2048 if id in ["table","room","map_paper","menu","map_frame"] else 1024
				var mat=material(node.get_active_material(surface),limit,id=="room")
				var previous_surfaces=replacement.get_surface_count();replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				if replacement.get_surface_count()!=previous_surfaces+1:push_error("Invalid prepared surface in "+id);quit(1);return
				replacement.surface_set_material(replacement.get_surface_count()-1,mat);triangle_count+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
			node.mesh=replacement;node.material_override=null
		var box=bounds(root_model,Transform3D.IDENTITY);var packed=PackedScene.new();packed.pack(root_model)
		var target=output.path_join(id+".scn");error=ResourceSaver.save(packed,target,ResourceSaver.FLAG_COMPRESS)
		if error!=OK:push_error("Could not save "+target);quit(1);return
		records[id]={"path":target,"source_name":record.name,"source_sha256":record.sha256,"original_triangles":record.triangles,"triangles":triangle_count,"texture_gpu_bytes":texture_bytes,"bytes":FileAccess.get_file_as_bytes(target).size(),"bounds":{"min":[box.position.x,box.position.y,box.position.z],"size":[box.size.x,box.size.y,box.size.z]},"orientation_degrees":[0,0,0],"lod_candidates":lod_note}
		print(id+": "+str(triangle_count)+" triangles, "+str(texture_bytes)+" texture bytes, saved "+str(records[id].bytes));root_model.free();await process_frame
	if FileAccess.file_exists(qa.path_join("poses.json")):
		var poses=JSON.parse_string(FileAccess.get_file_as_string(qa.path_join("poses.json")))
		for id in poses:
			if records.has(id):records[id].merge(poses[id],true)
	if records.has("room") and FileAccess.file_exists(qa.path_join("room-reduction.json")):records.room.projection=JSON.parse_string(FileAccess.get_file_as_string(qa.path_join("room-reduction.json"))).projection
	if records.has("kit_beam"):
		# The authored beam runs along X; posts must run along Y before fitting.
		var rotation=Basis(Vector3.FORWARD,PI/2.)
		var record=records.kit_beam;var box=AABB(Hearth20GeneratedModels.vector(record.bounds.min),Hearth20GeneratedModels.vector(record.bounds.size));box=Transform3D(rotation,Vector3.ZERO)*box
		record.orientation_basis=[[rotation.x.x,rotation.x.y,rotation.x.z],[rotation.y.x,rotation.y.y,rotation.y.z],[rotation.z.x,rotation.z.y,rotation.z.z]]
		record.oriented_bounds={"min":[box.position.x,box.position.y,box.position.z],"size":[box.size.x,box.size.y,box.size.z]}
	var preparation={"originals_modified":false,"room":"pixel-grid reduction, original image and UV mapping","prop_cleanup":JSON.parse_string(FileAccess.get_file_as_string(qa.path_join("prop-cleanup.json")))}
	FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify({"version":1,"models":records,"preparation":preparation},"  "))
	print("Prepared "+str(records.size())+" runtime scenes; originals retained.");quit()
