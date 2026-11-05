extends Control
class_name Hearth20FxPreview
var board: Hearth20BoardCanvas
var settings: Dictionary={}
var renderer: Hearth20FxRenderer
var elapsed:=10.0
var signature:=""
func _ready() -> void:
	custom_minimum_size=Vector2(220,164)
	clip_contents=true; mouse_filter=Control.MOUSE_FILTER_IGNORE
	renderer=Hearth20FxRenderer.new(); add_child(renderer)
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed+=delta
	renderer.world_scale=size.x/6.0
	renderer.world_offset=Vector2.ZERO
	renderer.reduced_motion=board.active_fx.reduced_motion if board!=null else false
	var key:=JSON.stringify(settings)
	if elapsed>maxf(2.8,float(settings.get("duration",2))+1.0) or key!=signature:
		signature=key; elapsed=0
		renderer.clear_all()
		var event: Dictionary=settings.duplicate(true)
		event.merge({"id":"preview-%d"%Time.get_ticks_usec(),"preset":"tabletop-fx-v1","source":Vector2(.8,1.5),"destination":Vector2(4.6,1.5),"started_usec":Time.get_ticks_usec(),"travel_usec":700000 if str(event.get("effect","")) in ["rocket","missile"] else 0,"impact_duration_usec":int(float(event.get("duration",2))*1000000),"seed":7841},true)
		if event.get("effect","") not in Hearth20BoardTools.CAST_EFFECTS: event.source=Vector2(3,1.5); event.destination=event.source
		renderer.add_authorized_event(event)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Hearth20Regal.swatch(Hearth20Regal.BG))
	var map:=Hearth20MapLibrary.texture("sunspire-sanctum",false)
	if map: draw_texture_rect_region(map,Rect2(Vector2.ZERO,size),Rect2(650,450,800,500),Color(1,1,1,.5))
	draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,.36))
	var gold:=Hearth20Regal.swatch(Hearth20Regal.GOLD)
	for corner in [Vector2(5,5),Vector2(size.x-5,5),Vector2(size.x-5,size.y-5),Vector2(5,size.y-5)]:
		var d: Vector2=(size*.5-corner).sign()
		draw_line(corner,corner+Vector2(d.x*12,0),Color(gold,.65),1,true)
		draw_line(corner,corner+Vector2(0,d.y*12),Color(gold,.65),1,true)
