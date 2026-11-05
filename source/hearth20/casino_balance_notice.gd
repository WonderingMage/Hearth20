extends CanvasLayer
class_name Hearth20CasinoBalanceNotice
## Lives beside the casino, so settlement survives closing its 3D scene.
var app: Hearth20App
var badge: Button
var veil: Control
var body: VBoxContainer
var entries: Array=[]
var seen={}
var signature=""
func setup(owner_app: Hearth20App) -> void:
	app=owner_app;layer=510
	badge=Button.new();badge.name="PendingCoinBalance";badge.text="✦ Update D&D Beyond coins";badge.position=Vector2(24,72);badge.custom_minimum_size=Vector2(290,42);badge.theme=Hearth20Design.theme();badge.pressed.connect(func():veil.show());add_child(badge)
	veil=Control.new();veil.name="CoinSettlementNotice";veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.theme=Hearth20Design.theme();add_child(veil)
	var dim=ColorRect.new();dim.color=Color(0,0,0,.7);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.add_child(dim)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.add_child(center)
	var panel=PanelContainer.new();panel.custom_minimum_size=Vector2(610,0);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color("#18120c"),3,28,Color("#bd944a")));center.add_child(panel)
	body=VBoxContainer.new();body.add_theme_constant_override("separation",14);panel.add_child(body)
	badge.hide();veil.hide()
	app.session.state_changed.connect(func(_s):refresh());app.session.snapshot_received.connect(func(_s):refresh())
	app.session.casino_action_result.connect(func(_r):refresh())
func refresh() -> void:
	entries=Hearth20CasinoWallet.pending(app.campaign,"dm-local") if app.session.local_role=="dm" else app.session.client_snapshot.get("casino_receipts",[])
	badge.visible=not entries.is_empty()
	if entries.is_empty():veil.hide();signature="";return
	var next=JSON.stringify(entries)
	if next==signature:return
	signature=next
	for node in body.get_children():body.remove_child(node);node.queue_free()
	var r=entries[0];_text("✦  YOUR COINS, SETTLED  ✦",26)
	_text(str(r.name)+" · "+str(r.kind).capitalize(),19)
	_text("Set your D&D Beyond balance to",16)
	_text(Hearth20CasinoWallet.label(int(r.after_cp)),30)
	var change=int(r.delta_cp)
	_text("Declared: "+Hearth20CasinoWallet.label(int(r.before_cp))+"\nNet change: "+("−" if change<0 else "+")+Hearth20CasinoWallet.label(absi(change)),15)
	_text("Enter these final totals on your sheet. Hearth20 has settled the casino table; D&D Beyond changes only when you edit it.",14)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);body.add_child(row)
	_button(row,"Copy final totals",func():DisplayServer.clipboard_set(Hearth20CasinoWallet.label(int(r.after_cp))))
	_button(row,"Open my D&D Beyond sheet",func():
		veil.hide()
		if app.has_method("open_beyond_sheet"):app.call("open_beyond_sheet")
		else:OS.shell_open("https://www.dndbeyond.com/my-characters"))
	var id=str(r.id)
	_button(body,"I updated D&D Beyond",func():
		var result=app.session.casino_action({"action":"acknowledge_balance","receipt_id":id})
		if not result.ok:_text(str(result.get("error","Unable to confirm the update.")),14)
		refresh())
	_button(body,"Remind me later",func():veil.hide())
	if not seen.has(id):seen[id]=true;veil.show()
func _text(text: String, points: int) -> void:
	var label=Label.new();label.text=text;label.add_theme_font_size_override("font_size",points);label.custom_minimum_size.x=550;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(label)
func _button(parent: Node, text: String, action: Callable) -> void:
	var button=Button.new();button.text=text;button.custom_minimum_size.y=40;button.pressed.connect(action);parent.add_child(button)
