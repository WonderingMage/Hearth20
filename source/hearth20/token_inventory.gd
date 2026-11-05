extends RefCounted
class_name Hearth20TokenInventory
## Stored actors retain identity, art, sheet data and grants, without a board presence.
static func entries(campaign: Dictionary) -> Array:
	return campaign.get("actors",[]).filter(func(actor): return actor is Dictionary and not actor.get("decorative",false))
static func snap_position(scene: Dictionary, point: Vector2) -> Vector2:
	if not scene.get("snap_to_grid",true): return point
	return Vector2(clampf(floorf(point.x),0,float(scene.width_cells)-1)+.5,clampf(floorf(point.y),0,float(scene.height_cells)-1)+.5)
static func new_actor(name_value: String, hero: bool, scene: Dictionary, point: Vector2) -> Dictionary:
	return {"id":"actor-%d-%d"%[Time.get_ticks_usec(),randi()%100000],"name":name_value.strip_edges().left(64),"is_hero":hero,"scene_id":scene.id,"position":snap_position(scene,point),"in_inventory":false,"token_size":1.0,"owner_player_id":"","hidden":not hero,"png_asset_id":"","movement_policy":Hearth20Contracts.default_movement_policy("blocked",[]),"hp":1,"max_hp":1,"temp":0,"ac":10,"armor_class":10,"speed":30,"level":1,"abilities":[10,10,10,10,10,10],"save_profs":[],"save_bonuses":{},"skill_bonuses":{},"skills":{},"vision":{"enabled":true,"darkvision_feet":0.0,"bright_light_feet":0.0,"dim_light_feet":0.0,"darkvision_override":false}}
