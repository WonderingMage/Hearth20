extends Window
class_name Hearth20NetworkDetails
var app: Hearth20App
var text: TextEdit
var elapsed=0.
static func open(owner_app: Hearth20App) -> Hearth20NetworkDetails:
	var owner=owner_app.seated_shell if owner_app.seated_shell!=null else owner_app
	var prior=owner.get_node_or_null("NetworkDetails")
	if is_instance_valid(prior):Hearth20Design.popup_window(prior);return prior
	var window=Hearth20NetworkDetails.new();window.name="NetworkDetails";window.app=owner_app;owner.add_child(window);window.setup();return window
func setup() -> void:
	title="Hearth20 · Connection details";size=Vector2i(820,590);min_size=Vector2i(650,420);theme=Hearth20Design.theme();transient=true;exclusive=false;close_requested.connect(queue_free)
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.BG),3,24,Hearth20Regal.swatch(Hearth20Regal.GOLD)));add_child(panel)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);panel.add_child(column)
	var heading=Label.new();heading.text="✦  CONNECTION DETAILS";heading.add_theme_font_override("font",Hearth20Design.font(true));heading.add_theme_font_size_override("font_size",25);column.add_child(heading)
	var note=Label.new();note.text="Rates adapt to traffic, loss and latency. Copy this report when a download seems slow. No IP addresses or account IDs are included.";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(note)
	text=TextEdit.new();text.editable=false;text.size_flags_vertical=Control.SIZE_EXPAND_FILL;text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;text.add_theme_font_size_override("font_size",14);text.add_theme_color_override("font_readonly_color",Hearth20Regal.swatch(Hearth20Regal.INK));column.add_child(text)
	var row=HBoxContainer.new();column.add_child(row)
	var copy=Button.new();copy.text="Copy report";copy.pressed.connect(func():DisplayServer.clipboard_set(text.text));row.add_child(copy)
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(spacer)
	var close=Button.new();close.text="Close";close.pressed.connect(queue_free);row.add_child(close)
	refresh();Hearth20Design.popup_window(self)
func _process(delta: float) -> void:
	if not visible:return
	elapsed+=delta
	if elapsed>=1.:elapsed=0.;refresh()
func refresh() -> void:
	if not is_instance_valid(app):return
	var link=app.session.steam_link
	var lines=["Hearth20 "+Hearth20Identity.VERSION,"Transport: "+("Steam" if app.session.transport=="steam" else "Direct IP / offline")]
	if is_instance_valid(link) and link.has_method("transfer_diagnostics"):
		var reports=link.transfer_diagnostics()
		if reports.is_empty():lines.append("No active Steam bulk transfer has been sampled yet.")
		for item in reports:
			lines.append("")
			lines.append("Connection %s · %s · %d ms RTT"%[str(item.peer),str(item.route),int(item.ping_ms)])
			lines.append("Requested pacing: %.2f MiB/s · Steam effective: %.2f MiB/s"%[float(item.requested_bps)/1048576.,float(item.effective_bps)/1048576.])
			lines.append("Actual wire upload: %.2f MiB/s · download: %.2f MiB/s"%[float(item.out_bps)/1048576.,float(item.in_bps)/1048576.])
			lines.append("Queued: %.0f KiB · awaiting acknowledgement: %.0f KiB"%[float(item.pending_bytes)/1024.,float(item.unacknowledged_bytes)/1024.])
			lines.append("Rate settings accepted: "+("Yes" if item.config_ok else "No"))
			if item.config_ok and absf(float(item.effective_bps)-float(item.requested_bps))>float(item.requested_bps)*.1:lines.append("The requested rate has not taken effect.")
			if float(item.remote_quality)>=0:lines.append("Delivery quality: %.1f%% local · %.1f%% remote"%[float(item.local_quality)*100.,float(item.remote_quality)*100.])
	var transfer=app.session.map_transfer_state
	if transfer.get("active",false):lines.append("\nMap payload received: %.1f / %.1f MiB · %.2f MiB/s"%[float(transfer.get("received",0))/1048576.,float(transfer.get("total",0))/1048576.,float(transfer.get("rate_bps",0))/1048576.])
	var next="\n".join(PackedStringArray(lines))
	if text.text!=next:text.text=next
