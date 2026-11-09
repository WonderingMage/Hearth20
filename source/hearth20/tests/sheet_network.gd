extends SceneTree
var session: Hearth20Session
var role: String
var folder: String
var output: String
var secret: String
var port: int
var checks:=0
var errors: Array=[]
var last: Dictionary={}
func _initialize() -> void:
	var a:=OS.get_cmdline_user_args();role=a[0];port=int(a[1]);output=a[2];secret=a[3];folder=a[4];call_deferred("run")
func expect(ok: bool, text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error("FAIL: "+text)
func mark(name_value: String) -> void:FileAccess.open(folder.path_join("sheet-"+name_value+".ready"),FileAccess.WRITE).store_string("ready")
func wait_mark(name_value: String) -> void:
	var path:=folder.path_join("sheet-"+name_value+".ready");var end:=Time.get_ticks_msec()+20000
	while not FileAccess.file_exists(path) and Time.get_ticks_msec()<end:await process_frame
	expect(FileAccess.file_exists(path),"sync "+name_value)
func wait_view(id: String) -> void:
	var end:=Time.get_ticks_msec()+15000
	while last.get("view_actor_id","")!=id and Time.get_ticks_msec()<end:await process_frame
	expect(last.get("view_actor_id","")==id,"authoritative active view "+id)
func has_sight() -> bool:
	for value in last.get("vision_mask",{}).get("levels",PackedByteArray()):
		if value>0:return true
	return false
func run() -> void:
	session=Hearth20Session.new();root.add_child(session);session.snapshot_received.connect(func(value):last=value.duplicate(true))
	if role=="host":
		var campaign:=Hearth20Identity.new_campaign("Synthetic character import network")
		var scene: Dictionary=campaign.scenes[0];scene.width_cells=80;scene.height_cells=12;scene.cell_pixels=8.0;scene.walls=[];scene.doors=[];scene.props=[];scene.annotations=[];scene.lights=[];scene.fog_rects=[];scene.dynamic_lighting=true;scene.ambient_light="dark"
		var image:=Image.create(640,96,false,Image.FORMAT_RGBA8);image.fill(Color("#a74b2d"));scene.map_asset=Hearth20Assets.store_asset(campaign,Hearth20Assets.inspect_token_png_bytes(image.save_png_to_buffer(),"fixture.png"),"map")
		session.configure(campaign)
		var fields: Dictionary={"CharacterName":"Synthetic network adept","CLASS LEVEL":"Cleric 3","STR":"13","DEX":"12","CON":"17","INT":"12","WIS":"18","CHA":"12","AC":"18","MaxHP":"30","CurrentHP":"30","Speed":"25","AdditionalSenses":"Darkvision 300 ft."};var sheet: Dictionary=Hearth20CharacterImport.new().from_fields(fields).sheet
		sheet.import_record.fields["A-private-field"]="A_ONLY_SHEET_SECRET"
		for spec in [["high-a",300],["normal-a",0],["hero-b",60]]:
			sheet.vision.darkvision_feet=spec[1]
			if spec[0]=="hero-b":sheet.import_record.fields={"B-private-field":"B_ONLY_SHEET_SECRET"};sheet.features="B features"
			var result:=session.apply_character_sheet("",sheet,"");expect(result.ok,"DM import committed for "+spec[0]);var actor:=Hearth20Contracts.find_actor(campaign,result.id);actor.id=spec[0];actor.position=Vector2(.5,5.5);actor.in_inventory=false
		expect(session.start_host(port).ok,"host starts");FileAccess.open(secret,FileAccess.WRITE).store_string(session.invite_secret)
		await wait_mark("A-joined");await wait_mark("B-joined")
		var a_id:="";var b_id:=""
		for id in session.remote_players:
			if session.remote_players[id].nickname=="A":a_id=id
			else:b_id=id
		expect(not a_id.is_empty() and not b_id.is_empty(),"both authenticated players identified")
		session.grant_token_control("high-a",a_id,true);session.grant_token_control("normal-a",a_id,true);session.grant_token_control("hero-b",b_id,true);mark("assigned")
		await wait_mark("A-normal");await wait_mark("B-checked")
		expect(campaign.viewpoints.get(a_id,"")=="normal-a","host keeps the player's legitimate normal-sight viewpoint")
		var saved:=Hearth20Identity.save_campaign(campaign,Hearth20Identity.SAVE_ROOT+"/sheet-network."+Hearth20Identity.SAVE_EXTENSION);expect(saved.ok,"host saves imported sheets, grants and viewpoint")
		var loaded:=Hearth20Identity.load_campaign(Hearth20Identity.SAVE_ROOT+"/sheet-network."+Hearth20Identity.SAVE_EXTENSION);expect(loaded.ok and loaded.campaign.viewpoints.get(a_id,"")=="normal-a","chosen viewpoint persists through reopen")
		session.grant_token_control("high-a","",false);session.grant_token_control("normal-a","",false);mark("revoked");await wait_mark("A-revoked");mark("done")
	else:
		var end:=Time.get_ticks_msec()+15000
		while not FileAccess.file_exists(secret) and Time.get_ticks_msec()<end:await process_frame
		expect(session.join_host("127.0.0.1",port,FileAccess.get_file_as_string(secret),role).ok,"player joins")
		while session.local_player_id.is_empty() and Time.get_ticks_msec()<end:await process_frame
		mark(role+"-joined");await wait_mark("assigned")
		await wait_view("high-a" if role=="A" else "hero-b")
		var bytes:=JSON.stringify(last)
		expect(not ("B_ONLY_SHEET_SECRET" if role=="A" else "A_ONLY_SHEET_SECRET") in bytes,"other player's imported raw fields never cross the network")
		var sight: Dictionary=last.vision_mask;var d:=int(sight.subdivisions);var row:=floori(5.5*d);var near:=row*int(sight.columns)+50*d;var far:=row*int(sight.columns)+63*d
		if role=="A":
			expect(int(sight.levels[near])==1 and int(sight.levels[far])==0,"player receives300ft gray vision but no beyond-range cells")
			expect(last.sheets.size()==2 and last.sheets.any(func(sheet):return sheet.vision.darkvision_feet==300),"only own complete imported sheets delivered")
			expect(session.set_view_actor("normal-a").ok,"player requests own normal-eyed token")
			await wait_view("normal-a");expect(not has_sight(),"active0ft token cannot borrow300ft inactive eyes")
			session.set_view_actor("hero-b");await create_timer(.3).timeout;expect(last.get("view_actor_id","")=="normal-a" and not has_sight(),"foreign token viewpoint request rejected")
			mark("A-normal");await wait_mark("revoked");end=Time.get_ticks_msec()+10000
			while not last.get("sheets",[]).is_empty() and Time.get_ticks_msec()<end:await process_frame
			expect(last.get("sheets",[]).is_empty() and last.get("view_actor_id","")=="" and not has_sight(),"revocation clears imported sheets, active view and map sight");mark("A-revoked")
		else:
			expect(int(sight.levels[near])==0,"60ft character cannot see another character's300ft range")
			expect(last.sheets.size()==1 and last.sheets[0].vision.darkvision_feet==60,"B receives only their60ft sheet");mark("B-checked")
		await wait_mark("done")
	session.stop_session();session.queue_free();await process_frame;await process_frame;Hearth20PlayerProfile.cached_key=null
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"role":role,"checks":checks,"errors":errors}));print("Sheet network %s: %d checks, %d failures."%[role,checks,errors.size()]);quit(0 if errors.is_empty() else 1)
