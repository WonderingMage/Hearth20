extends RefCounted
class_name Hearth20ModelImport
## Authoring-only bounded glTF import. Downloaded scenes never supply scripts.
const MAX_BYTES:=256*1024*1024
const FLESH_SHADER:="""
shader_type spatial;
render_mode cull_disabled;
varying vec3 flesh_position;
float hash3(vec3 p){p=fract(p*0.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float noise3(vec3 p){vec3 a=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash3(a),hash3(a+vec3(1,0,0)),f.x),mix(hash3(a+vec3(0,1,0)),hash3(a+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(a+vec3(0,0,1)),hash3(a+vec3(1,0,1)),f.x),mix(hash3(a+vec3(0,1,1)),hash3(a+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){flesh_position=VERTEX;}
void fragment(){
 vec3 p=flesh_position;
 float mottling=noise3(p*8.0)*.65+noise3(p*21.0)*.25+noise3(p*63.0)*.1;
 float vessel=1.0-smoothstep(.016,.065,abs(noise3(p*17.0+noise3(p*7.0))-.48));
 float grain=noise3(p*350.0);
 vec3 skin=mix(vec3(.16,.027,.046),vec3(.61,.28,.24),smoothstep(.16,.86,mottling));
 skin=mix(skin,vec3(.12,.035,.073),vessel*.37);
 ALBEDO=skin*(.91+grain*.14); ROUGHNESS=.28+grain*.18; SPECULAR=.52;
 METALLIC=0.0; CLEARCOAT=.42; CLEARCOAT_ROUGHNESS=.27;
}
"""
var source_root:=""
var model_dir:=""
var binary_chunks: Array=[]
var buffer_data: Array=[]
var failure:=""
var nodes:=0
var meshes:=0
var triangles:=0
var animation_players:=0
var texture_pixels:=0
var texture_pixel_budget:=67108864
func fail(message: String) -> Dictionary:
	failure=message; return {"ok":false,"error":message}
func read_uri(uri: String) -> PackedByteArray:
	if uri.begins_with("data:"):
		if not uri.contains(";base64,") or uri.length()>MAX_BYTES*1.4: failure="Embedded data URI exceeds the supported limit."; return PackedByteArray()
		return Marshalls.base64_to_raw(uri.get_slice(",",1))
	var decoded:=uri.uri_decode().replace("\\","/")
	if decoded.contains(":") or decoded.begins_with("/"): failure="Model references must stay inside their archive."; return PackedByteArray()
	var path:=model_dir.path_join(decoded).simplify_path()
	if not path.to_lower().begins_with(source_root.to_lower()+"/") or not FileAccess.file_exists(path): failure="A model buffer or texture is missing from the archive."; return PackedByteArray()
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>MAX_BYTES: failure="A model dependency exceeds 256 MiB."; return PackedByteArray()
	return file.get_buffer(file.get_length())
func scan_uris(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if str(key)=="uri":
				if not value[key] is String: return false
				var uri: String=value[key]
				if uri.begins_with("data:"): continue
				var decoded:=uri.uri_decode().replace("\\","/")
				if decoded.contains(":") or decoded.begins_with("/") or not model_dir.path_join(decoded).simplify_path().to_lower().begins_with(source_root.to_lower()+"/"): return false
			elif not scan_uris(value[key]): return false
	elif value is Array:
		for item in value:
			if not scan_uris(item): return false
	return true
func validate_source(path: String, root_dir: String) -> Dictionary:
	source_root=root_dir.replace("\\","/").trim_suffix("/"); model_dir=path.get_base_dir().replace("\\","/")
	var bytes:=FileAccess.get_file_as_bytes(path)
	if bytes.is_empty() or bytes.size()>MAX_BYTES: return fail("Model file is empty or exceeds 256 MiB.")
	var json_text:=""
	if path.get_extension().to_lower()=="glb":
		if bytes.size()<20 or bytes.decode_u32(0)!=0x46546c67 or bytes.decode_u32(4)!=2 or bytes.decode_u32(8)!=bytes.size(): return fail("Invalid glTF 2 binary header.")
		var offset:=12
		while offset+8<=bytes.size():
			var length:=int(bytes.decode_u32(offset)); var type:=int(bytes.decode_u32(offset+4)); offset+=8
			if length<0 or length%4!=0 or offset+length>bytes.size(): return fail("Invalid binary glTF chunk length.")
			if type==0x4e4f534a:
				if not json_text.is_empty() or offset!=20: return fail("Binary glTF must have one leading JSON chunk.")
				json_text=bytes.slice(offset,offset+length).get_string_from_utf8()
			elif type==0x004e4942:
				if binary_chunks.size()>0 or json_text.is_empty(): return fail("Invalid binary glTF buffer order.")
				binary_chunks.append(bytes.slice(offset,offset+length))
			offset+=length
		if offset!=bytes.size(): return fail("Invalid trailing glTF data.")
	else: json_text=bytes.get_string_from_utf8()
	if json_text.length()>8*1024*1024: return fail("Model description exceeds 8 MiB.")
	var data: Variant=JSON.parse_string(json_text)
	if not data is Dictionary or not data.get("asset") is Dictionary or str(data.asset.get("version",""))!="2.0": return fail("Choose a glTF 2 model.")
	if not scan_uris(data): return fail("External URLs and paths outside the archive are not supported.")
	for field in ["nodes","meshes","materials","accessors","bufferViews","animations","images","buffers"]:
		if not data.get(field,[]) is Array or data.get(field,[]).size()>(16384 if field=="accessors" else 4096): return fail("Model structure exceeds supported bounds.")
	var total_bytes:=0
	for record in data.get("buffers",[]):
		if not record is Dictionary or not Hearth20Contracts._integer_number(record.get("byteLength")): return fail("Invalid model buffer.")
		var size:=int(record.byteLength); total_bytes+=size
		if size<0 or total_bytes>MAX_BYTES: return fail("Model buffers exceed 256 MiB.")
		var buffer: PackedByteArray=read_uri(str(record.uri)) if record.has("uri") else (binary_chunks[0] if not binary_chunks.is_empty() else PackedByteArray())
		if not failure.is_empty() or buffer.size()<size: return fail(failure if not failure.is_empty() else "A model buffer is truncated.")
		buffer_data.append(buffer)
	for accessor in data.get("accessors",[]):
		if not accessor is Dictionary or not Hearth20Contracts._integer_number(accessor.get("count")) or int(accessor.count)<0 or int(accessor.count)>6000000: return fail("Geometry accessor exceeds its supported range.")
	for image in data.get("images",[]):
		if not image is Dictionary: return fail("Invalid model image record.")
		var image_bytes:=PackedByteArray()
		if image.has("uri"): image_bytes=read_uri(str(image.uri))
		elif image.has("bufferView"):
			var index:=int(image.bufferView)
			if index<0 or index>=data.get("bufferViews",[]).size(): return fail("Invalid image buffer view.")
			var view: Dictionary=data.bufferViews[index]; var buffer_index:=int(view.get("buffer",-1)); var begin:=int(view.get("byteOffset",0)); var length:=int(view.get("byteLength",0))
			if buffer_index<0 or buffer_index>=buffer_data.size() or begin<0 or length<0 or begin+length>buffer_data[buffer_index].size(): return fail("Invalid embedded image bounds.")
			image_bytes=buffer_data[buffer_index].slice(begin,begin+length)
		var dimensions:=Hearth20Assets._map_dimensions_from_header(image_bytes)
		if dimensions==Vector2i.ZERO: dimensions=Hearth20Assets._webp_dimensions(image_bytes)
		if dimensions.x<=0 or dimensions.y<=0 or dimensions.x>8192 or dimensions.y>8192: return fail("Use PNG, JPEG or WebP textures up to 8,192 pixels per side.")
		texture_pixels+=dimensions.x*dimensions.y
		if texture_pixels>clampi(texture_pixel_budget,67108864,134217728): return fail("Combined model textures exceed the selected bounded texture budget.")
	return {"ok":true}
func clean_tree(node: Node, owner_root: Node) -> bool:
	nodes+=1
	if nodes>4096 or node.get_script()!=null: failure="Imported scenes must contain bounded model data only."; return false
	if node is Camera3D or node is Light3D:
		node.get_parent().remove_child(node); node.free(); return true
	if not node is Node3D and not node is AnimationPlayer: failure="Unsupported model node type: "+node.get_class(); return false
	if node!=owner_root: node.owner=owner_root
	if node is MeshInstance3D and node.mesh!=null:
		meshes+=1
		for surface in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var index_data: Variant=arrays[Mesh.ARRAY_INDEX]
			triangles+=(index_data.size() if index_data is PackedInt32Array and not index_data.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
		if triangles>2000000 or meshes>1024: failure="Model exceeds two million triangles or 1,024 meshes."; return false
	if node is AnimationPlayer:
		animation_players+=1
		var chosen:=""
		for animation_name in node.get_animation_list():
			if chosen.is_empty() and str(animation_name)!="RESET": chosen=animation_name
			var animation: Animation=node.get_animation(animation_name)
			for track in animation.get_track_count():
				if animation.track_get_type(track) not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D,Animation.TYPE_BLEND_SHAPE]: failure="Imported animation contains unsupported tracks."; return false
			if "idle" in str(animation_name).to_lower() and (not "idle" in chosen.to_lower() or str(animation_name).length()<chosen.length()): chosen=animation_name
		if not chosen.is_empty():
			node.get_animation(chosen).loop_mode=Animation.LOOP_LINEAR; node.autoplay=chosen
	for child in node.get_children():
		if not clean_tree(child,owner_root): return false
	return true
func import_model(path: String, root_dir: String, destination: String, color_profile: String="") -> Dictionary:
	var checked:=validate_source(path,root_dir)
	if not checked.ok: return checked
	var document:=GLTFDocument.new(); var state:=GLTFState.new()
	if document.append_from_file(path,state)!=OK: return fail("Godot could not read the model. Keep all buffers and textures in the ZIP.")
	var model: Node=document.generate_scene(state)
	if not model is Node3D:
		if model!=null: model.free()
		return fail("Model has no 3D scene.")
	if not clean_tree(model,model) or meshes==0:
		model.free(); return fail(failure if not failure.is_empty() else "The model contains no meshes.")
	if color_profile=="gibbering-flesh":
		var shader:=Shader.new(); shader.code=FLESH_SHADER
		var material:=ShaderMaterial.new(); material.shader=shader
		for mesh_node in model.find_children("*","MeshInstance3D",true,false): mesh_node.material_override=material
	var packed:=PackedScene.new(); var result:=packed.pack(model)
	if result==OK: result=ResourceSaver.save(packed,destination,ResourceSaver.FLAG_BUNDLE_RESOURCES|ResourceSaver.FLAG_COMPRESS)
	model.free()
	if result!=OK: return fail("Could not save the self-contained replacement model.")
	return {"ok":true,"meshes":meshes,"triangles":triangles,"animations":animation_players,"texture_pixels":texture_pixels,"color_profile":color_profile}
