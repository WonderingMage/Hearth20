extends SceneTree
var checks=0
var errors=[]
var output=""
func _initialize() -> void:
	output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func geometry_bounds(node: Node3D,parent=Transform3D.IDENTITY) -> AABB:
	var transform=parent*node.transform;var box=AABB();var started=false
	if node is MeshInstance3D:
		for s in node.mesh.get_surface_count():
			var a=node.mesh.surface_get_arrays(s)
			for vertex in a[Mesh.ARRAY_VERTEX]:
				var p=transform*vertex
				if not started:box=AABB(p,Vector3.ZERO);started=true
				else:box=box.expand(p)
	for child in node.get_children():
		if child is Node3D:
			var next=geometry_bounds(child,transform)
			if next.size.length_squared()>0.:box=box.merge(next) if started else next;started=true
	return box
func run() -> void:
	await Hearth20GeneratedModels.prepare(self)
	var models=Hearth20GeneratedModels.catalog
	expect(models.size()==39,"all 36 delivered GLBs and three kits have runtime records")
	expect(Hearth20GeneratedModels.cache.size()==Hearth20GeneratedModels.ACTIVE.size(),"every active replacement loads behind the loader")
	expect(not Hearth20GeneratedModels.available("map_paper"),"rejected paper model is not preloaded")
	var total=0;var gpu=0
	for id in models:
		var record=models[id];total+=int(record.triangles);gpu+=int(record.texture_gpu_bytes)
		var scene=load(record.path) as PackedScene
		expect(scene!=null,"loadable scene: "+id)
		var instance=scene.instantiate();var triangles=0
		expect(instance.find_children("*","AnimationPlayer",true,false).is_empty(),"static replacement has no unwanted animation process: "+id)
		for mesh in instance.find_children("*","MeshInstance3D",true,false):
			expect(mesh.mesh!=null and mesh.mesh.get_surface_count()>0,"nonempty prepared mesh: "+id)
			for s in mesh.mesh.get_surface_count():
				var a=mesh.mesh.surface_get_arrays(s);var vertices=a[Mesh.ARRAY_VERTEX];var indices=a[Mesh.ARRAY_INDEX]
				triangles+=(indices.size() if indices!=null and not indices.is_empty() else vertices.size())/3
				expect(a[Mesh.ARRAY_TEX_UV]!=null and a[Mesh.ARRAY_TEX_UV].size()==vertices.size(),"UV mapping survives optimization: "+id)
				var material=mesh.get_active_material(s)
				expect(material is StandardMaterial3D,"PBR material retained: "+id)
				for slot in [BaseMaterial3D.TEXTURE_ALBEDO,BaseMaterial3D.TEXTURE_NORMAL,BaseMaterial3D.TEXTURE_ROUGHNESS]:
					var texture=material.get_texture(slot)
					if texture==null:continue
					var image=texture.get_image()
					expect(image.is_compressed() and image.has_mipmaps() and maxi(image.get_width(),image.get_height())<=2048,"bounded compressed mipmapped texture: "+id)
		expect(triangles==int(record.triangles),"manifest matches actual triangle count: "+id);instance.free()
		# The floor kit supplies only a texture and planar sample, never a fitted prop.
		if Hearth20GeneratedModels.available(id) and id!="kit_floor":
			var fitted=Hearth20GeneratedModels.make(id,Vector3(2,1,.7));var bounds=geometry_bounds(fitted)
			expect(bounds.size.distance_to(Vector3(2,1,.7))<.004,"fitted geometry has expected dimensions: "+id)
			expect(absf(bounds.position.y)<.003 and absf(bounds.get_center().x)<.003 and absf(bounds.get_center().z)<.003,"bottom-center pivot is usable: "+id);fitted.free()
		if record.has("base_alignment"):
			var normal=Hearth20GeneratedModels.vector(record.base_alignment.normal)
			expect(normal.dot(Vector3.UP)>cos(deg_to_rad(1.)),"measured contact plane sits level within one degree: "+id)
			var axes=record.orientation_basis;var rotation=Basis(Hearth20GeneratedModels.vector(axes[0]),Hearth20GeneratedModels.vector(axes[1]),Hearth20GeneratedModels.vector(axes[2]))
			expect(absf(rotation.determinant()-1.)<.0001 and rotation.is_equal_approx(rotation.orthonormalized()),"leveling preserves a rigid rotation without shear or mirroring: "+id)
	expect(total<500000,"complete library fits under 500k triangles")
	expect(gpu<170*1048576,"complete prepared catalog texture storage stays under 170 MiB")
	expect(int(models.room.triangles)<300000 and int(models.room.original_triangles)>4500000,"room reduction retains less than seven percent of source triangles")
	expect(int(models.table.triangles)<=60000,"main table reduced to under 60k triangles")
	expect(FileAccess.file_exists("res://hearth20/generated_models/CREDITS.md"),"CC BY source credits bundled")
	var result={"checks":checks,"errors":errors,"triangles":total,"declared_texture_bytes":gpu,"active_models":Hearth20GeneratedModels.ACTIVE.size()}
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("Generated models: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)
