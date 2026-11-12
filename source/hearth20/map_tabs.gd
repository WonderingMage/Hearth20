extends HBoxContainer
class_name Hearth20MapTabs
## A scrollable browser-like tab strip. Right-click acts on the clicked map ID.
var app: Hearth20App
var tabs: HBoxContainer
class ContextMenu extends Control:
	signal id_pressed(id: int)
	var panel: PanelContainer
	var items: Array[Button]=[]
	func _ready() -> void:
		name="MapContextMenu";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP;z_index=1100
		panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Design.SURFACE,8,8,Hearth20Design.GOLD));add_child(panel)
		var column=VBoxContainer.new();column.add_theme_constant_override("separation",4);panel.add_child(column)
		for record in [["Open this map","map"],["Bring all heroes here","tokens"]]:
			var index=items.size();var button=Button.new();button.text=record[0];button.icon=Hearth20Design.icon(record[1],18);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size=Vector2(248,36)
			button.pressed.connect(func():hide();id_pressed.emit(index));column.add_child(button);items.append(button)
		hide()
	func popup_at(point: Vector2) -> void:
		Hearth20Regal.sync(self);show();panel.size=panel.get_combined_minimum_size()
		panel.position=point.clamp(Vector2(8,8),(size-panel.size-Vector2(8,8)).max(Vector2(8,8)))
		items[0].grab_focus()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:hide();accept_event()
	func _input(event: InputEvent) -> void:
		if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:handle_key(event);get_viewport().set_input_as_handled()
	func handle_key(event: InputEvent) -> void:
		if not event is InputEventKey or not event.pressed:return
		var selected=0
		for index in items.size():
			if items[index].has_focus():selected=index;break
		if event.keycode==KEY_ESCAPE:hide()
		elif event.keycode in [KEY_UP,KEY_DOWN,KEY_TAB]:items[posmod(selected+(-1 if event.keycode==KEY_UP or event.shift_pressed else 1),items.size())].grab_focus()
		elif event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:hide();id_pressed.emit(selected)
var menu: ContextMenu
var target=""
var signature=""
var invite: Button
func setup(owner_app: Hearth20App) -> void:
	app=owner_app;custom_minimum_size.y=40;add_theme_constant_override("separation",8)
	var scroll:=ScrollContainer.new();scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;add_child(scroll)
	tabs=HBoxContainer.new();tabs.add_theme_constant_override("separation",3);scroll.add_child(tabs)
	var add:=Button.new();add.text="＋ Map";add.tooltip_text="Import a .hearth20map package or an image";add.pressed.connect(app._open_map_dialog);add_child(add)
	invite=Button.new();invite.text="Quick invite…";invite.tooltip_text="Invite players without scrolling the friends list";invite.pressed.connect(func():app.open_connections("host").quick_invite());add_child(invite)
	# A popup Window inside the map SubViewport can retain an exclusive input
	# grab while its originating tab is rebuilt. Keep this menu on the same
	# ordinary canvas as the map; it never captures the native window.
	menu=ContextMenu.new();menu.id_pressed.connect(_context_action);app.add_child(menu)
	app.session.state_changed.connect(func(_value):refresh());refresh()
func _process(_delta: float) -> void:
	if visible!=(app.session.local_role=="dm"):refresh()
	var link=app.get_node_or_null("/root/SteamLink") if is_instance_valid(app) else null
	invite.visible=link!=null and app.session.local_role=="dm" and link.state=="hosting"
func refresh() -> void:
	visible=app.session.local_role=="dm"
	if not visible:menu.hide();return
	var state: Array=[]
	for scene in app.campaign.get("scenes",[]):state.append([scene.id,scene.get("title","Map")])
	var next:=str([state,app.campaign.get("active_scene",""),app.campaign.get("map_covered",false),Hearth20Regal.revision])
	if signature==next:return
	signature=next
	for child in tabs.get_children():tabs.remove_child(child);child.queue_free()
	for scene in app.campaign.get("scenes",[]):
		var id: String=scene.id
		var button:=Button.new();button.name="MapTab";button.text=str(scene.get("title","Map"));button.tooltip_text=button.text+"\nClick to open · Right-click to bring all heroes";button.set_meta("scene_id",id)
		button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;button.custom_minimum_size=Vector2(176,34);button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		button.add_theme_constant_override("outline_size",0);button.set_meta("regal_custom_button",true)
		var active: bool=id==str(app.campaign.get("active_scene",""))
		for kind in ["normal","hover","pressed"]:
			var style:=Hearth20Design.panel(Hearth20Design.RAISED if active or kind!="normal" else Hearth20Design.SURFACE,0,10,Hearth20Design.GOLD if active else Hearth20Design.BORDER)
			style.corner_radius_top_left=10;style.corner_radius_top_right=10;style.border_width_bottom=3 if active else 0
			button.add_theme_stylebox_override(kind,style)
		button.pressed.connect(func():_open.call_deferred(id,false))
		button.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
				open_context(id,Vector2i(button.get_global_transform()*event.position));button.accept_event())
		tabs.add_child(button)
		button.size.x=clampf(button.get_minimum_size().x,116,190)
		button.custom_minimum_size.x=button.size.x
	Hearth20Regal.sync(self)
func open_context(id: String,point: Vector2i) -> void:
	if app.session.local_role!="dm" or Hearth20Contracts.find_scene(app.campaign,id).is_empty():return
	target=id;menu.popup_at(Vector2(point))
func _context_action(action: int) -> void:
	var destination=target;menu.hide();_open.call_deferred(destination,action==1)
func _open(id: String,heroes: bool) -> void:
	var result:=app._switch_library_scene(id,heroes,heroes)
	if not result.ok:app._on_status(str(result.get("error","Could not open map.")))
	elif heroes:app._on_status("All hero tokens brought to "+str(result.title)+". Token ownership and movement permissions are preserved.")
	refresh()
