extends VBoxContainer
class_name Hearth20TokenPanel
var app: Hearth20App
var new_name: LineEdit
var kind: OptionButton
var list: OptionButton
var token_name: LineEdit
var token_size: SpinBox
var shown: CheckBox
var controller: OptionButton
var may_move: CheckBox
var portrait: TextureRect
var detail: VBoxContainer
var status: Label
var signature:=""
var selected_id:=""
var controls: Array=[]
var inventory_context:=false
func setup(owner_app: Hearth20App) -> void:
	app=owner_app; add_theme_constant_override("separation",9)
	if not inventory_context: _button("Open campaign token inventory",func(): app.open_token_inventory())
	var creation:=VBoxContainer.new(); creation.visible=not inventory_context; add_child(creation)
	var heading:=Label.new(); heading.text="CREATE A TOKEN"; creation.add_child(heading)
	heading.visible=not inventory_context
	new_name=LineEdit.new(); new_name.placeholder_text="Token name"; new_name.max_length=64; creation.add_child(new_name)
	new_name.visible=not inventory_context
	kind=OptionButton.new(); kind.add_item("Creature / object"); kind.add_item("Player character"); creation.add_child(kind)
	kind.visible=not inventory_context
	_button("Place on the map",func():
		if new_name.text.strip_edges().is_empty(): status.text="Give the token a name first."; return
		app.board.activate_tool("token_place",true)
		app.board.pending_token={"name":new_name.text,"hero":kind.selected==1}
		status.text="Click and release on the map to place it. Escape cancels.",creation)
	var divider:=HSeparator.new(); add_child(divider)
	var label:=Label.new(); label.text="EDIT & ASSIGN"; add_child(label)
	list=OptionButton.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; add_child(list)
	list.item_selected.connect(func(index):
		app.board.selected_actor_id=str(list.get_item_metadata(index)); app.board.selection_changed.emit(app.board.selected_actor_id); app.board.queue_redraw(); _refresh_selection())
	detail=VBoxContainer.new(); detail.add_theme_constant_override("separation",9); add_child(detail)
	portrait=TextureRect.new(); portrait.custom_minimum_size=Vector2(100,100); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; detail.add_child(portrait)
	token_name=LineEdit.new(); token_name.max_length=64; token_name.placeholder_text="Selected token name"; detail.add_child(token_name)
	var size_label:=Label.new(); size_label.text="Token size · grid squares"; detail.add_child(size_label)
	token_size=SpinBox.new(); token_size.min_value=.25; token_size.max_value=4; token_size.step=.25; detail.add_child(token_size)
	shown=CheckBox.new(); shown.text="Visible to players with sight"; detail.add_child(shown)
	_button("Choose token image…",func(): app.token_dialog.popup_centered_ratio(.75),detail)
	_button("Apply appearance",_apply,detail)
	var grant_label:=Label.new(); grant_label.text="CONTROLLED BY"; detail.add_child(grant_label)
	controller=OptionButton.new(); detail.add_child(controller)
	may_move=CheckBox.new(); may_move.text="Allow movement in exploration"; may_move.button_pressed=true; detail.add_child(may_move)
	controller.item_selected.connect(func(index):
		var dm_only:=str(controller.get_item_metadata(index)).is_empty()
		may_move.disabled=dm_only; may_move.button_pressed=not dm_only)
	_button("Save control grant",func():
		var id:=str(controller.get_item_metadata(controller.selected))
		var result: Dictionary=app.session.grant_token_control(selected_id,id,may_move.button_pressed)
		status.text="Control updated. Save the campaign to keep this grant." if result.ok else str(result.error)
		app.board.queue_redraw(),detail)
	status=Label.new(); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	status.text="New tokens belong to the DM. Choose a player to grant access. Saved players can be assigned while offline."
	_refresh_list(); _refresh_selection()
func _button(caption: String, action: Callable, parent: Node=null) -> void:
	var button:=Button.new(); button.text=caption; button.custom_minimum_size.y=36; button.pressed.connect(action); (parent if parent!=null else self).add_child(button)
func _process(_delta: float) -> void:
	if app==null: return
	var roster: Array=[]
	for actor in _actors():
		if not actor.get("decorative",false): roster.append([actor.id,actor.get("name","Token"),actor.get("png_asset_id",""),actor.get("hidden",false),actor.get("token_size",1),actor.get("owner_player_id",""),actor.get("movement_policy",{})])
	var key:=str([roster,app.campaign.get("participants",{}),app.session.remote_players.keys()])
	if key!=signature: signature=key; _refresh_list(); _refresh_selection()
	elif selected_id!=app.board.selected_actor_id: _refresh_selection()
func _refresh_list() -> void:
	list.clear()
	for actor in _actors():
		if actor.get("decorative",false): continue
		list.add_item(str(actor.get("name","Token"))); list.set_item_metadata(list.item_count-1,str(actor.id))
func _actors() -> Array:
	return Hearth20TokenInventory.entries(app.campaign) if inventory_context else app.board.current_actors()
func _refresh_selection() -> void:
	selected_id=app.board.selected_actor_id
	var actor:=Hearth20Contracts.find_actor(app.campaign,selected_id)
	detail.visible=not actor.is_empty() and not actor.get("decorative",false)
	if not detail.visible: return
	for i in list.item_count:
		if str(list.get_item_metadata(i))==selected_id: list.select(i)
	token_name.text=str(actor.get("name","Token")); token_size.value=float(actor.get("token_size",1)); shown.button_pressed=not bool(actor.get("hidden",false))
	portrait.texture=app.board._actor_texture(str(actor.get("png_asset_id","")))
	portrait.visible=portrait.texture!=null
	controller.clear(); controller.add_item("DM only"); controller.set_item_metadata(0,"")
	var participants: Dictionary=app.campaign.get("participants",{}).duplicate(true)
	for id in app.session.remote_players:
		if not participants.has(id): participants[id]={"display_name":app.session.remote_players[id].nickname}
	for id in participants:
		controller.add_item(str(participants[id].get("display_name","Player"))+(" · online" if app.session.remote_players.has(id) else " · saved"))
		controller.set_item_metadata(controller.item_count-1,str(id))
		if str(actor.get("owner_player_id",""))==str(id): controller.select(controller.item_count-1)
	may_move.button_pressed=str(actor.get("movement_policy",{}).get("mode","blocked"))!="blocked"
	may_move.disabled=str(actor.get("owner_player_id","")).is_empty()
func _apply() -> void:
	if app.session.local_role!="dm": return
	var actor:=Hearth20Contracts.find_actor(app.campaign,selected_id)
	if actor.is_empty() or token_name.text.strip_edges().is_empty(): status.text="Select and name a token first."; return
	actor.name=token_name.text.strip_edges(); actor.token_size=token_size.value; actor.hidden=not shown.button_pressed
	app.campaign.revision=int(app.campaign.get("revision",0))+1
	app.session._broadcast_snapshots(); app.board.queue_redraw()
	_refresh_list(); status.text="Token appearance updated."
