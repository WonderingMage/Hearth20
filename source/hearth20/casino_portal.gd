extends Node
class_name Hearth20CasinoPortal
## Owns loading, map suspension, table rendering and deterministic teardown.
var app: Hearth20App
var layer: Control
var scene: Hearth20CasinoTable
var loader: Control
var progress: ProgressBar
var load_note: Label
var hud: Control
var status: Label
var detail: VBoxContainer
var actions: VBoxContainer
var summary: Label
var roster: VBoxContainer
var peek_hint: Button
var footer_panel: Control
var left_panel: Control
var book_nav: PanelContainer
var catalog_panel: PanelContainer
var change_game_button: Button
var selected=""
var selected_view_seat=-1
var signature=""
var phase="closed"
var saved: Array=[]
var assets: Dictionary={}
var paths={"art":"res://hearth20/casino/card-art.png","materials":"res://hearth20/casino/materials.png","salon":"res://hearth20/casino/tavern-v2.png","catalog":"res://hearth20/casino/salon.png","book":"res://hearth20/casino/book-materials.png","cover":"res://hearth20/casino/da-rolls-cover.png"}
var loaded: Dictionary={}
var game: Dictionary={}
var started_msec=0
var staged_frames=0
var wheel_payouts={"odd":1,"even":1,"red":1,"black":1,"ends":8,"number":18}
var game_loader: Control
var bet_prefs={}
var table_prefs={}
var balance_notice: Hearth20CasinoBalanceNotice
var balance_drafts={}
var balance_game_id=""
func setup(owner_app: Hearth20App) -> void:
	app=owner_app;app.session.state_changed.connect(func(_s):sync());app.session.snapshot_received.connect(func(_s):sync());app.session.casino_action_result.connect(_result)
	balance_notice=Hearth20CasinoBalanceNotice.new();add_child(balance_notice);balance_notice.setup(app)
func current() -> Dictionary:return Hearth20TavernGames.project(app.campaign,"dm-local") if app.session.local_role=="dm" else app.session.client_snapshot.get("casino",{})
func sync() -> void:
	if app.seated_shell!=null:
		if not app.seated_shell.ready_to_show or app.seated_shell.desired_mode()!="casino":return
		if phase=="closed" and not app.seated_shell.switching:return
	if app.session.local_role=="player" and (app.session.client_snapshot.get("connection_closed",false) or app.session.client_snapshot.is_empty()):
		if phase!="closed":close_local()
		return
	game=current()
	if app.session.local_role=="player" and app.session.client_snapshot.get("character_required",false):return
	if not game.is_empty() and phase=="closed":open()
	elif game.is_empty() and phase in ["ready","warming"] and app.session.local_role=="player" and app.seated_shell==null:close_local()
	if phase=="ready":_refresh()
func open() -> void:
	if phase!="closed":return
	if app.seated_shell!=null and app.seated_shell.desired_mode()!="casino":app.seated_shell.leave_focus();app.seated_shell.look_up=true;return
	if is_instance_valid(app.beyond_sheet):app.beyond_sheet.suspend_native()
	game=current();app.dice_stage.suspended=true;app.dice_stage.clear_rolls();phase="loading";started_msec=Time.get_ticks_msec();saved.clear();loaded.clear();assets.clear()
	# Only visual/gameplay branches pause. Session/RPC processing keeps running.
	for child in app.get_children():
		if child!=self and child!=app.session:
			_capture_branch(child)
	layer=Control.new();layer.name="CasinoExperience";layer.z_index=400;layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.mouse_filter=Control.MOUSE_FILTER_STOP;layer.theme=Hearth20Design.theme();(app.seated_shell if app.seated_shell!=null else app).add_child(layer)
	loader=Control.new();loader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(loader)
	var back=ColorRect.new();back.color=Color("#100d08");back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loader.add_child(back)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loader.add_child(center)
	var panel=PanelContainer.new();panel.custom_minimum_size=Vector2(620,290);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#18130c"),3,32,Color("#8b6b35")));center.add_child(panel)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",22);panel.add_child(column)
	column.add_child(_label("✧   T H E   G I L D E D   T A B L E   ✧",25));load_note=_label("Leaving the map · preparing your seat…",15);column.add_child(load_note)
	progress=ProgressBar.new();progress.show_percentage=false;progress.custom_minimum_size.y=8;column.add_child(progress)
	var tip=_label("Keep your strongest dragons close. A weaker play can awaken a useful power.",13);tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(tip)
	for key in paths:
		var err=ResourceLoader.load_threaded_request(paths[key],"Texture2D")
		if err not in [OK,ERR_BUSY]:load_note.text="Unable to load the casino artwork. Return to the map and try again.";_button(column,"Return to map",close_local);return
func _capture_branch(node: Node) -> void:
	if node is CanvasItem or node is Window:
		saved.append({"node":weakref(node),"kind":"visual","visible":node.visible,"process":node.process_mode});node.hide();node.process_mode=Node.PROCESS_MODE_DISABLED
	_capture_content(node)
func _capture_content(node: Node) -> void:
	if node is SubViewport:
		saved.append({"node":weakref(node),"kind":"viewport","update":node.render_target_update_mode});node.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if node is GPUParticles3D or node is GPUParticles2D or node is CPUParticles3D or node is CPUParticles2D:
		saved.append({"node":weakref(node),"kind":"particle","emitting":node.emitting,"speed":node.speed_scale});node.emitting=false;node.speed_scale=0
	if node is VideoStreamPlayer:saved.append({"node":weakref(node),"kind":"video","paused":node.paused});node.paused=true
	elif node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		saved.append({"node":weakref(node),"kind":"audio","paused":node.stream_paused});node.stream_paused=true
	for child in node.get_children():_capture_content(child)
func close_local() -> void:
	if phase in ["closed","closing"]:return
	phase="closing"
	if scene!=null:
		scene.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;scene.process_mode=Node.PROCESS_MODE_DISABLED
		if scene.card_viewport!=null:scene.card_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		if scene.game_view!=null:scene.game_view.release_pending()
	if app.seated_shell!=null and is_instance_valid(scene):app.seated_shell.release_casino_scene()
	if is_instance_valid(layer):layer.queue_free()
	scene=null;hud=null;loader=null
	# Drain in-flight resource requests so abandoned loaders retain no hidden scene.
	for key in paths:
		if loaded.has(key):continue
		while ResourceLoader.load_threaded_get_status(paths[key])==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(paths[key])==ResourceLoader.THREAD_LOAD_LOADED:ResourceLoader.load_threaded_get(paths[key])
	assets.clear();loaded.clear();await get_tree().process_frame
	for record in saved:
		var node=record.node.get_ref()
		if not is_instance_valid(node):continue
		if record.kind=="viewport":node.render_target_update_mode=record.update
		elif record.kind=="particle":node.emitting=record.emitting;node.speed_scale=record.speed
		elif record.kind=="video":node.paused=record.paused
		elif record.kind=="audio":node.stream_paused=record.paused
		else:node.visible=record.visible;node.process_mode=record.process
	saved.clear();signature="";phase="closed"
	if is_instance_valid(app.dice_stage):app.dice_stage.clear_rolls();app.dice_stage.suspended=false
	if is_instance_valid(app.board):app.board.queue_redraw()
	if is_instance_valid(app.toolbox):
		app.toolbox.rail_buttons.casino.button_pressed=false
		if app.toolbox.rail_buttons.has(app.toolbox.current):app.toolbox.rail_buttons[app.toolbox.current].button_pressed=true
func _process(_delta: float) -> void:
	if phase=="loading":
		var total=0.;var all_ready=true
		for key in paths:
			if loaded.has(key):total+=1.;continue
			var amount=[];var state=ResourceLoader.load_threaded_get_status(paths[key],amount)
			if state==ResourceLoader.THREAD_LOAD_LOADED:loaded[key]=true;assets[key]=ResourceLoader.load_threaded_get(paths[key]);total+=1.
			elif state==ResourceLoader.THREAD_LOAD_FAILED:load_note.text="Casino artwork could not be loaded.";return
			else:all_ready=false;total+=float(amount[0]) if not amount.is_empty() else 0.
		progress.value=total/paths.size()*65
		if all_ready:
			load_note.text="Setting the table · lighting the candles…";scene=app.seated_shell.use_casino_scene(layer) if app.seated_shell!=null else Hearth20CasinoTable.new()
			if app.seated_shell==null:layer.add_child(scene);scene.setup(assets)
			layer.move_child(scene,0);var initial=current();var seat_index=-1
			for i in initial.get("seats",[]).size():
				if initial.seats[i].get("mine",false):seat_index=i
			scene.game_loading_changed.connect(_game_loading) if not scene.game_loading_changed.is_connected(_game_loading) else null;scene.game_motion_finished.connect(_motion_finished) if not scene.game_motion_finished.is_connected(_motion_finished) else null;scene.wager_picked.connect(_wager_pick) if not scene.wager_picked.is_connected(_wager_pick) else null;scene.present(initial,seat_index);scene.book_opened_changed.connect(_book_ui) if not scene.book_opened_changed.is_connected(_book_ui) else null;scene.peek_changed.connect(_peek_ui) if not scene.peek_changed.is_connected(_peek_ui) else null;scene.card_selected.connect(_select_card) if not scene.card_selected.is_connected(_select_card) else null;scene.card_hovered.connect(_hover_card) if not scene.card_hovered.is_connected(_hover_card) else null;phase="warming";staged_frames=0
	elif phase=="warming":
		staged_frames+=1;progress.value=65+minf(30.,staged_frames*3.);load_note.text="Rendering your first view…"
		if staged_frames>=12 and Time.get_ticks_msec()-started_msec>=650:
			_build_hud();signature="";phase="ready";_refresh();progress.value=100;loader.queue_free();loader=null
func _label(text: String, points: int=14) -> Label:
	var label=Label.new();label.text=text;label.add_theme_font_size_override("font_size",points);label.add_theme_color_override("font_color",Color("#e1cfaa"));return label
func _button(parent: Node, text: String, action: Callable) -> Button:
	var button=Button.new();button.text=text;button.custom_minimum_size.y=36;button.pressed.connect(action);parent.add_child(button);return button
func _panel(at: Rect2) -> VBoxContainer:
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);panel.anchor_left=at.position.x;panel.anchor_top=at.position.y;panel.anchor_right=at.end.x;panel.anchor_bottom=at.end.y;panel.offset_left=16;panel.offset_top=16;panel.offset_right=-16;panel.offset_bottom=-16;panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color(.055,.043,.026,1.),3,16,Color("#66502c")));hud.add_child(panel)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll);var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",9);scroll.add_child(column);return column
func _build_hud() -> void:
	hud=Control.new();hud.name="CasinoControls";hud.z_index=20;hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(hud)
	var left=_panel(Rect2(0,0,.205,.70));left_panel=left.get_parent().get_parent();left.add_child(_label("THE GILDED TABLE",18));summary=_label("",14);summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;left.add_child(summary);roster=VBoxContainer.new();roster.add_theme_constant_override("separation",12);left.add_child(roster)
	var right=_panel(Rect2(.79,0,.21,.80));detail=VBoxContainer.new();detail.add_theme_constant_override("separation",10);right.add_child(detail);actions=VBoxContainer.new();actions.add_theme_constant_override("separation",8);right.add_child(actions)
	var bottom=_panel(Rect2(.21,.87,.58,.13));var bottom_row=HBoxContainer.new();footer_panel=bottom.get_parent().get_parent();bottom_row.add_theme_constant_override("separation",12);bottom.add_child(bottom_row);status=_label("",13);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bottom_row.add_child(status)
	change_game_button=_button(bottom_row,"Change game",_change_game);_update_game_change()
	_button(bottom_row,"Look at mode pulls" if app.seated_shell!=null else "Leave casino" if app.session.local_role=="dm" else "Leave session",func():
		if app.seated_shell!=null:app.seated_shell.look_at_pulls();return
		if app.session.local_role=="player":app.session.stop_session()
		elif current().is_empty():close_local()
		else:_send("close"))
func _peek_ui(peeking: bool) -> void:
	if is_instance_valid(footer_panel):footer_panel.visible=not peeking
	if is_instance_valid(left_panel):left_panel.visible=not peeking
	if is_instance_valid(peek_hint):peek_hint.queue_free();peek_hint=null
	if peeking:
		peek_hint=Button.new();peek_hint.text="PEEKING · Click the table center to bring your hand back";peek_hint.anchor_left=.26;peek_hint.anchor_right=.75;peek_hint.anchor_top=.02;peek_hint.anchor_bottom=.075;peek_hint.pressed.connect(func():scene.toggle_peek());hud.add_child(peek_hint)
func _clear(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()
func _refresh() -> void:
	game=current();var next=JSON.stringify(game)
	_update_game_change()
	if signature==next:return
	signature=next;selected="";_clear(roster);_clear(actions);_clear(detail)
	if is_instance_valid(catalog_panel):catalog_panel.queue_free();catalog_panel=null
	if game.is_empty():_catalog();scene.present({},0);return
	var dm=app.session.local_role=="dm";var mine=-1
	for i in game.seats.size():
		if game.seats[i].get("mine",false):mine=i
	if dm and selected_view_seat>=0 and selected_view_seat<game.seats.size():mine=selected_view_seat
	if mine<0:mine=-1 if dm else 0
	scene.present(game,mine);summary.text=("CASINO MASTER · DEALER\n" if dm else "")+"Three-Dragon Ante\n"+str(game.phase).capitalize()+" · Gambit "+str(game.gambit)+" · Round "+str(game.round)+"\nStakes "+str(game.pot)+" · Hole "+str(game.hole)+"\nEach coin = "+_money(game.chip_cp)
	if game.game in Hearth20CasinoGames.TYPES:Hearth20CasinoGamesUI.build(self,mine);return
	for i in game.seats.size():
		var s=game.seats[i];var box=VBoxContainer.new();roster.add_child(box)
		var label=_label(("✦ " if game.phase=="play" and game.turn==i else "")+str(s.name),15);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(label)
		box.add_child(_label(str(s.hand_count)+" cards · "+str(s.hoard)+" coins"+(" · ready" if s.ready and game.phase=="lobby" else ""),12))
		if dm:
			var index=i;_button(box,"View this seat",func():selected_view_seat=index;signature="";_refresh())
	if game.phase=="lobby":
		var cost=maxi(2,game.seats.size())*10*int(game.chip_cp);_text(detail,"Take a seat",23);_text(detail,"Starting hoard: 10 coins per seated player. Current buy-in: "+_money(cost)+". Gold stays in your purse until everyone is ready and the DM deals.",13)
		var eligible=[]
		if dm:eligible=app.campaign.actors.filter(func(a):return a.get("is_hero",false) and not a.get("decorative",false))
		else:eligible=app.session.client_snapshot.get("sheets",[])
		for actor in eligible:
			var id=str(actor.id)
			if not game.seats.any(func(s):return s.actor_id==id):_button(actions,"Seat "+str(actor.name),func():_send("join",{"actor_id":id}))
		for s in game.seats:
			if dm or s.get("mine",false):
				_wallet(s);var id=str(s.actor_id);_button(actions,"Unready "+s.name if s.ready else "Ready "+s.name,func():_send("ready",{"actor_id":id}));_button(actions,"Remove "+s.name,func():_send("leave",{"actor_id":id}))
		if dm:_button(actions,"Deal private hands",func():_send("start"))
	elif game.phase in ["ante","play"]:
		_text(detail,"Your cards",23);_text(detail,"Hover to lift a card. Click to inspect it. Right-drag to look; wheel to lean closer.",13)
		if not game.choice.is_empty():
			_text(actions,str(game.seats[game.choice.seat].name)+" · resolve "+str(game.choice.kind),15)
			for option in game.choice.get("options",[]):
				var id=str(option.id);_button(actions,str(option.label),func():_send("choose",{"option":id}))
	elif game.phase=="between":
		_text(detail,"Gambit settled",24);_text(detail,"Hands carry over. The DM can deal the next gambit or cash out the table.",14)
		if dm:_button(actions,"Next gambit",func():_send("next"));_button(actions,"Cash out & finish",func():_send("cashout"))
	else:_text(detail,"Buy-ins refunded" if game.phase=="cancelled" else "Final balances ready",24);_text(detail,"Each player receives an exact balance notice to enter in D&D Beyond. The website is updated by the player.",14)
	if dm and game.phase not in ["complete","cancelled"]:_button(actions,"Cancel & refund original buy-ins",func():_send("cancel"))
	if dm:_button(actions,"View gold ledger",_ledger)
	status.text=str(game.log.back()) if not game.log.is_empty() else "Choose a card."
func _update_game_change() -> void:
	if not is_instance_valid(change_game_button):return
	var state=current();change_game_button.visible=app.session.local_role=="dm" and not state.is_empty()
	change_game_button.disabled=Hearth20TavernGames.locked(state)
	change_game_button.text="Choose another game" if state.get("phase","") in ["complete","cancelled"] else "Change game"
	change_game_button.tooltip_text="Finish or refund the funded table before changing games." if change_game_button.disabled else "Return the party to game selection. Uncommitted coins are unchanged."
func _change_game() -> void:
	if app.session.local_role!="dm" or current().is_empty() or Hearth20TavernGames.locked(current()):return
	selected_view_seat=-1;selected="";_send("close")
func _money(cp: int) -> String:return ("%.2f"%(cp/100.))+" gp"
func _text(parent: Node, text: String, points: int) -> void:
	var label=_label(text,points);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label)
func _catalog() -> void:
	if app.session.local_role!="dm":
		summary.text="THE GILDED CASINO";_text(detail,"Your CM is choosing a game",23);_text(detail,"Your private hand and wagers will appear when the table opens.",14);return
	summary.text="The casino board\nChoose an evening's game.\nThe DM opens the chosen table for every connected player."
	_text(detail,"Tavern games",23);_text(detail,"Players declare their coins before playing. The CM settles the table; players enter their new balance in D&D Beyond.",14)
	Hearth20CasinoGamesUI.reserve(self,detail)
	catalog_panel=PanelContainer.new();catalog_panel.anchor_left=.23;catalog_panel.anchor_top=.12;catalog_panel.anchor_right=.76;catalog_panel.anchor_bottom=.84;catalog_panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color(.08,.06,.03,.94),3,24,Color("#a78442")));hud.add_child(catalog_panel)
	var backdrop=TextureRect.new();backdrop.texture=assets.catalog;backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;backdrop.modulate=Color(.5,.43,.34,1);backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;catalog_panel.add_child(backdrop)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",16);catalog_panel.add_child(column);column.add_child(_label("A NIGHT AT THE GILDED TABLE",24))
	var grid=GridContainer.new();grid.columns=2;grid.size_flags_vertical=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",16);column.add_child(grid)
	for spec in [["three_dragon_ante","Three-Dragon Ante","Traditional 80-card deck · 2–6 players"],["gambit_of_ord","Gambit of Ord","Soul-glass d8, d6, d4 · 2–6 players"],["run_of_luck","Run of Luck","Five living racers · three d4 stages"],["tymoras_spinner","Tymora's Spinner","Brass, velvet and fortune · D20 wheel"]]:
		var tile=PanelContainer.new();tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.size_flags_vertical=Control.SIZE_EXPAND_FILL;tile.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#1f180e"),3,16,Color("#806236")));grid.add_child(tile);var box=VBoxContainer.new();tile.add_child(box)
		box.add_theme_constant_override("separation",8)
		_text(box,spec[1],21);_text(box,spec[2],13);var type=str(spec[0]);var prefs=table_prefs.get(type,{"denomination":1 if type=="three_dragon_ante" else 2,"buyin":100,"minimum":5 if type=="gambit_of_ord" else 25});table_prefs[type]=prefs;var denomination=OptionButton.new()
		for label in ["Copper · 0.01 gp","Silver · 0.10 gp","Gold · 1 gp","Platinum · 10 gp"]:denomination.add_item(label)
		denomination.selected=int(prefs.denomination);denomination.item_selected.connect(func(index):prefs.denomination=index);box.add_child(denomination)
		var row=HBoxContainer.new();box.add_child(row);var buyin=Hearth20CasinoGamesUI.number(row,1,1000000,int(prefs.buyin));buyin.prefix="Buy-in ";var minimum=Hearth20CasinoGamesUI.number(row,1,int(buyin.value),int(prefs.minimum));minimum.prefix="Min ";buyin.value_changed.connect(func(v):prefs.buyin=int(v);minimum.max_value=v);minimum.value_changed.connect(func(v):prefs.minimum=int(v))
		row.visible=type!="three_dragon_ante"
		if type=="tymoras_spinner":_button(box,"Set wheel payouts",_wheel_terms)
		_button(box,"Open for the party",func():_send("open",{"game":type,"chip_cp":[1,10,100,1000][denomination.selected],"buyin":int(buyin.value),"minimum":int(minimum.value),"payouts":wheel_payouts.duplicate(true)}))
func _game_loading(active: bool) -> void:
	if is_instance_valid(game_loader):game_loader.queue_free();game_loader=null
	if not active:return
	game_loader=Control.new();game_loader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);game_loader.mouse_filter=Control.MOUSE_FILTER_STOP;game_loader.z_index=450;layer.add_child(game_loader)
	var back=ColorRect.new();back.color=Color(.035,.025,.015,.97);back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);game_loader.add_child(back)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);game_loader.add_child(center)
	var panel=PanelContainer.new();panel.custom_minimum_size=Vector2(560,210);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#18120b"),3,32,Color("#9e7c3e")));center.add_child(panel);var column=VBoxContainer.new();column.add_theme_constant_override("separation",22);panel.add_child(column)
	column.add_child(_label("✧  SETTING YOUR TABLE  ✧",25));var note=_label("Preparing your seat, setting the game and lighting the table…",15);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(note)
func _wallet(s: Dictionary) -> void:
	var mine=bool(s.get("mine",false));var dm=app.session.local_role=="dm"
	var actor=Hearth20Contracts.find_actor(app.campaign,str(s.actor_id)) if dm else {}
	if not mine and not (dm and actor.get("owner_player_id","").is_empty()):
		_text(actions,str(s.name)+(" · coins declared" if s.get("balance_declared",false) else " · awaiting player coin declaration"),13);return
	_text(actions,"Your declared coins · "+str(s.name),16)
	_text(actions,"Enter the balance on your D&D Beyond sheet. Hearth20 tracks this table only; update the website after payout or refund.",12)
	var value=Hearth20CasinoWallet.coins(int(s.get("declared_cp",0)))
	var fields={}
	if balance_game_id!=str(game.get("id","")):
		balance_game_id=str(game.get("id",""))
		balance_drafts.clear()
	var draft_key=str(game.get("id",""))+"/"+str(s.actor_id)
	var draft=balance_drafts.get(draft_key,{})
	for key in ["gp","sp","cp"]:
		var row=HBoxContainer.new();actions.add_child(row);_text(row,str(key).to_upper(),13)
		var input=LineEdit.new()
		input.name="Declared"+str(key).to_upper()
		input.text=str(draft.get(key,value[key]))
		input.placeholder_text="0"
		input.custom_minimum_size.y=38
		input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(input)
		fields[key]=input
	var id=str(s.actor_id)
	var preview=_label("",13)
	preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(preview)
	var submit=_button(actions,"Update declaration" if s.get("balance_declared",false) else "Declare my balance",func():
		var parsed=_read_balance(fields)
		if not parsed.ok:
			preview.text=parsed.error
			return
		_send("declare_balance",{"actor_id":id,"gp":parsed.gp,"sp":parsed.sp,"cp":parsed.cp}))
	var changed=func(_text=""):
		var raw={}
		for key in fields:raw[key]=fields[key].text
		balance_drafts[draft_key]=raw
		var parsed=Hearth20CasinoWallet.parse_declaration(raw)
		submit.disabled=not parsed.ok
		preview.text="Declared total · "+Hearth20CasinoWallet.label(parsed.total_cp) if parsed.ok else parsed.error
	for field in fields.values():field.text_changed.connect(changed)
	changed.call()
func _read_balance(fields: Dictionary) -> Dictionary:
	var raw={}
	for key in fields:raw[key]=fields[key].text
	return Hearth20CasinoWallet.parse_declaration(raw)
func _motion_finished() -> void:
	if phase=="ready":signature="";_refresh()
func _wager_pick(wager: Dictionary) -> void:
	var state=current();var id=str(state.get("id",""));var prefs=bet_prefs.get(id,{});prefs.kind=wager.kind;prefs.number=wager.number;bet_prefs[id]=prefs;signature="";_refresh()
func _wheel_terms() -> void:
	_clear(detail);_text(detail,"Wheel payouts",24);_text(detail,"Profit per winning chip. The original stake returns too. Terms lock when the table opens.",14)
	for kind in ["odd","even","red","black","ends","number"]:
		var key=kind;var row=HBoxContainer.new();detail.add_child(row);row.add_child(_label(kind.capitalize(),14));var value=Hearth20CasinoGamesUI.number(row,1,100,int(wheel_payouts[kind]));value.suffix=" : 1";value.value_changed.connect(func(v):wheel_payouts[key]=int(v))
	_button(detail,"Return to casino board",func():signature="";_refresh())
func _ledger() -> void:
	_clear(detail);_text(detail,"Gold ledger",23)
	var entries=app.campaign.get("tavern_ledger",[])
	for index in range(maxi(0,entries.size()-18),entries.size()):
		var e=entries[index];var actor=Hearth20Contracts.find_actor(app.campaign,str(e.actor_id));_text(detail,str(actor.get("name","Character"))+" · "+str(e.action)+"\n"+("+" if e.delta_cp>=0 else "")+_money(e.delta_cp)+" → "+_money(e.after_cp),12)
	_text(detail,"Latest 1,000 character-purse transactions are retained in the campaign.",12)
func _hover_card(id: String) -> void:
	if id.is_empty():return
	_show_card(id,false)
func _select_card(id: String) -> void:
	selected=id;scene.selected=id;_show_card(id,true)
func _show_card(id: String, commit: bool) -> void:
	if game.is_empty():return
	var c=Hearth20TavernGames.card(id)
	if c.is_empty():return
	_clear(detail);_text(detail,str(c.name)+"  ·  "+str(c.strength),24);_text(detail,str(c.type).capitalize()+" dragon" if c.type!="mortal" else "Mortal",12)
	var image=TextureRect.new();var atlas=AtlasTexture.new();atlas.atlas=assets.art;var cell=assets.art.get_size()/Vector2(5,4);atlas.region=Rect2(Vector2(int(c.art)%5,int(c.art)/5)*cell,cell);image.texture=atlas;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size.y=170;detail.add_child(image)
	_text(detail,str(c.text),14)
	if commit:
		var mine=-1
		for i in game.seats.size():
			if game.seats[i].get("hand",[]).has(id):mine=i;break
		if mine<0:return
		var actor_id=str(game.seats[mine].actor_id)
		if game.phase=="ante" and not game.seats[mine].ante_chosen:_button(detail,"Commit face-down ante",func():_send("ante",{"actor_id":actor_id,"card_id":id}))
		elif game.phase=="play" and game.turn==mine and game.choice.is_empty():_button(detail,"Play onto the table",func():_send("play",{"card_id":id}))
func _send(action: String, extras: Dictionary={}) -> void:
	var state=current();var command={"action":action,"game_id":str(state.get("id","")),"revision":int(state.get("revision",0))};command.merge(extras)
	var result=app.session.casino_action(command);_result(result)
func _result(result: Dictionary) -> void:
	if not result.get("ok",false):
		if is_instance_valid(status):status.text=str(result.get("error","The table changed."))
		return
	if phase=="ready":signature="";_refresh()

func _book_ui(opened: bool) -> void:
	if is_instance_valid(hud):hud.visible=not opened
	if not opened:
		if is_instance_valid(book_nav):book_nav.queue_free();book_nav=null
		return
	book_nav=PanelContainer.new();book_nav.anchor_left=.05;book_nav.anchor_top=.02;book_nav.anchor_right=.95;book_nav.anchor_bottom=.10;book_nav.add_theme_stylebox_override("panel",Hearth20Design.panel(Color(.05,.035,.02,.92),2,10,Color("#8c6c37")));layer.add_child(book_nav)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);book_nav.add_child(row)
	_button(row,"Contents",func():scene.book.select_chapter(-1))
	for i in Hearth20CasinoBook.TITLES.size():
		var index=i;_button(row,Hearth20CasinoBook.TITLES[i],func():scene.book.select_chapter(index))
	var space=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(space);_button(row,"Close DA ROLLS",func():scene.book.close_book())
	_button(row,"‹",func():scene.book.turn_spread(-1));_button(row,"›",func():scene.book.turn_spread(1))
