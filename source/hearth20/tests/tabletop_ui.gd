extends SceneTree
## Native Control/event acceptance; use only the isolated QA runner.
var checks := 0
var failures: Array[String] = []
var app: Node

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func pointer(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=position
	event.pressed=pressed
	return event

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("H20_QA_EVIDENCE")
	if not directory.is_empty():
		root.get_texture().get_image().save_png(directory.path_join(label+".png"))

func client_view(player_id: String) -> void:
	var view: Dictionary=app.session._project_for(player_id)
	app.session.local_role="player"
	app.session.local_player_id=player_id
	app.session.client_snapshot=view
	app.board.set_role("player")
	app._update_session_ui()
	app._on_snapshot(view)

func cleared(label: String) -> void:
	expect(app.session.client_snapshot.is_empty() and app.session.local_player_id.is_empty(),label+": private session state cleared")
	expect(app.chat_feed.get_parsed_text().is_empty() and app.handout_title.text.is_empty() and app.handout_body.text.is_empty(),label+": chat and handout text cleared")
	expect(app.selected_sheet_actor_id.is_empty() and app.board.snapshot.actors.is_empty() and app.board.snapshot.assets.is_empty(),label+": assigned sheet and board assets cleared")
	expect(app.player_session_note.text.begins_with("Disconnected"),label+": connection status agrees with empty view")

func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://hearth20_main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var campaign: Dictionary=app.campaign
	var scene: Dictionary=campaign.scenes[0]
	var hero_id: String=app.board.add_token("Mira Stonebrook",true,Vector2(4,4))
	var hero:=Hearth20Contracts.find_actor(campaign,hero_id)
	hero.merge({"owner_player_id":"player-ui","abilities":[12,18,14,11,16,10],"hp":32,"max_hp":41,"ac":16,"level":5,"prof_bonus":3,"initiative_bonus":6,"inventory":"Longbow · arrows\nLeather armor · equipped","notes":"Private hero notes","vision":{"enabled":true,"darkvision_feet":60.0,"bright_light_feet":0.0,"dim_light_feet":0.0}},true)
	app.board.selected_actor_id=hero_id
	app._on_selection(hero_id)
	app._show_sidebar_page(app.sheet_page)
	await process_frame
	app.dm_sheet_fields.str.value=19
	app.session.send_chat("An unrelated message should not reset a draft.")
	expect(int(app.dm_sheet_fields.str.value)==19,"unrelated chat preserves unsaved DM sheet fields")
	app._save_sheet_changes()
	expect(int(hero.abilities[0])==19 and int(hero.ac)==16,"DM sheet editor saves actual recorded fields")
	app.darkvision_field.value=75
	app.session.send_chat("An unrelated message should not reset a sight draft.")
	expect(int(app.darkvision_field.value)==75,"unrelated chat preserves the unsaved vision range")
	var original: Vector2=hero.position
	app.board.set_measure_tool(true)
	app.inspector_toggle.grab_focus()
	var escape:=InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	app._unhandled_key_input(escape)
	expect(not app.board.measure_tool,"Escape cancels the ruler when a toolbar button has focus")
	app.board.set_measure_tool(true)
	var start: Vector2=app.board._world_to_screen(Vector2(5,5),float(scene.cell_pixels))
	var end: Vector2=app.board._world_to_screen(Vector2(11,5),float(scene.cell_pixels))
	app.board._gui_input(pointer(start,true))
	app.board._gui_input(pointer(end,false))
	expect(is_equal_approx(app.board.measure_start.distance_to(app.board.measure_end)*float(scene.feet_per_cell),30.0) and hero.position==original,"ruler measures 30 ft without moving a token")
	app.board.set_template_tool("circle")
	app.board._gui_input(pointer(start,true))
	app.board._gui_input(pointer(end,false))
	expect(scene.templates.size()==1 and scene.templates[0].shape=="circle","DM drag places a persistent measured circle")
	var key:=InputEventKey.new()
	key.keycode=KEY_DELETE
	key.pressed=true
	app.board._gui_input(key)
	expect(scene.templates.is_empty(),"Delete removes the selected area")
	key=InputEventKey.new()
	key.keycode=KEY_Z
	key.ctrl_pressed=true
	key.pressed=true
	app.board._gui_input(key)
	expect(scene.templates.size()==1,"Ctrl+Z restores that removed area")
	app._select_mode()
	app.dm_notes_editor.text="Saved private DM journal"
	app.dm_notes_save_button.pressed.emit()
	app._save_campaign()
	hero.hp=2
	app.dm_notes_editor.text="Stale unsaved notes from before loading"
	app._load_campaign()
	campaign=app.campaign
	scene=campaign.scenes[0]
	hero=Hearth20Contracts.find_actor(campaign,hero_id)
	expect(int(hero.hp)==32 and int(hero.abilities[0])==19 and float(hero.vision.darkvision_feet)==60.0 and scene.templates.size()==1,"actual Save/Open controls restore sheet, sight and measured areas")
	expect(app.dm_notes_editor.text=="Saved private DM journal","Open replaces the private note editor with the loaded campaign's notes")
	app.session.set_scene_lighting(true,"dark")
	app.session.remote_players={"player-ui":{"nickname":"Preview player","peer_id":0}}
	app._on_host_state({"players":app.session.remote_players})
	app._preview_selected_player()
	await process_frame
	var windows: Array=app.get_children().filter(func(node):return node is Window and str(node.title).contains("PLAYER VIEW"))
	expect(windows.size()==1,"DM opens a real player-view window")
	if windows.size()==1:
		var preview: Node=windows[0].get_child(0).get_child(0)
		expect(preview.read_only_preview and preview.role=="player" and preview.snapshot.sheets.size()==1,"preview uses the authoritative owner projection and is read only")
		preview._move_selected(hero.position,hero.position+Vector2.ONE)
		expect(hero.position==original,"dragging in preview cannot move authoritative actors")
		windows[0].queue_free()
	await process_frame
	app.session.remote_players.clear()
	app.session.share_handout("Shared clue","Visible handout for this party",true)
	app.session.campaign.table_timeline.append({"id":"private-ui-roll","type":"chat","text":"Only this player and DM","sender":"DM","visibility":"gm","recipients":["player-ui"]})
	client_view("player-ui")
	app._show_sidebar_page(app.sheet_page)
	await process_frame
	expect(app.selected_sheet_actor_id==hero_id and app.sheet_summary.text.contains("Mira Stonebrook"),"one assigned sheet selects automatically without a visible pawn click")
	expect(not app.dm_notes_editor.visible and not app.handout_save_button.visible,"player view hides DM note and handout edit controls")
	expect(app.workspace_tabs.is_tab_hidden(app.workspace_tabs.get_tab_idx_from_control(app.scene_page)) and app.workspace_tabs.is_tab_hidden(app.workspace_tabs.get_tab_idx_from_control(app.token_page)) and app.workspace_tabs.is_tab_hidden(app.workspace_tabs.get_tab_idx_from_control(app.author_page)),"Workspace does not expose DM preparation tabs to a player")
	expect(app.handout_body.text=="Visible handout for this party","shared handout selects and displays its body")
	app.session.campaign.handouts[0].body="Updated clue from the DM"
	var edited_handout: Dictionary=app.session._project_for("player-ui")
	app.session.client_snapshot=edited_handout
	app._on_snapshot(edited_handout)
	expect(app.handout_body.text=="Updated clue from the DM","a selected handout updates when the DM changes its body")
	app.chat_composer.text="A draft message"
	app._on_snapshot(app.session.client_snapshot)
	expect(app.chat_composer.text=="A draft message","routine snapshots preserve the composed chat message")
	scene.blackout=true
	var covered: Dictionary=app.session._project_for("player-ui")
	app.session.client_snapshot=covered
	app._on_snapshot(covered)
	expect(app.sheet_summary.text.contains("Mira Stonebrook") and app.board.current_actors().is_empty(),"blackout keeps the assigned sheet while removing all board actors")
	await capture("ui-blackout-sheet-1280")
	scene.blackout=false
	app.session.campaign.handouts[0].public=false
	var retracted: Dictionary=app.session._project_for("player-ui")
	app.session.client_snapshot=retracted
	app._on_snapshot(retracted)
	expect(app.handout_title.text.is_empty() and app.handout_body.text.is_empty(),"retracting a shared handout clears its stale visible body")
	app.session.multiplayer.connection_failed.emit()
	cleared("failed-connect callback")
	client_view("player-ui")
	app.session.multiplayer.server_disconnected.emit()
	cleared("server-disconnect callback")
	await capture("ui-disconnected-1280")
	app.queue_free()
	await process_frame
	print("Native tabletop UI checks: %d assertions, %d failures." % [checks,failures.size()])
	quit(1 if not failures.is_empty() else 0)
