extends Node2D
class_name Hearth20FxRenderer
## Original layered fire-rocket cosmetic. Events are visual data and never touch rules.

const MAX_ACTIVE_EVENTS := 64
var events: Array[Dictionary] = []
var world_scale := 64.0
var world_offset := Vector2.ZERO
var reduced_motion := false
var visuals: Dictionary={}
var cinematic: Hearth20FxStage3D
var transient_light: Hearth20FxBoardLight
var scene: Dictionary={}
func _ready() -> void:
	transient_light=Hearth20FxBoardLight.new(); transient_light.z_index=0; add_child(transient_light)
	cinematic=Hearth20FxStage3D.new(); cinematic.z_index=2; add_child(cinematic)

func play_fire_rocket(source: Vector2, destination: Vector2, speed_cells_per_second: float = 8.0, duration_ms: int = 950) -> Dictionary:
	if not Hearth20Contracts.finite_point(source) or not Hearth20Contracts.finite_point(destination):
		return {"ok": false, "error": "FX endpoints are invalid."}
	if not is_finite(speed_cells_per_second) or speed_cells_per_second <= 0.1 or speed_cells_per_second > 1000.0 or duration_ms < 250 or duration_ms > 8000:
		return {"ok": false, "error": "FX travel speed or impact duration is outside the supported range."}
	while events.size() >= MAX_ACTIVE_EVENTS:
		events.pop_front()
	var travel_seconds := source.distance_to(destination) / speed_cells_per_second
	var now_usec := Time.get_ticks_usec()
	var event := {"id": "fx-%d" % now_usec, "preset": "fire-rocket-impact-v1", "source": source, "destination": destination, "started_usec": now_usec, "travel_usec": int(ceil(travel_seconds * 1_000_000.0)), "impact_duration_usec": duration_ms * 1000, "seed": int(now_usec & 0x7fffffff), "public": true}
	events.append(event)
	queue_redraw()
	return {"ok": true, "event": event.duplicate(true), "arrival_usec": int(event.started_usec) + int(event.travel_usec)}

func add_authorized_event(event: Dictionary) -> bool:
	if event.get("preset", "") not in ["fire-rocket-impact-v1", "tabletop-fx-v1"] or not Hearth20Contracts.finite_point(event.get("source", null)) or not Hearth20Contracts.finite_point(event.get("destination", null)):
		return false
	if not event.get("started_usec") is int or not event.get("travel_usec") is int or not event.get("impact_duration_usec") is int:
		return false
	if int(event.travel_usec) < 0 or int(event.travel_usec) > 120_000_000 or int(event.impact_duration_usec) < 1 or int(event.impact_duration_usec) > 120_000_000:
		return false
	while events.size() >= MAX_ACTIVE_EVENTS:
		events.pop_front()
	events.append(event.duplicate(true))
	queue_redraw()
	return true

func clear_all() -> void:
	events.clear()
	queue_redraw()

func _process(_delta: float) -> void:
	if events.is_empty() and visuals.is_empty() and cinematic!=null and cinematic.actors.is_empty() and transient_light.polygons.is_empty():return
	var now := Time.get_ticks_usec()
	events = events.filter(func(event: Dictionary) -> bool: return now <= int(event.started_usec) + int(event.travel_usec) + int(event.impact_duration_usec))
	var live: Dictionary={}
	var cinematic_ids: Array=events.slice(-8).map(func(event): return str(event.get("id","")))
	for event in events:
		var id:=str(event.get("id",""))
		live[id]=true
		if not visuals.has(id) and not reduced_motion and not cinematic_ids.has(id) and visuals.size()<24:
			var visual:=Hearth20FxVisual.new(); add_child(visual); visuals[id]=visual
			visual.modulate.a=.30
		if visuals.has(id):
			visuals[id].visible=not cinematic_ids.has(id) and not reduced_motion
			if visuals[id].visible: visuals[id].configure(event,world_scale,world_offset,now)
	for id in visuals.keys():
		if not live.has(id): visuals[id].queue_free(); visuals.erase(id)
	if cinematic!=null:
		var dimensions: Vector2=get_parent().size if get_parent() is Control else get_viewport_rect().size
		if cinematic.update_events(events if not reduced_motion else [],world_scale,world_offset,now,dimensions):transient_light.update_lights(events if not reduced_motion else [],scene,world_scale,world_offset,now)
	queue_redraw()

func _draw() -> void:
	var now := Time.get_ticks_usec()
	for event in events:
		if not reduced_motion and (visuals.has(str(event.get("id",""))) or events.slice(-8).has(event)): continue
		if event.get("preset", "") == "tabletop-fx-v1":
			_draw_particle_effect(event, now)
			continue
		var source: Vector2 = event.source
		var destination: Vector2 = event.destination
		var travel := maxi(1, int(event.travel_usec))
		var elapsed := now - int(event.started_usec)
		if elapsed <= travel:
			var p := clampf(float(elapsed) / float(travel), 0.0, 1.0)
			var head := source.lerp(destination, p)
			var trail_start := source.lerp(head, 0.72)
			var source_px := _to_local(trail_start)
			var head_px := _to_local(head)
			draw_line(source_px, head_px, Color(0.9, 0.18, 0.025, 0.22), 15.0, true)
			draw_line(source_px, head_px, Color(1.0, 0.28, 0.035, 0.8), 7.0, true)
			draw_circle(head_px, 10.0, Color(1.0, 0.22, 0.02, 0.9))
			draw_circle(head_px, 5.0, Color(1.0, 0.88, 0.42, 1.0))
			continue
		var impact_elapsed := maxi(0, elapsed - travel)
		var duration := maxi(1, int(event.impact_duration_usec))
		var t := clampf(float(impact_elapsed) / float(duration), 0.0, 1.0)
		var center := _to_local(destination)
		# Smoke/glow bed, initial flash, expanding ring and sparks are separate layers.
		draw_circle(center, world_scale * (0.12 + 0.48 * t), Color(0.25, 0.075, 0.035, 0.25 * (1.0 - t)))
		draw_circle(center, world_scale * (0.10 + 0.32 * t), Color(1.0, 0.20, 0.015, 0.30 * (1.0 - t)))
		var flash := 1.0 if t < 0.08 else (1.0 - t) * 0.55
		draw_circle(center, world_scale * (0.045 + 0.11 * minf(t * 4.0, 1.0)), Color(1.0, 0.78, 0.30, flash))
		draw_arc(center, world_scale * (0.08 + 0.38 * t), 0.0, TAU, 48, Color(1.0, 0.42, 0.09, (1.0 - t) * 0.95), maxf(1.5, world_scale * 0.035 * (1.0 - t * 0.35)), true)
		var seed := int(event.seed)
		for particle_index in 12:
			var angle := _particle_angle(seed, particle_index)
			var distance := world_scale * (0.10 + 0.30 * t) * (0.7 + float((particle_index * 7) % 11) / 20.0)
			var spark_end := center + Vector2(cos(angle), sin(angle)) * distance
			var spark_start := center + Vector2(cos(angle), sin(angle)) * distance * 0.72
			draw_line(spark_start, spark_end, Color(1.0, 0.72, 0.22, (1.0 - t) * 0.9), maxf(1.0, world_scale * 0.018), true)

func _to_local(world_point: Vector2) -> Vector2:
	return (world_point * world_scale) - world_offset

func _particle_angle(seed: int, index: int) -> float:
	var value := (seed ^ (index * 0x45d9f3b)) & 0x7fffffff
	value = int((value * 1103515245 + 12345) & 0x7fffffff)
	return float(value % 36000) / 100.0 * PI / 180.0

func _draw_particle_effect(e: Dictionary, now: int) -> void:
	var a := _to_local(e.source)
	var b := _to_local(e.destination)
	var elapsed := maxf(0.0,float(now-int(e.started_usec))/1000000)
	var duration := maxf(0.01,float(e.impact_duration_usec)/1000000)
	var travel := float(e.travel_usec)/1000000
	var kind := str(e.get("effect","breath"))
	var color := Color(e.get("color","#ff682b"))
	var scale := world_scale*clampf(float(e.get("size",1)),0.25,4)
	var seed := int(e.seed)
	if reduced_motion:
		draw_arc(b,scale*0.6,0,TAU,40,Color(color,0.7),3,true)
		return
	if kind in ["missile","rocket"] and elapsed < travel:
		var head := a.lerp(b,elapsed/maxf(0.01,travel))
		draw_line(head-(b-a).normalized()*scale*0.7,head,Color(color,0.35),scale*0.13,true)
		draw_circle(head,scale*0.09,color)
		draw_circle(head,scale*0.035,Color.WHITE)
		return
	var t := clampf((elapsed-travel)/duration,0,1)
	var fade := minf(1.0,t*10)*minf(1.0,(1-t)*4)
	var direction := (b-a).normalized()
	if direction.length_squared()<0.1: direction=Vector2.RIGHT
	var side := direction.orthogonal()
	if kind in ["beam","breath"]:
		draw_line(a,b,Color(color,fade*0.1),scale*(0.3 if kind=="beam" else 0.5),true)
	if kind in ["glow","shield","pooling"]:
		var radius := scale*(0.55+sin(t*TAU*2)*0.04)
		draw_circle(b,radius,Color(color,fade*0.1))
		draw_arc(b,radius,0,TAU,80,Color(color,fade*0.85),scale*0.035,true)
	var count := clampi(int(e.get("density",48)),8,128)
	for i in count:
		var angle := _particle_angle(seed,i)
		var noise := fmod(angle*17.319,1.0)
		var phase := fmod(t*(2.0 if kind in ["beam","breath","burn"] else 1.0)+float(i)/float(count),1.0)
		var outward := Vector2.from_angle(angle)
		var pos := b
		match kind:
			"beam": pos=a.lerp(b,phase)+side*sin(angle+elapsed*6)*scale*0.07
			"breath": pos=a.lerp(b,phase)+side*sin(angle+elapsed*5)*a.distance_to(b)*phase*0.28
			"burn", "burst": pos=b+Vector2(sin(angle)*scale*0.23,-phase*scale*1.2)+outward*scale*0.08
			"bubbling", "pooling": pos=b+outward*scale*sqrt(noise)*0.6+Vector2(0,-sin(phase*PI)*scale*0.2)
			"glow", "shield": pos=b+Vector2.from_angle(angle+elapsed*0.8)*scale*(0.55+sin(phase*PI)*0.05)
			"sparkle": pos=b+Vector2(sin(angle)*scale*0.6,-phase*scale*1.5)
			"splatter": pos=a.lerp(b,minf(1,t*4))+outward*scale*noise*t*0.65
			_: pos=b+outward*scale*t*(0.5+noise*0.65)
		var alpha := fade*(0.25+sin(phase*PI)*0.65)
		var radius := maxf(1.5,scale*(0.012+noise*0.035)*(1-phase*0.6))
		if kind in ["beam","nova","explode","rocket","splatter"]:
			draw_line(pos-outward*radius*3,pos,Color(color,alpha),radius,true)
		elif kind=="bubbling": draw_arc(pos,radius*2,0,TAU,12,Color(color,alpha),1.5,true)
		else:
			draw_circle(pos,radius*2,Color(color,alpha*0.12))
			draw_circle(pos,radius,Color(color,alpha))
	if kind in ["bomb","burst","explode","nova","rocket"]:
		draw_arc(b,scale*t,0,TAU,64,Color(color,(1-t)*0.7),maxf(1,scale*0.04*(1-t)),true)
