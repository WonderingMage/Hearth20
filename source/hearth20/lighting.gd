extends RefCounted
class_name Hearth20Lighting
## Source-aware light geometry. The host clips all player ray meshes to authorized sight.
const SOURCE_TYPES := ["torch","brazier","window","sunlight","moonlight","crystal"]
const MAX_VISUALS := 4096
static var field_cache: Dictionary={}
static var projected_field_cache={}

static func valid_source(value: Dictionary) -> bool:
	if value.get("source_type","torch") not in SOURCE_TYPES: return false
	if not value.get("light_color",value.get("color","#ffcd8e")) is String or not Color.html_is_valid(str(value.get("light_color",value.get("color","#ffcd8e")))): return false
	for field in ["angle_degrees","spread_degrees","ray_strength"]:
		var v: Variant=value.get(field,0.0 if field=="angle_degrees" else 360.0 if field=="spread_degrees" else 0.55)
		if not Hearth20Contracts._finite_number(v): return false
		if field=="angle_degrees" and absf(float(v))>360.0: return false
		if field=="spread_degrees" and (float(v)<1.0 or float(v)>360.0): return false
		if field=="ray_strength" and (float(v)<0.0 or float(v)>1.0): return false
	for field in ["portal_width","window_height","sill_height"]:
		var v: Variant=value.get(field,6.0)
		if not Hearth20Contracts._finite_number(v) or float(v)<0.1 or float(v)>100.0: return false
	return true

static func source(position: Vector2, bright: float, dim: float, metadata: Dictionary={}) -> Dictionary:
	return {"position":position,"bright":bright,"dim":dim,"type":str(metadata.get("source_type","torch")),"angle":float(metadata.get("angle_degrees",0)),"spread":float(metadata.get("spread_degrees",360)),"strength":float(metadata.get("ray_strength",0.55)),"color":str(metadata.get("light_color",metadata.get("color","#ffcd8e"))),"portal_width":float(metadata.get("portal_width",6.0)),"window_height":float(metadata.get("window_height",7.0)),"sill_height":float(metadata.get("sill_height",3.0))}

static func inside_cone(point: Vector2, light: Dictionary) -> bool:
	if float(light.get("spread",360))>=359.99: return true
	var delta: Vector2=point-light.position
	if delta.length_squared()<0.000001: return true
	return absf(wrapf(delta.angle()-deg_to_rad(float(light.get("angle",0))),-PI,PI))<=deg_to_rad(float(light.get("spread",360)))*0.5

static func _ray_end(origin: Vector2, direction: Vector2, radius: float, context: Dictionary) -> Vector2:
	var result:=origin+direction*radius
	var segments: Array=context.get("ray_segments",context.segments)
	var w:=float(context.width); var h:=float(context.height)
	if not context.has("ray_segments"):
		segments=segments.duplicate()
		segments.append_array([[Vector2.ZERO,Vector2(w,0)],[Vector2(w,0),Vector2(w,h)],[Vector2(w,h),Vector2(0,h)],[Vector2(0,h),Vector2.ZERO]])
	var nearest:=radius
	for segment in segments:
		var crossing: Variant=Geometry2D.segment_intersects_segment(origin,result,segment[0],segment[1])
		if crossing is Vector2:
			var distance:=origin.distance_to(crossing)
			if distance>0.0001 and distance<nearest:
				nearest=distance
	return origin+direction*maxf(0,nearest-0.001)

static func meshes(context: Dictionary) -> Array:
	var output: Array=[]
	var point_context:=context.duplicate()
	point_context.lights=[]
	for light in context.lights:
		if light.has("parallel"):
			output.append_array(Hearth20NaturalLight.sky_meshes(light,context)); continue
		if light.has("portal"): output.append_array(Hearth20NaturalLight.window_meshes(light,context))
		point_context.lights.append(light)
	output.append_array(_point_meshes(point_context))
	return output.slice(0,MAX_VISUALS)

static func _point_meshes(context: Dictionary) -> Array:
	var output: Array=[]
	if not bool(context.enabled): return output
	for light in context.lights.slice(0,32):
		var origin: Vector2=light.position
		var radius: float=(float(light.bright)+float(light.dim))/float(context.feet)
		var strength:=float(light.get("strength",0.55))
		if radius<=0.01 or strength<=0: continue
		var axis:=deg_to_rad(float(light.get("angle",0)))
		var spread:=deg_to_rad(float(light.get("spread",360)))
		var half:=spread*0.5
		var angles: Array[float]=[]
		var full:=spread>=TAU-0.001
		var divisions:=40 if full else 24
		for i in range(divisions+1): angles.append(-half+spread*float(i)/float(divisions))
		for segment in context.segments:
			for endpoint in segment:
				if origin.distance_to(endpoint)>radius+0.5: continue
				var angle:=wrapf((endpoint-origin).angle()-axis,-PI,PI)
				if absf(angle)<=half:
					for offset in [-0.0001,0.0,0.0001]: angles.append(clampf(angle+offset,-half,half))
		angles.sort()
		var previous:=Vector2.ZERO
		var previous_angle:=-100.0
		var color:=str(light.get("color","#ffcd8e"))
		for angle in angles:
			if angle-previous_angle<0.00001: continue
			var end:=_ray_end(origin,Vector2.from_angle(axis+angle),radius,context)
			if previous_angle>-99:
				var poly:=PackedVector2Array([origin,previous,end])
				if absf((previous-origin).cross(end-origin))>0.000005:
					var alpha:=strength*(0.55 if full else 0.48)
					var inner_a:=origin.lerp(previous,0.24)
					var inner_b:=origin.lerp(end,0.24)
					var center_alpha:=minf(0.6,alpha*1.5)
					var ia:=_irradiance(origin.distance_to(inner_a)*float(context.feet),alpha,radius*float(context.feet))
					var ib:=_irradiance(origin.distance_to(inner_b)*float(context.feet),alpha,radius*float(context.feet))
					var ea:=_irradiance(origin.distance_to(previous)*float(context.feet),alpha,radius*float(context.feet))
					var eb:=_irradiance(origin.distance_to(end)*float(context.feet),alpha,radius*float(context.feet))
					for piece in [[PackedVector2Array([origin,inner_a,inner_b]),[center_alpha,ia,ib]],[PackedVector2Array([inner_a,previous,end]),[ia,ea,eb]],[PackedVector2Array([inner_a,end,inner_b]),[ia,eb,ib]]]:
						output.append({"points":piece[0],"alpha":piece[1],"color":color,"type":str(light.get("type","torch"))})
					if output.size()>=MAX_VISUALS: return output
			previous=end
			previous_angle=angle
	return output

static func _irradiance(distance_feet: float, intensity: float, radius_feet: float) -> float:
	# I*cos(theta)/r² for a source six feet above a horizontal diffuse floor.
	var h:=6.0
	var r2:=distance_feet*distance_feet+h*h
	var cosine:=h/sqrt(r2)
	var cutoff:=1.0-smoothstep(radius_feet*0.75,radius_feet,distance_feet)
	return minf(0.6,intensity*1.5*h*h*cosine/r2*cutoff)

static func _visible_rects(context: Dictionary, minimum: int=1) -> Array:
	var result: Array=[]
	var previous: Dictionary={}
	var d:=float(context.subdivisions)
	for y in int(context.rows):
		var current: Dictionary={}
		var begin:=-1
		for x in range(int(context.columns)+1):
			var lit: bool=x<int(context.columns) and int(context.levels[y*int(context.columns)+x])>=minimum
			if lit and begin<0: begin=x
			if not lit and begin>=0:
				var key: String="%d:%d"%[begin,x]
				if previous.has(key):
					var index: int=previous[key]
					var extended: Rect2=result[index]
					extended.size.y+=1.0/d
					result[index]=extended
					current[key]=index
				else:
					current[key]=result.size()
					result.append(Rect2(Vector2(begin,y)/d,Vector2(x-begin,1)/d))
				begin=-1
		previous=current
	return result

static func _alpha_at(point: Vector2, mesh: Dictionary) -> float:
	if mesh.get("type","")=="sky_shadow": return 1.0
	var a: Vector2=mesh.points[0]; var b: Vector2=mesh.points[1]; var c: Vector2=mesh.points[2]
	var denominator: float=(b-a).cross(c-a)
	if absf(denominator)<0.000001: return 0.0
	var u: float=(point-a).cross(c-a)/denominator
	var v: float=(b-a).cross(point-a)/denominator
	return clampf(float(mesh.alpha[0])*(1-u-v)+float(mesh.alpha[1])*u+float(mesh.alpha[2])*v,0,0.6)

static func project(context: Dictionary) -> Array:
	if bool(context.blackout) or not bool(context.enabled): return []
	var visible:=_visible_rects(context)
	if visible.is_empty(): return []
	var output: Array=[]
	for mesh in meshes(context):
		var bounds:=Hearth20BoardTools._polygon_bounds(mesh.points)
		for rect in visible:
			if not bounds.intersects(rect): continue
			var square:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
			for clipped in Geometry2D.intersect_polygons(mesh.points,square):
				if clipped.size()<3: continue
				var alpha: Array=[]
				for point in clipped: alpha.append(_alpha_at(point,mesh))
				output.append({"points":clipped,"alpha":alpha,"color":mesh.color,"type":mesh.type})
				if output.size()>=MAX_VISUALS: return output
	return output

static func _raster_field(context: Dictionary) -> Dictionary:
	var ppc:=minf(16.0,1024.0/maxf(float(context.width),float(context.height)))
	var width:=ceili(float(context.width)*ppc)
	var height:=ceili(float(context.height)*ppc)
	var pixels:=PackedByteArray(); pixels.resize(width*height*3); pixels.fill(0)
	var all:=meshes(context)
	for layer in 3:
		for mesh in all:
			var type:=str(mesh.get("type",""))
			var mesh_layer:=1 if type=="sky_shadow" else 0 if type.begins_with("sky_") else 2
			if mesh_layer!=layer: continue
			var points: PackedVector2Array=mesh.points
			var a: Vector2=points[0]*ppc; var b: Vector2=points[1]*ppc; var c: Vector2=points[2]*ppc
			var vertices: Array=[a,b,c]
			var tint:=Color(str(mesh.color))
			var red:=tint.r*255.0; var green:=tint.g*255.0; var blue:=tint.b*255.0
			var y0:=maxi(0,ceili(minf(a.y,minf(b.y,c.y))-.5))
			var y1:=mini(height-1,floori(maxf(a.y,maxf(b.y,c.y))-.5))
			for y in range(y0,y1+1):
				var scan:=float(y)+.5
				var left:=INF; var right:=-INF; var left_alpha:=0.0; var right_alpha:=0.0
				for edge in 3:
					var start: Vector2=vertices[edge]; var end: Vector2=vertices[(edge+1)%3]
					if scan<minf(start.y,end.y) or scan>=maxf(start.y,end.y) or is_equal_approx(start.y,end.y): continue
					var t: float=(scan-start.y)/(end.y-start.y)
					var x: float=lerpf(start.x,end.x,t)
					var alpha: float=lerpf(float(mesh.alpha[edge]),float(mesh.alpha[(edge+1)%3]),t)
					if x<left: left=x; left_alpha=alpha
					if x>right: right=x; right_alpha=alpha
				if right<=left: continue
				var x0:=maxi(0,ceili(left-.5)); var x1:=mini(width-1,ceili(right-.5)-1)
				var slope: float=(right_alpha-left_alpha)/(right-left)
				var alpha: float=left_alpha+(float(x0)+.5-left)*slope
				var index: int=(y*width+x0)*3
				for x in range(x0,x1+1):
					if layer==1: pixels[index]=0; pixels[index+1]=0; pixels[index+2]=0
					else:
						pixels[index]=mini(255,int(pixels[index])+roundi(red*alpha))
						pixels[index+1]=mini(255,int(pixels[index+1])+roundi(green*alpha))
						pixels[index+2]=mini(255,int(pixels[index+2])+roundi(blue*alpha))
					alpha+=slope; index+=3
	return {"width":width,"height":height,"pixels":pixels}

static func project_field(context: Dictionary) -> Dictionary:
	if bool(context.blackout) or not bool(context.enabled): return {}
	var projected_key=str(context.get("environment_key",""))
	if not projected_key.is_empty():projected_key+=":"+Hearth20Contracts.sha256(context.get("levels",PackedByteArray()))
	if not projected_key.is_empty() and projected_field_cache.has(projected_key):return projected_field_cache[projected_key].duplicate()
	var sources: Array=[]
	for source_light in context.lights:
		var clean: Dictionary=source_light.duplicate(); clean.erase("line_mask"); sources.append(clean)
	var key:=Hearth20Contracts.sha256(var_to_bytes([context.width,context.height,context.feet,sources,context.segments]))
	if not field_cache.has(key):
		field_cache[key]=_raster_field(context)
		while field_cache.size()>4: field_cache.erase(field_cache.keys()[0])
	var field: Dictionary=field_cache[key]
	var image:=Image.create_from_data(int(field.width),int(field.height),false,Image.FORMAT_RGB8,field.pixels)
	var masked:=Image.create(int(field.width),int(field.height),false,Image.FORMAT_RGB8); masked.fill(Color.BLACK)
	var scale:=Vector2(float(field.width)/float(context.width),float(field.height)/float(context.height))
	for rect in _visible_rects(context,2):
		var begin:=Vector2i((rect.position*scale).ceil())
		var end:=Vector2i((rect.end*scale).floor())
		if end.x>begin.x and end.y>begin.y: masked.blit_rect(image,Rect2i(begin,end-begin),begin)
	var result={"width":int(field.width),"height":int(field.height),"codec":"rgb8-deflate-v1","data":masked.get_data().compress(FileAccess.COMPRESSION_DEFLATE)}
	if not projected_key.is_empty():
		projected_field_cache[projected_key]=result
		while projected_field_cache.size()>4:projected_field_cache.erase(projected_field_cache.keys()[0])
	return result.duplicate()

static func read_field(value: Variant) -> Image:
	if not value is Dictionary or value.get("codec","")!="rgb8-deflate-v1" or not value.get("data") is PackedByteArray: return null
	if not Hearth20Contracts._integer_number(value.get("width")) or not Hearth20Contracts._integer_number(value.get("height")): return null
	var width:=int(value.width); var height:=int(value.height)
	if width<1 or height<1 or width>1024 or height>1024 or value.data.is_empty() or value.data.size()>3145728: return null
	var data: PackedByteArray=value.data.decompress(width*height*3,FileAccess.COMPRESSION_DEFLATE)
	if data.size()!=width*height*3: return null
	return Image.create_from_data(width,height,false,Image.FORMAT_RGB8,data)

static func draw_mesh(canvas: CanvasItem, mesh: Dictionary, scale: float, offset: Vector2) -> void:
	var points:=PackedVector2Array()
	var colors:=PackedColorArray()
	var tint:=Color(str(mesh.color))
	var motion:=1.0
	if mesh.get("type","") in ["torch","brazier"]: motion=0.97+sin(float(Time.get_ticks_msec())*0.007)*0.03
	for i in mesh.points.size():
		points.append(mesh.points[i]*scale-offset)
		colors.append(Color(tint.r,tint.g,tint.b,float(mesh.alpha[i])*motion))
	if points.size()>=3 and not Geometry2D.triangulate_polygon(points).is_empty(): canvas.draw_polygon(points,colors)
