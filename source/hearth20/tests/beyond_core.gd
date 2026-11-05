extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	var c=Hearth20Identity.new_campaign("Beyond fork contract");var scene=c.scenes[0]
	var key=Crypto.new().generate_rsa(2048);var pem=key.save_to_string(true);var principal=Hearth20PlayerProfile.principal(pem);c.participants[principal]={"public_key":pem,"display_name":"Test player"}
	var image=Image.create(64,64,false,Image.FORMAT_RGBA8);image.fill(Color.GOLD);var png=image.save_png_to_buffer()
	var before=var_to_bytes(c)
	expect(not Hearth20JoinCharacter.submit(c,"impostor",{"name":"Fake"},png).ok and before==var_to_bytes(c),"join requires verified identity")
	expect(not Hearth20JoinCharacter.submit(c,principal,{"name":"Extra stats","coins":{"gp":9999}},png).ok and before==var_to_bytes(c),"join cannot sneak in character data")
	expect(not Hearth20JoinCharacter.submit(c,principal,{"name":"No PNG"},PackedByteArray()).ok,"PNG required")
	var result=Hearth20JoinCharacter.submit(c,principal,{"name":"Arden"},png);expect(result.ok,"name and PNG without PDF: "+str(result))
	if not result.ok:quit(1);return
	var a=Hearth20JoinCharacter.current(c,principal)
	expect(a.token_size==1 and a.in_inventory and a.movement_policy.mode=="blocked","unique size-one token in vault, DM controls movement")
	expect(not a.has("abilities") and not a.has("vision") and not a.has("hp") and a.coins.is_empty(),"no inferred stats, darkvision or sheet gold")
	expect(c.participants[principal].character_id==a.id and Hearth20Assets.read_asset(c,a.png_asset_id,"token")==png,"identity and PNG persisted in campaign")
	expect(Hearth20JoinCharacter.submit(c,principal,{"name":"Duplicate"},png).existing and c.actors.size()==1,"returning player cannot duplicate token")
	a.in_inventory=false;a.position=Vector2(2.5,2.5)
	var hidden=Hearth20TokenInventory.new_actor("PRIVATE GM TOKEN",false,scene,Vector2(3.5,3.5));hidden.id="private-token";hidden.layer="gm";c.actors.append(hidden);c.dm_notes="PRIVATE DM NOTES"
	scene.dynamic_lighting=true;scene.ambient_light="dark"
	scene.annotations=[{"id":"source","kind":"light","layer":"light","owner":"dm-local","points":[Vector2(5,4)],"bright":20,"dim":20,"enabled":true,"color":"#ffcd8e"}]
	var ordinary=Hearth20Vision.build_view(c,principal,scene)
	expect(Hearth20Vision.visible(Vector2(22,14),ordinary),"common map view does not depend on a character sight radius")
	a.vision={"enabled":true,"darkvision_feet":300};a.conditions=["Blinded"]
	var changed=Hearth20Vision.build_view(c,principal,scene)
	expect(ordinary.levels==changed.levels and ordinary.observers.is_empty(),"sheet senses and conditions cannot change common vision")
	expect(Hearth20Lighting.project_field(ordinary)==Hearth20Lighting.project_field(Hearth20Vision.build_view(c,"dm-local",scene)),"DM and player environmental light fields are identical")
	var projected=Hearth20Contracts.project_for_player(c,principal,PackedByteArray())
	expect(not JSON.stringify(projected).contains("PRIVATE") and projected.actors.size()==1,"common light never exposes GM layer or notes")
	expect(projected.sheets.size()==1 and not projected.sheets[0].has("abilities") and not projected.sheets[0].has("coins"),"only pawn identity belongs in player sheet metadata")
	scene.fog_rects=[Rect2(8,8,4,4)]
	var fog=Hearth20Vision.build_view(c,principal,scene);expect(not Hearth20Vision.visible(Vector2(9,9),fog) and Hearth20Vision.visible(Vector2(2,2),fog),"explicit DM masks remain private")
	scene.blackout=true;var blackout=Hearth20Contracts.project_for_player(c,principal,PackedByteArray())
	expect(blackout.scene.id=="blackout" and blackout.actors.is_empty() and blackout.fx.is_empty() and blackout.assets.is_empty(),"top map cover redacts all board contents")
	a.erase("vision");a.erase("conditions");scene.blackout=false;scene.annotations=[]
	var saved=Hearth20Identity.save_campaign(c,Hearth20Identity.SAVE_ROOT+"/beyond-core."+Hearth20Identity.SAVE_EXTENSION);var loaded=Hearth20Identity.load_campaign(Hearth20Identity.SAVE_ROOT+"/beyond-core."+Hearth20Identity.SAVE_EXTENSION)
	expect(saved.ok and loaded.ok and Hearth20JoinCharacter.current(loaded.campaign,principal).id==a.id,"save/reopen keeps player token mapping")
	var foreign=c.duplicate(true);foreign.edition="hearth20";expect(not Hearth20Identity.validate_campaign(foreign).ok,"original edition cannot be mistaken for fork campaign")
	expect(Hearth20BeyondSheet.valid_url("https://www.dndbeyond.com/characters/123") and not Hearth20BeyondSheet.valid_url("https://www.dndbeyond.com.evil.test/characters/123") and not Hearth20BeyondSheet.valid_url("file:///private"),"browser entry accepts D&D Beyond HTTPS only")
	print("Beyond core: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
