extends Control
class_name Hearth20SeatedShell
## One shared 3D room. Map/sheet focus uses the existing interactive application.
var app: Hearth20App
var table: Hearth20CasinoTable
var map_viewport: SubViewport
var focus_surface: SubViewportContainer
var table_home: Control
var map_items: Node3D
var map_plate: MeshInstance3D
var hand: Node3D
var pulls: Hearth20SeatedPulls
var hud: Control
var hint: Label
var mode_label: Label
var home_row: HBoxContainer
var back: Button
var loader: Control
var focus_state="table"
var current_mode="map"
var requested_mode="map"
var switching=false
var ready_to_show=false
var changing_focus=false
var looking=false
var look_up=false
var look=Vector2.ZERO
var look_blend=Vector2.ZERO
var held_pull=""
var pull_origin=0.
var pull_amount=0.
var content_scale=1.
var elapsed=0.
var last_revision=-1
var viewport_tick=0.
var scale_bases={}
var look_button: Button
var papyrus: Hearth20SeatedPapyrus
var preview_stamp=0
var refreshments: Hearth20RefreshmentTray
var sheet_poll=0.
func _ready() -> void:
	name="SeatedTable";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme=Hearth20Design.theme();process_priority=100
	get_window().focus_entered.connect(_focus_entered);get_window().focus_exited.connect(_focus_exited)
	table_home=Control.new();table_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(table_home)
	# RPC node paths must match between title-loaded hosts and direct-start lab children.
	focus_surface=SubViewportContainer.new();focus_surface.name="FocusedTableSurface";focus_surface.stretch=true;focus_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);focus_surface.z_index=700;add_child(focus_surface)
	map_viewport=SubViewport.new();map_viewport.name="TableUi";map_viewport.size=Vector2i(1440,900);map_viewport.handle_input_locally=true;map_viewport.gui_embed_subwindows=true;focus_surface.add_child(map_viewport)
	app=Hearth20App.new();app.name="TableApplication";app.seated_shell=self;app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);map_viewport.add_child(app)
	# Canvas notifications/rolls belong to this player's screen, not the map texture.
	app.casino_portal.balance_notice.reparent(self)
	app.dice_stage.reparent(self);app.dice_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(app.multiplayer_lab.overlay):app.multiplayer_lab.overlay.reparent(self)
	focus_surface.hide();_build_hud();_loading();_prepare_table()
func _prepare_table() -> void:
	var assets={};var paths=app.casino_portal.paths
	for key in paths:ResourceLoader.load_threaded_request(paths[key],"Texture2D")
	while assets.size()<paths.size():
		for key in paths:
			if not assets.has(key) and ResourceLoader.load_threaded_get_status(paths[key])==ResourceLoader.THREAD_LOAD_LOADED:assets[key]=ResourceLoader.load_threaded_get(paths[key])
		await get_tree().process_frame
	table=Hearth20CasinoTable.new();table_home.add_child(table);table.setup(assets);table.camera_override=true;table.casino_active=false;table.book.hide();table.stock_deck.hide();table.center_props.hide()
	table.book.process_mode=Node.PROCESS_MODE_DISABLED
	pulls=Hearth20SeatedPulls.new();table.world.add_child(pulls);pulls.setup(table)
	refreshments=Hearth20RefreshmentTray.new();add_child(refreshments);refreshments.setup(self)
	_build_map();_camera(1.);map_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	# Compile each room-facing material/light combination behind the loading screen.
	for direction in 8:
		var angle=float(direction)*TAU/8.;table.camera.look_at(Vector3(sin(angle)*3.,1.85,2.45-cos(angle)*3.),Vector3.UP)
		for _frame in 2:await get_tree().process_frame
	_camera(1.)
	for _frame in 3:await get_tree().process_frame
	ready_to_show=true;loader.queue_free();loader=null;app.casino_portal.sync()
func _loading() -> void:
	loader=ColorRect.new();loader.color=Color("#100d08");loader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loader.z_index=1500;add_child(loader)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loader.add_child(center)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",20);center.add_child(box)
	_label(box,"✧  TAKING YOUR SEAT  ✧",30);_label(box,"Lighting the tavern and preparing your table…",17)
func _label(parent: Node, text: String, points=14) -> Label:
	var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",points);l.add_theme_color_override("font_color",Color("#e5cfaa"));parent.add_child(l);return l
func _focus_entered() -> void:Hearth20Preferences.apply_focus(true)
func _focus_exited() -> void:Hearth20Preferences.apply_focus(false)
func _button(parent: Node,text: String,action: Callable) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size.y=40;b.pressed.connect(action);parent.add_child(b);return b
func _build_hud() -> void:
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.z_index=900;add_child(hud)
	var panel=PanelContainer.new();panel.anchor_left=.25;panel.anchor_right=.75;panel.anchor_top=.88;panel.anchor_bottom=.985;panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color(.045,.033,.019,.92),3,14,Color("#9c783a")));hud.add_child(panel)
	var col=VBoxContainer.new();col.add_theme_constant_override("separation",5);panel.add_child(col);mode_label=_label(col,"THE ADVENTURE TABLE",16);mode_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint=_label(col,"Click the map or your character sheet · Right-drag to look around",12);hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;col.add_child(row)
	_button(row,"Focus battlemap",func():focus_map());_button(row,"Peek at my sheet",focus_sheet);_button(row,"Look up",toggle_pulls)
	_button(row,"Refreshments",func():refreshments.glance())
	_button(row,"⚙ Settings",func():app.open_preferences())
	home_row=HBoxContainer.new();home_row.alignment=BoxContainer.ALIGNMENT_CENTER;home_row.anchor_left=.28;home_row.anchor_right=.72;home_row.anchor_top=.07;home_row.anchor_bottom=.13;hud.add_child(home_row)
	_button(home_row,"Host a game",func():app._host_table();focus_map(app.session_page));_button(home_row,"Join a game",func():focus_map(app.session_page));_button(home_row,"Open campaign",func():focus_map();app._load_campaign())
	back=Button.new();back.text="↙ Back to the table";back.anchor_top=1.;back.anchor_bottom=1.;back.offset_left=24;back.offset_right=214;back.offset_top=-54;back.offset_bottom=-12;back.z_index=1100;back.pressed.connect(leave_focus);add_child(back);back.hide()
	look_button=Button.new();look_button.text="↑ Ceiling pulls";look_button.tooltip_text="Look up · the DM can drag a wooden pull downward to choose map or casino";look_button.anchor_left=.5;look_button.anchor_right=.5;look_button.offset_left=-85;look_button.offset_right=85;look_button.offset_top=20;look_button.offset_bottom=60;look_button.z_index=950;look_button.pressed.connect(toggle_pulls);add_child(look_button)
func look_at_pulls() -> void:
	look_up=true;look=Vector2.ZERO
func toggle_pulls() -> void:
	look_up=not look_up;look=Vector2.ZERO
func _build_map() -> void:
	map_items=Node3D.new();map_items.name="BattlemapTableItems";table.world.add_child(map_items)
	var frame=table._bevel(Vector3(2.72,.045,1.88),.035,table.bronze);frame.position=Vector3(0,.865,-.13);map_items.add_child(frame)
	map_plate=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(2.62,1.78);map_plate.mesh=plane;map_plate.position=Vector3(0,.892,-.13);map_items.add_child(map_plate)
	var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled;uniform sampler2D board:source_color,filter_linear;uniform vec4 crop=vec4(0,0,1,1);void fragment(){ALBEDO=texture(board,crop.xy+UV*crop.zw).rgb;}"
	var material_value=ShaderMaterial.new();material_value.shader=shader;material_value.set_shader_parameter("board",map_viewport.get_texture());map_plate.material_override=material_value
	hand=Node3D.new();hand.name="PersonalPapyrusSheet";hand.position=Vector3(.0,1.02,1.03);hand.rotation.x=.33;map_items.add_child(hand)
	papyrus=Hearth20SeatedPapyrus.new();hand.add_child(papyrus);papyrus.setup()
func desired_mode() -> String:
	return str(app.campaign.get("table_mode","map")) if app.session.local_role=="dm" else str(app.session.client_snapshot.get("table_mode","map"))
func focus_join_when_ready() -> void:
	while not ready_to_show:await get_tree().process_frame
	focus_map(app.session_page);app.player_name.grab_focus()
func use_casino_scene(parent: Node) -> Hearth20CasinoTable:
	table.casino_active=true;table.reparent(parent,false);table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);table.book.process_mode=Node.PROCESS_MODE_INHERIT;table.book.show();table.show();table.process_mode=Node.PROCESS_MODE_INHERIT;table.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;return table
func release_casino_scene() -> void:
	if not is_instance_valid(table):return
	table.casino_active=false
	table.reparent(table_home,false);table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);table.show();table.process_mode=Node.PROCESS_MODE_INHERIT;table.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	table.book.hide();table.book.process_mode=Node.PROCESS_MODE_DISABLED;table.stock_deck.hide();table.center_props.hide();table.card_surface.hide();table.card_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
func _switch(mode: String) -> void:
	if switching or not ready_to_show:return
	switching=true;requested_mode=mode;leave_focus();look_up=false;look=Vector2.ZERO;held_pull=""
	while table.book.busy:await get_tree().process_frame
	if table.book.opened:
		table.book.close_book()
		while table.book.busy:await get_tree().process_frame
	await get_tree().create_timer(.25).timeout
	var out=create_tween();out.tween_method(_scale_content,1.,.001,.43).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN);await out.finished
	map_items.visible=mode=="map"
	if mode=="casino":
		app.casino_portal.open()
		while app.casino_portal.phase!="ready":await get_tree().process_frame
		if is_instance_valid(app.casino_portal.hud):app.casino_portal.hud.hide()
	else:
		await app.casino_portal.close_local();release_casino_scene()
	current_mode=mode;_scale_content(.001)
	var incoming=create_tween();incoming.tween_method(_pop,0.,1.,.78);await incoming.finished;_scale_content(1.);switching=false
	if mode=="casino" and is_instance_valid(app.casino_portal.hud):app.casino_portal.hud.show()
func _pop(t: float) -> void:
	_scale_content(1.-exp(-7.*t)*(cos(10.*t)+.7*sin(10.*t)) if t<1. else 1.)
	var rubber=Vector3(1.+sin(t*PI)*.045,1.-sin(t*PI)*.075,1.+sin(t*PI)*.045)
	if current_mode=="map":map_items.scale*=rubber
	else:
		for node in [table.card_root,table.stock_deck,table.center_props,table.book,table.game_view.world_root,table.game_view.overlay_root]:
			if is_instance_valid(node):node.scale*=rubber
func _scale_content(amount: float) -> void:
	content_scale=maxf(.001,amount)
	if current_mode=="map":map_items.scale=Vector3(content_scale,content_scale,content_scale)
	elif table!=null:
		for node in [table.card_root,table.stock_deck,table.center_props,table.book,table.game_view.world_root,table.game_view.overlay_root]:
			if not is_instance_valid(node):continue
			var id=node.get_instance_id()
			if not scale_bases.has(id):scale_bases[id]=node.scale
			node.scale=scale_bases[id]*Vector3(content_scale,content_scale,content_scale)
func focus_map(page: Control=null) -> void:
	if not ready_to_show or switching or current_mode!="map":return
	focus_state="map";focus_surface.show();back.show();hud.hide();table.hide();table.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;table.card_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;table.soul_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;map_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	table.room.set_active(false)
	table.process_mode=Node.PROCESS_MODE_DISABLED
	app.board.soft_light.refresh_hz=60.
	if page!=null:app._show_sidebar_page(page)
func focus_sheet() -> void:
	if not ready_to_show or switching:return
	if app.session.is_spectating():return
	if current_mode=="casino":OS.shell_open(app.beyond_sheet.requested);return
	focus_map(app.sheet_page);focus_state="sheet";changing_focus=true
	if not is_instance_valid(app.beyond_sheet.expanded):app.beyond_sheet.toggle_expanded()
	changing_focus=false;back.hide()
func leave_focus() -> void:
	if not is_instance_valid(table):return
	if focus_state=="sheet" and app.beyond_sheet.browser_ready:app.beyond_sheet.capture_sheet_preview()
	changing_focus=true
	if is_instance_valid(app.beyond_sheet.expanded):app.beyond_sheet.toggle_expanded()
	changing_focus=false;focus_state="table";focus_surface.hide();back.hide();hud.show();table.show();table.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	table.room.set_active(true)
	table.process_mode=Node.PROCESS_MODE_INHERIT
	app.board.soft_light.refresh_hz=10.
	app.beyond_sheet.suspend_native();app.board.queue_redraw()
func _camera(delta: float) -> void:
	var target=Vector2(look.x,-.05 if not look_up else .88)+Vector2(0,look.y)
	look_blend.x=lerp_angle(look_blend.x,target.x,minf(1.,delta*7.));look_blend.y=lerpf(look_blend.y,target.y,minf(1.,delta*7.))
	var peek=table.peek_blend if current_mode=="casino" and not look_up else 0.
	var reading=table.book_blend if current_mode=="casino" and not look_up else 0.
	table.camera.position=Vector3(0,1.96,2.45).lerp(Vector3(0,2.10,2.20),peek).lerp(Vector3(0,2.52,1.62),reading);var pitch=look_blend.y
	var room_gaze=smoothstep(.45,1.15,absf(wrapf(look_blend.x,-PI,PI)))*1.265 if not look_up else 0.
	var target_point=Vector3(sin(look_blend.x)*2.7,.85+pitch*3.1+room_gaze,2.45-cos(look_blend.x)*2.7).lerp(Vector3(0,.87,0),peek).lerp(Vector3(0,1.25,.65),reading)
	table.camera.look_at(target_point,Vector3.UP)
	table.card_camera.global_transform=table.camera.global_transform;table.card_camera.fov=table.camera.fov
func _process(delta: float) -> void:
	if not ready_to_show:return
	elapsed+=delta;viewport_tick+=delta
	look_button.visible=focus_state=="table" and not switching and not app.session.is_spectating()
	if desired_mode()!=requested_mode and not switching:requested_mode=desired_mode();_switch(requested_mode)
	if focus_state=="table":
		_camera(delta)
		hud.visible=current_mode=="map" and not looking
		if current_mode=="casino" and is_instance_valid(app.casino_portal.hud):app.casino_portal.hud.visible=not look_up and not looking and not switching and not table.book.opened and not app.session.is_spectating()
		if is_instance_valid(app.casino_portal.book_nav):app.casino_portal.book_nav.visible=not look_up and not looking
		var online=not (app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer);home_row.visible=not online and current_mode=="map"
		mode_label.text="THE ADVENTURE TABLE" if current_mode=="map" else "THE GILDED CASINO"
		hint.text="Drag a wooden pull down to choose the table" if look_up and app.session.local_role=="dm" else "Only the DM can pull the mode ropes" if look_up else "Click the map or character sheet · Right-drag to look around"
		if current_mode=="map":
			var rect=app.board.get_global_rect();var dimensions=Vector2(map_viewport.size);map_plate.material_override.set_shader_parameter("crop",Vector4(rect.position.x/dimensions.x,rect.position.y/dimensions.y,rect.size.x/dimensions.x,rect.size.y/dimensions.y))
			if rect.size.x>0:map_plate.mesh.size=Vector2(2.62,2.62*rect.size.y/rect.size.x)
			var revision=int(app.campaign.get("revision",0)) if app.session.local_role=="dm" else int(app.session.client_snapshot.get("revision",0))
			var live_fx=not app.board.active_fx.events.is_empty();var refresh=1./30. if live_fx else .1
			app.board.soft_light.refresh_hz=30. if live_fx else 10.
			app.board.active_fx.cinematic.refresh_hz=30.
			if revision!=last_revision or viewport_tick>refresh:map_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;last_revision=revision;viewport_tick=0.
	else:
		home_row.hide();app.board.active_fx.cinematic.refresh_hz=60.
	if current_mode=="casino":map_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	sheet_poll+=delta
	if sheet_poll>=.35:sheet_poll=0.;_update_sheet_preview()
	if held_pull.is_empty():
		for mode in pulls.handles:pulls.pull(mode,lerpf(pulls.rest_y-pulls.handles[mode].position.y,0,minf(1.,delta*12.)))
	if focus_state=="table" and current_mode=="map":
		for child in app.get_children():
			if child is Window and child.visible:focus_map();break
func _update_sheet_preview() -> void:
	if app.beyond_sheet.channel.is_empty():return
	var path=app.beyond_sheet.channel.path_join("sheet-preview.png")
	if not FileAccess.file_exists(path):return
	var stamp=FileAccess.get_modified_time(path)
	if stamp<=preview_stamp:return
	var image=Image.new()
	if image.load(path)!=OK:return
	preview_stamp=stamp;papyrus.set_preview(ImageTexture.create_from_image(image))
func _input(event: InputEvent) -> void:
	if not ready_to_show or focus_state!="table" or switching:return
	if has_modal():return
	if is_instance_valid(refreshments) and refreshments.menu.visible:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		looking=event.pressed;get_viewport().set_input_as_handled();return
	if event is InputEventMouseMotion and looking:
		look.x=wrapf(look.x-event.relative.x*.004,-PI,PI)
		var pitch=clampf((.88 if look_up else -.05)+look.y-event.relative.y*.003,-.85,2.1)
		look_up=pitch>.62;look.y=pitch-(.88 if look_up else -.05)
		get_viewport().set_input_as_handled();return
	if app.session.is_spectating():return
	if event is InputEventMouseMotion and not held_pull.is_empty():
		pull_amount=clampf((event.position.y-pull_origin)*.004,0,.38);pulls.pull(held_pull,pull_amount);get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and refreshments.hit(event.position*Vector2(table.viewport.size)/size):get_viewport().set_input_as_handled();return
		if event.pressed and look_up:
			var mode=pulls.hit(table.camera,event.position*Vector2(table.viewport.size)/size)
			if not mode.is_empty() and app.session.local_role=="dm":held_pull=mode;pull_origin=event.position.y;pull_amount=0;get_viewport().set_input_as_handled();return
		elif not event.pressed and not held_pull.is_empty():
			var mode=held_pull;held_pull=""
			if pull_amount>.14:app.session.set_table_mode(mode)
			get_viewport().set_input_as_handled();return
		elif event.pressed and current_mode=="map" and not look_up:
			var screen=event.position*Vector2(table.viewport.size)/size;var origin=table.camera.project_ray_origin(screen);var ray=table.camera.project_ray_normal(screen)
			var crossing=Plane(Vector3.UP,.90).intersects_ray(origin,ray)
			if crossing is Vector3:
				if absf(crossing.x)<.46 and crossing.z>.73 and crossing.z<1.4:focus_sheet();get_viewport().set_input_as_handled()
				elif absf(crossing.x)<1.36 and absf(crossing.z+.13)<.95:focus_map();get_viewport().set_input_as_handled()
func _unhandled_key_input(event: InputEvent) -> void:
	if has_modal():return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and focus_state!="table":leave_focus();get_viewport().set_input_as_handled()
func has_modal() -> bool:
	for node in get_children()+app.get_children():
		if node is Window and node.visible:return true
	return false
