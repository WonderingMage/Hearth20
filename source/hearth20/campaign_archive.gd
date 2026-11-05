extends RefCounted
class_name Hearth20CampaignArchive
## Named local saves. Index metadata is optional; legacy single-table saves remain readable.
static func valid_path(path: String) -> bool:
	return path.begins_with(Hearth20Identity.SAVE_ROOT+"/") and path.get_base_dir()==Hearth20Identity.SAVE_ROOT and not path.contains("..") and not path.contains("\\") and path.ends_with("."+Hearth20Identity.SAVE_EXTENSION)
static func new_path(title_value="campaign") -> String:
	var pattern=RegEx.new();pattern.compile("[^a-z0-9]+")
	var stem=pattern.sub(str(title_value).to_lower(),"-",true).trim_prefix("-").trim_suffix("-").left(48)
	return Hearth20Identity.SAVE_ROOT+"/"+(stem if not stem.is_empty() else "campaign")+"-"+Crypto.new().generate_random_bytes(8).hex_encode()+"."+Hearth20Identity.SAVE_EXTENSION
static func describe(campaign: Dictionary,path: String) -> Dictionary:
	var scene={}
	for candidate in campaign.get("scenes",[]):
		if candidate is Dictionary and candidate.get("id","")==campaign.get("active_scene",""):scene=candidate;break
	var file=FileAccess.open(path,FileAccess.READ)
	return {"path":path,"title":str(campaign.get("title","Untitled table")).left(96),"scene":str(scene.get("title","No active map")).left(96),"tokens":campaign.get("actors",[]).size(),"scenes":campaign.get("scenes",[]).size(),"saved_at":FileAccess.get_modified_time(path),"bytes":file.get_length() if file!=null else 0,"edition":Hearth20Identity.EDITION}
static func index_saved(campaign: Dictionary,path: String) -> void:
	if not valid_path(path):return
	var file=FileAccess.open(path+".meta.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(describe(campaign,path)))
	var scene=Hearth20Contracts.find_scene(campaign,str(campaign.get("active_scene","")))
	var asset=campaign.get("assets",{}).get(scene.get("map_asset",""),{})
	if not asset is Dictionary or int(asset.get("width",0))*int(asset.get("height",0))>16777216:return
	var image=Hearth20Assets.decode_map(Marshalls.base64_to_raw(str(asset.get("base64",""))))
	if image==null:return
	var scale=minf(320./image.get_width(),180./image.get_height())
	image.resize(maxi(1,roundi(image.get_width()*scale)),maxi(1,roundi(image.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
	image.save_png(path+".thumb.png")
static func list_tables() -> Array:
	var result=[];var folder=DirAccess.open(Hearth20Identity.SAVE_ROOT)
	if folder==null:return result
	for name_value in folder.get_files():
		var path=Hearth20Identity.SAVE_ROOT.path_join(name_value)
		if not valid_path(path):continue
		var record={};var meta=FileAccess.open(path+".meta.json",FileAccess.READ)
		if meta!=null and meta.get_length()<32768:
			var value=JSON.parse_string(meta.get_as_text())
			if value is Dictionary and value.get("edition","")==Hearth20Identity.EDITION and Hearth20Contracts._integer_number(value.get("saved_at")) and int(value.saved_at)==FileAccess.get_modified_time(path) and value.get("title") is String and value.get("scene") is String and Hearth20Contracts._integer_number(value.get("tokens")) and Hearth20Contracts._integer_number(value.get("scenes")):record=value
		if record.is_empty():
			var loaded=read_table(path)
			if not loaded.ok:record={"path":path,"title":name_value.get_basename(),"scene":"Unreadable save · your file is preserved","tokens":0,"scenes":0,"saved_at":FileAccess.get_modified_time(path),"invalid":true}
			else:record=describe(loaded.campaign,path)
		record.path=path;result.append(record)
	result.sort_custom(func(a,b):return int(a.saved_at)>int(b.saved_at))
	return result
static func read_table(path: String) -> Dictionary:
	if not valid_path(path):return {"ok":false,"errors":["Choose a table from this computer's campaign vault."]}
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<1 or file.get_length()>Hearth20Identity.MAX_SAVE_BYTES:return {"ok":false,"errors":["The saved table could not be read or exceeds its size limit."]}
	var parser=JSON.new()
	if parser.parse(file.get_as_text())!=OK:return {"ok":false,"errors":["This saved table is incomplete or unreadable. Your file has not been changed."]}
	var campaign=Hearth20Identity._decode_variant(parser.data);var checked=Hearth20Identity.validate_campaign(campaign)
	return {"ok":true,"campaign":campaign} if checked.ok else checked
