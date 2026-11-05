extends RefCounted
class_name Hearth20JoinCharacter
## A connection proves identity; a first character is a data-only, one-time submission.
static func current(campaign: Dictionary, player: String) -> Dictionary:
	var recorded = campaign.get("participants",{}).get(player,{}).get("character_id","")
	var actor = Hearth20Contracts.find_actor(campaign,str(recorded))
	if not actor.is_empty() and actor.get("owner_player_id","")==player and actor.get("is_hero",false):return actor
	# Existing assigned characters remain usable when opening pre-onboarding campaigns.
	for candidate in campaign.get("actors",[]):
		if candidate.get("owner_player_id","")==player and candidate.get("is_hero",false):return candidate
	return {}
static func primitive(value: Variant, depth: int=0) -> bool:
	if depth>8:return false
	if value==null or value is bool or value is int:return true
	if value is float:return is_finite(value)
	if value is String or value is StringName:return str(value).length()<=32000
	if value is Array:
		if value.size()>512:return false
		for item in value:
			if not primitive(item,depth+1):return false
		return true
	if value is Dictionary:
		if value.size()>4096:return false
		for key in value:
			if (not key is String and not key is StringName) or str(key).length()>256 or not primitive(value[key],depth+1):return false
		return true
	return false
static func submit(campaign: Dictionary, player: String, sheet: Dictionary, png: PackedByteArray) -> Dictionary:
	if not campaign.get("participants",{}).has(player):return {"ok":false,"error":"Join and verify your player identity first."}
	var prior=current(campaign,player)
	if not prior.is_empty():return {"ok":true,"id":str(prior.id),"existing":true}
	if not primitive(sheet) or var_to_bytes(sheet).size()>1024 or not sheet.get("name") is String:return {"ok":false,"error":"Choose a character name."}
	var name_value=str(sheet.name).strip_edges()
	if name_value.is_empty() or name_value.length()>64:return {"ok":false,"error":"Character names must contain 1–64 characters."}
	if sheet.keys()!=["name"]:return {"ok":false,"error":"Join with your character name and PNG. Character statistics stay on D&D Beyond."}
	if campaign.actors.size()>=Hearth20Contracts.MAX_ACTORS:return {"ok":false,"error":"The DM's token inventory is full."}
	var image=Hearth20Assets.inspect_token_png_bytes(png,"player-character.png")
	if not image.ok:return image
	var proposed=campaign.duplicate(true);var scene=Hearth20Contracts.find_scene(proposed,proposed.active_scene)
	var actor=Hearth20TokenInventory.new_actor(name_value,true,scene,Vector2(.5,.5))
	for key in Hearth20TableData.SHEET_FIELDS:
		if key!="name":actor.erase(key)
	actor.erase("armor_class");actor.erase("vision");actor.coins={};actor.sheet_external=true
	actor.id="character-"+Crypto.new().generate_random_bytes(16).hex_encode();actor.owner_player_id=player;actor.in_inventory=true;actor.token_size=1.0;actor.hidden=false
	actor.png_asset_id=Hearth20Assets.store_asset(proposed,image,"token")
	proposed.actors.append(actor);proposed.participants[player].character_id=actor.id
	if var_to_bytes(proposed).size()>Hearth20Identity.MAX_SAVE_BYTES:return {"ok":false,"error":"The campaign has reached its saved-data limit."}
	var checked=Hearth20Contracts.validate_campaign(proposed)
	if not checked.ok:return {"ok":false,"error":"The character token could not be created: "+str(checked.errors)}
	campaign.actors.append(actor);campaign.assets=proposed.assets;campaign.participants[player].character_id=actor.id
	return {"ok":true,"id":str(actor.id),"existing":false}

