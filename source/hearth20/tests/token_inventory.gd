extends SceneTree
var checks:=0
var errors: Array=[]
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks+=1
	if not ok: errors.append(note); push_error("FAIL: "+note)
func capture(window: Window, filename: String) -> void:
	await create_timer(.15).timeout; await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(filename+".png"))
func run() -> void:
	root.size=Vector2i(1440,900)
	var app: Hearth20App=load("res://hearth20_main.tscn").instantiate(); root.add_child(app); await process_frame
	var session: Hearth20Session=app.session; var board: Hearth20BoardCanvas=app.board
	var id:=board.add_token("Aurelia",true,Vector2(4,4)); var actor:=Hearth20Contracts.find_actor(app.campaign,id)
	expect(actor.position==Vector2(4.5,4.5),"new board tokens are centered in their cell")
	board.selected_actor_id=id; board._move_selected(actor.position,Vector2(7.1,6.95))
	expect(actor.position==Vector2(7.5,6.5),"drag movement ends at the square center")
	var result:=session.create_inventory_token("Ember guardian"); var stored_id: String=result.id; var stored:=Hearth20Contracts.find_actor(app.campaign,stored_id)
	expect(result.ok and stored.in_inventory and not board.current_actors().has(stored),"new inventory tokens have no board presence")
	stored.owner_player_id="player-a"; stored.movement_policy=Hearth20Contracts.default_movement_policy("free_until_revoked",["player-a"]); stored.vision={"enabled":true,"darkvision_feet":60,"bright_light_feet":20,"dim_light_feet":20}
	var image:=Image.create(16,16,false,Image.FORMAT_RGBA8); image.fill(Color("#d98c37")); var png:=image.save_png_to_buffer(); Hearth20Assets.attach_token_override(app.campaign,stored_id,png,"vault-portrait.png")
	var view:=Hearth20Contracts.project_for_player(app.campaign,"player-a",PackedByteArray())
	expect(not str(view).contains("Ember guardian") and not view.assets.has(stored.png_asset_id),"stored NPC identity and image stay out of player packets")
	var sight:=Hearth20Vision.build_view(app.campaign,"player-a",board.current_scene())
	expect(sight.observers.is_empty() and sight.lights.is_empty(),"stored tokens contribute neither sight nor carried lighting")
	expect(not Hearth20Contracts.authorize_and_apply_move(app.campaign,"player-a","player",stored_id,stored.position,Vector2(1,1),5).ok,"owned stored tokens cannot be moved with a forged board request")
	var copy:=session.duplicate_inventory_token(stored_id); var duplicated:=Hearth20Contracts.find_actor(app.campaign,copy.id)
	expect(copy.ok and duplicated.in_inventory and duplicated.png_asset_id==stored.png_asset_id and duplicated.owner_player_id=="" and duplicated.movement_policy.mode=="blocked","duplicates reuse art and start under DM control")
	expect(session.place_inventory_token(stored_id,Vector2(23.99,15.99)).ok and stored.position==Vector2(23.5,15.5),"edge placement remains centered inside the map")
	expect(board.current_actors().has(stored) and not stored.in_inventory and stored.owner_player_id=="player-a","placing a stored token retains its assignment")
	session.store_inventory_token(stored_id)
	var path:=Hearth20Identity.SAVE_ROOT+"/token-vault.h20campaign"; var saved:=Hearth20Identity.save_campaign(app.campaign,path); var loaded:=Hearth20Identity.load_campaign(path)
	expect(saved.ok and loaded.ok and Hearth20Contracts.find_actor(loaded.campaign,stored_id).in_inventory and Hearth20Contracts.find_actor(loaded.campaign,stored_id).png_asset_id==stored.png_asset_id,"inventory and art persist in a self-contained campaign")
	var invalid:=app.campaign.duplicate(true); Hearth20Contracts.find_actor(invalid,stored_id).in_inventory="yes"; expect(not Hearth20Contracts.validate_campaign(invalid).ok,"inventory flags are validated")
	var window:=app.open_token_inventory(); window.select_token(stored_id); await capture(window,"campaign-token-inventory-black")
	window.search.text="Ember"; window.search.text_changed.emit("Ember"); await process_frame; expect(window.visible_entries.size()==2,"inventory searches tokens across the campaign")
	window.filter.select(1); window.refresh(); expect(window.visible_entries.all(func(item): return item.get("in_inventory",false)),"stored filter excludes map tokens")
	window.search.clear(); Hearth20Regal.toggle(); window.theme=Hearth20Design.theme(); await capture(window,"campaign-token-inventory-parchment"); Hearth20Regal.toggle()
	window.queue_free(); await process_frame
	board.selected_actor_id=id; board.current_scene().snap_to_grid=false; board._move_selected(actor.position,Vector2(3.2,4.8)); expect(actor.position==Vector2(3.2,4.8),"free placement still works when snap is disabled")
	board.current_scene().snap_to_grid=true; expect(session.center_scene_tokens().ok and actor.position==Vector2(3.5,4.5),"DM can center existing map tokens")
	session.local_role="player"
	expect(not session.create_inventory_token("Forged").ok and not session.place_inventory_token(stored_id,Vector2(2,2)).ok and not session.store_inventory_token(id).ok and not session.duplicate_inventory_token(id).ok and app.open_token_inventory()==null,"all inventory actions and UI remain DM-only")
	session.local_role="dm"; app.queue_free(); await process_frame; await process_frame
	print("Token inventory: %d assertions, %d failures."%[checks,errors.size()]); quit(0 if errors.is_empty() else 1)
