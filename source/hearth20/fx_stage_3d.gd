extends SubViewportContainer
class_name Hearth20FxStage3D
const PITCH:=.53
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var actors: Dictionary={}
var refresh_hz=60.
var last_update_usec=-1000000
var last_layout=Vector4.ZERO
var last_offset=Vector2.INF
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; stretch=true;material=Hearth20FxPost.material()
	viewport=SubViewport.new(); viewport.transparent_bg=true; viewport.own_world_3d=true; viewport.handle_input_locally=false; viewport.msaa_3d=Viewport.MSAA_4X; add_child(viewport)
	world=Node3D.new(); viewport.add_child(world); camera=Camera3D.new(); camera.current=true; camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.near=.1; camera.far=10000; world.add_child(camera)
	var environment:=WorldEnvironment.new(); var settings:=Environment.new(); settings.background_mode=Environment.BG_COLOR; settings.background_color=Color(0,0,0,0); settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color=Color("#b5c6dc"); settings.ambient_light_energy=.35; settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC; environment.environment=settings; world.add_child(environment)
	for spec in [[Vector3(-45,-35,0),Color("#ffe5bd"),1.3],[Vector3(-20,140,0),Color("#91b8e6"),.65]]:
		var light:=DirectionalLight3D.new(); light.rotation_degrees=spec[0]; light.light_color=spec[1]; light.light_energy=spec[2]; world.add_child(light)
	hide();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
func update_events(events: Array, scale_px: float, offset: Vector2, now: int, dimensions: Vector2) -> bool:
	if viewport==null: return false
	if events.is_empty():
		var changed=visible or not actors.is_empty()
		for actor in actors.values():actor.queue_free()
		actors.clear();visible=false;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;return changed
	var layout=Vector4(dimensions.x,dimensions.y,scale_px,refresh_hz)
	if layout==last_layout and offset==last_offset and now-last_update_usec<int(1000000./maxf(1.,refresh_hz)):return false
	last_update_usec=now;last_layout=layout;last_offset=offset
	size=dimensions.max(Vector2(64,64)); camera.size=size.y; var center:=Vector3(size.x*.5,0,size.y*.5/cos(PITCH)); camera.position=center+Vector3(0,1800,1800*tan(PITCH)); camera.look_at(center)
	var live: Dictionary={};var showing=false
	for event in events.slice(-8):
		var id:=str(event.id); live[id]=true
		var source: Vector2=event.source*scale_px-offset;var target: Vector2=event.destination*scale_px-offset;var pixel_scale=scale_px*clampf(float(event.get("size",1)),.25,4)
		var footprint=Rect2(source,Vector2.ZERO).expand(target).grow(pixel_scale*12.)
		if not footprint.intersects(Rect2(Vector2.ZERO,size)):
			if actors.has(id):actors[id].hide()
			continue
		showing=true
		if not actors.has(id):
			var actor:=Hearth20FxActor3D.new(); world.add_child(actor); actor.setup(event); actors[id]=actor
		var actor: Hearth20FxActor3D=actors[id];actor.show()
		var age:=float(now-int(event.started_usec))/1000000.0; var travel:=float(event.travel_usec)/1000000.0; var flight:=travel>0 and age<travel; var at: Vector2=source.lerp(target,clampf(age/maxf(.001,travel),0,1)) if flight else target
		actor.position=Vector3(at.x,sin(clampf(age/maxf(.001,travel),0,1)*PI)*pixel_scale*.6 if flight else 0,at.y/cos(PITCH)); actor.scale=Vector3(pixel_scale,pixel_scale,pixel_scale/cos(PITCH)); actor.animate(now,(source-target)/maxf(1,pixel_scale))
	for id in actors.keys():
		if not live.has(id): actors[id].queue_free(); actors.erase(id)
	visible=showing; viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if visible else SubViewport.UPDATE_DISABLED
	return true
