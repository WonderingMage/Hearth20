extends RefCounted
class_name Hearth20TokenInventory
static func visual_bounds(actor: Dictionary) -> Rect2:
	var diameter:=float(actor.get("token_size",actor.get("size",1.0)))
	var extent:=Vector2(float(actor.get("display_width_cells",diameter)),float(actor.get("display_height_cells",diameter)))
	var angle:=deg_to_rad(float(actor.get("rotation_degrees",0)))
	var bound:=Vector2(absf(cos(angle))*extent.x+absf(sin(angle))*extent.y,absf(sin(angle))*extent.x+absf(cos(angle))*extent.y)
	return Rect2(actor.get("position",Vector2.ZERO)-bound*0.5,bound)
## Stored actors retain identity, art, sheet data and grants, without a board presence.
static func entries(campaign: Dictionary) -> Array:
	return campaign.get("actors",[]).filter(func(actor): return actor is Dictionary and not actor.get("decorative",false))
static func snap_position(scene: Dictionary, point: Vector2) -> Vector2:
	if not scene.get("snap_to_grid",true): return point
	return Vector2(clampf(floorf(point.x),0,float(scene.width_cells)-1)+.5,clampf(floorf(point.y),0,float(scene.height_cells)-1)+.5)
static func new_actor(name_value: String, hero: bool, scene: Dictionary, point: Vector2) -> Dictionary:
	return {"id":"actor-%d-%d"%[Time.get_ticks_usec(),randi()%100000],"name":name_value.strip_edges().left(64),"is_hero":hero,"scene_id":scene.id,"position":snap_position(scene,point),"in_inventory":false,"token_size":1.0,"owner_player_id":"","hidden":not hero,"png_asset_id":"","movement_policy":Hearth20Contracts.default_movement_policy("blocked",[]),"hp":1,"max_hp":1,"temp":0,"ac":10,"armor_class":10,"speed":30,"level":1,"abilities":[10,10,10,10,10,10],"save_profs":[],"save_bonuses":{},"skill_bonuses":{},"skills":{},"vision":{"enabled":true,"darkvision_feet":0.0,"bright_light_feet":0.0,"dim_light_feet":0.0,"darkvision_override":false}}

static func party_positions(scene: Dictionary, entries: Array, count: int) -> Array:
	var output: Array=[]
	if count<=0:return output
	for entry in entries:
		var p:=snap_position(scene,Hearth20Contracts._point_from_record(entry))
		if _party_square(scene,p,output):output.append(p)
		if output.size()>=count:return output
	var center:=Vector2i(entries[0] if entries[0] is Vector2 else Hearth20Contracts._point_from_record(entries[0])) if not entries.is_empty() else Vector2i(1,1)
	for radius in range(0,maxi(int(scene.width_cells),int(scene.height_cells))+1):
		for y in range(center.y-radius,center.y+radius+1):
			var row: Array=[]
			if radius==0 or absi(y-center.y)==radius:
				for x in range(center.x-radius,center.x+radius+1):row.append(x)
			else:row=[center.x-radius,center.x+radius]
			for x in row:
				var p:=Vector2(x+.5,y+.5)
				if _party_square(scene,p,output):output.append(p)
				if output.size()>=count:return output
	return output

static func _party_square(scene: Dictionary,p: Vector2,used: Array) -> bool:
	if p.x<.5 or p.y<.5 or p.x>float(scene.width_cells)-.5 or p.y>float(scene.height_cells)-.5 or used.has(p):return false
	for delta in [Vector2(.42,0),Vector2(0,.42),Vector2(.4,.4),Vector2(-.4,.4)]:
		if Hearth20Contracts._crosses_blocking_geometry(p-delta,p+delta,scene):return false
	return true
