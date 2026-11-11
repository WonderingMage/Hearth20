extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func run() -> void:
	var c=Hearth20Identity.new_campaign("Map tab campaign")
	for index in 3:
		var scene=c.scenes[0].duplicate(true);scene.id="other-"+str(index);scene.title="Secret map "+str(index);scene.width_cells=12;scene.height_cells=10;scene.library_entry=[{"x":2.5,"y":2.5}];c.scenes.append(scene)
	for index in 7:
		var hero=Hearth20TokenInventory.new_actor("Hero "+str(index),true,c.scenes[0],Vector2(1.5+index,2.5));hero.owner_player_id="pilot";hero.movement_policy=Hearth20Contracts.default_movement_policy("free_until_revoked",["pilot"])
		if index==6:hero.in_inventory=true
		c.actors.append(hero)
	var npc=Hearth20TokenInventory.new_actor("NPC",false,c.scenes[0],Vector2(2.5,4.5));c.actors.append(npc)
	var s=Hearth20Session.new();root.add_child(s);s.configure(c)
	expect(s.set_blackout(true).ok and c.map_covered,"cover is recorded at campaign level")
	for scene in c.scenes:
		expect(s.switch_library_scene(scene.id,false).ok,"DM can switch to loaded map "+scene.id)
		var snapshot=s._project_for("pilot")
		expect(snapshot.scene.id=="blackout" and snapshot.map_png.is_empty() and snapshot.actors.is_empty(),"every loaded map remains concealed")
		expect(not JSON.stringify(snapshot).contains("Secret map"),"covered navigation does not leak map names")
	expect(s.switch_library_scene("other-1",true,true).ok,"right-click action can bring all heroes to its target map")
	var heroes=c.actors.filter(func(a):return a.is_hero)
	var positions=[]
	for hero in heroes:
		expect(hero.scene_id=="other-1" and not hero.in_inventory,"all heroes, including stowed heroes, reach the chosen map")
		expect(hero.owner_player_id=="pilot" and hero.movement_policy.controllers==["pilot"],"moving maps never grants or revokes ownership")
		expect(fposmod(hero.position.x,1.)==.5 and fposmod(hero.position.y,1.)==.5 and not positions.has(hero.position),"hero placement uses distinct square centers")
		positions.append(hero.position)
	expect(npc.scene_id=="scene-start","NPCs remain on their original map")
	expect(c.map_covered and s._project_for("pilot").scene.id=="blackout","bringing heroes never uncovers the map")
	var path=Hearth20Identity.SAVE_ROOT.path_join("covered-map-tabs.h20scampaign")
	expect(Hearth20Identity.save_campaign(c,path).ok,"covered campaign can be saved")
	var loaded=Hearth20Identity.load_campaign(path);expect(loaded.ok and loaded.campaign.map_covered,"cover remains on after reopening the campaign")
	expect(s.set_blackout(false).ok and c.scenes.all(func(scene):return not scene.blackout),"Reveal clears the cover across all maps")
	expect(s._project_for("pilot").scene.id!="blackout","players see the active map only after explicit reveal")
	var before=var_to_bytes(c);s.local_role="player"
	expect(not s.switch_library_scene("other-2",true,true).ok and not s.set_blackout(false).ok and var_to_bytes(c)==before,"players cannot navigate DM tabs, move the party or uncover maps")
	s.queue_free();await process_frame
	print("Map navigation: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)
