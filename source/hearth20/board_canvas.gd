extends Control
class_name Hearth20BoardCanvas
## Native 2D top-down map canvas. All picking and rendering share cell-space math.

signal selection_changed(actor_id: String)
signal hint_changed(text: String)
signal object_selected(object: Dictionary)

var session: Node
var role := "dm"
var campaign: Dictionary = {}
var snapshot: Dictionary = {}
var selected_actor_id := ""
var dragging_actor := false
var panning := false
var space_pan := false
var drag_origin := Vector2.ZERO
var drag_world_origin := Vector2.ZERO
var drag_points: Array=[]
var camera_pan := Vector2.ZERO
var camera_zoom := 1.0
var fit_pending := true
var fog_tool := false
var door_tool := false
var fx_target_mode := false
var tool_start := Vector2.ZERO
var seen_fx: Dictionary = {}
var actor_image_cache: Dictionary = {}
var map_texture_cache: Texture2D
var map_texture_cache_key := ""
var selected_map_image: Image
var active_fx: Node2D
var measure_tool := false
var template_shape := ""
var measuring := false
var measure_start := Vector2.ZERO
var measure_end := Vector2.ZERO
var selected_template_id := ""
var pings: Array = []
var read_only_preview := false
var last_canvas_size := Vector2.ZERO
var tool_name := "select"
var active_layer := "tokens"
var tool_settings := {"kind":"freehand", "layer":"tokens", "color":"#d4b477", "fill":"#00000000", "width":3.0, "text":"", "font":"Sans", "font_size":24.0, "bold":false, "italic":false, "border":true, "border_color":"#d4b477", "opacity":1.0, "bright":20.0, "dim":20.0, "light_color":"#ffcd8e", "source_type":"torch", "enabled":true, "open":false}
var ruler_settings := {"shape":"line", "origin":"center", "snap":"center", "distance":"grid", "angle":60, "round":true, "beam_width":5, "linger":false, "color":"#76e0ca"}
var fx_settings := {"effect":"breath", "color":"#ff682b", "size":1.0, "duration":2.0, "density":48}
var pending_token: Dictionary={}
var selected_object_id := ""
var draft: Dictionary = {}
var tool_drag := false
var moving_object := false
var resizing_object := false
var resize_anchor := Vector2.ZERO
var remote_rulers: Dictionary = {}
var local_ruler: Dictionary = {}
var last_preview_msec := 0
var mask_reveal := false
var mask_polygon := false
var polygon_points: Array = []
var gm_mask_opacity := 0.5
var font_cache: Dictionary = {}
var rich_empty_state := false
var lighting_preview := true
var light_meshes: Array = []
var lighting_cache_key := ""
var soft_light: Hearth20SoftLight
var preview_texture: Texture2D
var draw_revision=-1
var draw_palette=-1
var draw_camera=Vector3.INF

static func native_map_rect(image_size: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(image_size))

func _ready() -> void:
	clip_contents = true
	add_to_group("hearth20_themed")
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	soft_light=Hearth20SoftLight.new()
	add_child(soft_light)
	active_fx = Hearth20FxRenderer.new()
	active_fx.z_index = 5
	add_child(active_fx)
	resized.connect(_on_resized)

func set_campaign(value: Dictionary, active_session: Node, active_role: String) -> void:
	campaign = value
	session = active_session
	if session and not session.ping_received.is_connected(_on_ping_received):
		session.ping_received.connect(_on_ping_received)
	if session and not session.tool_preview_received.is_connected(_on_tool_preview):
		session.tool_preview_received.connect(_on_tool_preview)
	role = active_role
	snapshot.clear()
	map_texture_cache = null
	map_texture_cache_key = ""
	fit_pending = true
	queue_redraw()

func set_player_snapshot(value: Dictionary) -> void:
	if role != "player" or value.get("edition", "") != Hearth20Identity.EDITION:
		return
	if bool(value.get("connection_closed", false)):
		remote_rulers.clear()
		local_ruler.clear()
		draft.clear()
		selected_object_id = ""
		tool_drag = false
		actor_image_cache.clear()
		seen_fx.clear()
		pings.clear()
		selected_actor_id = ""
		if active_fx:
			active_fx.events.clear()
	var old_scene: Dictionary = snapshot.get("scene", {})
	var new_scene: Dictionary = value.get("scene", {})
	var view_changed := snapshot.is_empty()
	for scene_key in ["id", "width_cells", "height_cells", "cell_pixels"]:
		if old_scene.get(scene_key, null) != new_scene.get(scene_key, null):
			view_changed = true
	# Vision changes the redacted image on every move. Preserve the player's
	# pan/zoom while refreshing that texture instead of repeatedly fitting it.
	if map_texture_cache_key != str(value.get("map_sha256", "")):
		map_texture_cache = null
		map_texture_cache_key = ""
	snapshot = value
	var current_fx_ids := {}
	for fx in snapshot.get("fx", []):
		var event_id := str(fx.get("id", ""))
		current_fx_ids[event_id] = true
		if event_id.is_empty() or seen_fx.has(event_id):
			continue
		var effect: Dictionary = fx.duplicate(true)
		var now := Time.get_ticks_usec()
		var delay_msec := maxi(0, int(fx.get("delay_to_arrival_msec", 0)))
		effect.started_usec = now-clampi(int(fx.get("elapsed_msec",0)),0,240000)*1000
		effect.travel_usec = clampi(int(fx.get("original_travel_msec",delay_msec)),0,120000)*1000
		effect.impact_duration_usec = int(fx.get("impact_duration_msec", 950)) * 1000
		effect.source = fx.get("start", Vector2.ZERO)
		effect.destination = fx.get("end", fx.get("center", Vector2.ZERO))
		active_fx.add_authorized_event(effect)
		seen_fx[event_id] = true
		while seen_fx.size() > 512:
			seen_fx.erase(seen_fx.keys()[0])
	active_fx.events = active_fx.events.filter(func(event: Dictionary) -> bool: return current_fx_ids.has(str(event.get("id", ""))))
	if view_changed:
		fit_pending = true
		dragging_actor = false
		measuring = false
		panning = false
		pings.clear()
	queue_redraw()

func set_role(active_role: String) -> void:
	if role != active_role:
		map_texture_cache = null
		map_texture_cache_key = ""
	role = active_role
	if active_role == "player":
		snapshot.clear()
		actor_image_cache.clear()
		seen_fx.clear()
		pings.clear()
		selected_actor_id = ""
		if active_fx:
			active_fx.events.clear()
	fit_pending = true
	queue_redraw()

func current_scene() -> Dictionary:
	if role == "player":
		return snapshot.get("scene", {})
	return Hearth20Contracts.find_scene(campaign, str(campaign.get("active_scene", "")))

func current_actors() -> Array:
	return snapshot.get("actors", []) if role == "player" else campaign.get("actors", []).filter(func(actor): return not actor.get("in_inventory",false) and actor.get("scene_id","")==campaign.get("active_scene",""))

func current_assets() -> Dictionary:
	return snapshot.get("assets", {}) if role == "player" else campaign.get("assets", {})

func _gui_input(event: InputEvent) -> void:
	if _tool_input(event):
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseMotion and not pending_token.is_empty():queue_redraw()
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_SPACE:
				space_pan = true
				return
			if event.keycode == KEY_ESCAPE:
				fog_tool = false
				door_tool = false
				fx_target_mode = false
				dragging_actor = false
				panning = false
				measuring = false
				measure_tool = false
				template_shape = ""
				queue_redraw()
				hint_changed.emit("Active map action cancelled.")
				accept_event()
				return
			match event.keycode:
				KEY_M:
					set_measure_tool(not measure_tool)
					accept_event()
					return
				KEY_DELETE:
					if role == "dm" and not selected_template_id.is_empty():
						var result: Dictionary = session.remove_template(selected_template_id)
						hint_changed.emit(str(result.get("error", "Measured area removed. Ctrl+Z restores it.")))
						selected_template_id = ""
						queue_redraw()
						accept_event()
					return
				KEY_Z:
					if role == "dm" and event.ctrl_pressed:
						var result: Dictionary = session.undo_template_removal()
						hint_changed.emit(str(result.get("error", "Measured area restored.")))
						queue_redraw()
						accept_event()
					return
				KEY_F:
					fit_map()
					accept_event()
					return
				KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
					_zoom_at(get_rect().size * 0.5, 1.15)
					accept_event()
					return
				KEY_MINUS, KEY_KP_SUBTRACT:
					_zoom_at(get_rect().size * 0.5, 1.0 / 1.15)
					accept_event()
					return
				KEY_LEFT:
					camera_pan.x -= 70.0 / camera_zoom
					queue_redraw()
					accept_event()
					return
				KEY_RIGHT:
					camera_pan.x += 70.0 / camera_zoom
					queue_redraw()
					accept_event()
					return
				KEY_UP:
					camera_pan.y -= 70.0 / camera_zoom
					queue_redraw()
					accept_event()
					return
				KEY_DOWN:
					camera_pan.y += 70.0 / camera_zoom
					queue_redraw()
					accept_event()
					return
		else:
			if event.keycode == KEY_SPACE:
				space_pan = false
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.12)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 1.0 / 1.12)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		panning = event.pressed
		drag_origin = event.position
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			if event.shift_pressed and session and not read_only_preview:
				var result: Dictionary = session.send_ping(_screen_to_world(event.position))
				hint_changed.emit(str(result.get("error", "Table ping sent.")))
				accept_event()
				return
			if measure_tool or not template_shape.is_empty():
				measuring = true
				measure_start = _screen_to_world(event.position)
				measure_end = measure_start
				accept_event()
				return
			if space_pan:
				panning = true
				drag_origin = event.position
				accept_event()
				return
			if role == "dm" and door_tool:
				_toggle_door_at(event.position)
				accept_event()
				return
			if role == "dm" and fx_target_mode:
				fx_target_mode = false
				var result: Dictionary = fire_rocket_to(_screen_to_world(event.position))
				hint_changed.emit(str(result.get("error", "Rocket impact point selected.")))
				accept_event()
				return
			if role == "dm" and fog_tool:
				tool_start = _screen_to_world(event.position)
				drag_origin = event.position
				dragging_actor = false
				panning = false
				accept_event()
				return
			var hit := _actor_at(event.position)
			if not hit.is_empty():
				selected_actor_id = str(hit.get("id", ""))
				selection_changed.emit(selected_actor_id)
				dragging_actor = not read_only_preview
				drag_origin = event.position
				drag_world_origin = hit.get("position", Vector2.ZERO)
				drag_points=[drag_world_origin,drag_world_origin]
				hint_changed.emit("Drag to move · Right-click to add a waypoint · Escape to cancel")
			else:
				selected_actor_id = ""
				selection_changed.emit("")
				selected_template_id = _template_at(_screen_to_world(event.position)) if role == "dm" else ""
				if role == "dm":
					panning = selected_template_id.is_empty()
					drag_origin = event.position
			accept_event()
			queue_redraw()
		else:
			if measuring:
				measuring = false
				measure_end = _screen_to_world(event.position)
				if role == "dm" and not template_shape.is_empty():
					var result: Dictionary = session.place_template(template_shape, measure_start, measure_end)
					selected_template_id = str(result.get("id", ""))
					hint_changed.emit(str(result.get("error", "Measured area placed. Select it and Delete to remove.")))
				else:
					hint_changed.emit("Ruler · %.1f ft · no token moved" % (measure_start.distance_to(measure_end) * float(current_scene().get("feet_per_cell", 5.0))))
				queue_redraw()
				accept_event()
				return
			if role == "dm" and fog_tool:
				var end_point := _screen_to_world(event.position)
				var x0 := floorf(minf(tool_start.x, end_point.x))
				var y0 := floorf(minf(tool_start.y, end_point.y))
				var x1 := ceilf(maxf(tool_start.x, end_point.x))
				var y1 := ceilf(maxf(tool_start.y, end_point.y))
				if x1 > x0 and y1 > y0:
					var scene := current_scene()
					var fog: Array = scene.get("fog_rects", [])
					fog.append({"x": x0, "y": y0, "width": x1 - x0, "height": y1 - y0})
					scene.fog_rects = fog
					campaign.revision = int(campaign.get("revision", 0)) + 1
					if session and session.local_role == "dm":
						session._broadcast_snapshots()
				queue_redraw()
				accept_event()
				return
			if dragging_actor:
				drag_points[-1]=Hearth20TokenInventory.snap_position(current_scene(),_bounded_point(event.position))
				_move_selected(drag_world_origin, drag_points.back(),drag_points)
				dragging_actor = false
				drag_points.clear()
			if panning:
				panning = false
			accept_event()
		return
	if event is InputEventMouseMotion:
		if measuring:
			measure_end = _screen_to_world(event.position)
			queue_redraw()
			accept_event()
		elif panning:
			camera_pan -= (event.position - drag_origin) / camera_zoom
			drag_origin = event.position
			queue_redraw()
			accept_event()
		elif dragging_actor:
			if role=="dm" and not Rect2(Vector2.ZERO,size).has_point(event.position):
				var actor=Hearth20Contracts.find_actor(campaign,selected_actor_id)
				if not actor.is_empty() and not actor.get("decorative",false):
					dragging_actor=false;drag_points.clear()
					force_drag(Hearth20TokenDrag.payload(session,selected_actor_id),Hearth20TokenDrag.preview(self,actor))
					accept_event();return
			drag_points[-1]=Hearth20TokenInventory.snap_position(current_scene(),_bounded_point(event.position))
			queue_redraw()
			accept_event()

func _draw() -> void:
	Hearth20Design.panel(Color("#0d1420"),14,0,Hearth20Design.BORDER).draw(get_canvas_item(),Rect2(Vector2.ZERO,get_rect().size))
	var scene := current_scene()
	if role == "player" and (scene.is_empty() or scene.get("id", "") == "disconnected"):
		soft_light.set_active(false)
		_draw_empty_state("Waiting for the table", "Join a hosted table to receive your character sheet and the map.", "Workspace → Connect")
		return
	if scene.is_empty():
		soft_light.set_active(false)
		_draw_empty_state("No active scene", "Create or load a campaign scene to begin placing tokens and map geometry.", "Open the Scene inspector")
		return
	var cell_px := float(scene.get("cell_pixels", 64.0))
	var width_cells := int(scene.get("width_cells", 24))
	var height_cells := int(scene.get("height_cells", 16))
	var size := Vector2(width_cells, height_cells) * cell_px
	if fit_pending:
		if size.x > 0.0 and size.y > 0.0 and get_rect().size.x > 0.0 and get_rect().size.y > 0.0:
			camera_zoom = clampf(minf(get_rect().size.x / size.x, get_rect().size.y / size.y) * 0.92, 0.1, 3.0)
			camera_pan = -((get_rect().size / camera_zoom) - size) * 0.5
		fit_pending = false
		last_canvas_size = get_rect().size
	var map_rect := _screen_rect(Rect2(Vector2.ZERO, size))
	draw_rect(map_rect, Hearth20Regal.swatch(Hearth20Regal.SURFACE), true)
	var texture := _map_texture()
	if texture != null:
		# Calibration changes the scene's cell scale, while ceil-rounded height
		# can leave a fractional final row. Keep the imported artwork at its
		# exact native pixel size instead of stretching it into that extra space.
		var native_image_rect := _screen_rect(native_map_rect(Vector2i(texture.get_width(), texture.get_height())))
		draw_texture_rect(texture, native_image_rect, false)
	else:
		_draw_checkered_background(map_rect)
	_draw_lighting(scene,cell_px,map_rect)
	if bool(scene.get("grid_visible", true)):
		_draw_grid(scene, cell_px)
	_draw_geometry(scene, cell_px)
	_draw_objects("map", cell_px)
	_draw_actors(scene, cell_px, "map")
	_draw_templates(scene, cell_px)
	_draw_fog(scene, cell_px)
	if role == "player":
		_draw_player_vision(cell_px)
	_draw_actors(scene, cell_px)
	_draw_objects("tokens", cell_px)
	_draw_actors(scene, cell_px, "foreground")
	_draw_objects("foreground", cell_px)
	if role == "dm":
		_draw_actors(scene, cell_px, "gm")
		_draw_objects("gm", cell_px)
		if active_layer == "light" or tool_name == "lighting": _draw_objects("light", cell_px)
	_draw_tool_preview(cell_px)
	_draw_measurement(cell_px)
	_draw_pings(cell_px)
	var has_content := not current_actors().is_empty()
	for layer_name in ["walls", "doors", "props", "fog_rects", "annotations"]:
		if not scene.get(layer_name, []).is_empty():
			has_content = true
	if texture == null and role == "dm" and not has_content:
		_draw_empty_state("Bring your map into the table", "Your scene grid and tokens remain ready. Import a PNG or JPEG, then set how many 5-foot cells span its width.", "Use Scene inspector  →  Import map")
	if dragging_actor:
		_draw_ruler({"shape":"line","points":drag_points,"distance":"euclidean","color":Hearth20Regal.swatch(Hearth20Regal.GOLD).to_html()},cell_px,"")
	if active_fx:
		active_fx.world_scale = cell_px * camera_zoom
		active_fx.world_offset = camera_pan * camera_zoom
		active_fx.scene=scene
		active_fx.queue_redraw()

func _draw_empty_state(title: String, body: String, steps: String) -> void:
	if rich_empty_state: return
	var viewport_size := get_rect().size
	var card := Rect2(Vector2(maxf(28.0, viewport_size.x * 0.16), maxf(32.0, viewport_size.y * 0.20)), Vector2(minf(620.0, viewport_size.x * 0.68), 238.0))
	draw_rect(card, Hearth20Regal.swatch(Hearth20Regal.RAISED), true)
	draw_rect(card, Hearth20Regal.swatch(Hearth20Regal.BORDER), false, 1.0)
	draw_string(ThemeDB.fallback_font, card.position + Vector2(26, 43), "HEARTH20  /  MAP WORKSPACE", HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 52, 12, Color("#75c9b6"))
	draw_string(ThemeDB.fallback_font, card.position + Vector2(26, 87), title, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 52, 23, Color("#f0e6d3"))
	draw_multiline_string(ThemeDB.fallback_font, card.position + Vector2(26, 122), body, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 52, 16, 3, Color("#b4c0bf"))
	draw_string(ThemeDB.fallback_font, card.position + Vector2(26, 205), steps, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 52, 14, Color("#75c9b6"))

func fit_map() -> void:
	fit_pending = true
	queue_redraw()

func _draw_checkered_background(map_rect: Rect2) -> void:
	var tile := 64.0 * camera_zoom
	var count_x := ceili(map_rect.size.x / maxf(tile, 1.0))
	var count_y := ceili(map_rect.size.y / maxf(tile, 1.0))
	for y in count_y:
		for x in count_x:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(map_rect.position + Vector2(x, y) * tile, Vector2(tile, tile)), Hearth20Regal.swatch(Hearth20Regal.RAISED), true)

func _draw_grid(scene: Dictionary, cell_px: float) -> void:
	var color := Color(str(scene.get("grid_color","#d8c99e")))
	color.a=float(scene.get("grid_opacity",0.34))
	var line_width:=float(scene.get("grid_thickness",1.0))
	var width := int(scene.get("width_cells", 24))
	var height := int(scene.get("height_cells", 16))
	for x in range(width + 1):
		_grid_line(_world_to_screen(Vector2(x, 0), cell_px), _world_to_screen(Vector2(x, height), cell_px), color, line_width)
	for y in range(height + 1):
		_grid_line(_world_to_screen(Vector2(0, y), cell_px), _world_to_screen(Vector2(width, y), cell_px), color, line_width)

func _grid_line(a: Vector2, b: Vector2, color: Color, thickness: float) -> void:
	draw_line(a,b,Color(0,0,0,color.a*.55),thickness+1.0,true)
	draw_line(a,b,color,thickness,true)

func _draw_geometry(scene: Dictionary, cell_px: float) -> void:
	for wall in scene.get("walls", []):
		if role=="dm" and not str(scene.get("map_asset","")).is_empty() and active_layer!="light": continue
		if wall is Dictionary and wall.has("a") and wall.has("b"):
			var a := _geometry_point(wall.a)
			var b := _geometry_point(wall.b)
			draw_line(_world_to_screen(a, cell_px), _world_to_screen(b, cell_px), Color("#ddd7c8"), 4.0, true)
	for door in scene.get("doors", []):
		if door is Dictionary and door.has("a") and door.has("b"):
			var a := _geometry_point(door.a)
			var b := _geometry_point(door.b)
			draw_line(_world_to_screen(a, cell_px), _world_to_screen(b, cell_px), Color("#58d6a0") if bool(door.get("open", false)) else Color("#ffcc72"), 5.0, true)
	for prop in scene.get("props", []):
		if prop is Dictionary and prop.has("position"):
			var pos: Vector2 = prop.position if prop.position is Vector2 else Vector2(float(prop.position.get("x", 0.0)), float(prop.position.get("y", 0.0)))
			var center := _world_to_screen(pos, cell_px)
			draw_circle(center, maxf(5.0, 7.0 * camera_zoom), Color("#b3996c"))

func _geometry_point(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))

func _draw_fog(scene: Dictionary, cell_px: float) -> void:
	if role != "dm":
		return
	for fog in scene.get("fog_rects", []):
		var rect := Rect2()
		if fog is Rect2:
			rect = fog
		elif fog is Dictionary:
			rect = Rect2(Vector2(fog.get("x", 0.0), fog.get("y", 0.0)), Vector2(fog.get("width", 0.0), fog.get("height", 0.0)))
		draw_rect(_screen_rect(Rect2(rect.position * cell_px, rect.size * cell_px)), Color(0.045, 0.052, 0.062, gm_mask_opacity), true)

func _draw_lighting(scene: Dictionary, cell_px: float, map_rect: Rect2) -> void:
	if not bool(scene.get("dynamic_lighting",false)) or (role=="dm" and not lighting_preview):
		if soft_light:soft_light.set_active(false)
		return
	if role=="dm":
		if not lighting_preview or not bool(scene.get("dynamic_lighting",false)): return
		var cache_key=Hearth20Vision.signature(campaign,scene)
		if lighting_cache_key!=cache_key:
			light_meshes=Hearth20Lighting.meshes(Hearth20Vision.build_view(campaign,"dm-local",scene))
			lighting_cache_key=cache_key
		var ambient:=str(scene.get("ambient_light","bright"))
		var darkness:=0.66 if ambient=="dark" else 0.32 if ambient=="dim" else 0.0
		draw_rect(map_rect,Color(0.015,0.025,0.06,darkness))
	else:
		light_meshes=scene.get("light_visuals",[])
	var map_art:=_map_texture()
	if map_art!=null and soft_light!=null:
		var key=lighting_cache_key+":"+map_texture_cache_key+":"+str(Hearth20NaturalLight.settings(scene).hash()) if role=="dm" else Hearth20Contracts.sha256(var_to_bytes([snapshot.get("map_sha256",""),scene.get("light_field",{}),snapshot.get("vision_mask",{}),scene.get("natural_light",{}),scene.get("ambient_light","bright")]))
		soft_light.configure(key,map_art,light_meshes,scene,snapshot.get("vision_mask",{}),role=="player")
		var lit:=soft_light.texture()
		if lit!=null:
			draw_texture_rect(lit,_screen_rect(native_map_rect(Vector2i(map_art.get_size()))),false)
			return
	if soft_light:soft_light.set_active(false)
	for mesh in light_meshes:
		Hearth20Lighting.draw_mesh(self,mesh,cell_px*camera_zoom,camera_pan*camera_zoom)

func _draw_player_vision(cell_px: float) -> void:
	if snapshot.get("scene", {}).get("id", "") == "blackout":
		draw_rect(Rect2(Vector2.ZERO, get_rect().size), Color("#0b1015"))
		_draw_empty_state("The table is covered", "Your character sheet and chat are still available.", "The DM will reveal the map when it is ready")
		return
	var mask: Dictionary = snapshot.get("vision_mask", {})
	if mask.is_empty():
		return
	var columns := int(mask.get("columns", 0))
	var subdivisions := maxi(1, int(mask.get("subdivisions", 1)))
	var levels: PackedByteArray = mask.get("levels", PackedByteArray())
	if columns <= 0:
		return
	var block := cell_px / float(subdivisions)
	for index in levels.size():
		var level := int(levels[index])
		if level >= 3:
			continue
		var tint := Color(0.0, 0.0, 0.0, 1.0) if level == 0 else Color(0.02, 0.04, 0.09, 0.47 if level == 1 else 0.25)
		var pos := Vector2(index % columns, index / columns) * block
		draw_rect(_screen_rect(Rect2(pos, Vector2.ONE * block)), tint)

func _draw_actors(_scene: Dictionary, cell_px: float, layer: String = "tokens") -> void:
	var occupied_captions: Array[Rect2] = []
	for actor in current_actors():
		if actor.get("layer", "tokens") != layer: continue
		if not actor is Dictionary or not actor.get("position") is Vector2:
			continue
		var center := _world_to_screen(actor.position, cell_px)
		var diameter := maxf(24.0, cell_px * camera_zoom * float(actor.get("token_size", 0.82)))
		var rect := Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
		if not rect.grow(44.).intersects(Rect2(Vector2.ZERO,size)):continue
		var hidden_for_players := role == "dm" and (bool(actor.get("hidden", false)) or layer == "gm")
		var token_tint := Color(1.0, 1.0, 1.0, 0.48) if hidden_for_players else Color.WHITE
		if actor.get("decorative",false)==true:
			for other in current_actors():
				if other.get("layer","tokens")=="tokens" and other.get("position",Vector2(-999,-999)).distance_to(actor.position)<float(actor.get("token_size",1))*0.5: token_tint.a=0.42
		var texture := _actor_texture(str(actor.get("png_asset_id", actor.get("asset_id", ""))))
		if texture:
			draw_texture_rect(texture, rect, false, token_tint)
		else:
			var fill := Color("#547fa0") if bool(actor.get("is_hero", actor.get("kind", "") == "hero")) else Color("#9a624a")
			if hidden_for_players:
				fill.a = 0.48
			draw_circle(center, diameter * 0.5, fill)
			draw_arc(center, diameter * 0.5, 0.0, TAU, 48, Color("#d2ae79") if hidden_for_players else Color("#faf3df"), 2.0)
		if str(actor.get("id", "")) == selected_actor_id:
			draw_arc(center, diameter * 0.58, 0.0, TAU, 48, Color("#62e4d1"), 3.0)
		if actor.get("decorative",false)==true: continue
		var label := str(actor.get("name", "Hero" if bool(actor.get("is_hero", false)) else "Token"))
		if role == "player" and str(actor.get("kind", "")) == "hero":
			for sheet in snapshot.get("sheets", []):
				if str(sheet.get("id", "")) == str(actor.get("id", "")):
					label = str(sheet.get("name", "My hero"))
					break
		if hidden_for_players:
			label = "Hidden · " + label
		var caption := label.left(24) + ("…" if label.length() > 24 else "")
		var label_width := clampf(ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0, 70.0, 220.0)
		var caption_height := 36.0 if role == "player" and actor.has("movement") else 21.0
		var caption_rect := Rect2(center + Vector2(-label_width * 0.5, diameter * 0.5 + 3), Vector2(label_width, caption_height))
		var original_y := caption_rect.position.y
		caption_rect.position.x = clampf(caption_rect.position.x, 4.0, maxf(4.0, get_rect().size.x - label_width - 4.0))
		for attempt in 11:
			var offset := 0.0 if attempt == 0 else ceilf(float(attempt) / 2.0) * (caption_height + 2.0) * (1.0 if attempt % 2 == 1 else -1.0)
			caption_rect.position.y = clampf(original_y + offset, 4.0, maxf(4.0, get_rect().size.y - caption_height - 4.0))
			var overlaps := false
			for previous in occupied_captions:
				if caption_rect.grow(2.0).intersects(previous):
					overlaps = true
					break
			if not overlaps:
				break
		occupied_captions.append(caption_rect)
		if absf(caption_rect.position.y - original_y) > 3.0:
			draw_line(center + Vector2(0.0, diameter * 0.5), Vector2(caption_rect.get_center().x, caption_rect.position.y), Color(0.7, 0.84, 0.82, 0.55), 1.0)
		draw_rect(caption_rect, Color(0.04, 0.06, 0.07, 0.86))
		draw_string(ThemeDB.fallback_font, caption_rect.position + Vector2(4, 15), caption, HORIZONTAL_ALIGNMENT_CENTER, label_width - 8.0, 13, Color("#d2ae79") if hidden_for_players else Color.WHITE)
		if role == "player" and actor.has("movement"):
			var movement: Dictionary = actor.movement
			var mode := str(movement.get("mode", "blocked")).replace("_", " ")
			var permission := "Free" if mode == "free until revoked" else "Blocked" if mode == "blocked" else "%.0f ft left" % float(movement.get("remaining_feet", 0.0))
			draw_string(ThemeDB.fallback_font, caption_rect.position + Vector2(0.0, 30.0), permission, HORIZONTAL_ALIGNMENT_CENTER, caption_rect.size.x, 11, Color("#9ee5d8"))

func _actor_texture(asset_id: String) -> Texture2D:
	if asset_id.is_empty():
		return null
	if actor_image_cache.has(asset_id):
		return actor_image_cache[asset_id]
	var record: Variant = current_assets().get(asset_id, null)
	if not record is Dictionary or record.get("kind", "") != "token":
		return null
	var bytes := Marshalls.base64_to_raw(str(record.get("base64", "")))
	if bytes.size() != int(record.get("byte_length", -1)) or Hearth20Assets.sha256(bytes) != str(record.get("sha256", "")):
		return null
	var checked := Hearth20Assets.inspect_token_png_bytes(bytes)
	if not checked.ok:
		return null
	var texture := ImageTexture.create_from_image(checked.image)
	actor_image_cache[asset_id] = texture
	return texture

func _map_image() -> Image:
	if role == "player":
		var bytes: PackedByteArray = snapshot.get("map_png", PackedByteArray())
		if bytes.is_empty() or Hearth20Assets.sha256(bytes) != str(snapshot.get("map_sha256", "")):
			return null
		var image := Image.new()
		return image if image.load_png_from_buffer(bytes) == OK else null
	var scene := current_scene()
	if scene.is_empty():
		return null
	var bytes := Hearth20Assets.read_asset(campaign, str(scene.get("map_asset", "")), "map")
	if bytes.is_empty():
		return null
	return Hearth20Assets.decode_map(bytes)

func _map_texture() -> Texture2D:
	if read_only_preview and preview_texture!=null: return preview_texture
	var texture_key := str(snapshot.get("map_sha256", "")) if role == "player" else str(current_scene().get("map_asset", ""))
	if texture_key.is_empty():
		return null
	if map_texture_cache != null and map_texture_cache_key == texture_key:
		return map_texture_cache
	var image := _map_image()
	if image == null:
		map_texture_cache = null
		map_texture_cache_key = ""
		return null
	map_texture_cache = ImageTexture.create_from_image(image)
	map_texture_cache_key = texture_key
	return map_texture_cache

func import_map(path: String) -> Dictionary:
	if role != "dm":
		return {"ok": false, "error": "Only the DM imports a map."}
	var inspected := Hearth20Assets.inspect_map_file(path)
	if not inspected.ok:
		return inspected
	var scene := current_scene()
	if scene.is_empty():
		return {"ok": false, "error": "Create a scene first."}
	var grid: Dictionary=inspected.get("grid",{})
	var target_cells := int(grid.get("width_cells",maxi(1,int(scene.get("calibration_width_cells",scene.get("width_cells",24))))))
	if grid.is_empty():target_cells=mini(target_cells,maxi(1,floori(256.0*float(inspected.width)/float(inspected.height))))
	var target_height := ceili(float(inspected.height)/(float(inspected.width)/float(target_cells)))
	if target_height>256:return {"ok":false,"error":"Map is too tall for square cells. Crop or pad the image so it fits within 256 cells."}
	var asset_id := Hearth20Assets.store_asset(campaign, inspected, "map")
	if asset_id.is_empty():
		return {"ok": false, "error": "Map image could not be stored."}
	# The DM calibrates by setting the number of cells spanning the image width.
	scene.cell_pixels = float(inspected.width) / float(target_cells)
	scene.width_cells = target_cells
	scene.height_cells = maxi(1, ceili(float(inspected.height) / float(scene.cell_pixels)))
	scene.map_asset = asset_id
	scene.map_width = int(inspected.width)
	scene.map_height = int(inspected.height)
	scene.calibration_width_cells = target_cells
	if not grid.is_empty():scene.feet_per_cell=float(grid.feet_per_cell)
	campaign.revision = int(campaign.get("revision", 0)) + 1
	actor_image_cache.clear()
	map_texture_cache = null
	map_texture_cache_key = ""
	fit_pending = true
	queue_redraw()
	if session and session.local_role == "dm":
		session._broadcast_snapshots()
	return {"ok": true, "sha256": inspected.sha256, "width": inspected.width, "height": inspected.height, "calibration_width_cells": target_cells,"auto_calibrated":not grid.is_empty(),"height_cells":target_height,"feet_per_cell":scene.feet_per_cell}

func calibrate_map_width(cells: int) -> Dictionary:
	if role != "dm" or cells < 1 or cells > 256:
		return {"ok": false, "error": "Map width calibration must be 1 to 256 cells."}
	var scene := current_scene()
	var image := _map_image()
	if scene.is_empty() or image == null:
		return {"ok": false, "error": "Import a map before calibrating it."}
	if ceili(float(image.get_height())/(float(image.get_width())/float(cells)))>256:
		return {"ok":false,"error":"This scale makes the map taller than 256 cells. Choose fewer width cells."}
	scene.calibration_width_cells = cells
	scene.cell_pixels = float(image.get_width()) / float(cells)
	scene.width_cells = cells
	scene.height_cells = maxi(1, ceili(float(image.get_height()) / float(scene.cell_pixels)))
	campaign.revision = int(campaign.get("revision", 0)) + 1
	fit_pending = true
	queue_redraw()
	return {"ok": true, "cell_pixels": scene.cell_pixels, "height_cells": scene.height_cells}

func add_token(name: String, hero: bool = false, position: Vector2 = Vector2(4, 4)) -> String:
	if role != "dm":
		return ""
	var scene := current_scene()
	if scene.is_empty() or campaign.actors.size() >= Hearth20Contracts.MAX_ACTORS:
		return ""
	var actor:=Hearth20TokenInventory.new_actor(name,hero,scene,position)
	var id: String=actor.id
	campaign.actors.append(actor)
	campaign.revision = int(campaign.get("revision", 0)) + 1
	selected_actor_id = id
	selection_changed.emit(id)
	queue_redraw()
	if session and session.local_role == "dm":
		session._broadcast_snapshots()
	return id

func attach_token_png(path: String) -> Dictionary:
	if selected_actor_id.is_empty():
		return {"ok": false, "error": "Select a token first."}
	var result := Hearth20Assets.inspect_token_png(path)
	if not result.ok:
		return result
	var attached := Hearth20Assets.attach_token_override(campaign, selected_actor_id, result.bytes, result.name)
	if attached.ok:
		actor_image_cache.clear()
		queue_redraw()
		if session and session.local_role == "dm":
			session._broadcast_snapshots()
	return attached

func update_movement_policy(mode: String, feet: float = 0.0) -> Dictionary:
	if not session:
		return {"ok": false, "error": "No table session."}
	return session.set_player_movement(selected_actor_id, mode, feet)

func set_fog_tool(enabled: bool) -> void:
	measure_tool = false
	template_shape = ""
	measuring = false
	fog_tool = enabled
	door_tool = false
	fx_target_mode = false
	queue_redraw()

func set_door_tool(enabled: bool) -> void:
	measure_tool = false
	template_shape = ""
	measuring = false
	door_tool = enabled
	fog_tool = false
	fx_target_mode = false
	queue_redraw()

func toggle_snap_to_grid() -> bool:
	if role != "dm":
		return false
	var scene := current_scene()
	scene.snap_to_grid = not bool(scene.get("snap_to_grid", true))
	campaign.revision = int(campaign.get("revision", 0)) + 1
	if session and session.local_role == "dm":
		session._broadcast_snapshots()
	return bool(scene.snap_to_grid)

func _toggle_door_at(screen_point: Vector2) -> void:
	if role != "dm":
		return
	var scene := current_scene()
	var cell_px := float(scene.get("cell_pixels", 64.0))
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for door in scene.get("doors", []):
		if not door is Dictionary or not door.has("a") or not door.has("b"):
			continue
		var a := _world_to_screen(_geometry_point(door.a), cell_px)
		var b := _world_to_screen(_geometry_point(door.b), cell_px)
		var point := Geometry2D.get_closest_point_to_segment(screen_point, a, b)
		var distance := point.distance_to(screen_point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = door
	if nearest.is_empty() or nearest_distance > maxf(12.0, 14.0 * camera_zoom):
		hint_changed.emit("Door tool is DM-only. Click a visible door segment.")
		return
	nearest.open = not bool(nearest.get("open", false))
	campaign.revision = int(campaign.get("revision", 0)) + 1
	if session and session.local_role == "dm":
		session._broadcast_snapshots()
	queue_redraw()
	hint_changed.emit("Door %s." % ("opened" if nearest.open else "closed"))

func clear_fog() -> void:
	if role != "dm":
		return
	var scene := current_scene()
	scene.fog_rects = []
	campaign.revision = int(campaign.get("revision", 0)) + 1
	if session and session.local_role == "dm":
		session._broadcast_snapshots()
	queue_redraw()

func begin_fire_rocket_target() -> void:
	if role == "dm" and not selected_actor_id.is_empty():
		measure_tool = false
		template_shape = ""
		measuring = false
		fx_target_mode = true
		fog_tool = false
		door_tool = false
		hint_changed.emit("Choose the rocket's impact point on the map.")

func fire_rocket_to(destination: Vector2) -> Dictionary:
	var actor := Hearth20Contracts.find_actor(campaign, selected_actor_id) if role == "dm" else {}
	if actor.is_empty():
		return {"ok": false, "error": "Select a token to launch the cosmetic rocket from."}
	var result: Dictionary = session.play_fire_rocket(actor.position, destination, selected_actor_id)
	if result.ok:
		active_fx.play_fire_rocket(actor.position, destination)
	return result

func _move_selected(from: Vector2, to: Vector2, path: Array=[]) -> void:
	if selected_actor_id.is_empty() or read_only_preview:
		return
	var scene := current_scene()
	var snapped := Hearth20TokenInventory.snap_position(scene,to)
	if not path.is_empty():
		var result: Dictionary=session.board_action({"action":"move_path","actor_id":selected_actor_id,"points":path,"expected_revision":int(campaign.get("revision",0)) if role=="dm" else int(snapshot.get("revision",-1))})
		if not result.ok:hint_changed.emit(str(result.get("error","Token could not be moved.")))
		queue_redraw();return
	if role == "dm":
		if session and session.local_role == "dm":
			var actor := Hearth20Contracts.find_actor(campaign, selected_actor_id)
			if not actor.is_empty():
				var distance := from.distance_to(snapped) * float(scene.get("feet_per_cell", 5.0))
				var moved := Hearth20Contracts.authorize_and_apply_move(campaign, "dm-local", "dm", selected_actor_id, from, snapped, distance)
				if moved.ok:
					session._broadcast_snapshots()
	else:
		var current_revision := int(snapshot.get("revision", -1))
		if current_revision >= 0 and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			session.request_move.rpc_id(1, selected_actor_id, from, snapped, current_revision)
	queue_redraw()

func _get_drag_data(_at_position: Vector2) -> Variant:
	# Keep native dragging off while planning. Leaving the board starts it explicitly.
	return null
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not read_only_preview and Hearth20TokenDrag.accepts(session,data)
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position,data):return
	var id=str(data.actor_id);var actor=Hearth20Contracts.find_actor(campaign,id)
	var result=session.place_inventory_token(id,_screen_to_world(at_position))
	if not result.ok:hint_changed.emit(str(result.get("error","Token could not be placed.")))
	else:selected_actor_id=id;selection_changed.emit(id)
	dragging_actor=false;queue_redraw()

func _actor_at(screen: Vector2) -> Dictionary:
	var scene := current_scene()
	var cell_px := float(scene.get("cell_pixels", 64.0))
	for actor in current_actors().duplicate():
		if not actor is Dictionary:
			continue
		if role == "dm" and actor.get("layer", "tokens") != active_layer: continue
		var position: Variant = actor.get("position", null)
		if not position is Vector2:
			continue
		var radius := maxf(12.0, cell_px * camera_zoom * float(actor.get("token_size", 0.82)) * 0.6)
		if _world_to_screen(position, cell_px).distance_to(screen) <= radius:
			if role == "player" and str(actor.get("kind", "")) != "hero":
				continue
			return actor
	return {}

func _world_to_screen(point: Vector2, cell_px: float) -> Vector2:
	return (point * cell_px - camera_pan) * camera_zoom

func _screen_to_world(point: Vector2) -> Vector2:
	var scene := current_scene()
	var cell_px := maxf(1.0, float(scene.get("cell_pixels", 64.0)))
	return ((point / maxf(camera_zoom, 0.01)) + camera_pan) / cell_px

func _screen_rect(world_rect_px: Rect2) -> Rect2:
	return Rect2((world_rect_px.position - camera_pan) * camera_zoom, world_rect_px.size * camera_zoom)

func _zoom_at(screen_point: Vector2, factor: float) -> void:
	var before := _screen_to_world(screen_point)
	camera_zoom = clampf(camera_zoom * factor, 0.15, 3.0)
	var after := _screen_to_world(screen_point)
	var scene := current_scene()
	var cell_px := float(scene.get("cell_pixels", 64.0))
	camera_pan += (before - after) * cell_px
	queue_redraw()

func _on_resized() -> void:
	var canvas_size := get_rect().size
	if not fit_pending and last_canvas_size.x > 0.0 and last_canvas_size.y > 0.0:
		camera_pan += (last_canvas_size - canvas_size) * 0.5 / maxf(camera_zoom, 0.01)
	last_canvas_size = canvas_size
	queue_redraw()

func set_measure_tool(enabled: bool) -> void:
	measure_tool = enabled
	template_shape = ""
	measuring = false
	fog_tool = false
	door_tool = false
	fx_target_mode = false
	hint_changed.emit("Ruler · drag to measure; Escape to return to selection." if enabled else "Selection tool.")
	queue_redraw()

func set_template_tool(shape: String) -> void:
	if role != "dm" or shape not in ["circle", "rectangle", "line", "cone"]:
		return
	set_measure_tool(false)
	template_shape = shape
	hint_changed.emit("%s area · drag to set size/direction; Escape cancels." % shape.capitalize())

func _draw_templates(scene: Dictionary, cell_px: float) -> void:
	for template in scene.get("templates", []):
		_draw_area(str(template.get("shape", "line")), template.start, template.end, cell_px, str(template.get("id", "")) == selected_template_id)
	if measuring and not template_shape.is_empty():
		_draw_area(template_shape, measure_start, measure_end, cell_px, true)

func _draw_area(shape: String, start: Vector2, end: Vector2, cell_px: float, selected: bool) -> void:
	var a := _world_to_screen(start, cell_px)
	var b := _world_to_screen(end, cell_px)
	var color := Color("#76e0ca") if selected else Color("#d9ad6c")
	var fill := Color(color, 0.16)
	if shape == "circle":
		draw_circle(a, a.distance_to(b), fill)
		draw_arc(a, a.distance_to(b), 0, TAU, 80, color, 2.0, true)
	elif shape == "rectangle":
		var rect := Rect2(a, Vector2.ZERO).expand(b)
		draw_rect(rect, fill)
		draw_rect(rect, color, false, 2.0)
	elif shape == "cone":
		var perpendicular := (b - a).normalized().orthogonal() * a.distance_to(b) * 0.5
		var points := PackedVector2Array([a, b + perpendicular, b - perpendicular])
		draw_colored_polygon(points, fill)
		points.append(a)
		draw_polyline(points, color, 2.0, true)
	else:
		draw_line(a, b, Color(color, 0.24), maxf(4.0, cell_px * camera_zoom), true)
		draw_line(a, b, color, 2.0, true)
	var feet := start.distance_to(end) * float(current_scene().get("feet_per_cell", 5.0))
	var label := "%.1f ft radius" % feet if shape == "circle" else "%.1f × %.1f ft" % [absf(end.x - start.x) * float(current_scene().get("feet_per_cell", 5.0)), absf(end.y - start.y) * float(current_scene().get("feet_per_cell", 5.0))] if shape == "rectangle" else "%.1f ft %s" % [feet, shape]
	draw_string(ThemeDB.fallback_font, b + Vector2(8, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

func _template_at(point: Vector2) -> String:
	var templates: Array = current_scene().get("templates", [])
	for index in range(templates.size() - 1, -1, -1):
		var template: Dictionary = templates[index]
		var start: Vector2 = template.start
		var end: Vector2 = template.end
		if template.shape == "circle" and point.distance_to(start) <= start.distance_to(end):
			return str(template.id)
		if template.shape == "rectangle" and Rect2(start, Vector2.ZERO).expand(end).grow(0.1).has_point(point):
			return str(template.id)
		if template.shape == "line" and Geometry2D.get_closest_point_to_segment(point, start, end).distance_to(point) < 0.5:
			return str(template.id)
		if template.shape == "cone":
			var side := (end - start).normalized().orthogonal() * start.distance_to(end) * 0.5
			if Geometry2D.is_point_in_polygon(point, PackedVector2Array([start, end + side, end - side])):
				return str(template.id)
	return ""

func _draw_measurement(cell_px: float) -> void:
	if not measure_tool:
		return
	var a := _world_to_screen(measure_start, cell_px)
	var b := _world_to_screen(measure_end, cell_px)
	draw_line(a, b, Color("#8fe9e0"), 2.0, true)
	for point in [a, b]:
		draw_circle(point, 4.0, Color("#8fe9e0"))
	var text := "%.1f ft" % (measure_start.distance_to(measure_end) * float(current_scene().get("feet_per_cell", 5.0)))
	var label_pos := b + Vector2(12, -12)
	var text_width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_rect(Rect2(label_pos + Vector2(-5, -18), Vector2(text_width + 12, 25)), Color("#17272e"))
	draw_string(ThemeDB.fallback_font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#b2fff0"))

func _on_ping_received(event: Dictionary) -> void:
	pings.append({"point": event.point, "sender": event.get("sender", "Player"), "started": Time.get_ticks_msec()})
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	var animated_pings=not pings.is_empty();var rulers_before=remote_rulers.size()
	pings = pings.filter(func(event: Dictionary) -> bool: return Time.get_ticks_msec() - int(event.started) < 1800)
	var now := Time.get_ticks_msec()
	for key in remote_rulers.keys():
		if now - int(remote_rulers[key].received) > 1600: remote_rulers.erase(key)
	if not local_ruler.is_empty() and now - last_preview_msec > 100 and session and not read_only_preview:
		session.send_tool_preview(local_ruler)
		last_preview_msec = now
	if role == "dm" and active_fx:
		for effect in current_scene().get("fx", []):
			if effect.get("preset", "") != "tabletop-fx-v1" or seen_fx.has(str(effect.id)): continue
			active_fx.add_authorized_event(effect)
			seen_fx[str(effect.id)] = true
	var revision=int(campaign.get("revision",0)) if role=="dm" else int(snapshot.get("revision",0))
	var camera_state=Vector3(camera_pan.x,camera_pan.y,camera_zoom)
	if animated_pings or rulers_before!=remote_rulers.size() or revision!=draw_revision or Hearth20Regal.revision!=draw_palette or camera_state!=draw_camera:
		draw_revision=revision;draw_palette=Hearth20Regal.revision;draw_camera=camera_state;queue_redraw()

func activate_tool(value: String, dismiss_ruler: bool = false) -> void:
	if read_only_preview: return
	if tool_drag or dismiss_ruler or not bool(local_ruler.get("linger",false)):
		if session: session.send_tool_preview({})
		local_ruler.clear()
	draft.clear()
	pending_token.clear()
	polygon_points.clear()
	tool_drag = false
	moving_object = false
	resizing_object = false
	measure_tool = false
	template_shape = ""
	measuring = false
	fog_tool = false
	door_tool = false
	fx_target_mode = false
	dragging_actor = false
	drag_points.clear()
	panning = false
	tool_name = value
	queue_redraw()

func _bounded_point(screen: Vector2) -> Vector2:
	var scene := current_scene()
	return _screen_to_world(screen).clamp(Vector2.ZERO, Vector2(float(scene.get("width_cells",24)) - 0.001, float(scene.get("height_cells",16)) - 0.001))

func _ruler_point(screen: Vector2) -> Vector2:
	var point := _bounded_point(screen)
	if ruler_settings.snap == "center": point = point.floor() + Vector2.ONE * 0.5
	elif ruler_settings.snap == "corner": point = point.round()
	var scene := current_scene()
	return point.clamp(Vector2.ZERO, Vector2(float(scene.get("width_cells",24)) - 0.001, float(scene.get("height_cells",16)) - 0.001))

func _tool_input(event: InputEvent) -> bool:
	if read_only_preview: return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			activate_tool("select",true)
			return false
		if event.keycode in [KEY_DELETE, KEY_BACKSPACE] and not selected_object_id.is_empty():
			var result: Dictionary = session.board_action({"action":"delete", "id":selected_object_id})
			hint_changed.emit(str(result.get("error", "Drawing removed. Ctrl+Z restores your last edit.")))
			selected_object_id = ""
			object_selected.emit({})
			return true
		if event.keycode == KEY_Z and event.ctrl_pressed and selected_template_id.is_empty() and not session.board_undo.get(session.local_player_id, []).is_empty():
			var result: Dictionary = session.board_action({"action":"undo"})
			hint_changed.emit(str(result.get("error", "Drawing edit undone.")))
			return true
		if event.keycode == KEY_Q and tool_drag and tool_name == "measure" and ruler_settings.shape == "line":
			if local_ruler.points.size() < 64: local_ruler.points.append(local_ruler.points.back())
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if dragging_actor:
			drag_points[-1]=Hearth20TokenInventory.snap_position(current_scene(),_bounded_point(event.position))
			if drag_points.size()<64 and drag_points[-1]!=drag_points[-2]:drag_points.append(drag_points.back())
			return true
		if tool_name == "mask" and mask_polygon and polygon_points.size() >= 3:
			var result: Dictionary = session.board_action({"action":"mask_polygon", "points":polygon_points, "reveal":mask_reveal})
			hint_changed.emit(str(result.get("error", "Map mask updated.")))
			polygon_points.clear()
			return true
		if tool_name == "measure" and tool_drag and ruler_settings.shape == "line":
			local_ruler.points[-1] = _ruler_point(event.position)
			if local_ruler.points.size() < 64: local_ruler.points.append(local_ruler.points.back())
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if tool_name=="token_place":
			if not event.pressed and role=="dm" and not pending_token.is_empty():
				var token_data:=pending_token.duplicate()
				var point:=_bounded_point(event.position)
				point=Hearth20TokenInventory.snap_position(current_scene(),point)
				activate_tool("select",true)
				var id: String=str(token_data.get("actor_id",""))
				if id.is_empty(): id=add_token(str(token_data.name),bool(token_data.hero),point)
				elif session:
					var placed: Dictionary=session.place_inventory_token(id,point)
					if not placed.ok: hint_changed.emit(str(placed.error)); return true
					active_layer=str(Hearth20Contracts.find_actor(campaign,id).get("layer","tokens"))
				selected_actor_id=id; selection_changed.emit(id)
				hint_changed.emit("Token placed. Use Tokens to edit its appearance and grant control.")
			return true
		if event.pressed and not tool_drag and not local_ruler.is_empty():
			local_ruler.clear()
			if session: session.send_tool_preview({})
		if space_pan: return false
		if event.pressed:
			grab_focus()
			var point := _bounded_point(event.position)
			if tool_name == "select":
				var object := object_at(point)
				selected_object_id = str(object.get("id", ""))
				object_selected.emit(object)
				if object.is_empty(): return false
				selected_actor_id = ""
				selected_template_id = ""
				selection_changed.emit("")
				if role == "dm" or bool(object.get("mine", false)):
					draft = object.duplicate(true)
					moving_object = true
					resizing_object = false
					if object.kind in ["rectangle","ellipse","text"]:
						var rect := Hearth20BoardTools.bounds(object)
						var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
						for i in 4:
							if _world_to_screen(corners[i],float(current_scene().cell_pixels)).distance_to(event.position)<10:
								resizing_object=true
								resize_anchor=corners[(i+2)%4]
					tool_drag = true
					tool_start = point
				return true
			if tool_name == "measure":
				local_ruler = ruler_settings.duplicate(true)
				local_ruler.points = [_ruler_point(event.position), _ruler_point(event.position)]
				tool_drag = true
				return true
			if tool_name == "beacon":
				var o := tool_settings.duplicate(true)
				o.kind = "beacon"
				o.layer = "tokens"
				o.points = [point]
				var result: Dictionary = session.board_action({"action":"add", "object":o})
				hint_changed.emit(str(result.get("error", "Beacon placed for the table.")))
				return true
			if tool_name == "mask" and mask_polygon:
				if polygon_points.size() < 64: polygon_points.append(point)
				return true
			if tool_name in ["draw", "text", "lighting", "mask", "fx"]:
				tool_start = point
				draft = tool_settings.duplicate(true)
				draft.layer = active_layer
				draft.points = [point, point]
				if tool_name == "text": draft.kind = "text"
				if tool_name == "lighting": draft.layer = "light"
				tool_drag = true
				return true
		elif tool_drag:
			tool_drag = false
			if tool_name == "measure":
				local_ruler.points[-1] = _ruler_point(event.position)
				if not bool(ruler_settings.linger):
					local_ruler.clear()
					session.send_tool_preview({})
				return true
			if moving_object:
				moving_object = false
				var result: Dictionary = session.board_action({"action":"update", "object":draft})
				hint_changed.emit(str(result.get("error", "Drawing moved.")))
			elif tool_name == "mask":
				var rect := Rect2(tool_start, Vector2.ZERO).expand(_bounded_point(event.position))
				if rect.size.x > 0.01 and rect.size.y > 0.01:
					var result: Dictionary = session.board_action({"action":"mask", "rect":rect, "reveal":mask_reveal})
					hint_changed.emit(str(result.get("error", "Mask updated.")))
			elif tool_name == "fx":
				var command := fx_settings.duplicate(true)
				command.end = _bounded_point(event.position)
				command.start = tool_start if str(command.effect) in Hearth20BoardTools.CAST_EFFECTS else command.end
				var result: Dictionary = session.board_action({"action":"fx", "effect":command})
				hint_changed.emit(str(result.get("error", "Effect shared with the table.")))
			else:
				if draft.kind != "freehand": draft.points[-1] = _bounded_point(event.position)
				if draft.kind == "text":
					var p: Vector2 = draft.points[0]
					var end: Vector2 = draft.points[-1]
					if p.distance_to(end) < 0.2:
						draft.points[-1] = (p + Vector2(4, 1.5)).min(Vector2(float(current_scene().width_cells)-0.001,float(current_scene().height_cells)-0.001))
				var result: Dictionary = session.board_action({"action":"add", "object":draft})
				hint_changed.emit(str(result.get("error", "Placed. Use Select to move, edit or delete it.")))
			draft.clear()
			return true
	if event is InputEventMouseMotion and tool_drag:
		var point := _bounded_point(event.position)
		if tool_name == "measure": local_ruler.points[-1] = _ruler_point(event.position)
		elif moving_object:
			var delta := point - tool_start
			var original := selected_object()
			if not original.is_empty():
				if resizing_object:
					draft.points=[resize_anchor,point]
				else:
					var rect := Hearth20BoardTools.bounds(original)
					delta = delta.clamp(-rect.position, Vector2(float(current_scene().width_cells)-0.001,float(current_scene().height_cells)-0.001) - rect.end)
					draft.points = original.points.map(func(p): return p + delta)
		elif not draft.is_empty():
			if draft.kind == "freehand" and tool_name == "draw":
				if draft.points.size() < 512 and point.distance_to(draft.points.back()) > 0.025: draft.points.append(point)
			else: draft.points[-1] = point
		queue_redraw()
		return true
	return false

func selected_object() -> Dictionary:
	for object in current_scene().get("annotations", []):
		if str(object.id) == selected_object_id: return object
	return {}

func object_at(point: Vector2) -> Dictionary:
	var objects: Array = current_scene().get("annotations", [])
	for i in range(objects.size()-1, -1, -1):
		var o: Dictionary = objects[i]
		if o.get("layer", "tokens") != active_layer: continue
		var rect := Hearth20BoardTools.bounds(o).grow(0.15)
		if o.kind in ["freehand", "line", "wall", "window", "door"]:
			for j in range(1, o.points.size()):
				if Geometry2D.get_closest_point_to_segment(point, o.points[j-1], o.points[j]).distance_to(point) <= 0.15: return o
		elif o.kind in ["light", "beacon"]:
			if point.distance_to(o.points[0]) < 0.5: return o
		elif rect.has_point(point): return o
	return {}

func _draw_objects(layer: String, cell_px: float) -> void:
	for o in current_scene().get("annotations", []):
		if o.get("layer", "tokens") == layer and not (moving_object and o.id == selected_object_id): _draw_object(o, cell_px)

func _object_font(o: Dictionary) -> Font:
	var key := str(o.get("font","Sans")) + str(o.get("bold",false)) + str(o.get("italic",false))
	if not font_cache.has(key):
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Georgia", "DejaVu Serif"]) if o.get("font","Sans") == "Serif" else PackedStringArray(["Consolas", "DejaVu Sans Mono"]) if o.get("font","Sans") == "Mono" else PackedStringArray(["Segoe UI", "DejaVu Sans"])
		font.font_weight = 700 if bool(o.get("bold",false)) else 400
		font.font_italic = bool(o.get("italic",false))
		font_cache[key] = font
	return font_cache[key]

func _draw_object(o: Dictionary, cell_px: float) -> void:
	var points := PackedVector2Array()
	for p in o.points: points.append(_world_to_screen(p,cell_px))
	var color := Color(o.get("color","#76e0ca"))
	color.a *= float(o.get("opacity",1.0)) * (0.55 if o.get("layer", "tokens") == "gm" else 1.0)
	var fill := Color(o.get("fill","#00000000"))
	var width := maxf(1.0,float(o.get("width",3.0))*camera_zoom)
	var rect := Rect2(points[0],Vector2.ZERO)
	for p in points: rect = rect.expand(p)
	match str(o.kind):
		"rectangle", "text":
			if fill.a > 0: draw_rect(rect,fill)
			if o.kind == "rectangle" or bool(o.get("border",true)): draw_rect(rect,Color(o.get("border_color",color.to_html())),false,width,true)
			if o.kind == "text":
				var font := _object_font(o)
				var size := clampi(roundi(float(o.get("font_size",24))*camera_zoom),6,288)
				var text_line := TextParagraph.new()
				text_line.add_string(str(o.get("text","")),font,size)
				text_line.width = maxf(10.0,rect.size.x-14)
				text_line.max_lines_visible = maxi(1,floori((rect.size.y-10)/maxf(1.0,font.get_height(size))))
				text_line.draw(get_canvas_item(),rect.position+Vector2(7,5),color)
		"ellipse":
			var ellipse := PackedVector2Array()
			for i in 81: ellipse.append(rect.get_center()+Vector2(cos(float(i)/80*TAU),sin(float(i)/80*TAU))*rect.size*0.5)
			if fill.a > 0 and rect.size.x > 1 and rect.size.y > 1: draw_colored_polygon(ellipse,fill)
			draw_polyline(ellipse,color,width,true)
		"beacon", "light":
			var radius := 12.0 if o.kind == "beacon" else 8.0
			draw_circle(points[0],radius+5,Color(color,0.15))
			draw_circle(points[0],radius,color)
			draw_arc(points[0],radius+8,0,TAU,40,Color(color,0.7),2,true)
			if o.kind == "light":
				draw_arc(points[0],(float(o.get("bright",20))+float(o.get("dim",20)))/float(current_scene().feet_per_cell)*cell_px*camera_zoom,0,TAU,80,Color(color,0.25),1,true)
			else: draw_string(ThemeDB.fallback_font,points[0]+Vector2(20,-10),str(o.get("text","Waypoint")),HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
		_:
			if points.size() >= 2:
				if o.kind == "window" or (o.kind == "door" and bool(o.get("open",false))):
					for i in range(1,points.size()): draw_dashed_line(points[i-1],points[i],color,width,7,true)
				else: draw_polyline(points,color,width,true)
	if str(o.get("id","")) == selected_object_id:
		draw_rect(rect.grow(5),Color("#f0c674"),false,1,true)
		if o.kind in ["rectangle","ellipse","text"]:
			for p in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]: draw_rect(Rect2(p-Vector2.ONE*3,Vector2.ONE*6),Color("#f0c674"))

func _draw_tool_preview(cell_px: float) -> void:
	if tool_name=="token_place" and not pending_token.is_empty() and role=="dm":
		var point:=_bounded_point(get_local_mouse_position())
		point=Hearth20TokenInventory.snap_position(current_scene(),point)
		draw_circle(_world_to_screen(point,cell_px),cell_px*camera_zoom*.42,Color("#e0bd7580"))
	if not draft.is_empty():
		if tool_name == "mask":
			var rect := Rect2(_world_to_screen(draft.points[0],cell_px),Vector2.ZERO).expand(_world_to_screen(draft.points[-1],cell_px))
			draw_rect(rect,Color(0.3,0.9,0.7,0.22) if mask_reveal else Color(0.7,0.3,0.4,0.3))
			draw_rect(rect,Color("#76e0ca"),false,2,true)
		elif tool_name == "fx":
			if str(fx_settings.effect) in Hearth20BoardTools.CAST_EFFECTS:
				draw_line(_world_to_screen(draft.points[0],cell_px),_world_to_screen(draft.points[-1],cell_px),Color(fx_settings.color),2,true)
			else:
				var cursor:=_world_to_screen(draft.points[-1],cell_px)
				draw_arc(cursor,cell_px*camera_zoom*float(fx_settings.size)*.6,0,TAU,48,Color(fx_settings.color),1.5,true)
		else: _draw_object(draft,cell_px)
	if polygon_points.size() > 1:
		var polygon := PackedVector2Array()
		for p in polygon_points: polygon.append(_world_to_screen(p,cell_px))
		draw_polyline(polygon,Color("#76e0ca"),2,true)
	for item in remote_rulers.values(): _draw_ruler(item.measure,cell_px,str(item.name))
	if not local_ruler.is_empty(): _draw_ruler(local_ruler,cell_px,"")

func _draw_ruler(m: Dictionary, cell_px: float, author: String) -> void:
	var color := Color(m.get("color","#76e0ca"))
	var poly := Hearth20BoardTools.polygon(m,float(current_scene().get("feet_per_cell",5)))
	if poly.size() > 2:
		var screen := PackedVector2Array()
		for p in poly: screen.append(_world_to_screen(p,cell_px))
		if absf(Geometry2D.triangulate_polygon(screen).size()) > 0: draw_colored_polygon(screen,Color(color,0.18))
		screen.append(screen[0])
		draw_polyline(screen,color,2,true)
	var points := PackedVector2Array()
	for p in m.points: points.append(_world_to_screen(p,cell_px))
	if m.get("shape","line") == "line": draw_polyline(points,color,2,true)
	for p in points: draw_circle(p,4,color)
	var distance := Hearth20BoardTools.distance(m,float(current_scene().get("feet_per_cell",5)))
	if m.shape != "line": distance = m.points[0].distance_to(m.points.back()) * float(current_scene().get("feet_per_cell",5))
	if m.shape == "square":
		var delta: Vector2 = (m.points.back()-m.points[0]).abs()
		distance = maxf(delta.x,delta.y)*float(current_scene().get("feet_per_cell",5))*(2.0 if m.origin=="center" else 1.0)
	var text := (author+" · " if not author.is_empty() else "") + "%.1f ft" % distance
	if m.shape == "circle": text += " diameter" if m.origin == "edge" else " radius"
	if m.shape == "beam": text += " · %d ft wide" % int(m.beam_width)
	if m.shape == "cone": text += " · %d°" % int(m.angle)
	if m.shape == "square": text += " side · " + str(m.origin)
	var pos := points[-1]+Vector2(12,-16)
	var text_width := ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	pos = pos.clamp(Vector2(8,24),Vector2(maxf(8,size.x-text_width-15),maxf(24,size.y-12)))
	draw_rect(Rect2(pos-Vector2(6,19),Vector2(text_width+14,28)),Color("#12262e"))
	draw_string(ThemeDB.fallback_font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,color)

func _on_tool_preview(event: Dictionary) -> void:
	if bool(event.get("own",false)) or (role == "dm" and event.get("sender","") == "dm-local"): return
	if event.get("measure",{}).is_empty(): remote_rulers.erase(str(event.sender))
	else: remote_rulers[str(event.sender)] = {"measure":event.measure, "name":event.get("name","Player"), "received":Time.get_ticks_msec()}
	set_process(true)
	queue_redraw()

func _draw_pings(cell_px: float) -> void:
	for ping in pings:
		var elapsed := float(Time.get_ticks_msec() - int(ping.started)) / 1800.0
		var center := _world_to_screen(ping.point, cell_px)
		var color := Color(0.5, 1.0, 0.86, 1.0 - elapsed)
		draw_arc(center, 10.0 + fmod(elapsed * 2.0, 1.0) * 42.0, 0, TAU, 48, color, 3.0, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(12, -14), str(ping.sender), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
