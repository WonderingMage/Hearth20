extends RefCounted
class_name Hearth20NaturalLight
## Equinox sky model and finite window projection, in the board's recorded feet.
const DEFAULTS := {"time_hours":16.5,"north_degrees":0.0,"sun_intensity":1.0,"moon_intensity":0.35,"haze":0.35,"exposure":1.0}
static func settings(scene: Dictionary) -> Dictionary:
	var result:=DEFAULTS.duplicate()
	result.merge(scene.get("natural_light",{}),true)
	return result
static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()>6: return false
	for key in value:
		if not DEFAULTS.has(key) or not Hearth20Contracts._finite_number(value[key]): return false
		var v:=float(value[key])
		if key=="time_hours" and (v<0 or v>24): return false
		if key=="north_degrees" and (v<0 or v>360): return false
		if key in ["sun_intensity","moon_intensity","exposure"] and (v<0 or v>3): return false
		if key=="haze" and (v<0 or v>1): return false
	return true
static func sky(scene: Dictionary) -> Dictionary:
	var s:=settings(scene)
	var hour:=fposmod(float(s.time_hours),24.0)
	var solar:=sin((hour-6.0)*PI/12.0)
	var daylight:=solar>0
	var altitude:=asin(absf(solar)*sin(deg_to_rad(65.0)))
	var azimuth:=fposmod(90.0+(hour-6.0)*15.0+(0.0 if daylight else 180.0),360.0)
	var direction:=Vector2.from_angle(deg_to_rad(azimuth+90.0+float(s.north_degrees)))
	var energy:=float(s.sun_intensity if daylight else s.moon_intensity)*smoothstep(0.0,0.15,absf(solar))
	var tint:=Color("#ffe5ae").lerp(Color("#fff2ce"),sin(altitude)) if daylight else Color("#a5c9f4")
	return {"hour":hour,"daylight":daylight,"altitude":altitude,"azimuth":azimuth,"direction":direction,"energy":energy,"color":tint.to_html(false)}
static func time_label(hour: float) -> String:
	var minute:=roundi(hour*60)
	return "%02d:%02d"%[minute/60,minute%60]
static func prepare(lights: Array, scene: Dictionary, context: Dictionary) -> Array:
	if not scene.has("natural_light"): return lights
	var sky_state:=sky(scene)
	var result: Array=[]
	var exterior:=bool(scene.get("outdoor",false)) or str(scene.get("library_id","")) in ["briarwood-crossroads","moonwater-bridge","mossfall-chapel","oldwatch-keep","saltwind-docks","willowfen-ruins","frostpass-ambush","market-of-lanterns","red-sail-sloop"]
	var added_sky:=false
	for original in lights:
		var light: Dictionary=original.duplicate(true)
		if light.type=="window":
			var nearest: Dictionary={}
			var best:=1.5
			for object in scene.get("annotations",[]):
				if object.kind!="window" or object.points.size()<2: continue
				if not str(light.get("window_id","")).is_empty():
					if object.id==light.window_id:nearest=object;break
					continue
				var center: Vector2=(object.points[0]+object.points[-1])*0.5
				var distance: float=center.distance_to(light.position)
				if distance<best: best=distance; nearest=object
			var normal:=Vector2.from_angle(deg_to_rad(float(light.angle)))
			var width: float=float(light.get("portal_width",6.0))/float(context.feet)
			if not nearest.is_empty():
				width=nearest.points[0].distance_to(nearest.points[-1])
				var perpendicular: Vector2=(nearest.points[-1]-nearest.points[0]).normalized().orthogonal()
				if perpendicular.dot(normal)<0: perpendicular=-perpendicular
				normal=perpendicular
				light.position=(nearest.points[0]+nearest.points[-1])*0.5+normal*0.055
			var facing:=maxf(0,normal.dot(sky_state.direction))
			var altitude:=maxf(deg_to_rad(3.0),float(sky_state.altitude))
			light.portal={"width":width,"normal":normal,"direction":sky_state.direction,"near":float(light.get("sill_height",3.0))/tan(altitude)/float(context.feet),"far":(float(light.get("sill_height",3.0))+float(light.get("window_height",7.0)))/tan(altitude)/float(context.feet),"energy":float(sky_state.energy)*facing*sin(altitude),"color":sky_state.color,"daylight":sky_state.daylight}
			# Diffuse sky/first-bounce proxy. Occlusion remains the same wall solver.
			light.spread=360.0
			light.color=sky_state.color
			light.bright=10.0 if float(sky_state.energy)>0.25 else 0.0
			light.dim=(35.0 if bool(sky_state.daylight) else 20.0) if float(sky_state.energy)>0.001 else 0.0
			light.strength*=float(sky_state.energy)*0.65
		elif light.type in ["sunlight","moonlight"]:
			if exterior:
				if added_sky: continue
				added_sky=true
				light.parallel={"direction":sky_state.direction,"energy":sky_state.energy,"altitude":sky_state.altitude,"daylight":sky_state.daylight,"roofs":_roofs(scene)}
				light.type="sunlight" if sky_state.daylight else "moonlight"
				light.color=sky_state.color; light.strength=sky_state.energy
				light.bright=1000.0 if sky_state.daylight and float(sky_state.energy)>0.001 else 0.0
				light.dim=1000.0 if not sky_state.daylight and float(sky_state.energy)>0.001 else 0.0
				result.append(light); continue
			var active: bool=(light.type=="sunlight")==bool(sky_state.daylight)
			light.strength*=float(sky_state.energy) if active else 0.0
			light.color=sky_state.color
			if not active: light.bright=0.0; light.dim=0.0
		result.append(light)
	return result

static func _roofs(scene: Dictionary) -> Array:
	if scene.has("roof_rects"):
		var roofs: Array=[]
		for record in scene.roof_rects:roofs.append(Hearth20Contracts._rect_from_record(record))
		return roofs
	match str(scene.get("library_id","")):
		"oldwatch-keep": return [Rect2(4.8,3.75,7.2,7.2),Rect2(21,3.75,7.15,7.2)]
		"saltwind-docks": return [Rect2(2,3,10,13)]
		"red-sail-sloop": return [Rect2(22.05,4.7,5.65,13.55)]
	return []
static func _shadow_length(light: Dictionary, context: Dictionary) -> float:
	return minf(128.0,10.0/maxf(0.06,tan(float(light.parallel.altitude)))/float(context.feet))
static func sunlit(point: Vector2, light: Dictionary, context: Dictionary) -> bool:
	for roof in light.parallel.roofs:
		if roof.has_point(point): return false
	return Hearth20Vision.clear_line(point-Vector2(light.parallel.direction)*_shadow_length(light,context),point,context)
static func area_sunlit(rect: Rect2, light: Dictionary, context: Dictionary) -> bool:
	for roof in light.parallel.roofs:
		if roof.intersects(rect): return false
	var offset: Vector2=light.parallel.direction*_shadow_length(light,context)
	var corners:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	var sweep:=corners.duplicate()
	for p in corners: sweep.append(p-offset)
	var hull:=Geometry2D.convex_hull(sweep)
	for segment in context.segments:
		if Geometry2D.is_point_in_polygon(segment[0],hull) or Geometry2D.is_point_in_polygon(segment[1],hull): return false
		for i in range(hull.size()-1):
			if Hearth20Contracts.segment_intersects(hull[i],hull[i+1],segment[0],segment[1]): return false
	return true

static func shadow_polygons(light: Dictionary, context: Dictionary) -> Array:
	var cuts: Array=[]
	for roof in light.parallel.roofs:
		cuts.append(PackedVector2Array([roof.position,Vector2(roof.end.x,roof.position.y),roof.end,Vector2(roof.position.x,roof.end.y)]))
	var offset: Vector2=light.parallel.direction*_shadow_length(light,context)
	for segment in context.segments:
		var a: Vector2=segment[0]; var b: Vector2=segment[1]
		if absf((b-a).cross(offset))>0.0001: cuts.append(PackedVector2Array([a,b,b+offset,a+offset]))
	return cuts

static func sky_meshes(light: Dictionary, context: Dictionary) -> Array:
	if float(light.parallel.energy)<0.001: return []
	var w:=float(context.width); var h:=float(context.height)
	var cuts:=shadow_polygons(light,context)
	var output: Array=[]
	var energy:=minf(0.55,float(light.parallel.energy)*0.27)
	for triangle in [PackedVector2Array([Vector2.ZERO,Vector2(w,0),Vector2(w,h)]),PackedVector2Array([Vector2.ZERO,Vector2(w,h),Vector2(0,h)])]:
		output.append({"points":triangle,"alpha":[energy,energy,energy],"color":light.color,"type":"sky_"+str(light.type)})
	for polygon in cuts:
		var indices:=Geometry2D.triangulate_polygon(polygon)
		for i in range(0,indices.size(),3):
			output.append({"points":PackedVector2Array([polygon[indices[i]],polygon[indices[i+1]],polygon[indices[i+2]]]),"alpha":[1.0,1.0,1.0],"color":"#000000","type":"sky_shadow"})
	return output

static func window_meshes(light: Dictionary, context: Dictionary) -> Array:
	var portal: Dictionary=light.portal
	if float(portal.energy)<=0.001 or float(light.strength)<=0.001: return []
	var direction: Vector2=portal.direction
	var tangent: Vector2=portal.normal.orthogonal()
	var far:=minf(float(portal.far),sqrt(float(context.width*context.width+context.height*context.height)))
	var near:=minf(float(portal.near),far)
	var output: Array=[]
	var count:=32
	for i in count:
		var a: Vector2=light.position+tangent*float(portal.width)*(float(i)/count-0.5)
		var b: Vector2=light.position+tangent*float(portal.width)*(float(i+1)/count-0.5)
		var end_a:=Hearth20Lighting._ray_end(a,direction,far,context)
		var end_b:=Hearth20Lighting._ray_end(b,direction,far,context)
		var da:=a.distance_to(end_a); var db:=b.distance_to(end_b)
		if da<=near+0.001 or db<=near+0.001: continue
		var start_a:=a+direction*near; var start_b:=b+direction*near
		var energy:=minf(0.58,float(portal.energy)*0.75)
		for triangle in [PackedVector2Array([start_a,start_b,end_b]),PackedVector2Array([start_a,end_b,end_a])]:
			output.append({"points":triangle,"alpha":[energy,energy,energy],"color":str(portal.color),"type":"sunlight" if portal.daylight else "moonlight"})
	return output
