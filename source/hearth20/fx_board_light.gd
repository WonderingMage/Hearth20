extends Node2D
class_name Hearth20FxBoardLight
## Cosmetic transient radiance/absorption, clipped by the board's known barriers.
## This never edits fog, vision entitlement, token statistics or permanent lights.
const LIGHT:="""
shader_type canvas_item;render_mode blend_add;
uniform vec4 tint:source_color;uniform float strength=1.;uniform float age=0.;
void fragment(){vec2 p=UV-.5;float radius=length(p)*2.;float glow=pow(max(0.,1.-radius),2.5);float rays=.93+.07*sin(atan(p.y,p.x)*11.+age*.5);COLOR=vec4(tint.rgb*glow*strength*rays,1.);}
"""
const DARK:="""
shader_type canvas_item;render_mode blend_mul;
uniform float strength=1.;uniform float age=0.;
void fragment(){float radius=length(UV-.5)*2.;float falloff=pow(max(0.,1.-radius),1.7);float shade=1.-falloff*strength*(.93+sin(age*2.)*.04);COLOR=vec4(vec3(max(.08,shade)),1.);}
"""
var polygons: Dictionary={}
var context: Dictionary={}
var geometry_key:=""
var rays: Dictionary={}
var white_texture: ImageTexture
func update_lights(events: Array, scene: Dictionary, scale_px: float, offset: Vector2, now: int) -> void:
	var key:=str([scene.get("id",""),scene.get("width_cells",128),scene.get("height_cells",128),scene.get("walls",[]),scene.get("doors",[]),scene.get("annotations",[])])
	if key!=geometry_key:
		rays.clear()
		geometry_key=key; context={"width":scene.get("width_cells",128),"height":scene.get("height_cells",128),"segments":[]}
		for wall in scene.get("walls",[]): context.segments.append([Hearth20Vision._point(wall.a),Hearth20Vision._point(wall.b)])
		for door in scene.get("doors",[]):
			if not door.get("open",false): context.segments.append([Hearth20Vision._point(door.a),Hearth20Vision._point(door.b)])
		for object in scene.get("annotations",[]):
			if object.kind!="window": context.segments.append_array(Hearth20BoardTools.barriers(object))
	var live: Dictionary={}
	for event in events.slice(-12):
		var powers: Array=Hearth20FxActor3D.profile(Hearth20BoardTools.fx_material(event)); var dark: bool=powers[1]>0; var power:=float(powers[1] if dark else powers[0])
		if power<=.01: continue
		var id:=str(event.id); live[id]=true
		if not polygons.has(id):
			var polygon:=Polygon2D.new(); var shader:=Shader.new(); shader.code=DARK if dark else LIGHT; var material:=ShaderMaterial.new(); material.shader=shader; polygon.material=material; add_child(polygon); polygons[id]=polygon
			if white_texture==null:
				var bitmap:=Image.create(1,1,false,Image.FORMAT_RGBA8); bitmap.fill(Color.WHITE); white_texture=ImageTexture.create_from_image(bitmap)
			polygon.texture=white_texture
		var polygon: Polygon2D=polygons[id]; var age:=maxf(0,float(now-int(event.started_usec))/1000000.0); var travel:=float(event.travel_usec)/1000000.0; var t:=clampf((age-travel)/maxf(.001,float(event.impact_duration_usec)/1000000.0),0,1); var radius:=clampf(float(event.get("size",1)),.25,4)*(3.0 if dark else 3.8)
		var center: Vector2=event.source.lerp(event.destination,clampf(age/maxf(.001,travel),0,1)) if travel>age else event.destination
		var screen=center*scale_px-offset;var extent=radius*scale_px
		var dimensions=get_parent().get_parent().size if get_parent().get_parent() is Control else get_viewport_rect().size
		if not Rect2(screen-Vector2.ONE*extent,Vector2.ONE*extent*2.).intersects(Rect2(Vector2.ZERO,dimensions)):
			polygon.hide();continue
		polygon.show()
		var vertices:=PackedVector2Array(); var uvs:=PackedVector2Array(); var ray_key:=str(center.snapped(Vector2.ONE*.08))+":"+str(radius)
		if not rays.has(id) or rays[id].key!=ray_key:
			var points:=PackedVector2Array()
			for i in 128: points.append(Hearth20Lighting._ray_end(center,Vector2.from_angle(float(i)/128*TAU),radius,context))
			rays[id]={"key":ray_key,"points":points}
		for point in rays[id].points: vertices.append(point*scale_px-offset); uvs.append((point-center)/radius*.5+Vector2.ONE*.5)
		polygon.polygon=vertices; polygon.uv=uvs; polygon.material.set_shader_parameter("age",age); polygon.material.set_shader_parameter("strength",power*(1.0 if dark else .18)*minf(1,age*10)*minf(1,(1-t)*4))
		if not dark: polygon.material.set_shader_parameter("tint",Color(event.get("color","#ff682b")))
	for id in polygons.keys():
		if not live.has(id): polygons[id].queue_free(); polygons.erase(id); rays.erase(id)
