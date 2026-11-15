extends RefCounted
class_name Hearth20Belongings
## Host-owned journals and unique physical items; never trust a client owner field.
const MAX_ITEMS=256
const MAX_NOTES=20000
const MAX_DESCRIPTION=8000
static func valid(c: Dictionary) -> bool:
	var journals=c.get("player_journals",{});var items=c.get("custom_items",[])
	if not journals is Dictionary or journals.size()>512 or not items is Array or items.size()>MAX_ITEMS:return false
	for player in journals:
		if not Hearth20Contracts.valid_identifier(player) or not journals[player] is String or journals[player].length()>MAX_NOTES:return false
	var ids={}
	for item in items:
		if not item is Dictionary or item.size()!=8:return false
		for key in ["id","name","description","png_asset_id","scene_id","holder"]:
			if not item.get(key) is String:return false
		if not Hearth20Contracts.valid_identifier(item.id) or ids.has(item.id) or item.name.strip_edges().is_empty() or item.name.length()>80 or item.description.length()>MAX_DESCRIPTION or not item.get("hidden") is bool or not Hearth20Contracts.finite_point(item.get("position")):return false
		ids[item.id]=true
		if not c.assets.has(item.png_asset_id) or c.assets[item.png_asset_id].get("kind")!="token":return false
		if not item.holder.is_empty() and item.holder!="dm-local" and not c.get("participants",{}).has(item.holder):return false
		if item.holder.is_empty():
			var page=Hearth20Contracts.find_scene(c,item.scene_id)
			if page.is_empty() or not Hearth20BoardTools.point_ok(item.position,page):return false
	return true
static func find(c: Dictionary,id: String) -> Dictionary:
	for item in c.get("custom_items",[]):
		if item.id==id:return item
	return {}
static func visible(c: Dictionary,item: Dictionary,player: String) -> bool:
	if not item.holder.is_empty():return false
	var page=Hearth20PlayerMap.scene(c,player)
	if page.is_empty() or item.scene_id!=page.id:return false
	if player=="dm-local":return true
	if item.hidden or c.get("map_covered",false) or page.get("blackout",false):return false
	return Hearth20Vision.visible(item.position,Hearth20Vision.build_view(c,player,page))
static func summary(item: Dictionary) -> Dictionary:
	return {"id":item.id,"name":item.name,"description":item.description,"asset_id":item.png_asset_id}
static func project(c: Dictionary,player: String) -> Dictionary:
	var result={"notes":str(c.get("player_journals",{}).get(player,"")),"inventory":[],"board":[],"assets":{}}
	for item in c.get("custom_items",[]):
		var owned=item.holder==player
		if not owned and not visible(c,item,player):continue
		var record=summary(item)
		if owned:result.inventory.append(record)
		else:record.position=item.position;result.board.append(record)
		result.assets[item.png_asset_id]=c.assets[item.png_asset_id].duplicate(true)
	return result
static func create(c: Dictionary,name_value: String,description: String,png: PackedByteArray) -> Dictionary:
	if name_value.strip_edges().is_empty() or name_value.length()>80 or description.length()>MAX_DESCRIPTION:return {"ok":false,"error":"Give the item a name (up to 80 characters) and description (up to 8,000)."}
	if c.get("custom_items",[]).size()>=MAX_ITEMS:return {"ok":false,"error":"This campaign already has 256 custom items."}
	var inspected=Hearth20Assets.inspect_token_png_bytes(png)
	if not inspected.ok:return inspected
	# Small item art should not compete with map transfers or balloon campaign saves.
	var image: Image=inspected.image
	if maxi(image.get_width(),image.get_height())>512:
		var ratio=512./float(maxi(image.get_width(),image.get_height()));image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
	inspected=Hearth20Assets.inspect_token_png_bytes(image.save_png_to_buffer())
	if c.assets.has(inspected.asset_id) and c.assets[inspected.asset_id].get("kind")!="token":return {"ok":false,"error":"This image is already used as a map. Choose a separate item illustration."}
	if not c.assets.has(inspected.asset_id) and c.assets.size()>=4096:return {"ok":false,"error":"The campaign image table is full."}
	var encoded=0
	for asset in c.assets.values():encoded+=str(asset.get("base64","")).length()
	if encoded+ceili(inspected.bytes.size()*4./3.)>48*1024*1024:return {"ok":false,"error":"This campaign's image storage is full. Use a smaller image or another campaign."}
	var asset_id=Hearth20Assets.store_asset(c,inspected,"token")
	var item={"id":"item-"+Crypto.new().generate_random_bytes(16).hex_encode(),"name":name_value.strip_edges(),"description":description,"png_asset_id":asset_id,"holder":"dm-local","scene_id":"","position":Vector2.ZERO,"hidden":true}
	if not c.has("custom_items"):c.custom_items=[]
	c.custom_items.append(item);return {"ok":true,"id":item.id}
static func apply(c: Dictionary,player: String,command: Dictionary) -> Dictionary:
	var action=command.get("action","");var allowed={"notes":["action","text","target"],"pickup":["action","id"],"destroy":["action","id"],"place":["action","id","position"],"hide":["action","id","hidden"],"stow":["action","id"],"give":["action","id","target"]}
	if action not in allowed or command.keys().any(func(key):return key not in allowed[action]):return {"ok":false,"error":"Invalid item or journal request."}
	var dm=player=="dm-local"
	if action=="notes":
		var target=command.get("target",player)
		if not target is String or (target!=player and not dm) or (target!="dm-local" and not c.get("participants",{}).has(target)):return {"ok":false,"error":"You can only edit your own journal."}
		if not command.get("text") is String or command.text.length()>MAX_NOTES:return {"ok":false,"error":"Personal notes support up to 20,000 characters."}
		if not c.has("player_journals"):c.player_journals={}
		if not c.player_journals.has(target) and c.player_journals.size()>=512:return {"ok":false,"error":"The campaign journal limit has been reached."}
		c.player_journals[target]=command.text;return {"ok":true,"message":"Notes stored in the DM's campaign.","text":command.text,"target":target}
	if not command.get("id") is String:return {"ok":false,"error":"Choose an item."}
	var item=find(c,command.id)
	if item.is_empty():return {"ok":false,"error":"That item is no longer available."}
	match action:
		"pickup":
			if not visible(c,item,player):return {"ok":false,"error":"That item is hidden, already claimed, or on another map."}
			if c.get("custom_items",[]).filter(func(record):return record.holder==player).size()>=96:return {"ok":false,"error":"Your inventory is full (96 items)."}
			item.holder=player;item.scene_id=""
		"destroy":
			if not dm and item.holder!=player:return {"ok":false,"error":"You can only destroy an item in your inventory."}
			c.custom_items.erase(item)
			var asset_id=item.png_asset_id
			if not c.custom_items.any(func(record):return record.png_asset_id==asset_id) and not c.get("actors",[]).any(func(actor):return actor.get("png_asset_id")==asset_id):c.assets.erase(asset_id)
		"place":
			if not dm:return {"ok":false,"error":"Only the DM places items on a map."}
			var page=Hearth20PlayerMap.scene(c,player)
			if page.is_empty() or not Hearth20BoardTools.point_ok(command.get("position"),page):return {"ok":false,"error":"Choose a position inside the map."}
			item.holder="";item.scene_id=page.id;item.position=Hearth20TokenInventory.snap_position(page,command.position)
		"hide":
			if not dm or not command.get("hidden") is bool:return {"ok":false,"error":"Only the DM conceals items."}
			item.hidden=command.hidden
		"stow":
			if not dm:return {"ok":false,"error":"Only the DM stows table items."}
			item.holder="dm-local";item.scene_id=""
		"give":
			var target=command.get("target","")
			if not dm or not target is String or not c.get("participants",{}).has(target):return {"ok":false,"error":"Choose a campaign player."}
			if c.get("custom_items",[]).filter(func(record):return record.holder==target).size()>=96:return {"ok":false,"error":"That player's inventory is full."}
			item.holder=target;item.scene_id=""
	return {"ok":true,"message":"Item "+{"pickup":"added to your inventory.","destroy":"destroyed.","place":"placed on the map.","hide":"visibility updated.","stow":"returned to the DM's item vault.","give":"given to the player."}.get(action,"updated.")}
