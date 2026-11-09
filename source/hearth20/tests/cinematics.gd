extends SceneTree
var checks:=0
var errors: Array=[]
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks+=1
	if not ok: errors.append(note); push_error("FAIL: "+note)
func capture(window: Window, filename: String) -> void:
	await create_timer(.18).timeout; await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(filename+".png"))
func wait_dice(stage: Hearth20DiceStage) -> void:
	var deadline:=Time.get_ticks_msec()+18000
	while stage.preparing and Time.get_ticks_msec()<deadline: await process_frame
	expect(not stage.preparing,"selected dice load asynchronously before animation")
func run() -> void:
	root.size=Vector2i(1440,900)
	for sides in [4,6,8,10,12,20]: expect(Hearth20DiceModel.shape(sides).size()==sides,"actual polyhedron face count for d%d"%sides)
	var app: Hearth20App=load("res://hearth20_main.tscn").instantiate(); root.add_child(app); await process_frame
	app._load_sample_map("sunspire-sanctum",false)
	var saved_set:=Hearth20PlayerProfile.dice_set()
	Hearth20PlayerProfile.remember_dice_set("set-7"); Hearth20PlayerProfile.remember("Remembered adventurer","localhost",28930)
	expect(Hearth20PlayerProfile.dice_set()=="set-7" and Hearth20PlayerProfile.preferences().display_name=="Remembered adventurer","dice choice and join preferences preserve one another")
	Hearth20PlayerProfile.remember_dice_set("res://private.scn"); expect(Hearth20PlayerProfile.dice_set()=="set-7","arbitrary model paths cannot become a dice preference")
	for id in Hearth20DiceSets.NAMES:
		Hearth20DiceSets.request(id); var deadline:=Time.get_ticks_msec()+18000
		while not Hearth20DiceSets.ready(id) and Time.get_ticks_msec()<deadline: Hearth20DiceSets.poll(); await process_frame
		expect(Hearth20DiceSets.cache.has(id),"bundled collection cold-loads: "+id)
		for sides in [4,6,8,10,12,20]:
			var die:=Hearth20DiceSets.make(id,sides,sides); var calibrated: Dictionary=die.get_child(0).get_meta("value_axes",{})
			expect(die.get_meta("dice_set","")==id and calibrated.size()==sides and calibrated.has(1) and calibrated.has(sides) and die.get_meta("result_normal").length()>.99,"imported mesh and all calibrated values: %s d%d"%[id,sides]); die.free()
		expect(Hearth20DiceSets.cache.size()<=2,"resident collection cache is bounded")
	var picker:=Hearth20DiceSetsWindow.new(); app.add_child(picker); picker.setup(app.session)
	await create_timer(.4).timeout; await capture(picker,"dm-supplied-dice-collection"); expect(picker.chosen=="dm" and picker.buttons.size()==1,"DM picker uses the mandated supplied set"); picker.queue_free()
	var player_picker_session:=Hearth20Session.new(); root.add_child(player_picker_session); player_picker_session.local_role="player"
	var player_picker:=Hearth20DiceSetsWindow.new(); app.add_child(player_picker); player_picker.setup(player_picker_session); player_picker.select_set("set-7")
	await create_timer(.4).timeout; await capture(player_picker,"seven-player-dice-collections"); expect(player_picker.buttons.size()==7 and player_picker.chosen=="set-7","player can browse all seven supplied collections"); player_picker.queue_free(); player_picker_session.queue_free()
	Hearth20PlayerProfile.remember_dice_set(saved_set)
	var stage: Hearth20DiceStage=app.dice_stage
	expect(app.session.submit_roll("","dice","","advantage","public","1d20+5").ok,"public advantage creates an authoritative roll")
	await wait_dice(stage)
	expect(stage.pieces.size()==2 and stage.pieces.all(func(piece): return piece.node.get_meta("face_count")==20),"both d20s animate as real twenty-faced meshes")
	var entry: Dictionary=app.campaign.table_timeline.back()
	expect(entry.dice_set=="dm" and stage.pieces.all(func(piece): return piece.node.get_meta("dice_set","")=="dm"),"DM public rolls use the supplied sculpted-number set")
	expect(stage.pieces.map(func(piece): return piece.node.get_meta("result_value"))==entry.dice,"3D dice use the exact host-recorded individual values")
	await capture(root,"three-dimensional-d20-roll-in-motion")
	stage.age=3; await create_timer(.15).timeout
	expect(stage.pieces.all(func(piece): return (piece.node.quaternion*piece.node.get_meta("result_normal")).dot(stage.camera.global_basis.z)>.999),"each recorded result face settles toward the viewing camera")
	expect(stage.pieces.all(func(piece): return (piece.node.quaternion*piece.node.get_meta("result_basis").y).dot(stage.camera.global_basis.y)>.999),"settled printed numerals are upright on screen, including calibrated imported meshes")
	expect(str(entry.total) in stage.result_label.text,"settled total matches the recorded modifier and kept die")
	await capture(root,"two-d20-advantage-settled")
	stage.enqueue(entry); expect(stage.queue.is_empty(),"duplicate live packets cannot replay a roll")
	stage.clear_rolls(); app.session.timeline_changed.emit([entry]); expect(stage.active_entry.is_empty(),"saved or replayed chat history does not animate dice")
	var invalid:=entry.duplicate(true); invalid.dice=[1001]; stage.enqueue(invalid); expect(stage.active_entry.is_empty(),"out-of-range animation values are rejected")
	for sides in [4,6,8,10,12,20,100]:
		var roll: Dictionary={"id":"showcase-d%d"%sides,"type":"roll","sender":"Polyhedral showcase","visibility":"public","formula":"1d%d"%sides,"dice":[sides],"kept":sides,"modifier":0,"total":sides,"mode":"normal"}
		roll.dice_set="dm"; stage.enqueue(roll); await wait_dice(stage); stage.age=3; await create_timer(.1).timeout
		expect(stage.pieces.size()==(2 if sides==100 else 1),"standard dice presentation d%d"%sides)
		await capture(root,"three-dimensional-d%d"%sides)
		if sides==10:
			var rendered:=stage.viewport.get_texture().get_image(); rendered.resize(360,225); var amber_pixels:=0
			for y in rendered.get_height():
				for x in rendered.get_width():
					var pixel:=rendered.get_pixel(x,y)
					if pixel.a>.6 and pixel.r>.8 and pixel.g>.35 and pixel.b<.6: amber_pixels+=1
			expect(amber_pixels>20,"ordinary DM d10 has clearly rendered amber numeral geometry")
		stage.clear_rolls()
	var malformed:=entry.duplicate(true); malformed.id="bad-total"; malformed.total+=1; expect(not Hearth20DiceStage.valid_entry(malformed),"animation total must agree with actual dice and modifier")
	malformed=entry.duplicate(true); malformed.dice_set="res://arbitrary.scn"; expect(not Hearth20DiceStage.valid_entry(malformed),"animation model references use only the bundled allowlist")
	var window:=Window.new(); window.size=Vector2i(600,600); window.title="Cinematic material study"; root.add_child(window)
	var background:=ColorRect.new(); background.color=Color("#444038"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.add_child(background)
	var fx:=Hearth20FxRenderer.new(); window.add_child(fx); fx.world_scale=90; fx.scene={"id":"study","width_cells":7,"height_cells":7,"walls":[{"a":Vector2(4.7,0),"b":Vector2(4.7,7)}]}; window.popup_centered()
	var hashes: Array=[]
	for material_name in Hearth20BoardTools.COLORS:
		fx.clear_all(); var event: Dictionary=app.session.make_effect({"effect":"burn" if material_name=="Fire" else "shield" if material_name=="Holy" else "explode","material":material_name,"color":Hearth20BoardTools.COLORS[material_name],"size":1.2,"duration":6,"density":80},Vector2(3,3.5),Vector2(3,3.5)); event.started_usec=Time.get_ticks_usec()-900000; fx.add_authorized_event(event)
		await create_timer(.25).timeout; await RenderingServer.frame_post_draw
		expect(fx.cinematic.actors.size()==1,"true spatial actor created for "+material_name)
		var actor: Hearth20FxActor3D=fx.cinematic.actors.values()[0]
		expect(actor.cloud.multimesh.instance_count>=200,"dense instanced 3D material geometry: "+material_name)
		var image:=fx.cinematic.viewport.get_texture().get_image(); hashes.append(Hearth20Contracts.sha256(image.get_data()))
		if material_name=="Fire":
			expect(actor.volume!=null and actor.volume.material_override is ShaderMaterial,"fire uses a ray-marched spatial volume")
			expect(not fx.transient_light.polygons.is_empty(),"fire casts transient light onto the board")
			var polygon: Polygon2D=fx.transient_light.polygons.values()[0]
			expect(Array(polygon.polygon).all(func(point): return point.x<=4.7*90+.1),"transient radiance stops at a wall")
		elif material_name=="Death": expect(actor.darkness>.5 and not fx.transient_light.polygons.is_empty(),"death absorbs board light instead of emitting it")
		var rendered:=window.get_texture().get_image()
		if material_name=="Fire": expect(rendered.get_pixel(385,315).r>.30,"fire actually raises the board's red radiance outside its geometry")
		elif material_name=="Death": expect(rendered.get_pixel(375,315).r<.24,"death actually darkens the board outside its geometry")
		if material_name in ["Fire","Death"]: expect(rendered.get_pixel(500,315).r>.25 and rendered.get_pixel(500,315).r<.29,"wall blocks transient lighting and absorption")
		await capture(window,"cinematic-3d-"+material_name.to_lower())
		var before:=actor.cloud.multimesh.get_instance_transform(0); await create_timer(.18).timeout
		expect(before!=actor.cloud.multimesh.get_instance_transform(0),"material geometry animates in three dimensions: "+material_name)
	expect(hashes.all(func(value): return hashes.count(value)==1),"all eleven spatial material renders differ")
	fx.reduced_motion=true; await process_frame; await process_frame; expect(fx.cinematic.actors.is_empty(),"reduced motion releases the cinematic 3D actors")
	window.queue_free(); app.queue_free(); await process_frame; await process_frame
	print("Cinematics: %d assertions, %d failures."%[checks,errors.size()]); quit(0 if errors.is_empty() else 1)
