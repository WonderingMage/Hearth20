extends Control
class_name Hearth20MapDownloadMeter
## Non-interactive, player-only bottom-edge progress from actual transfer bytes.
var session: Hearth20Session
var caption: Label
var progress=0.0
func setup(owner_session: Hearth20Session) -> void:
	session=owner_session;mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption=Label.new();caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.add_theme_font_size_override("font_size",11)
	caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);caption.offset_right=-226;caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;add_child(caption)
	session.map_transfer_progress.connect(_show_progress)
	_show_progress(session.map_transfer_state)
func _show_progress(state: Dictionary) -> void:
	visible=session.local_role=="player" and bool(state.get("active",false))
	progress=clampf(float(state.get("progress",0)),0.,1.)
	caption.text="%s  %d%%  ·  %.1f / %.1f MB"%[str(state.get("phase","Downloading map…")),roundi(progress*100),float(state.get("received",0))/1048576.,float(state.get("total",0))/1048576.]
	caption.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD));queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0,size.y-5,size.x,4),Hearth20Regal.swatch(Hearth20Regal.SURFACE))
	draw_rect(Rect2(0,size.y-5,size.x*progress,4),Hearth20Regal.swatch(Hearth20Regal.GOLD))
