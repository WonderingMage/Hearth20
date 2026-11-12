extends SceneTree
class BoardFixture extends Hearth20BoardCanvas:
	func _ready() -> void:set_process(false)
	func _draw() -> void:pass
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func run() -> void:
	var fixture=OS.get_environment("H20_MAP_FIXTURES")
	if fixture.is_empty():fixture=ProjectSettings.globalize_path("res://../qa/map-packages/fixtures")
	var valid=fixture.path_join("lantern-larch.hearth20map")
	var c=Hearth20Identity.new_campaign();var s=Hearth20Session.new();root.add_child(s);s.configure(c)
	var hero=Hearth20TokenInventory.new_actor("Stored hero",true,c.scenes[0],Vector2(2.5,2.5));hero.in_inventory=true;hero.owner_player_id="pilot";hero.movement_policy=Hearth20Contracts.default_movement_policy("free_until_revoked",["pilot"]);c.actors.append(hero)
	var before=var_to_bytes(c)
	expect(not s.import_map_package(fixture.path_join("bad-sha.hearth20map")).ok and var_to_bytes(c)==before,"rejected import keeps the starter and all campaign data")
	expect(s.import_map_package(valid).ok and c.scenes.size()==1 and c.scenes[0].id!="scene-start","successful import discards the unused starter")
	var stored=Hearth20Contracts.find_actor(c,hero.id)
	expect(stored.in_inventory and stored.scene_id==c.active_scene and stored.owner_player_id=="pilot" and stored.movement_policy.controllers==["pilot"],"stored tokens survive starter cleanup with ownership and inventory state")
	expect(Hearth20Contracts.validate_campaign(c).ok,"starter cleanup leaves no dangling scene references")
	expect(s.import_map_package(valid).ok and c.scenes.size()==2,"later imports retain real previously loaded maps")
	var old=Hearth20Identity.new_campaign().scenes[0].duplicate(true);c.scenes.append(old)
	s.configure(c);expect(Hearth20Contracts.find_scene(c,"scene-start").is_empty(),"reopening a legacy campaign cleans its unused starter")
	for kind in ["drawing","npc","named"]:
		var authored=Hearth20Identity.new_campaign()
		if kind=="drawing":authored.scenes[0].annotations=[{"id":"work","kind":"rectangle","owner":"dm-local","layer":"tokens","points":[Vector2(1,1),Vector2(2,2)],"color":"#ffffff","width":2.}]
		elif kind=="npc":authored.actors.append(Hearth20TokenInventory.new_actor("Guard",false,authored.scenes[0],Vector2(1.5,1.5)))
		else:authored.scenes[0].title="My blank encounter"
		s.configure(authored)
		expect(s.import_map_package(valid).ok and authored.scenes.size()==2 and not Hearth20Contracts.find_scene(authored,"scene-start").is_empty(),"import preserves an authored starter with "+kind)
	var sample=Hearth20Identity.new_campaign();s.configure(sample)
	expect(s.load_sample_map("lantern-larch-inn").ok and sample.scenes.size()==1 and sample.scenes[0].id!="scene-start","sample-library import also removes the unused starter")
	var image_campaign=Hearth20Identity.new_campaign();s.configure(image_campaign)
	var board=BoardFixture.new();root.add_child(board);board.set_campaign(image_campaign,s,"dm")
	expect(board.import_map(fixture.path_join("assets/map.png")).ok and image_campaign.scenes.size()==1 and image_campaign.scenes[0].title=="map","ordinary image import names its initial tab after the file")
	board.queue_free();s.queue_free();await create_timer(.2).timeout
	print("Map starter cleanup: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
