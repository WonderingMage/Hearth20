extends Window
class_name Hearth20MapLibraryWindow
## Searchable native gallery with a real lighting-enabled board preview.
var app: Node
var search: LineEdit
var categories: OptionButton
var cards: GridContainer
var preview: Hearth20BoardCanvas
var heading: Label
var description: Label
var lighting_note: Label
var move_party: CheckButton
var add_button: Button
var error_note: Label
var selected_id := ""
var preview_campaign: Dictionary={}
var campaign_list: VBoxContainer

func setup(owner_app: Node) -> void:
	app=owner_app
	title="Hearth20 · Sample Map Library"
	min_size=Vector2i(820,580)
	size=Vector2i(mini(1120,app.get_viewport_rect().size.x-50),mini(790,app.get_viewport_rect().size.y-50))
	theme=Hearth20Design.theme()
	close_requested.connect(queue_free)
	var background:=ColorRect.new()
	background.color=Hearth20Regal.swatch(Hearth20Regal.BG)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	add_child(margin)
	var root:=VBoxContainer.new()
	root.add_theme_constant_override("separation",14)
	margin.add_child(root)
	var eyebrow:=_label("THE HEARTH20 STARTER COLLECTION",10,Hearth20Design.GOLD)
	root.add_child(eyebrow)
	var title_label:=_label("A scene for every adventure.",28,Hearth20Design.INK)
	title_label.add_theme_font_override("font",Hearth20Design.font(true))
	root.add_child(title_label)
	var tabs:=TabContainer.new()
	tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	var sample_page:=VBoxContainer.new()
	sample_page.name="Samples · 15"
	sample_page.add_theme_constant_override("separation",12)
	tabs.add_child(sample_page)
	var filters:=HBoxContainer.new()
	filters.add_theme_constant_override("separation",10)
	sample_page.add_child(filters)
	search=LineEdit.new()
	search.placeholder_text="Search inns, caves, ruins…"
	search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	search.max_length=96
	search.text_changed.connect(func(_value): _populate())
	filters.add_child(search)
	categories=OptionButton.new()
	for category in ["All maps","Interiors","Wilderness","Ruins","Underground","Strongholds","Settlements","Coastal"]: categories.add_item(category)
	categories.item_selected.connect(func(_index): _populate())
	filters.add_child(categories)
	var split:=HSplitContainer.new()
	split.size_flags_vertical=Control.SIZE_EXPAND_FILL
	split.split_offset=390
	sample_page.add_child(split)
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x=350
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	cards=GridContainer.new()
	cards.columns=2
	cards.add_theme_constant_override("h_separation",10)
	cards.add_theme_constant_override("v_separation",10)
	cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(cards)
	var detail:=VBoxContainer.new()
	detail.custom_minimum_size.x=360
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",10)
	split.add_child(detail)
	var frame:=PanelContainer.new()
	frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size.y=230
	frame.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Design.SURFACE,12,0,Hearth20Design.BORDER))
	detail.add_child(frame)
	preview=Hearth20BoardCanvas.new()
	preview.read_only_preview=true
	preview.lighting_preview=true
	frame.add_child(preview)
	heading=_label("",23,Hearth20Design.INK)
	heading.add_theme_font_override("font",Hearth20Design.font(true))
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(heading)
	description=_label("",13,Hearth20Design.MUTED)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(description)
	lighting_note=_label("",11,Hearth20Design.GOLD)
	lighting_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(lighting_note)
	var mood:=CheckButton.new()
	mood.text="Preview lighting & god rays"
	mood.button_pressed=true
	mood.toggled.connect(func(v): preview.lighting_preview=v; preview.queue_redraw())
	detail.add_child(mood)
	var campaign_page:=ScrollContainer.new()
	campaign_page.name="Campaign scenes"
	campaign_page.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(campaign_page)
	campaign_list=VBoxContainer.new()
	campaign_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	campaign_list.add_theme_constant_override("separation",10)
	campaign_page.add_child(campaign_list)
	for scene in app.campaign.get("scenes",[]):
		var scene_id:=str(scene.id)
		var button:=Button.new()
		button.text=str(scene.get("title","Scene"))+(" · Current" if scene_id==app.campaign.active_scene else "")
		button.icon=Hearth20Design.icon("map",20)
		button.add_theme_constant_override("icon_max_width",20)
		button.custom_minimum_size.y=46
		button.pressed.connect(func():
			var result: Dictionary=app._switch_library_scene(scene_id,move_party.button_pressed)
			if result.get("ok",false): queue_free()
			else: error_note.text=str(result.get("error","Could not switch scenes.")))
		campaign_list.add_child(button)
	move_party=CheckButton.new()
	move_party.text="Bring party heroes to the selected scene"
	move_party.button_pressed=true
	root.add_child(move_party)
	var footer:=HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	root.add_child(footer)
	error_note=_label("Adds a new scene. Your current scene is kept.",12,Hearth20Design.MUTED)
	error_note.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	error_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(error_note)
	add_button=Button.new()
	add_button.text="Add this map"
	add_button.custom_minimum_size=Vector2(166,40)
	Hearth20Design.primary(add_button)
	add_button.pressed.connect(func():
		var result: Dictionary=app._load_sample_map(selected_id,move_party.button_pressed)
		if result.get("ok",false): queue_free()
		else: error_note.text=str(result.get("error","Map could not be added.")))
	footer.add_child(add_button)
	tabs.tab_changed.connect(func(index): add_button.visible=index==0)
	_populate()
	if not Hearth20MapLibrary.catalog().is_empty(): select_map(str(Hearth20MapLibrary.catalog()[0].id))

func _label(value: String, pixels: int, color: Color) -> Label:
	var result:=Label.new()
	result.text=value
	result.add_theme_font_size_override("font_size",pixels)
	result.add_theme_color_override("font_color",Hearth20Regal.resolve(color))
	return result

func _populate() -> void:
	for child in cards.get_children(): cards.remove_child(child); child.queue_free()
	var query:=search.text.strip_edges().to_lower()
	var category:=categories.get_item_text(categories.selected)
	var group:=ButtonGroup.new()
	for map in Hearth20MapLibrary.catalog():
		if categories.selected>0 and category!=str(map.category): continue
		if not query.is_empty() and not query in (str(map.title)+" "+str(map.description)+" "+str(map.category)).to_lower(): continue
		var map_id:=str(map.id)
		var card:=Button.new()
		card.custom_minimum_size=Vector2(162,154)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.toggle_mode=true
		card.set_meta("map_id",map_id)
		card.button_group=group
		card.button_pressed=selected_id==map_id
		card.tooltip_text=str(map.title)+" · "+str(map.category)
		card.pressed.connect(func(): select_map(map_id))
		cards.add_child(card)
		var body:=VBoxContainer.new()
		body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.offset_left=7; body.offset_right=-7; body.offset_top=7; body.offset_bottom=-7
		body.mouse_filter=Control.MOUSE_FILTER_IGNORE
		body.add_theme_constant_override("separation",5)
		card.add_child(body)
		var image:=TextureRect.new()
		image.texture=Hearth20MapLibrary.texture(map_id)
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.size_flags_vertical=Control.SIZE_EXPAND_FILL
		image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		body.add_child(image)
		var name_label:=_label(str(map.title),12,Hearth20Design.INK)
		name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		body.add_child(name_label)
		var meta:=_label(str(map.category)+" · 32 × 24 · "+str(map.light_count)+" lights",10,Hearth20Design.MUTED)
		meta.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		meta.mouse_filter=Control.MOUSE_FILTER_IGNORE
		body.add_child(meta)
	if cards.get_child_count()==0: cards.add_child(_label("No maps match this search.",13,Hearth20Design.MUTED))

func select_map(map_id: String) -> void:
	var record:=Hearth20MapLibrary.find(map_id)
	var scene:=Hearth20MapLibrary.scene(map_id)
	if record.is_empty() or scene.is_empty():
		error_note.text="The selected bundled map could not be opened."; add_button.disabled=true; return
	selected_id=map_id
	for card in cards.get_children():
		if card is Button: card.set_pressed_no_signal(str(card.get_meta("map_id",""))==map_id)
	preview_campaign=Hearth20Identity.new_campaign()
	preview_campaign.scenes=[scene]
	preview_campaign.active_scene=scene.id
	var art:=Hearth20MapLibrary.texture(map_id,false)
	preview.preview_texture=art
	scene.map_asset="preview-art"
	preview.set_campaign(preview_campaign,null,"dm")
	preview.lighting_cache_key=""
	preview.fit_map()
	heading.text=str(record.title)
	description.text=str(record.description)
	lighting_note.text="32 × 24 squares · 5 ft / square · %d lights\n%s"%[int(record.light_count),", ".join(record.source_types)]
	add_button.disabled=false
