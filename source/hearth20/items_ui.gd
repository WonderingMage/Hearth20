extends Window
class_name Hearth20ItemsWindow
var app: Hearth20App
var listing: ItemList
var portrait: TextureRect
var heading: Label
var body: Label
var status: Label
var actions: VBoxContainer
var entries: Array=[]
var selected_id=""
var signature=""
var search: LineEdit
static func open(owner_app: Hearth20App,id="") -> Hearth20ItemsWindow:
	var window=Hearth20ItemsWindow.new();window.app=owner_app;window.selected_id=id
	(owner_app.seated_shell if owner_app.seated_shell!=null else owner_app).add_child(window);window.setup();return window
static func button(parent: Node,text: String,callback: Callable) -> Button:
	var value=Button.new();value.text=text;value.custom_minimum_size.y=36;value.pressed.connect(callback);parent.add_child(value);return value
func setup() -> void:
	title="Hearth20 · Items & inventory";size=Vector2i(940,700);min_size=Vector2i(780,580);theme=Hearth20Design.theme();transient=true;close_requested.connect(queue_free)
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.BG),3,22,Hearth20Regal.swatch(Hearth20Regal.GOLD)));add_child(panel)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box)
	var title_label=Label.new();title_label.text="✦  THE CAMPAIGN ITEM VAULT" if app.session.local_role=="dm" else "✦  YOUR ADVENTURER'S INVENTORY";title_label.add_theme_font_size_override("font_size",25);box.add_child(title_label)
	var top=HBoxContainer.new();box.add_child(top);search=LineEdit.new();search.placeholder_text="Find an item…";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search.text_changed.connect(func(_text):refresh(true));top.add_child(search)
	if app.session.local_role=="dm":button(top,"+ Create item",create_editor)
	var row=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_theme_constant_override("separation",20);box.add_child(row)
	listing=ItemList.new();listing.custom_minimum_size.x=280;listing.size_flags_horizontal=Control.SIZE_EXPAND_FILL;listing.size_flags_vertical=Control.SIZE_EXPAND_FILL;listing.fixed_icon_size=Vector2i(64,64);listing.max_text_lines=2;listing.allow_rmb_select=true;row.add_child(listing)
	listing.item_selected.connect(func(index):selected_id=entries[index].id;detail())
	listing.item_clicked.connect(func(index,_at,mouse_button):if mouse_button==MOUSE_BUTTON_RIGHT:selected_id=entries[index].id;detail();inventory_context())
	var scroll=ScrollContainer.new();scroll.custom_minimum_size.x=340;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;row.add_child(scroll)
	var detail_box=VBoxContainer.new();detail_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_box.add_theme_constant_override("separation",12);scroll.add_child(detail_box)
	portrait=TextureRect.new();portrait.custom_minimum_size=Vector2(192,192);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;detail_box.add_child(portrait)
	heading=Label.new();heading.add_theme_font_size_override("font_size",23);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail_box.add_child(heading)
	body=Label.new();body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_theme_font_size_override("font_size",16);detail_box.add_child(body)
	actions=VBoxContainer.new();detail_box.add_child(actions)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status);status.text="Right-click an item for actions. Items and images are kept in the DM's campaign save."
	button(box,"Return to table",queue_free)
	app.session.state_changed.connect(func(_state):refresh());app.session.snapshot_received.connect(func(_state):refresh());app.session.belongings_result.connect(func(result):status.text=str(result.get("message",result.get("error","Item created."))))
	refresh(true);Hearth20Design.popup_window(self)
func refresh(force=false) -> void:
	var raw=app.campaign.get("custom_items",[]) if app.session.local_role=="dm" else app.session.client_snapshot.get("item_inventory",[])
	if app.session.local_role=="player":raw=raw+app.session.client_snapshot.get("board_items",[]).filter(func(item):return item.id==selected_id)
	var key=str(raw)+search.text
	if not force and key==signature:return
	signature=key;entries=[];listing.clear()
	for item in raw:
		if not search.text.is_empty() and not search.text.to_lower() in (item.name+" "+item.description).to_lower():continue
		entries.append(item);var label=item.name
		if app.session.local_role=="dm":
			label+="\n"+("DM vault" if item.holder=="dm-local" else "On map · "+("concealed" if item.hidden else "revealed") if item.holder.is_empty() else "Held by "+str(app.campaign.get("participants",{}).get(item.holder,{}).get("display_name","Player")))
		listing.add_item(label,app.board._actor_texture(str(item.get("png_asset_id",item.get("asset_id","")))))
		if item.id==selected_id:listing.select(entries.size()-1)
	detail()
func detail() -> void:
	for child in actions.get_children():actions.remove_child(child);child.queue_free()
	var chosen={}
	for item in entries:
		if item.id==selected_id:chosen=item;break
	portrait.texture=null;heading.text="Choose an item";body.text="Your keepsakes, keys and homebrew treasures will appear here."
	if chosen.is_empty():return
	heading.text=chosen.name;body.text=chosen.description if not chosen.description.is_empty() else "No description.";portrait.texture=app.board._actor_texture(str(chosen.get("png_asset_id",chosen.get("asset_id",""))))
	if app.session.local_role=="dm":
		button(actions,"Place on current map…",place)
		button(actions,"Reveal to players" if chosen.hidden else "Conceal from players",func():act({"action":"hide","id":selected_id,"hidden":not chosen.hidden}))
		button(actions,"Return to DM item vault",func():act({"action":"stow","id":selected_id}))
		var picker=OptionButton.new();picker.fit_to_longest_item=false;actions.add_child(picker)
		for id in app.campaign.get("participants",{}):picker.add_item(str(app.campaign.participants[id].get("display_name","Player")));picker.set_item_metadata(picker.item_count-1,id)
		var give=button(actions,"Give directly to player",func():if picker.selected>=0:act({"action":"give","id":selected_id,"target":picker.get_item_metadata(picker.selected)}));give.disabled=picker.item_count==0
	elif app.session.client_snapshot.get("board_items",[]).any(func(item):return item.id==selected_id):button(actions,"Place in my inventory",func():act({"action":"pickup","id":selected_id}))
	if app.session.local_role=="dm" or app.session.client_snapshot.get("item_inventory",[]).any(func(item):return item.id==selected_id):button(actions,"Destroy item…",confirm_destroy)
func act(command: Dictionary) -> void:
	var result=app.session.belongings_action(command);status.text=str(result.get("message",result.get("error","Waiting for the DM…")));refresh(true);app.board.queue_redraw()
func place() -> void:
	app.board.activate_tool("item_place",true);app.board.pending_item_id=selected_id
	if app.seated_shell!=null:app.seated_shell.focus_map()
	app._on_status("Click a map square to place the item. Escape cancels.");queue_free()
func inventory_context() -> void:
	var menu=PopupMenu.new();add_child(menu);menu.add_item("Read item",0);menu.add_item("Destroy item…",1);menu.id_pressed.connect(func(id):if id==1:confirm_destroy());menu.popup_hide.connect(menu.queue_free);menu.position=DisplayServer.mouse_get_position();menu.popup()
func confirm_destroy() -> void:
	var id=selected_id;var dialog=ConfirmationDialog.new();dialog.title="Destroy this item?";dialog.dialog_text="This removes the item from the campaign. It cannot be picked up again.";dialog.ok_button_text="Destroy item";add_child(dialog);dialog.confirmed.connect(func():act({"action":"destroy","id":id}));dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free);dialog.popup_centered(Vector2i(470,180))
func create_editor() -> void:
	var window=Window.new();window.title="Hearth20 · Create custom item";window.size=Vector2i(580,550);window.min_size=Vector2i(500,500);window.theme=theme;window.transient=true;add_child(window);window.close_requested.connect(window.queue_free)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);window.add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,20)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);margin.add_child(column)
	var name_input=LineEdit.new();name_input.placeholder_text="Item name · e.g. Centipede bracelet";name_input.max_length=80;column.add_child(name_input)
	var description=TextEdit.new();description.placeholder_text="What it looks like, how it works, or simply ‘orange’.";description.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;description.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(description)
	var image_note=Label.new();image_note.text="PNG required · optimized to 512 pixels for quick transfer";image_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(image_note)
	var payload={"png":PackedByteArray()}
	var picker=FileDialog.new();picker.access=FileDialog.ACCESS_FILESYSTEM;picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE;picker.add_filter("*.png","Item PNG");picker.use_native_dialog=OS.get_name()=="Windows";window.add_child(picker)
	var dismiss:=Hearth20Design.dismiss_file_picker.bind(picker)
	picker.file_selected.connect(func(path):
		dismiss.call()
		var inspected=Hearth20Assets.inspect_token_png(path)
		if inspected.ok:payload.png=inspected.bytes;image_note.text=path.get_file()+" · ready"
		else:image_note.text=inspected.error)
	picker.canceled.connect(dismiss);picker.close_requested.connect(dismiss)
	button(column,"Choose item PNG…",func():Hearth20Design.open_file_picker(picker,.7))
	button(column,"Create in DM vault",func():
		var result=app.session.create_custom_item(name_input.text,description.text,payload.png)
		if result.ok:selected_id=result.id;refresh(true);window.queue_free()
		else:image_note.text=str(result.error))
	button(column,"Cancel",window.queue_free);Hearth20Design.popup_window(window)
static func board_context(board: Hearth20BoardCanvas,item: Dictionary,at: Vector2) -> void:
	var menu=PopupMenu.new();board.add_child(menu);menu.add_item("Read · "+item.name,0)
	if board.role=="dm":menu.add_item("Reveal item" if item.hidden else "Conceal item",2);menu.add_item("Return to item vault",3)
	else:menu.add_item("Place in my inventory",1)
	menu.id_pressed.connect(func(id):
		if id==0:
			var app=board.get_parent()
			while app!=null and not app is Hearth20App:app=app.get_parent()
			if app!=null:
				open(app,item.id)
		else:
			var command={"action":"pickup","id":item.id} if id==1 else {"action":"hide","id":item.id,"hidden":not item.hidden} if id==2 else {"action":"stow","id":item.id}
			var result=board.session.belongings_action(command);board.hint_changed.emit(str(result.get("message",result.get("error","Waiting for the DM…"))));board.queue_redraw())
	menu.popup_hide.connect(menu.queue_free);menu.position=Vector2i(board.get_screen_transform()*at);menu.popup()
