extends RefCounted
class_name Hearth20TokenDrag
static func accepts(session: Hearth20Session, data: Variant) -> bool:
	return session.local_role=="dm" and data is Dictionary and data.get("kind","")=="hearth20-token" and data.get("scope","")==session.token_drag_scope and not Hearth20Contracts.find_actor(session.campaign,str(data.get("actor_id",""))).is_empty()
static func payload(session: Hearth20Session, id: String) -> Dictionary:return {"kind":"hearth20-token","scope":session.token_drag_scope,"actor_id":id}
static func preview(board: Hearth20BoardCanvas, actor: Dictionary) -> Control:
	var box=VBoxContainer.new();box.custom_minimum_size=Vector2(96,110);box.modulate.a=.85;box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var image=TextureRect.new();image.texture=board._actor_texture(str(actor.get("png_asset_id","")));image.custom_minimum_size=Vector2(80,80);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;box.add_child(image)
	var name_label=Label.new();name_label.text=str(actor.get("name","Token"));name_label.add_theme_font_size_override("font_size",12);box.add_child(name_label);return box
