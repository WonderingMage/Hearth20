extends SceneTree
var app: Hearth20App
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error("FAIL: "+message)
func capture(window: Window, filename: String) -> void:
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(filename+".png"))
func run() -> void:
	root.size=Vector2i(1440,900)
	var maps:=Hearth20MapLibrary.catalog()
	expect(maps.size()==15,"exactly fifteen sample maps are embedded")
	var ids: Array=[]
	var hashes: Array=[]
	var sources: Array=[]
	var campaign:=Hearth20Identity.new_campaign("Library persistence fixture")
	var original_id:=str(campaign.active_scene)
	campaign.actors=[{"id":"library-hero","name":"Demo adventurer","is_hero":true,"scene_id":original_id,"position":Vector2(2,2),"owner_player_id":"player-test","abilities":[10,10,10,10,10,10],"notes":"Private retained note","vision":{"enabled":true,"darkvision_feet":60,"bright_light_feet":0,"dim_light_feet":0}}]
	for record in maps:
		var id:=str(record.id)
		expect(not id in ids,"unique library id: "+id); ids.append(id)
		var scene:=Hearth20MapLibrary.scene(id)
		expect(not scene.is_empty() and Hearth20Contracts.valid_scene(scene),"valid editable geometry: "+id)
		if scene.is_empty(): continue
		expect(scene.dynamic_lighting and scene.ambient_light=="dark" and scene.annotations.any(func(o): return o.kind=="light"),"prepared lighting: "+id)
		var art:=Hearth20MapLibrary.texture(id,false)
		var thumb:=Hearth20MapLibrary.texture(id)
		expect(art!=null and art.get_size()==Vector2(2048,1536) and thumb!=null and thumb.get_size()==Vector2(384,288),"full artwork and thumbnail packaged: "+id)
		var hash:=art.get_image().save_png_to_buffer().hex_encode().sha256_text()
		expect(not hash in hashes,"distinct map artwork: "+id); hashes.append(hash)
		for kind in record.source_types:
			if not kind in sources: sources.append(kind)
		for p in scene.library_entry: expect(Hearth20Contracts._point_inside_scene(Vector2(p.x,p.y),scene),"bounded party entry: "+id)
		var added:=Hearth20MapLibrary.add_to_campaign(campaign,id,false)
		expect(added.ok,"map adds without replacing campaign content: "+id)
	expect(campaign.scenes.size()==16 and campaign.actors[0].scene_id==original_id and campaign.actors[0].notes=="Private retained note","all maps coexist and unchecked party stays in original scene")
	expect(sources.size()==6,"collection demonstrates all six source styles")
	expect(not Hearth20MapLibrary.add_to_campaign(campaign,"../project",true).ok,"catalog rejects arbitrary paths")
	var save_path: String=Hearth20Identity.SAVE_ROOT.path_join("sample-library-roundtrip.h20campaign")
	var saved:=Hearth20Identity.save_campaign(campaign,save_path)
	var restored:=Hearth20Identity.load_campaign(save_path)
	expect(saved.ok and restored.ok and restored.campaign.scenes.size()==16 and restored.campaign.assets.size()==17,"all sample art and foreground geometry round trip inside a self-contained campaign")
	lighting_checks()
	visibility_mask_checks()
	app=load("res://hearth20_main.tscn").instantiate(); root.add_child(app)
	await create_timer(0.2).timeout
	var old_scene:=str(app.campaign.active_scene)
	var library:=app._open_map_library()
	await create_timer(0.2).timeout
	expect(library!=null and library.cards.get_child_count()==15,"native gallery presents all fifteen maps")
	var contact:=Image.create(1536,1152,false,Image.FORMAT_RGBA8)
	contact.fill(Color("#0b1018"))
	var tile_index:=0
	for record in maps:
		library.select_map(str(record.id))
		await process_frame
		await RenderingServer.frame_post_draw
		var tile:=library.get_texture().get_image().get_region(Rect2i(library.preview.get_global_rect()))
		tile.resize(384,288,Image.INTERPOLATE_LANCZOS)
		contact.blit_rect(tile,Rect2i(0,0,384,288),Vector2i((tile_index%4)*384,(tile_index/4)*288))
		tile_index+=1
	contact.save_png(OS.get_environment("H20_QA_EVIDENCE").path_join("sample-lighting-contact-sheet.png"))
	library.select_map("sunspire-sanctum")
	await capture(library,"sample-library-gallery")
	library.search.text="crypt"; library.search.text_changed.emit("crypt")
	expect(library.cards.get_child_count()==1,"gallery search filters to matching map")
	library.search.text=""; library.search.text_changed.emit("")
	library.categories.select(2); library.categories.item_selected.emit(2)
	expect(library.cards.get_child_count()==3,"category filter lists three wilderness maps")
	library.categories.select(0); library.categories.item_selected.emit(0)
	library.move_party.button_pressed=false
	library.select_map("sunspire-sanctum")
	library.add_button.pressed.emit()
	await create_timer(0.3).timeout
	expect(app.campaign.scenes.size()==2 and app.board.current_scene().library_id=="sunspire-sanctum","gallery action loads chosen map into the real application")
	app.board.fit_map()
	await capture(root,"sample-sunspire-lighting")
	var hero_id: String=app.board.add_token("Darkvision 60 ft",true,Vector2(14,17.5))
	var hero:=Hearth20Contracts.find_actor(app.campaign,hero_id)
	hero.owner_player_id="preview-player"; hero.vision={"enabled":true,"darkvision_feet":60,"bright_light_feet":0,"dim_light_feet":0}
	expect(app._load_sample_map("ashen-cellblock",true).ok,"jail loads and moves party to prepared entry")
	expect(Hearth20Contracts.find_actor(app.campaign,hero_id).scene_id==app.campaign.active_scene,"party hero moves with selected map")
	app.board.fit_map()
	await capture(root,"sample-jail-dm")
	app.board.set_role("player")
	var active: Dictionary=app.board.current_scene() if app.board.role=="dm" else Hearth20Contracts.find_scene(app.campaign,str(app.campaign.active_scene))
	app.board.set_player_snapshot(Hearth20Contracts.project_for_player(app.campaign,"preview-player",Hearth20Assets.read_asset(app.campaign,str(active.map_asset),"map")))
	app.board.fit_map()
	await capture(root,"sample-jail-player-darkvision")
	app.board.set_role("dm")
	expect(app._switch_library_scene(old_scene,false).ok and app.board.current_actors().is_empty(),"scene switch preserves off-scene tokens and filters canvas")
	app.session.local_role="player"
	expect(not app.session.load_sample_map("echoing-caverns").ok and not app.session.switch_library_scene(old_scene).ok,"players cannot load or switch campaign scenes")
	expect(app._open_map_library()==null,"player cannot open the DM library")
	print("Sample library: %d assertions, %d failures."%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func lighting_checks() -> void:
	var c:=Hearth20Identity.new_campaign()
	var s: Dictionary=c.scenes[0]
	s.dynamic_lighting=true; s.ambient_light="dark"
	s.width_cells=16; s.height_cells=12
	s.annotations=[{"id":"window-source","owner":"dm-local","kind":"light","layer":"light","points":[Vector2(2,6)],"bright":40,"dim":10,"source_type":"window","light_color":"#ffeeaa","angle_degrees":0,"spread_degrees":60,"ray_strength":0.9}]
	c.actors=[{"id":"viewer","name":"Viewer","is_hero":true,"scene_id":s.id,"owner_player_id":"viewer","position":Vector2(3,6),"vision":{"enabled":true,"darkvision_feet":60,"bright_light_feet":0,"dim_light_feet":0}}]
	var view:=Hearth20Vision.build_view(c,"viewer",s)
	expect(Hearth20Vision.level_at(Vector2(6,6),view)==3 and Hearth20Vision.level_at(Vector2(1,6),view)==1,"window light illuminates its direction; darkvision behind stays gray")
	var meshes:=Hearth20Lighting.meshes(view)
	expect(not meshes.is_empty() and meshes.all(func(m): return Array(m.points).all(func(p): return p.x>=1.99)),"directional god rays stay within their source cone")
	s.doors=[{"id":"door","a":Vector2(5,0),"b":Vector2(5,12),"open":false}]
	view=Hearth20Vision.build_view(c,"viewer",s)
	expect(not Hearth20Vision.visible(Vector2(7,6),view),"closed door blocks player sight and light")
	meshes=Hearth20Lighting.meshes(view)
	expect(meshes.all(func(m): return Array(m.points).all(func(p): return p.x<=5.001)),"ray geometry terminates at closed door")
	s.doors[0].open=true
	view=Hearth20Vision.build_view(c,"viewer",s)
	expect(Hearth20Vision.level_at(Vector2(7,6),view)==3 and Hearth20Lighting.meshes(view).any(func(m): return Array(m.points).any(func(p): return p.x>6)),"opening door reveals continued light shafts")
	s.fog_rects=[Rect2(6,0,4,12)]
	view=Hearth20Vision.build_view(c,"viewer",s)
	var projected:=Hearth20Lighting.project(view)
	expect(not projected.is_empty() and projected.all(func(m): return Array(m.points).all(func(p): return not Rect2(6.001,0,3.998,12).has_point(p))),"player light polygons are clipped out of hidden fog")
	expect(projected.all(func(m): return m.keys().all(func(k): return k in ["points","alpha","color","type"])),"light packets contain authorized polygons without private emitter origin or identity")
	var encoded:=Hearth20Lighting.project_field(view)
	var field:=Hearth20Lighting.read_field(encoded)
	expect(field!=null and encoded.keys().all(func(k): return k in ["width","height","codec","data"]),"compact light packets carry only authorized sampled radiance")
	var hidden_clean:=true
	for y in field.get_height():
		for x in range(6*16,10*16):
			if field.get_pixel(x,y)!=Color(0,0,0,1): hidden_clean=false
	expect(hidden_clean,"compressed player light field contains no samples from concealed fog")
	s.blackout=true
	expect(Hearth20Lighting.project(Hearth20Vision.build_view(c,"viewer",s)).is_empty(),"blackout removes all light visuals")
	s.blackout=false; s.annotations=[]; s.fog_rects=[]
	view=Hearth20Vision.build_view(c,"viewer",s)
	expect(Hearth20Vision.level_at(Vector2(6,6),view)==1 and Hearth20Lighting.meshes(view).is_empty(),"darkvision reveals gray detail without creating a light source")
	expect(not Hearth20Lighting.valid_source({"spread_degrees":INF}) and not Hearth20Lighting.valid_source({"ray_strength":2}),"source settings reject nonfinite or excessive values")

func visibility_mask_checks() -> void:
	# Compare complete authorized cells against the independent convex sight
	# region test, including short walls, grazing grid lines and diagonals.
	var layouts: Array=[[[Vector2(3,0),Vector2(3,6)]],[[Vector2(2.81,2.13),Vector2(2.88,2.18)]],[[Vector2(2,1),Vector2(5,4.5)]],[[Vector2(2,1),Vector2(5,1)],[Vector2(5,1),Vector2(5,5)],[Vector2(2,5),Vector2(5,5)]]]
	var safe:=true
	var tested:=0
	for walls in layouts:
		var context: Dictionary={"width":8,"height":6,"subdivisions":4,"columns":32,"rows":24,"segments":walls}
		for origin in [Vector2(.75,.75),Vector2(6.125,3.375),Vector2(2.5,3.5)]:
			var mask:=Hearth20Vision._sight_mask(origin,context)
			for y in 24:
				for x in 32:
					if mask[y*32+x]==0: continue
					tested+=1
					if not Hearth20Vision.clear_area(origin,Rect2(Vector2(x,y)/4.0,Vector2.ONE/4.0),context):
						safe=false
						print("Unsafe cached cell ",origin," ",Vector2(x,y)," barriers ",walls)
	expect(safe and tested>1000,"cached visibility never discloses a block crossing an opaque sight region")
