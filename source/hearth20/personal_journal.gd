extends VBoxContainer
class_name Hearth20PersonalJournal
var app: Hearth20App
var editor: TextEdit
var target: OptionButton
var status: Label
var timer: Timer
var dirty=false
var submitting=false
var selected="dm-local"
var identity=""
var roster_key=""
func setup(owner_app: Hearth20App) -> void:
	app=owner_app;size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_theme_constant_override("separation",8)
	var heading=Label.new();heading.text="PERSONAL NOTES & ITEMS";heading.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD));add_child(heading)
	target=OptionButton.new();target.fit_to_longest_item=false;add_child(target);target.item_selected.connect(func(index):flush();selected=str(target.get_item_metadata(index));dirty=false;refresh(true))
	editor=TextEdit.new();editor.placeholder_text="Session notes, homebrew items, clues…";editor.custom_minimum_size.y=200;editor.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;add_child(editor)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",12);add_child(status)
	var row=HBoxContainer.new();add_child(row)
	var save=Button.new();save.text="Save notes now";save.pressed.connect(flush);row.add_child(save)
	var inventory=Button.new();inventory.text="Items & inventory";inventory.size_flags_horizontal=Control.SIZE_EXPAND_FILL;inventory.pressed.connect(func():Hearth20ItemsWindow.open(app));row.add_child(inventory)
	timer=Timer.new();timer.one_shot=true;timer.wait_time=.65;timer.timeout.connect(flush);add_child(timer)
	editor.text_changed.connect(func():dirty=true;status.text="Saving notes to the host…";timer.start())
	app.session.snapshot_received.connect(func(_value):refresh());app.session.state_changed.connect(func(_value):refresh());app.session.belongings_result.connect(_result)
	refresh(true)
func flush() -> void:
	if not dirty or submitting:return
	timer.stop();submitting=true
	var command={"action":"notes","text":editor.text}
	if app.session.local_role=="dm":command.target=selected
	var result=app.session.belongings_action(command)
	if not result.ok:submitting=false;status.text=str(result.error)
func _result(result: Dictionary) -> void:
	if not submitting or result.get("action")!="notes":return
	submitting=false
	if result.get("ok",false) and result.has("text"):
		if result.text==editor.text:dirty=false;status.text="Stored in the DM's campaign · kept by Save and Autosave."
		else:timer.start()
	elif not result.get("ok",false):status.text=str(result.get("error","Could not store notes. Try Save notes now."))
func refresh(force=false) -> void:
	if force:dirty=false;submitting=false;timer.stop()
	var session=app.session;var dm=session.local_role=="dm";var new_identity=session.local_role+":"+session.local_player_id
	if identity!=new_identity:identity=new_identity;dirty=false;submitting=false;selected="dm-local" if dm else session.local_player_id;force=true;roster_key=""
	target.visible=dm
	var roster=str(app.campaign.get("participants",{})) if dm else ""
	if dm and roster_key!=roster:
		roster_key=roster;target.clear();target.add_item("My personal notes");target.set_item_metadata(0,"dm-local")
		for id in app.campaign.get("participants",{}):
			target.add_item(str(app.campaign.participants[id].get("display_name","Player"))+" · saved notes");target.set_item_metadata(target.item_count-1,id)
		for i in target.item_count:
			if target.get_item_metadata(i)==selected:target.select(i)
	var connected=dm or (not session.local_player_id.is_empty() and session.client_snapshot.get("belongings_supported",false))
	editor.editable=connected
	if not connected:editor.set_block_signals(true);editor.text="";editor.set_block_signals(false);dirty=false;status.text="Join an updated host to use your saved journal and inventory.";return
	if force or not dirty:
		var text=str(app.campaign.get("player_journals",{}).get(selected,"")) if dm else str(session.client_snapshot.get("personal_notes",""))
		if editor.text!=text:editor.set_block_signals(true);editor.text=text;editor.set_block_signals(false)
		status.text="Personal to this player and the DM · saved with the campaign."
