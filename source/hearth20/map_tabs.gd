extends HBoxContainer
class_name Hearth20MapTabs
## A scrollable browser-like tab strip. Right-click acts on the clicked map ID.
var app: Hearth20App
var tabs: HBoxContainer
var menu: PopupMenu
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
	menu=PopupMenu.new();menu.theme=Hearth20Design.theme();menu.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Design.SURFACE,5,10,Hearth20Design.GOLD,true));menu.add_theme_color_override("font_color",Hearth20Design.INK)
	menu.add_item("Open this map",0);menu.add_item("Bring all heroes here",1);menu.id_pressed.connect(_context_action);add_child(menu)
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
		button.pressed.connect(func():_open(id,false))
		button.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
				open_context(id,Vector2i(get_global_mouse_position()));button.accept_event())
		tabs.add_child(button)
		button.size.x=clampf(button.get_minimum_size().x,116,190)
		button.custom_minimum_size.x=button.size.x
	Hearth20Regal.sync(self)
func open_context(id: String,point: Vector2i) -> void:
	if app.session.local_role!="dm" or Hearth20Contracts.find_scene(app.campaign,id).is_empty():return
	target=id;menu.position=point;menu.popup()
func _context_action(action: int) -> void:
	_open(target,action==1)
func _open(id: String,heroes: bool) -> void:
	var result:=app._switch_library_scene(id,heroes,heroes)
	if not result.ok:app._on_status(str(result.get("error","Could not open map.")))
	elif heroes:app._on_status("All hero tokens brought to "+str(result.title)+". Token ownership and movement permissions are preserved.")
	refresh()
