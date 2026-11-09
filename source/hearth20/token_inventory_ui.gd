extends Window
class_name Hearth20TokenInventoryWindow
var app: Hearth20App
var search: LineEdit
var filter: OptionButton
var cards: GridContainer
var counts: Label
var selected_note: Label
var status: Label
var page_note: Label
var editor: Hearth20TokenPanel
var new_name: LineEdit
var kind: OptionButton
var store_button: Button
var place_button: Button
var duplicate_button: Button
var selected_id:=""
var revision:=-1
var theme_revision:=-1
var page:=0
var visible_entries: Array=[]
func setup(owner_app: Hearth20App) -> void:
	app=owner_app; title="Hearth20 · Campaign token inventory"; theme=Hearth20Design.theme(); min_size=Vector2i(940,620); size=Vector2i(1240,800); close_requested.connect(queue_free)
	tree_exiting.connect(func():
		var actor:=Hearth20Contracts.find_actor(app.campaign,app.board.selected_actor_id)
		if actor.get("in_inventory",false) or actor.get("scene_id",app.campaign.active_scene)!=app.campaign.active_scene: app.board.selected_actor_id=""; app.board.selection_changed.emit(""); app.board.queue_redraw())
	var background:=ColorRect.new(); background.color=Hearth20Regal.swatch(Hearth20Regal.BG); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin:=MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,22)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",12); margin.add_child(column)
	var heading:=_label("The campaign token vault",30); heading.add_theme_font_override("font",Hearth20Design.font(true)); column.add_child(heading)
	var drop=Button.new();drop.text="✧  DROP A MAP TOKEN HERE TO STOW IT  ✧";drop.custom_minimum_size.y=54;drop.tooltip_text="Drag stored token cards back onto the map to place them.";column.add_child(drop)
	drop.set_drag_forwarding(Callable(),func(_p,data):return Hearth20TokenDrag.accepts(app.session,data),func(_p,data):_result(app.session.store_inventory_token(str(data.actor_id))))
	counts=_label("",13); column.add_child(counts)
	var tools:=HBoxContainer.new(); tools.add_theme_constant_override("separation",10); column.add_child(tools)
	search=LineEdit.new(); search.placeholder_text="Search all campaign tokens…"; search.size_flags_horizontal=Control.SIZE_EXPAND_FILL; search.text_changed.connect(func(_text): page=0; refresh()); tools.add_child(search)
	filter=OptionButton.new()
	for name_value in ["All campaign tokens","Stored in inventory","On this map","On other maps"]: filter.add_item(name_value)
	filter.item_selected.connect(func(_index): page=0; refresh()); tools.add_child(filter)
	_button(tools,"Center map tokens",func(): _result(app.session.center_scene_tokens()))
	var body:=HBoxContainer.new(); body.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",18); column.add_child(body)
	var gallery:=VBoxContainer.new(); gallery.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_child(gallery)
	var create:=HBoxContainer.new(); create.add_theme_constant_override("separation",8); gallery.add_child(create)
	new_name=LineEdit.new(); new_name.placeholder_text="New inventory token name"; new_name.max_length=64; new_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL; create.add_child(new_name)
	kind=OptionButton.new(); kind.add_item("Creature / object"); kind.add_item("Character"); create.add_child(kind)
	_button(create,"Add to inventory",_create)
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; gallery.add_child(scroll)
	cards=GridContainer.new(); cards.columns=3; cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL; cards.add_theme_constant_override("h_separation",10); cards.add_theme_constant_override("v_separation",10); scroll.add_child(cards)
	var pages:=HBoxContainer.new(); gallery.add_child(pages); _button(pages,"‹ Previous",func(): page=maxi(0,page-1); refresh()); page_note=_label("",12); page_note.size_flags_horizontal=Control.SIZE_EXPAND_FILL; page_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; pages.add_child(page_note)
	_button(pages,"Next ›",func():
		if (page+1)*24<visible_entries.size(): page+=1; refresh())
	var inspector:=VBoxContainer.new(); inspector.custom_minimum_size.x=300; body.add_child(inspector)
	selected_note=_label("Choose a token to inspect.",14); selected_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; inspector.add_child(selected_note)
	place_button=_button(inspector,"Place on current map",_place); store_button=_button(inspector,"Return to inventory",func(): _result(app.session.store_inventory_token(selected_id)))
	duplicate_button=_button(inspector,"Duplicate into inventory",func():
		var result: Dictionary=app.session.duplicate_inventory_token(selected_id); _result(result)
		if result.ok: select_token(str(result.id)))
	var detail_scroll:=ScrollContainer.new(); detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; inspector.add_child(detail_scroll)
	editor=Hearth20TokenPanel.new(); editor.inventory_context=true; editor.size_flags_horizontal=Control.SIZE_EXPAND_FILL; detail_scroll.add_child(editor); editor.setup(app)
	status=_label("Stored tokens keep their image and player assignment. Save the campaign to retain the inventory.",12); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(status)
	selected_id=app.board.selected_actor_id; refresh(); Hearth20Design.popup_window(self)
func _label(caption: String, points: int) -> Label:
	var label:=Label.new(); label.text=caption; label.add_theme_font_size_override("font_size",points); label.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.INK)); return label
func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button:=Button.new(); button.text=caption; button.custom_minimum_size.y=36; button.pressed.connect(action); parent.add_child(button); return button
func _process(_delta: float) -> void:
	if app==null: return
	Hearth20Regal.sync(self)
	if theme_revision!=Hearth20Regal.revision: theme_revision=Hearth20Regal.revision; refresh()
	if app.session.local_role!="dm": queue_free(); return
	if selected_id!=app.board.selected_actor_id:
		selected_id=app.board.selected_actor_id; refresh()
	if revision!=int(app.campaign.get("revision",0)): refresh()
func refresh() -> void:
	revision=int(app.campaign.get("revision",0))
	var all:=Hearth20TokenInventory.entries(app.campaign); var stored:=all.filter(func(actor): return actor.get("in_inventory",false)).size()
	counts.text="%d campaign tokens   ·   %d stored   ·   %d placed across maps"%[all.size(),stored,all.size()-stored]
	visible_entries=all.filter(func(actor):
		if not search.text.strip_edges().is_empty() and not search.text.to_lower() in str(actor.get("name","")).to_lower(): return false
		var held: bool=actor.get("in_inventory",false); var here: bool=actor.get("scene_id","")==app.campaign.active_scene
		return filter.selected==0 or (filter.selected==1 and held) or (filter.selected==2 and not held and here) or (filter.selected==3 and not held and not here))
	visible_entries.sort_custom(func(a,b): return str(a.get("name","")).naturalnocasecmp_to(str(b.get("name","")))<0)
	page=clampi(page,0,maxi(0,ceili(visible_entries.size()/24.0)-1))
	for child in cards.get_children(): cards.remove_child(child); child.queue_free()
	for actor in visible_entries.slice(page*24,(page+1)*24): _card(actor)
	page_note.text="%d matches  ·  Page %d / %d"%[visible_entries.size(),page+1,maxi(1,ceili(visible_entries.size()/24.0))]
	var actor:=Hearth20Contracts.find_actor(app.campaign,selected_id)
	place_button.disabled=actor.is_empty(); duplicate_button.disabled=actor.is_empty(); store_button.disabled=actor.is_empty() or actor.get("in_inventory",false)
	selected_note.text=(str(actor.get("name",""))+"\n"+_location(actor)) if not actor.is_empty() else "Choose a token to inspect."
func _location(actor: Dictionary) -> String:
	if actor.get("in_inventory",false): return "Stored in inventory"
	return "On "+str(Hearth20Contracts.find_scene(app.campaign,str(actor.get("scene_id",""))).get("title","another map"))
func _card(actor: Dictionary) -> void:
	var button:=Button.new(); button.custom_minimum_size=Vector2(170,164); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.tooltip_text=str(actor.get("name","Token"))+" · "+_location(actor); cards.add_child(button)
	if str(actor.id)==selected_id:
		button.add_theme_stylebox_override("normal",Hearth20Regal.button_style("pressed")); button.set_meta("regal_button_revision",Hearth20Regal.revision)
	var box:=VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.offset_left=10; box.offset_top=10; box.offset_right=-10; box.offset_bottom=-8; box.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(box)
	var texture: Texture2D=app.board._actor_texture(str(actor.get("png_asset_id","")))
	if texture!=null:
		var image:=TextureRect.new(); image.texture=texture; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.custom_minimum_size.y=91; image.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.add_child(image)
	else:
		var crest:=_label(str(actor.get("name","?")).left(1).to_upper(),48); crest.custom_minimum_size.y=91; crest.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; crest.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.add_child(crest)
	var name_label:=_label(str(actor.get("name","Token")),14); name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.add_child(name_label)
	var location:=_label(_location(actor),11); location.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; location.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.add_child(location)
	button.pressed.connect(func(): select_token(str(actor.id)))
	button.set_drag_forwarding(func(_p):
		if not actor.get("in_inventory",false):return null
		button.set_drag_preview(Hearth20TokenDrag.preview(app.board,actor));return Hearth20TokenDrag.payload(app.session,str(actor.id)),Callable(),Callable())
func select_token(id: String) -> void:
	selected_id=id; app.board.selected_actor_id=id; app.board.selection_changed.emit(id); app.board.queue_redraw(); editor._refresh_selection(); refresh()
func _result(result: Dictionary) -> void:
	status.text="Campaign token inventory updated. Save the campaign to keep it." if result.ok else str(result.get("error","Token action failed.")); app.board.queue_redraw(); refresh()
func _create() -> void:
	var result: Dictionary=app.session.create_inventory_token(new_name.text,kind.selected==1); _result(result)
	if result.ok: new_name.clear(); select_token(str(result.id))
func _place() -> void:
	if Hearth20Contracts.find_actor(app.campaign,selected_id).is_empty(): return
	app.board.activate_tool("token_place",true); app.board.pending_token={"actor_id":selected_id}; app._on_status("Click and release on the map to place the inventory token. Escape cancels."); hide(); queue_free()
