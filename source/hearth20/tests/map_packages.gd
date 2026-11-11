extends SceneTree
var checks=0
var errors=[]
var fixture=""
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func run() -> void:
	fixture=OS.get_environment("H20_MAP_FIXTURES")
	if fixture.is_empty():fixture=ProjectSettings.globalize_path("res://../qa/map-packages/fixtures")
	var valid=fixture.path_join("lantern-larch.hearth20map")
	var package=Hearth20MapPackage.read(valid)
	expect(package.ok,"a complete Python-authored map package is readable")
	if not package.ok:push_error(str(package));quit(1);return
	expect(package.scene.width_cells==32 and package.scene.height_cells==24,"grid comes from the manifest without manual calibration")
	expect(package.scene.annotations.filter(func(o):return o.kind=="wall").size()==12,"all traced walls are installed as editable blockers")
	expect(package.scene.annotations.filter(func(o):return o.kind=="light").size()==4 and package.foreground.size()==1,"light sources and foreground art are loaded")
	expect(package.scene.annotations.filter(func(o):return o.kind=="window").size()==3 and package.scene.annotations.filter(func(o):return o.kind=="door").size()==3,"window apertures and door states survive parsing")
	var campaign=Hearth20Identity.new_campaign("Package import test")
	var session=Hearth20Session.new();root.add_child(session);session.configure(campaign)
	var hero=Hearth20TokenInventory.new_actor("Owned hero",true,campaign.scenes[0],Vector2(2.5,2.5));hero.owner_player_id="pilot";hero.movement_policy=Hearth20Contracts.default_movement_policy("free_until_revoked",["pilot"]);campaign.actors.append(hero)
	session.set_blackout(true)
	var result=session.import_map_package(valid)
	expect(result.ok and campaign.scenes.size()==2,"import adds a new scene and retains the current campaign")
	var scene=Hearth20Contracts.find_scene(campaign,campaign.active_scene)
	expect(scene.blackout and campaign.map_covered,"an imported map stays concealed while the table cover is on")
	expect(Hearth20Contracts.find_actor(campaign,hero.id).scene_id==scene.id and Hearth20Contracts.find_actor(campaign,hero.id).movement_policy.controllers==["pilot"],"party placement keeps identity and control grants")
	var concealed=session._project_for("pilot")
	expect(concealed.scene.id=="blackout" and concealed.map_png.is_empty() and concealed.actors.is_empty(),"new map assets are never disclosed while covered")
	session.set_blackout(false)
	var decorative: Dictionary=campaign.actors.filter(func(a):return a.get("decorative",false))[0]
	expect(decorative.display_width_cells==2.5 and decorative.rotation_degrees==18.,"foreground retains independent size and orientation")
	expect(not Hearth20Assets.read_asset(campaign,decorative.png_asset_id,"token").is_empty(),"foreground image is stored inside the campaign")
	var lighting=Hearth20Vision.build_view(campaign,"pilot",scene)
	expect(lighting.lights.filter(func(light):return light.has("portal")).size()==3,"window light sources pair with their explicit apertures")
	var outdoor=scene.duplicate(true);outdoor.outdoor=true;outdoor.roof_rects=[{"x":5,"y":5,"width":3,"height":3}]
	outdoor.annotations.append({"id":"sky","owner":"dm-local","kind":"light","layer":"light","points":[Vector2(1,1)],"source_type":"sunlight","bright":1000,"dim":0,"light_color":"#ffe5ae"})
	var field=Hearth20Vision.build_view(campaign,"pilot",outdoor,false)
	expect(field.lights.any(func(light):return light.has("parallel") and light.parallel.roofs==[Rect2(5,5,3,3)]),"custom outdoor maps use their own roof masks instead of built-in map IDs")
	var saved=Hearth20Identity.SAVE_ROOT.path_join("map-package-test.h20scampaign")
	expect(Hearth20Identity.save_campaign(campaign,saved).ok,"self-contained imported map saves")
	var loaded=Hearth20Identity.load_campaign(saved)
	expect(loaded.ok and loaded.campaign.scenes.size()==2 and loaded.campaign.actors.filter(func(a):return a.get("decorative",false))[0].rotation_degrees==18.,"saved walls, lights, foreground and geometry round-trip")
	var prior=var_to_bytes(campaign)
	for name in ["bad-sha","bad-grid","bad-wall","bad-light","bad-window-id","bad-foreground","bad-id","bad-entry","unknown-field","path-traversal","unreferenced","compressed","duplicate","truncated","bad-directory"]:
		var failed=session.import_map_package(fixture.path_join(name+".hearth20map"))
		expect(not failed.ok,"bad package is rejected: "+name)
		expect(var_to_bytes(campaign)==prior,"bad package cannot partially change the campaign: "+name)
	session.local_role="player";expect(not session.import_map_package(valid).ok,"players cannot import packages")
	session.queue_free();await process_frame
	print("Map packages: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)
