extends RefCounted
class_name Hearth20Vision
## Host-only sight calculation. A player receives a redacted image, never the source.
## Visibility is deliberately conservative at a quarter-cell boundary.

const MAX_SAMPLES := 65536
const MAX_RANGE := 1000.0
static var line_masks: Dictionary={}
static var common_cache={}
static func _copy_view(value: Dictionary) -> Dictionary:
	var result=value.duplicate();result.levels=value.levels.duplicate()
	for key in ["lights","observers","segments","ray_segments"]:result[key]=value.get(key,[]).duplicate(true)
	for light in result.lights:
		if light.get("line_mask") is PackedByteArray:light.line_mask=light.line_mask.duplicate()
	return result
static func signature(campaign: Dictionary,scene: Dictionary) -> String:
	var barriers=[];var carried=[]
	for object in scene.get("annotations",[]):
		if object.get("layer","")=="light" or object.get("kind","") in ["wall","window","door","light"]:barriers.append(object)
	for actor in campaign.get("actors",[]):
		if actor.get("in_inventory",false) or actor.get("scene_id","")!=scene.get("id",""):continue
		var settings=actor.get("vision",{})
		if settings is Dictionary and float(settings.get("bright_light_feet",0))+float(settings.get("dim_light_feet",0))>0:carried.append([actor.get("position"),settings])
	var sky=Hearth20NaturalLight.settings(scene);sky.erase("haze");sky.erase("exposure")
	return Hearth20Contracts.sha256(var_to_bytes([scene.get("id"),scene.get("width_cells"),scene.get("height_cells"),scene.get("feet_per_cell"),scene.get("dynamic_lighting"),scene.get("blackout"),scene.get("ambient_light"),scene.get("walls",[]),scene.get("doors",[]),scene.get("lights",[]),scene.get("fog_rects",[]),sky,barriers,carried]))

static func valid_settings(value: Variant) -> bool:
	if not value is Dictionary or not value.get("enabled", true) is bool:
		return false
	for field in ["darkvision_feet", "bright_light_feet", "dim_light_feet","blindsight_feet","truesight_feet","tremorsense_feet"]:
		var number: Variant = value.get(field, 0.0)
		if not (number is float or number is int) or not is_finite(float(number)) or float(number) < 0.0 or float(number) > MAX_RANGE:
			return false
	return true

static func build_view(campaign: Dictionary, player_id: String, scene: Dictionary,use_cache=true) -> Dictionary:
	var key=signature(campaign,scene)
	# This fork uses common environmental vision. Private actors and sheets are still
	# filtered separately for every recipient in project_for_player.
	if use_cache and common_cache.has(key):return _copy_view(common_cache[key])
	var result=_build_view(campaign,player_id,scene);result.environment_key=key
	if use_cache:
		common_cache[key]=result
		while common_cache.size()>4:common_cache.erase(common_cache.keys()[0])
	return _copy_view(result) if use_cache else result
static func _build_view(campaign: Dictionary, _player_id: String, scene: Dictionary) -> Dictionary:
	var width := int(scene.get("width_cells", 24))
	var height := int(scene.get("height_cells", 16))
	var subdivisions := clampi(floori(sqrt(float(MAX_SAMPLES) / float(width * height))), 1, 4)
	var context := {"enabled": bool(scene.get("dynamic_lighting", false)), "blackout": bool(scene.get("blackout", false)), "ambient": str(scene.get("ambient_light", "bright")), "feet": float(scene.get("feet_per_cell", 5.0)), "width": width, "height": height, "subdivisions": subdivisions, "columns": width * subdivisions, "rows": height * subdivisions, "common_view":true, "observers": [], "lights": [], "segments": [], "scene": scene}
	for wall in scene.get("walls", []):
		context.segments.append([_point(wall.a), _point(wall.b)])
	for door in scene.get("doors", []):
		if not bool(door.get("open", false)):
			context.segments.append([_point(door.a), _point(door.b)])
	for object in scene.get("annotations", []):
		if object.kind != "window": context.segments.append_array(Hearth20BoardTools.barriers(object))
		if object.kind == "light" and bool(object.get("enabled", true)):
			context.lights.append(Hearth20Lighting.source(object.points[0],float(object.get("bright",20)),float(object.get("dim",20)),object))
	for actor in campaign.get("actors",[]):
		if not actor is Dictionary or actor.get("in_inventory",false) or actor.get("scene_id","")!=scene.id or not actor.get("position") is Vector2:continue
		var settings: Dictionary=actor.get("vision",{}) if actor.get("vision",{}) is Dictionary else {}
		if float(settings.get("bright_light_feet",0))+float(settings.get("dim_light_feet",0))>0:
			context.lights.append(Hearth20Lighting.source(actor.position,float(settings.get("bright_light_feet",0)),float(settings.get("dim_light_feet",0)),settings))
	for light in scene.get("lights", []):
		if light is Dictionary and bool(light.get("enabled", true)):
			context.lights.append(Hearth20Lighting.source(_point(light.get("position",Vector2.ZERO)),float(light.get("bright_feet",0)),float(light.get("dim_feet",0)),light))
	context.lights=Hearth20NaturalLight.prepare(context.lights,scene,context)
	context.ray_segments=context.segments.duplicate()
	context.ray_segments.append_array([[Vector2.ZERO,Vector2(width,0)],[Vector2(width,0),Vector2(width,height)],[Vector2(width,height),Vector2(0,height)],[Vector2(0,height),Vector2.ZERO]])
	if bool(context.enabled) and not bool(context.blackout):
		for observer in context.observers: observer.line_mask=_sight_mask(observer.position,context)
		for light in context.lights:
			light.line_mask=_sky_mask(light,context) if light.has("parallel") else _sight_mask(light.position,context)
	var levels := PackedByteArray()
	levels.resize(int(context.columns) * int(context.rows))
	levels.fill(0)
	if not context.blackout:
		var step := 1.0 / float(subdivisions)
		for y in int(context.rows):
			for x in int(context.columns):
				var origin := Vector2(x, y) * step
				levels[y * int(context.columns) + x] = block_level(Rect2(origin, Vector2.ONE * step), context)
	context.levels = levels
	return context

static func _mark_cell(mask: PackedByteArray, x: int, y: int, columns: int, rows: int, value: int) -> void:
	if x>=0 and y>=0 and x<columns and y<rows: mask[y*columns+x]=value

static func _mark_edge(mask: PackedByteArray, a: Vector2, b: Vector2, context: Dictionary, value: int) -> void:
	# Supercover grid traversal: even a narrow shadow crossing a cell corner
	# invalidates that complete visibility sample.
	var w:=float(context.width); var h:=float(context.height)
	if (is_zero_approx(a.x) and is_zero_approx(b.x)) or (is_equal_approx(a.x,w) and is_equal_approx(b.x,w)) or (is_zero_approx(a.y) and is_zero_approx(b.y)) or (is_equal_approx(a.y,h) and is_equal_approx(b.y,h)): return
	var d:=float(context.subdivisions)
	var start:=a*d; var finish:=b*d; var delta:=finish-start
	var x:=floori(start.x); var y:=floori(start.y)
	var ex:=floori(finish.x); var ey:=floori(finish.y)
	var sx:=int(signf(delta.x)); var sy:=int(signf(delta.y))
	var dx:=absf(1.0/delta.x) if sx!=0 else INF
	var dy:=absf(1.0/delta.y) if sy!=0 else INF
	var tx:=((float(x+1)-start.x) if sx>0 else (start.x-float(x)))*dx if sx!=0 else INF
	var ty:=((float(y+1)-start.y) if sy>0 else (start.y-float(y)))*dy if sy!=0 else INF
	for step in range(int(context.columns)+int(context.rows)+8):
		_mark_cell(mask,x,y,int(context.columns),int(context.rows),value)
		if x==ex and y==ey: break
		if absf(tx-ty)<0.0000001:
			_mark_cell(mask,x+sx,y,int(context.columns),int(context.rows),value)
			_mark_cell(mask,x,y+sy,int(context.columns),int(context.rows),value)
			x+=sx; y+=sy; tx+=dx; ty+=dy
		elif tx<ty: x+=sx; tx+=dx
		else: y+=sy; ty+=dy

static func _fill_polygon(mask: PackedByteArray, polygon: PackedVector2Array, context: Dictionary, fill: int, boundary: int) -> void:
	var d:=float(context.subdivisions)
	var bounds:=Hearth20BoardTools._polygon_bounds(polygon)
	var y0:=maxi(0,ceili(bounds.position.y*d-.5)); var y1:=mini(int(context.rows)-1,ceili(bounds.end.y*d-.5)-1)
	for y in range(y0,y1+1):
		var scan: float=(float(y)+.5)/d
		var crossings: Array[float]=[]
		for i in polygon.size():
			var a:=polygon[i]; var b:=polygon[(i+1)%polygon.size()]
			if (a.y>scan)!=(b.y>scan): crossings.append(a.x+(b.x-a.x)*(scan-a.y)/(b.y-a.y))
		crossings.sort()
		for i in range(0,crossings.size()-1,2):
			var x0:=maxi(0,ceili(crossings[i]*d-.5)); var x1:=mini(int(context.columns)-1,ceili(crossings[i+1]*d-.5)-1)
			for x in range(x0,x1+1): mask[y*int(context.columns)+x]=fill
	for i in polygon.size(): _mark_edge(mask,polygon[i],polygon[(i+1)%polygon.size()],context,boundary)

static func _sight_mask(origin: Vector2, context: Dictionary) -> PackedByteArray:
	var key:="point:"+Hearth20Contracts.sha256(var_to_bytes([origin,context.width,context.height,context.subdivisions,context.segments]))
	if line_masks.has(key): return line_masks[key]
	var mask:=PackedByteArray(); mask.resize(int(context.columns)*int(context.rows)); mask.fill(0)
	var angles: Array[float]=[]
	for i in 96: angles.append(float(i)*TAU/96.0)
	for segment in context.segments:
		if Geometry2D.get_closest_point_to_segment(origin,segment[0],segment[1]).distance_squared_to(origin)<0.000000001: return mask
		for endpoint in segment:
			var angle: float=(endpoint-origin).angle()
			for offset in [-0.00001,0.0,0.00001]: angles.append(fposmod(angle+offset,TAU))
	angles.sort()
	var cast_context:=context.duplicate(); cast_context.ray_segments=context.segments
	var radius:=Vector2(float(context.width),float(context.height)).length()*2.0
	var polygon:=PackedVector2Array()
	for angle in angles: polygon.append(Hearth20Lighting._ray_end(origin,Vector2.from_angle(angle),radius,cast_context))
	var rectangle:=PackedVector2Array([Vector2.ZERO,Vector2(context.width,0),Vector2(context.width,context.height),Vector2(0,context.height)])
	for clipped in Geometry2D.intersect_polygons(polygon,rectangle):
		if clipped.size()>=3: _fill_polygon(mask,clipped,context,1,0)
	line_masks[key]=mask
	while line_masks.size()>64: line_masks.erase(line_masks.keys()[0])
	return mask

static func _sky_mask(light: Dictionary, context: Dictionary) -> PackedByteArray:
	var key:="sky:"+Hearth20Contracts.sha256(var_to_bytes([light.parallel,context.width,context.height,context.subdivisions,context.feet,context.segments]))
	if line_masks.has(key): return line_masks[key]
	var mask:=PackedByteArray(); mask.resize(int(context.columns)*int(context.rows)); mask.fill(1)
	var rectangle:=PackedVector2Array([Vector2.ZERO,Vector2(context.width,0),Vector2(context.width,context.height),Vector2(0,context.height)])
	for cut in Hearth20NaturalLight.shadow_polygons(light,context):
		for clipped in Geometry2D.intersect_polygons(cut,rectangle):
			if clipped.size()>=3: _fill_polygon(mask,clipped,context,0,0)
	line_masks[key]=mask
	while line_masks.size()>64: line_masks.erase(line_masks.keys()[0])
	return mask

static func _point(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))

static func clear_line(a: Vector2, b: Vector2, context: Dictionary) -> bool:
	if a.distance_squared_to(b) < 0.0000001:
		return true
	var endpoint := b.move_toward(a, minf(0.0001, a.distance_to(b) * 0.01))
	for segment in context.get("segments", []):
		if Hearth20Contracts.segment_intersects(a, endpoint, segment[0], segment[1]):
			return false
	return true

static func level_at(point: Vector2, context: Dictionary) -> int:
	if bool(context.get("blackout", false)) or point.x < 0.0 or point.y < 0.0 or point.x >= float(context.width) or point.y >= float(context.height):
		return 0
	if not Hearth20Contracts.point_is_visible(point, context.scene):
		return 0
	if context.get("common_view",false) or not bool(context.get("enabled", false)):
		return 3
	var light_level := 3 if context.ambient == "bright" else 2 if context.ambient == "dim" else 0
	if light_level < 3:
		for light in context.lights:
			if light.has("parallel"):
				if float(light.bright)+float(light.dim)>0 and Hearth20NaturalLight.sunlit(point,light,context): light_level=maxi(light_level,3 if float(light.bright)>0 else 2)
				continue
			var distance := point.distance_to(light.position) * float(context.feet)
			if distance <= float(light.bright) + float(light.dim) and Hearth20Lighting.inside_cone(point,light) and clear_line(light.position, point, context):
				light_level = maxi(light_level, 3 if float(light.bright) > 0.0 and distance <= float(light.bright) else 2)
	var best:=0
	for observer in context.observers:
		var distance:=point.distance_to(observer.position)*float(context.feet)
		var level:=observer_level(observer,distance,light_level)
		if level>0 and clear_line(observer.position,point,context):best=maxi(best,level)
	return best

static func visible(point: Vector2, context: Dictionary) -> bool:
	return level_at(point, context) > 0

static func clear_area(origin: Vector2, rect: Rect2, context: Dictionary) -> bool:
	# A corner-only ray test can miss the thin shadow of a short wall between
	# rays. Reject an entire block if ANY opaque segment intersects the convex
	# sight region from the observer to that block.
	var hull := Geometry2D.convex_hull(PackedVector2Array([origin, rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
	for segment in context.segments:
		if Geometry2D.is_point_in_polygon(segment[0], hull) or Geometry2D.is_point_in_polygon(segment[1], hull):
			return false
		for index in range(hull.size() - 1):
			if Hearth20Contracts.segment_intersects(hull[index], hull[index + 1], segment[0], segment[1]):
				return false
	return true

static func block_level(rect: Rect2, context: Dictionary) -> int:
	if bool(context.get("blackout", false)): return 0
	for fog in context.scene.get("fog_rects", []):
		var covered: Rect2 = fog if fog is Rect2 else Rect2(Vector2(float(fog.x), float(fog.y)), Vector2(float(fog.width), float(fog.height)))
		if rect.intersects(covered):
			return 0
	if context.get("common_view",false) or not bool(context.enabled):
		return 3
	if context.observers.is_empty(): return 0
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var divisions:=float(context.get("subdivisions",4))
	var aligned:=rect.size.is_equal_approx(Vector2.ONE/divisions) and (rect.position*divisions).is_equal_approx((rect.position*divisions).round())
	var column:=roundi(rect.position.x*divisions); var row:=roundi(rect.position.y*divisions)
	var sample_index:=row*int(context.get("columns",0))+column
	var use_masks:=aligned and column>=0 and row>=0 and column<int(context.get("columns",0)) and row<int(context.get("rows",0))
	var illumination := 3 if context.ambient == "bright" else 2 if context.ambient == "dim" else 0
	if illumination < 3:
		for light in context.lights:
			var cached: bool=use_masks and light.has("line_mask")
			if cached and int(light.line_mask[sample_index])==0: continue
			if light.has("parallel"):
				if float(light.bright)+float(light.dim)>0 and (cached or Hearth20NaturalLight.area_sunlit(rect,light,context)): illumination=maxi(illumination,3 if float(light.bright)>0 else 2)
				if illumination==3: break
				continue
			var farthest: float=((rect.get_center()-light.position).abs()+rect.size*.5).length()*float(context.feet)
			var in_cone:=true
			if float(light.get("spread",360))<360:
				for corner in corners:
					if not Hearth20Lighting.inside_cone(corner,light): in_cone=false; break
			if in_cone and farthest <= float(light.bright) + float(light.dim) and (cached or clear_area(light.position, rect, context)):
				illumination = maxi(illumination, 3 if float(light.bright) > 0.0 and farthest <= float(light.bright) else 2)
			if illumination==3: break
	for observer in context.observers:
		var farthest: float=((rect.get_center()-observer.position).abs()+rect.size*.5).length()*float(context.feet)
		var perception:=observer_level(observer,farthest,illumination)
		if perception==0:continue
		if use_masks and observer.has("line_mask"):
			if int(observer.line_mask[sample_index])>0: return perception
		elif clear_area(observer.position, rect, context): return perception
	return 0

static func segment_visible(a: Vector2, b: Vector2, context: Dictionary) -> bool:
	var samples := maxi(1, ceili(a.distance_to(b) * float(context.get("subdivisions", 4)) * 2.0))
	for index in range(samples + 1):
		if not visible(a.lerp(b, float(index) / float(samples)), context):
			return false
	if bool(context.get("enabled", false)) and context.has("levels"):
		var divisions := float(context.subdivisions)
		var begin := Vector2i(floori(minf(a.x, b.x) * divisions), floori(minf(a.y, b.y) * divisions))
		var end := Vector2i(floori(maxf(a.x, b.x) * divisions), floori(maxf(a.y, b.y) * divisions))
		for y in range(maxi(0, begin.y), mini(int(context.rows) - 1, end.y) + 1):
			for x in range(maxi(0, begin.x), mini(int(context.columns) - 1, end.x) + 1):
				if int(context.levels[y * int(context.columns) + x]) != 0:
					continue
				var rect := Rect2(Vector2(x, y) / divisions, Vector2.ONE / divisions)
				if rect.has_point(a) or rect.has_point(b):
					return false
				var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
				for index in 4:
					if Hearth20Contracts.segment_intersects(a, b, corners[index], corners[(index + 1) % 4]):
						return false
	return true

static func mask_map(source: PackedByteArray, context: Dictionary) -> PackedByteArray:
	if source.is_empty():
		return PackedByteArray()
	var cache_key="vision:"+Hearth20Contracts.sha256(var_to_bytes([context.columns,context.rows,context.subdivisions,context.levels,context.scene.get("cell_pixels",64.)]))
	var cached=Hearth20MaskedImageCache.lookup(cache_key,source)
	if not cached.is_empty():return cached
	var image := Hearth20Assets.decode_map(source)
	if image==null:
		return PackedByteArray()
	var masked := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	masked.fill(Color.BLACK)
	var gray: Image
	if context.levels.has(1):
		gray = image.duplicate()
		gray.convert(Image.FORMAT_LA8)
		gray.convert(Image.FORMAT_RGBA8)
	var px := float(context.scene.get("cell_pixels", 64.0)) / float(context.subdivisions)
	var bounds := Rect2i(0, 0, image.get_width(), image.get_height())
	if is_equal_approx(px,roundf(px)):
		# Merge complete pixel-aligned cells. Fractional calibration keeps the
		# original conservative per-cell path below, including its edge exclusions.
		for minimum in ([1,2] if gray!=null else [2]):
			for visible in Hearth20Lighting._visible_rects(context,minimum):
				var begin=Vector2i((visible.position*float(context.subdivisions)).round())*roundi(px)
				var extent=Vector2i((visible.size*float(context.subdivisions)).round())*roundi(px)
				var rect=Rect2i(begin,extent).intersection(bounds)
				if rect.has_area():masked.blit_rect(gray if minimum==1 else image,rect,rect.position)
		var result=masked.save_png_to_buffer();Hearth20MaskedImageCache.put(cache_key,source,result);return result
	for y in int(context.rows):
		for x in int(context.columns):
			var level := int(context.levels[y * int(context.columns) + x])
			if level == 0:
				continue
			# Copy only pixels fully inside a visible block, excluding overlapping
			# fractional calibration pixels at its edges.
			var begin := Vector2i(ceili(float(x) * px), ceili(float(y) * px))
			var end := Vector2i(floori(float(x + 1) * px), floori(float(y + 1) * px))
			var rect := Rect2i(begin, end - begin).intersection(bounds)
			if rect.size.x > 0 and rect.size.y > 0:
				masked.blit_rect(gray if level == 1 else image, rect, rect.position)
	var result=masked.save_png_to_buffer();Hearth20MaskedImageCache.put(cache_key,source,result);return result

static func public_mask(context: Dictionary) -> Dictionary:
	return {"columns": int(context.columns), "rows": int(context.rows), "subdivisions": int(context.subdivisions), "levels": context.levels, "dynamic_lighting": bool(context.enabled), "blackout": bool(context.blackout)}

static func template_visible(template: Dictionary, context: Dictionary) -> bool:
	var start: Vector2 = template.start
	var end: Vector2 = template.end
	var bounds := Rect2(start, Vector2.ZERO).expand(end).grow(0.01)
	if template.shape == "circle":
		bounds = Rect2(start - Vector2.ONE * start.distance_to(end), Vector2.ONE * 2.0 * start.distance_to(end))
	elif template.shape == "cone":
		bounds = bounds.grow(start.distance_to(end) * 0.5)
	if bounds.position.x < 0.0 or bounds.position.y < 0.0 or bounds.end.x >= float(context.width) or bounds.end.y >= float(context.height):
		return false
	var divisions := float(context.subdivisions)
	for y in range(floori(bounds.position.y * divisions), ceili(bounds.end.y * divisions)):
		for x in range(floori(bounds.position.x * divisions), ceili(bounds.end.x * divisions)):
			if int(context.levels[y * int(context.columns) + x]) == 0:
				return false
	return segment_visible(start, end, context)

static func view_actors(campaign: Dictionary, player: String, scene: Dictionary) -> Array:
	return campaign.get("actors",[]).filter(func(actor):return actor is Dictionary and actor.get("owner_player_id","")==player and actor.get("scene_id","")==scene.get("id","") and not actor.get("in_inventory",false) and not actor.get("decorative",false) and actor.get("layer","tokens")=="tokens" and actor.get("vision",{}).get("enabled",true))
static func view_actor_id(_campaign: Dictionary, _player: String, _scene: Dictionary) -> String:
	return ""

static func observer_level(observer: Dictionary, distance: float, illumination: int) -> int:
	if float(observer.get("blindsight",0))>0 and distance<=float(observer.blindsight):return maxi(1,illumination)
	if observer.get("blind",false):return 0
	if float(observer.get("truesight",0))>0 and distance<=float(observer.truesight):return 3
	if illumination==0:return 1 if float(observer.darkvision)>0 and distance<=float(observer.darkvision) else 0
	return 3 if illumination==2 and distance<=float(observer.darkvision) else illumination
