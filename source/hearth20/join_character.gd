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
	if sheet.keys()!=["name"]:return {"ok":false,"error":"Join with your character name and token image. Character statistics stay on D&D Beyond."}
	if campaign.actors.size()>=Hearth20Contracts.MAX_ACTORS:return {"ok":false,"error":"The DM's token inventory is full."}
	var image=Hearth20Assets.inspect_token_art_bytes(png,"player-character")
	if not image.ok:return image
	if campaign.assets.has(image.asset_id) and campaign.assets[image.asset_id].get("kind","")!="token":
		return {"ok":false,"error":"That image is already used as a map. Choose a separate token image."}
	var proposed=campaign.duplicate(true);var scene=Hearth20Contracts.find_scene(proposed,proposed.active_scene)
	var actor=Hearth20TokenInventory.new_actor(name_value,true,scene,Vector2(.5,.5))
	for key in Hearth20TableData.SHEET_FIELDS:
		if key!="name":actor.erase(key)
	actor.erase("armor_class");actor.erase("vision");actor.coins={};actor.sheet_external=true
	actor.id="character-"+Crypto.new().generate_random_bytes(16).hex_encode();actor.owner_player_id=player;actor.in_inventory=true;actor.token_size=1.0;actor.hidden=false
	actor.name_revealed=true
	actor.png_asset_id=Hearth20Assets.store_asset(proposed,image,"token")
	proposed.actors.append(actor);proposed.participants[player].character_id=actor.id
	if var_to_bytes(proposed).size()>Hearth20Identity.MAX_SAVE_BYTES:return {"ok":false,"error":"The campaign has reached its saved-data limit."}
	var checked=Hearth20Contracts.validate_campaign(proposed)
	if not checked.ok:return {"ok":false,"error":"The character token could not be created: "+str(checked.errors)}
	campaign.actors.append(actor);campaign.assets=proposed.assets;campaign.participants[player].character_id=actor.id
	return {"ok":true,"id":str(actor.id),"existing":false}

static func edit(campaign: Dictionary, player: String, actor_id: String, sheet: Dictionary, png: PackedByteArray) -> Dictionary:
	var actor := Hearth20Contracts.find_actor(campaign,actor_id)
	if not campaign.get("participants",{}).has(player) or not Hearth20TokenInventory.can_edit_character(actor,player):
		return {"ok":false,"error":"Choose your own placed character token."}
	if sheet.size()!=2 or not sheet.get("name") is String:
		return {"ok":false,"error":"Enter a token name."}
	var name_value := str(sheet.name).strip_edges()
	var can_rename := Hearth20TokenInventory.name_is_public(actor)
	if not can_rename and (not name_value.is_empty() or png.is_empty()):
		return {"ok":false,"error":"This token's name is concealed. Choose a new appearance."}
	if can_rename and (name_value.is_empty() or name_value.length()>64 or name_value.contains("\n") or name_value.contains("\r")):
		return {"ok":false,"error":"Token names must contain 1–64 characters."}
	if not png.is_empty():
		var image := Hearth20Assets.inspect_token_art_bytes(png,"player-character")
		if not image.ok:return image
		var asset_id: String = image.asset_id
		if campaign.assets.has(asset_id):
			if campaign.assets[asset_id].get("kind","")!="token":
				return {"ok":false,"error":"That image is already used as a map. Choose a separate token image."}
		else:
			var proposed := {"assets":{}}
			Hearth20Assets.store_asset(proposed,image,"token")
			if var_to_bytes(campaign).size()+var_to_bytes(proposed.assets[asset_id]).size()>Hearth20Identity.MAX_SAVE_BYTES:
				return {"ok":false,"error":"The campaign has reached its saved-data limit."}
			campaign.assets[asset_id]=proposed.assets[asset_id]
		actor.png_asset_id=asset_id
	if can_rename:actor.name=name_value
	return {"ok":true}

