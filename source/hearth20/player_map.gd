extends RefCounted
class_name Hearth20PlayerMap
## A DM's editor tab never chooses another player's map.
static func actor(campaign: Dictionary,player: String) -> Dictionary:
	var ids=[str(campaign.get("viewpoints",{}).get(player,"")),str(campaign.get("participants",{}).get(player,{}).get("character_id",""))]
	for id in ids:
		if id.is_empty():continue
		var candidate=Hearth20Contracts.find_actor(campaign,id)
		if not candidate.is_empty() and candidate.get("owner_player_id","")==player:return candidate
	for candidate in campaign.get("actors",[]):
		if candidate.get("owner_player_id","")==player and candidate.get("is_hero",false):return candidate
	return {}
static func scene(campaign: Dictionary,player: String) -> Dictionary:
	if player=="dm-local":return Hearth20Contracts.find_scene(campaign,str(campaign.get("active_scene","")))
	var pawn=actor(campaign,player)
	if pawn.is_empty() or pawn.get("in_inventory",false) or pawn.get("decorative",false) or pawn.get("layer","tokens")!="tokens":return {}
	return Hearth20Contracts.find_scene(campaign,str(pawn.get("scene_id","")))
static func context(campaign: Dictionary,player: String) -> Dictionary:
	var result=campaign.duplicate()
	result.active_scene=str(scene(campaign,player).get("id",""))
	return result
static func waiting(campaign: Dictionary,player: String) -> Dictionary:
	var result=Hearth20Contracts.covered_projection(campaign,player)
	result.scene.id="unplaced";result.scene.title="Waiting for your character"
	return result
