extends Control
class_name Hearth20SeatedShell
## One shared 3D room. Map/sheet focus uses the existing interactive application.
const AssetRequests=preload("res://hearth20/asset_requests.gd")
const TITLE_SCENE="res://hearth20_boot.tscn"
var app: Hearth20App
var console: Hearth20SkirtConsole
var console_button: Button
var casino_console_button: Button
var jax_alert: Hearth20JaxAlert
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
var campaign_label: Label
var role_label: Label
var invite_button: Button
var action_row: HFlowContainer
var home_row: HBoxContainer
var back: Button
var loader: Control
var loading_cancelled=false
var loading_assets=[]
var focus_state="table"
var current_mode="map"
var requested_mode="map"
var switching=false
var ready_to_show=false
var changing_focus=false
var looking=false
var look_up=false
var viewing_table_controls=false
var console_view_blend := 0.0
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
var loading_status: Label
var loading_bar: ProgressBar
var company: Hearth20TableCompany
func _ready() -> void:
	name="SeatedTable";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme=Hearth20Design.theme();process_priority=100
	get_window().focus_entered.connect(_focus_entered);get_window().focus_exited.connect(_focus_exited)
	table_home=Control.new();table_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(table_home)
	# RPC node paths must match between title-loaded hosts and direct-start lab children.
	focus_surface=SubViewportContainer.new();focus_surface.name="FocusedTableSurface";focus_surface.stretch=true;focus_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);focus_surface.z_index=700;add_child(focus_surface)
	map_viewport=SubViewport.new();map_viewport.name="TableUi";map_viewport.size=Vector2i(1440,900);map_viewport.handle_input_locally=true;map_viewport.gui_embed_subwindows=true;focus_surface.add_child(map_viewport)
	app=Hearth20App.new();app.name="TableApplication";app.seated_shell=self;app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);map_viewport.add_child(app)
	jax_alert=Hearth20JaxAlert.new();add_child(jax_alert);app.session.jax_alert_received.connect(jax_alert.trigger);app.session.jax_alert_cancelled.connect(jax_alert.dismiss)
	app.session.table_alert_received.connect(jax_alert.trigger_named)
	# Canvas notifications/rolls belong to this player's screen, not the map texture.
	app.casino_portal.balance_notice.reparent(self)
	# The focused map is at 700; rolls must composite above it on the player's screen.
	app.dice_stage.reparent(self);app.dice_stage.z_index=1000;app.dice_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(app.multiplayer_lab.overlay):app.multiplayer_lab.overlay.reparent(self)
	app.shell.board_controls.hide()
	focus_surface.hide();_build_hud();_loading();_prepare_table()
func _prepare_table() -> void:
	var assets={};var paths=app.casino_portal.paths
	var deadline=Time.get_ticks_msec()+AssetRequests.TIMEOUT_MSEC
	for path in paths.values():
		if not ResourceLoader.exists(path,"Texture2D") or ResourceLoader.load_threaded_request(path,"Texture2D")!=OK:
			_table_load_failed("The table’s artwork could not load.")
			return
		loading_assets.append(path)
	while assets.size()<paths.size():
		for key in paths:
			if assets.has(key):continue
			var path=paths[key];var state=ResourceLoader.load_threaded_get_status(path)
			if state==ResourceLoader.THREAD_LOAD_IN_PROGRESS:continue
			loading_assets.erase(path)
			var texture=ResourceLoader.load_threaded_get(path) if state!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else null
			if not texture is Texture2D:
				_table_load_failed("The table’s artwork could not load.")
				return
			assets[key]=texture
		if assets.size()==paths.size():break
		if Time.get_ticks_msec()>=deadline:
			_table_load_failed("The table’s artwork took too long to load.")
			return
		await get_tree().process_frame
		if loading_cancelled:return
	await Hearth20GeneratedModels.prepare(get_tree(),func(done,total):
		if is_instance_valid(loading_status):loading_status.text="Preparing the tavern and setting your table…";loading_bar.value=15.+float(done)/total*65.)
	if loading_cancelled:return
	table=Hearth20CasinoTable.new();table_home.add_child(table);table.setup(assets);table.camera_override=true;table.casino_active=false;table.book.hide();table.stock_deck.hide();table.center_props.hide()
	table.book.process_mode=Node.PROCESS_MODE_DISABLED
	pulls=Hearth20SeatedPulls.new();table.world.add_child(pulls);pulls.setup(table)
	refreshments=Hearth20RefreshmentTray.new();add_child(refreshments);refreshments.setup(self)
	_build_map();_camera(1.);map_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	company=Hearth20TableCompany.new();table.world.add_child(company);company.setup(app.session)
	console=Hearth20SkirtConsole.new();table.world.add_child(console);console.setup(self)
	# Compile each room-facing material/light combination behind the loading screen.
	for direction in 8:
		if is_instance_valid(loading_bar):loading_bar.value=80.+direction*2.
		var angle=float(direction)*TAU/8.;table.camera.look_at(Vector3(sin(angle)*3.,1.85,2.45-cos(angle)*3.),Vector3.UP)
		for _frame in 2:await get_tree().process_frame
	_camera(1.)
	for _frame in 3:await get_tree().process_frame
	ready_to_show=true;loader.queue_free();loader=null;app.casino_portal.sync()
func _table_load_failed(message: String) -> void:
	loading_cancelled=true
	AssetRequests.discard(get_tree(),loading_assets)
	loading_assets.clear()
	loading_status.text=message+" Return to the title and try again."
	loading_bar.hide()
func _return_to_title() -> void:
	loading_cancelled=true
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)
func _exit_tree() -> void:
	AssetRequests.discard(get_tree(),loading_assets)
func _loading() -> void:
	loader=ColorRect.new();loader.color=Color("#100d08");loader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loader.z_index=1500;add_child(loader)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loader.add_child(center)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",20);center.add_child(box)
	_label(box,"✧  TAKING YOUR SEAT  ✧",30);loading_status=_label(box,"Lighting the tavern and preparing your table…",17)
	loading_bar=ProgressBar.new();loading_bar.custom_minimum_size=Vector2(430,14);loading_bar.show_percentage=false;box.add_child(loading_bar)
	_button(box,"Return to title",_return_to_title)
func _label(parent: Node, text: String, points=14) -> Label:
	var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",points);l.add_theme_color_override("font_color",Color("#e5cfaa"));parent.add_child(l);return l
func _focus_entered() -> void:Hearth20Preferences.apply_focus(true)
func _focus_exited() -> void:Hearth20Preferences.apply_focus(false)
func _button(parent: Node,text: String,action: Callable) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size.y=40;b.pressed.connect(action);parent.add_child(b);return b
func _build_hud() -> void:
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.z_index=900;add_child(hud)
	var badge := PanelContainer.new()
	badge.position=Vector2(20,18)
	badge.custom_minimum_size.x=224
	badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#1e1a16f2"),6,9,Hearth20Design.BORDER))
	hud.add_child(badge)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation",2)
	badge.add_child(identity)
	campaign_label=_label(identity,"New Hearth20 table",17)
	campaign_label.add_theme_font_override("font",Hearth20Design.font(true))
	campaign_label.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.INK))
	campaign_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	role_label=_label(identity,"Game Master · Local table",11)
	role_label.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.MUTED))
	var invite_anchor := HBoxContainer.new()
	invite_anchor.anchor_left=1.
	invite_anchor.anchor_right=1.
	invite_anchor.offset_left=-160
	invite_anchor.offset_right=-20
	invite_anchor.offset_top=18
	invite_anchor.offset_bottom=54
	invite_anchor.alignment=BoxContainer.ALIGNMENT_END
	invite_anchor.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(invite_anchor)
	invite_button=_button(invite_anchor,"Quick invite…",func():app.open_connections("host").quick_invite())
	invite_button.icon=Hearth20Design.icon("connect",16)
	invite_button.add_theme_constant_override("icon_max_width",16)
	invite_button.custom_minimum_size.y=34
	invite_button.tooltip_text="Invite friends to your Steam table"
	invite_button.hide()
	var dock := VBoxContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock.offset_bottom=-17
	dock.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dock.add_theme_constant_override("separation",4)
	hud.add_child(dock)
	var fit_dock := func():
		var inset := maxf(12,(hud.size.x-660)*0.5)
		dock.offset_left=inset
		dock.offset_right=-inset
	hud.resized.connect(fit_dock)
	fit_dock.call()
	var space := Control.new()
	space.size_flags_vertical=Control.SIZE_EXPAND_FILL
	space.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dock.add_child(space)
	hint=_label(dock,"Right-drag to look around",12)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color",Color("#f2dfc1"))
	hint.add_theme_color_override("font_shadow_color",Color("#19110b"))
	hint.add_theme_constant_override("shadow_offset_y",1)
	hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var panel := PanelContainer.new()
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var strip_style := Hearth20Design.panel(Color("#1e1a16f5"),7,6,Hearth20Design.BORDER,true)
	panel.add_theme_stylebox_override("panel",strip_style)
	dock.add_child(panel)
	action_row=HFlowContainer.new()
	action_row.alignment=FlowContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("h_separation",4)
	action_row.add_theme_constant_override("v_separation",4)
	action_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(action_row)
	var map_button=_button(action_row,"Focus battlemap",func():focus_map())
	Hearth20Design.primary(map_button)
	var sheet_button=_button(action_row,"Character sheet",focus_sheet)
	var refresh_button=_button(action_row,"Refreshments",func():refreshments.glance())
	console_button=_button(action_row,"Table controls",_show_table_controls)
	console_button.tooltip_text="Look down at the DM’s wooden window controls"
	var settings_button=_button(action_row,"Settings",app.open_preferences)
	for pair in [[map_button,"map"],[sheet_button,"sheet"],[refresh_button,"cup"],[console_button,"panel"],[settings_button,"gear"]]:
		var button: Button=pair[0]
		button.icon=Hearth20Design.icon(pair[1],16)
		button.add_theme_constant_override("icon_max_width",16)
		button.add_theme_font_size_override("font_size",13)
		button.custom_minimum_size.y=34
	refresh_button.theme_type_variation="QuietButton"
	console_button.theme_type_variation="QuietButton"
	settings_button.theme_type_variation="QuietButton"
	home_row=HBoxContainer.new()
	home_row.alignment=BoxContainer.ALIGNMENT_CENTER
	home_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	home_row.anchor_left=0.5
	home_row.anchor_right=0.5
	home_row.offset_left=-188
	home_row.offset_right=188
	home_row.offset_top=72
	home_row.offset_bottom=110
	hud.add_child(home_row)
	_button(home_row,"Host a game",func():app.open_connections("host"))
	_button(home_row,"Join a game",func():app.open_connections("join"))
	_button(home_row,"Open campaign",func():focus_map();app._load_campaign())
	back=Button.new();back.icon=Hearth20Design.icon("back",18);back.add_theme_constant_override("icon_max_width",18);back.tooltip_text="Back to the table";back.custom_minimum_size=Vector2(40,36);back.size_flags_vertical=Control.SIZE_SHRINK_CENTER;back.pressed.connect(leave_focus);app.shell.toolbar.add_child(back);app.shell.toolbar.move_child(back,0);back.hide()
	look_button=Button.new();look_button.anchor_left=.5;look_button.anchor_right=.5;look_button.offset_left=-78;look_button.offset_right=78;look_button.offset_top=18;look_button.offset_bottom=54;look_button.z_index=950;look_button.pressed.connect(_use_camera_button);add_child(look_button)
	casino_console_button=_button(self,"Table controls",_show_table_controls)
	casino_console_button.anchor_left=.5;casino_console_button.anchor_right=.5
	casino_console_button.offset_left=87;casino_console_button.offset_right=239
	casino_console_button.offset_top=18;casino_console_button.offset_bottom=54
	casino_console_button.z_index=950
	casino_console_button.icon=Hearth20Design.icon("panel",16)
	casino_console_button.hide()
	_update_camera_button()
func _update_camera_button() -> void:
	look_button.text="Back to the table" if viewing_table_controls else "↑ Ceiling pulls"
	look_button.tooltip_text="Return to your seat (Esc)" if viewing_table_controls else "Look up · the DM can drag a wooden pull downward to choose map or casino"
func _use_camera_button() -> void:
	if viewing_table_controls:_leave_table_controls()
	else:toggle_pulls()
func _show_table_controls() -> void:
	if not ready_to_show or switching or focus_state!="table" or app.session.local_role!="dm" or app.session.is_spectating() or table.book.opened:return
	viewing_table_controls=true
	looking=false;look_up=false;look=Vector2(0,-1.1);held_pull=""
	_update_camera_button()
func _leave_table_controls() -> void:
	if not viewing_table_controls:return
	viewing_table_controls=false
	looking=false;look_up=false;look=Vector2.ZERO
	if is_instance_valid(console):
		console.held="";console.hovered=""
	_update_camera_button()
func look_at_pulls() -> void:
	_leave_table_controls()
	look_up=true;look=Vector2.ZERO
func toggle_pulls() -> void:
	_leave_table_controls()
	look_up=not look_up;look=Vector2.ZERO
func _build_map() -> void:
	map_items=Node3D.new();map_items.name="BattlemapTableItems";table.world.add_child(map_items)
	var crafted_frame=Hearth20GeneratedModels.make("map_frame",Vector3(3.0,.045,2.10))
	if crafted_frame!=null:crafted_frame.position=Vector3(0,.842,-.13);map_items.add_child(crafted_frame)
	else:
		var frame=table._bevel(Vector3(2.72,.045,1.88),.035,table.bronze);frame.position=Vector3(0,.865,-.13);map_items.add_child(frame)
	map_plate=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(2.62,1.78);map_plate.mesh=plane;map_plate.position=Vector3(0,.892,-.13);map_items.add_child(map_plate)
	var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled;uniform sampler2D board:source_color,filter_linear;uniform vec4 crop=vec4(0,0,1,1);void fragment(){ALBEDO=texture(board,crop.xy+UV*crop.zw).rgb;}"
	var material_value=ShaderMaterial.new();material_value.shader=shader;material_value.set_shader_parameter("board",map_viewport.get_texture());map_plate.material_override=material_value
	hand=Node3D.new();hand.name="PersonalPapyrusSheet";hand.position=Vector3(.0,1.02,1.03);hand.rotation.x=.33;map_items.add_child(hand)
	papyrus=Hearth20SeatedPapyrus.new();hand.add_child(papyrus);papyrus.setup()
func desired_mode() -> String:
	return str(app.campaign.get("table_mode","map")) if app.session.local_role=="dm" else str(app.session.client_snapshot.get("table_mode","map"))
func focus_join_when_ready() -> void:
	focus_connections_when_ready("join")
func focus_connections_when_ready(role: String) -> void:
	while not ready_to_show and not loading_cancelled:await get_tree().process_frame
	if ready_to_show:app.open_connections(role)
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
		while app.casino_portal.phase in ["loading","warming"]:await get_tree().process_frame
		if app.casino_portal.phase!="ready":
			map_items.show();_scale_content(1.);switching=false
			if app.session.local_role=="dm":app.session.set_table_mode("map")
			return
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
	_leave_table_controls()
	app.shell.board_controls.show()
	focus_state="map";focus_surface.show();back.show();hud.hide();table.hide();table.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;table.card_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;table.soul_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;map_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	table.room.set_active(false)
	console.hide()
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
	var context_menu := app.active_context_menu()
	if context_menu != null:context_menu.hide()
	_leave_table_controls()
	if focus_state=="sheet" and app.beyond_sheet.browser_ready:app.beyond_sheet.capture_sheet_preview()
	changing_focus=true
	if is_instance_valid(app.beyond_sheet.expanded):app.beyond_sheet.toggle_expanded()
	app.shell.board_controls.hide()
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
	console_view_blend=lerpf(console_view_blend,1.0 if viewing_table_controls else 0.0,minf(1.0,delta*8.0))
	if console_view_blend>.001 and is_instance_valid(console):
		table.camera.position=table.camera.position.lerp(Vector3(0,1.82,2.87),console_view_blend)
		var console_center: Vector3=console.to_global(Vector3(0,-Hearth20SkirtConsole.ROW_GAP*.5,.07))
		target_point=target_point.lerp(console_center,console_view_blend)
	table.camera.look_at(target_point,Vector3.UP)
	table.card_camera.global_transform=table.camera.global_transform;table.card_camera.fov=table.camera.fov
func _process(delta: float) -> void:
	if not ready_to_show:return
	elapsed+=delta;viewport_tick+=delta
	var exterior=table.room.get_node_or_null("WindowWorld")
	if exterior!=null:exterior.request(app.session.room_environment())
	var can_use_console=app.session.local_role=="dm" and not app.session.is_spectating()
	console_button.visible=can_use_console
	casino_console_button.visible=can_use_console and current_mode=="casino" and focus_state=="table" and not switching and not viewing_table_controls and not table.book.opened
	if not can_use_console:_leave_table_controls()
	look_button.visible=focus_state=="table" and not switching and not app.session.is_spectating() and not table.book.opened
	if desired_mode()!=requested_mode and not switching:
		requested_mode=desired_mode()
		if requested_mode!=current_mode:_switch(requested_mode)
	if focus_state=="table":
		_camera(delta)
		hud.visible=current_mode=="map" and not viewing_table_controls and not looking and look_blend.y>-.55
		if current_mode=="casino" and is_instance_valid(app.casino_portal.hud):app.casino_portal.hud.visible=not viewing_table_controls and not look_up and not looking and look_blend.y>-.55 and not switching and not table.book.opened and not app.session.is_spectating()
		if is_instance_valid(app.casino_portal.book_nav):app.casino_portal.book_nav.visible=not viewing_table_controls and not look_up and not looking and look_blend.y>-.55
		var online=not (app.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
		home_row.visible=not online and current_mode=="map"
		var player_view: bool=app.session.local_role=="player"
		campaign_label.text="Your adventure" if player_view else str(app.campaign.get("title","New Hearth20 table"))
		role_label.text=("Player" if player_view else "Game Master")+" · "+("Connected" if online else "Local table")
		var steam_link=get_node_or_null("/root/SteamLink")
		invite_button.visible=can_use_console and steam_link!=null and steam_link.state=="hosting"
		hint.text="Drag a wooden pull down to choose the table" if look_up and app.session.local_role=="dm" else "Only the DM can pull the mode ropes" if look_up else app.casino_portal.load_error if not app.casino_portal.load_error.is_empty() else "Right-drag to look around"
		if current_mode=="map":
			var rect=app.board.get_global_rect();var dimensions=Vector2(map_viewport.size);map_plate.material_override.set_shader_parameter("crop",Vector4(rect.position.x/dimensions.x,rect.position.y/dimensions.y,rect.size.x/dimensions.x,rect.size.y/dimensions.y))
			if rect.size.x>0:map_plate.mesh.size=Vector2(2.62,2.62*rect.size.y/rect.size.x)
			var revision=int(app.campaign.get("revision",0)) if app.session.local_role=="dm" else int(app.session.client_snapshot.get("revision",0))
			var live_fx=not app.board.active_fx.events.is_empty()
			var refresh=1./30. if live_fx or not app.board.drawn_gifs.is_empty() else .1
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
	# HUD actions have priority over the scene beneath their buttons.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and held_pull.is_empty():
		var buttons=action_row.get_children()+home_row.get_children()+[look_button,invite_button,casino_console_button]
		for button in buttons:
			if button.is_visible_in_tree() and button.get_global_rect().has_point(event.position):
				if is_instance_valid(console):console.held=""
				return
	if viewing_table_controls and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		_leave_table_controls()
	if is_instance_valid(console):
		if event is InputEventMouseMotion:console.hovered=console.hit(table.camera,event.position*Vector2(table.viewport.size)/size)
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			var hit=console.hit(table.camera,event.position*Vector2(table.viewport.size)/size)
			if event.pressed and not hit.is_empty():console.held=hit;get_viewport().set_input_as_handled();return
			if not event.pressed and not console.held.is_empty():
				var pressed=console.held;console.held=""
				if hit==pressed:console.activate(hit)
				get_viewport().set_input_as_handled();return
	if viewing_table_controls:return
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
	var context_menu := app.active_context_menu()
	if context_menu != null:
		context_menu.handle_key(event)
		get_viewport().set_input_as_handled();return
	if has_modal():return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		if not ready_to_show:_return_to_title()
		elif viewing_table_controls:_leave_table_controls()
		elif focus_state!="table":leave_focus()
		else:return
		get_viewport().set_input_as_handled()
func has_modal() -> bool:
	for node in get_children()+app.get_children()+get_tree().root.get_children():
		if node is Window and node.visible:return true
	return false
