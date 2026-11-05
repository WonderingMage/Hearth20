extends SceneTree
const Identity = preload("res://hearth20/identity.gd")
const Contracts = preload("res://hearth20/contracts.gd")
const Vision = preload("res://hearth20/vision.gd")
const TableData = preload("res://hearth20/table_data.gd")
var checks := 0
var failures: Array[String] = []
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var c := Identity.new_campaign("Independent roll and vision fixture")
	var s: Dictionary = c.scenes[0]
	s.width_cells = 24; s.height_cells = 16; s.cell_pixels = 8.0; s.feet_per_cell = 5.0
	s.dynamic_lighting = true; s.ambient_light = "dark"; s.blackout = false
	s.doors = [{"id":"door-secret","a":Vector2(4.5,0),"b":Vector2(4.5,5),"open":false,"hidden":false}]
	var hero_a := {"id":"hero-a","name":"Private Hero A","is_hero":true,"owner_player_id":"player-a","scene_id":s.id,"position":Vector2(2,2),"hidden":false,"abilities":[16,14,12,10,10,10],"prof_bonus":3,"skills":{"Acrobatics":1},"hp":31,"ac":17,"notes":"A's private notes","vision":{"enabled":true,"darkvision_feet":60.0,"bright_light_feet":10.0,"dim_light_feet":20.0}}
	var hero_b := {"id":"hero-b","name":"Private Hero B","is_hero":true,"owner_player_id":"player-b","scene_id":s.id,"position":Vector2(2.5,2),"hidden":false,"abilities":[8,10,10,10,10,10],"hp":25,"ac":15,"notes":"B's private notes","vision":{"enabled":true,"darkvision_feet":0.0,"bright_light_feet":0.0,"dim_light_feet":0.0}}
	var enemy := {"id":"enemy-secret","name":"Hidden Wraith","is_hero":false,"owner_player_id":"","scene_id":s.id,"position":Vector2(8,2),"hidden":false,"hp":99,"ac":23,"initiative":19,"private_notes":"never expose"}
	c.actors = [hero_a,hero_b,enemy]
	var context_a := Vision.build_view(c,"player-a",s)
	var context_b := Vision.build_view(c,"player-b",s)
	expect(Vision.visible(Vector2(3,2),context_a),"shared torch bright radius is visible to owner")
	expect(Vision.level_at(Vector2(3.5,2),context_b)==3,"a teammate's bright light is visible to another player's hero")
	expect(Vision.level_at(Vector2(4.2,2),context_b)==2,"shared torch's additional dim radius stays dim")
	expect(Vision.level_at(Vector2(7,2),context_b)==0,"light ends after bright and dim radii for a hero without darkvision")
	s.doors[0].open=true; var open_for_range := Vision.build_view(c,"player-a",s); expect(Vision.level_at(Vector2(13.8,2),open_for_range)>0,"darkvision sees within 60 feet in darkness"); s.doors[0].open=false
	expect(Vision.level_at(Vector2(14.5,2),context_a)==0,"darkvision does not see beyond 60 feet")
	expect(not Vision.clear_line(Vector2(2,2),Vector2(8,2),context_a),"closed door blocks vision line")
	var thin_shadow_scene := s.duplicate(true)
	thin_shadow_scene.doors = []
	thin_shadow_scene.walls = [{"a":Vector2(4.99,2.01),"b":Vector2(4.99,2.24)}]
	var thin_shadow_campaign := c.duplicate(true)
	thin_shadow_campaign.scenes[0] = thin_shadow_scene
	var thin_shadow_view := Vision.build_view(thin_shadow_campaign,"player-a",thin_shadow_scene)
	var tiny_target := Rect2(Vector2(5.0,2.0),Vector2(0.25,0.25))
	expect(not Vision.clear_area(Vector2(2,2),tiny_target,thin_shadow_view),"thin short wall blocks the whole tiny target region through convex shadow test")
	expect(Vision.block_level(tiny_target,thin_shadow_view)==0,"tiny region fully behind thin wall receives no vision level")
	var projection_a := Contracts.project_for_player(c,"player-a",PackedByteArray())
	var enemy_ids_a: Array = projection_a.actors.map(func(a): return a.get("id",""))
	expect(not enemy_ids_a.any(func(id): return id=="enemy-secret"),"closed door visibility prevents enemy details reaching player A")
	var owned_a: Dictionary = projection_a.sheets.filter(func(sheet): return sheet.id=="hero-a")[0]
	expect(owned_a.name=="Private Hero A" and owned_a.hp==31 and owned_a.notes=="A's private notes","player A receives their own full allowlisted sheet")
	expect(projection_a.sheets.size()==1 and not JSON.stringify(projection_a.sheets).contains("Private Hero B"),"player A does not receive player B's sheet")
	var projection_b := Contracts.project_for_player(c,"player-b",PackedByteArray())
	expect(projection_b.sheets.size()==1 and projection_b.sheets[0].id=="hero-b" and not JSON.stringify(projection_b.sheets).contains("A's private notes"),"player B receives only B's sheet")
	expect(not JSON.stringify(projection_b.actors).contains("Hidden Wraith") and not JSON.stringify(projection_b.actors).contains("enemy-secret"),"concealed or occluded identities are absent from B's actor snapshot")
	s.doors[0].open=true
	var open_context := Vision.build_view(c,"player-a",s)
	expect(Vision.clear_line(Vector2(2,2),Vector2(8,2),open_context),"opening a door clears the vision obstruction")
	var visible_projection := Contracts.project_for_player(c,"player-a",PackedByteArray())
	expect(visible_projection.actors.any(func(a): return str(a.get("id","")).begins_with("token-") and a.get("kind","")=="token"),"visible non-owned NPC is projected with a neutral public identity")
	expect(not JSON.stringify(visible_projection.actors).contains("enemy-secret") and not JSON.stringify(visible_projection.actors).contains("Hidden Wraith"),"visible enemy still has no internal identity or name")
	s.blackout=true
	var blackout := Contracts.project_for_player(c,"player-a",PackedByteArray())
	expect(blackout.actors.is_empty() and blackout.vision_mask.is_empty() and blackout.sheets.size()==1,"blackout removes board actors and mask while keeping the owner's sheet")
	var bad_settings := Vision.valid_settings({"enabled":true,"darkvision_feet":1001.0,"bright_light_feet":0.0,"dim_light_feet":0.0})
	expect(not bad_settings,"vision settings reject range above one thousand feet")
	var bad_nan := Vision.valid_settings({"enabled":true,"darkvision_feet":NAN,"bright_light_feet":0.0,"dim_light_feet":0.0})
	expect(not bad_nan,"vision settings reject NaN ranges")
	var concealed_light_campaign := c.duplicate(true)
	concealed_light_campaign.scenes[0].blackout=false
	concealed_light_campaign.actors[0].vision = {"enabled":true,"darkvision_feet":0.0,"bright_light_feet":0.0,"dim_light_feet":0.0}
	concealed_light_campaign.actors[1].vision = {"enabled":true,"darkvision_feet":0.0,"bright_light_feet":0.0,"dim_light_feet":0.0}
	concealed_light_campaign.actors[2].position = Vector2(12,2)
	concealed_light_campaign.actors[2].hidden = true
	concealed_light_campaign.actors[2].vision = {"enabled":false,"darkvision_feet":0.0,"bright_light_feet":10.0,"dim_light_feet":20.0}
	concealed_light_campaign.scenes[0].doors[0].open = true
	var hidden_light_view := Vision.build_view(concealed_light_campaign,"player-b",concealed_light_campaign.scenes[0])
	expect(Vision.level_at(Vector2(11,2),hidden_light_view)==0,"concealed NPC light does not reveal the map to a player")
	var actor := {"abilities":[16,14,12,10,10,10],"prof_bonus":3,"skills":{"Acrobatics":1}}
	var dex := TableData.roll(actor,"ability","dex","normal","1d20",_seeded_rng(7))
	expect(dex.ok and dex.modifier==2 and dex.formula=="1d20+2" and dex.total==int(dex.dice[0])+2,"ability modifier and total are host-calculated")
	var acrobatics := TableData.roll(actor,"skill","Acrobatics","normal","1d20",_seeded_rng(7))
	expect(acrobatics.ok and acrobatics.modifier==5 and acrobatics.formula=="1d20+5","skill bonus adds proficiency from the owner sheet")
	expect(not TableData.roll(actor,"dice","","normal","1d1001",_seeded_rng(7)).ok,"oversized dice sides are rejected")
	expect(not TableData.roll(actor,"dice","","advantage","2d6",_seeded_rng(7)).ok,"advantage is bounded to a single d20")
	var saves_upper := {"abilities":[16,14,12,10,10,10],"prof_bonus":3,"save_bonuses":{"DEX":8}}
	var saves_lower := {"abilities":[16,14,12,10,10,10],"prof_bonus":3,"save_bonuses":{"dex":6}}
	var save_fallback := {"abilities":[16,14,12,10,10,10],"prof_bonus":3,"save_profs":[1]}
	expect(TableData.modifier(saves_upper,"save","dex").bonus==8,"uppercase save bonus is retained")
	expect(TableData.modifier(saves_lower,"save","dex").bonus==6,"lowercase save bonus fallback is retained")
	expect(TableData.modifier(save_fallback,"save","dex").bonus==5,"save proficiency adds to the ability modifier")
	var expertise := {"abilities":[16,14,12,10,10,10],"prof_bonus":3,"skills":{"Acrobatics":2}}
	expect(TableData.modifier(expertise,"skill","acrobatics").bonus==8,"expertise applies double proficiency plus ability modifier")
	var initiative_override := {"abilities":[10,10,10,10,10,10],"initiative_bonus":4}
	expect(TableData.modifier(initiative_override,"initiative","").bonus==4,"recorded initiative bonus overrides default")
	expect(TableData.modifier(actor,"initiative","").bonus==2,"initiative falls back to Dexterity modifier")
	var malformed_sheet := {"abilities":"bad","save_bonuses":[]}
	expect(not TableData.modifier(malformed_sheet,"save","dex").ok,"malformed ability and save bonus fields fail closed")
	var safe_sheet := TableData.sheet({"id":"bad-sheet","name":"Broken","abilities":"bad","vision":"bad"})
	expect(safe_sheet.abilities.size()==6 and safe_sheet.vision.is_empty(),"owner sheet projection replaces malformed ability and vision fields with safe defaults")
	var bad_templates := s.duplicate(true)
	bad_templates.templates="bad"
	expect(not Contracts.valid_scene(bad_templates),"scene validator rejects templates with the wrong container type")
	var session_probe = preload("res://hearth20/session.gd").new()
	root.add_child(session_probe)
	session_probe.campaign=c.duplicate(true)
	session_probe.campaign.table_timeline=[{"type":"chat","visibility":"gm","text":"must not leak","recipients":"player-a"},{"type":"chat","visibility":"public","text":"public survives","recipients":null},{"type":"chat","visibility":"gm","text":"owner private","recipients":["player-a"]}]
	var sanitized_timeline: Array = session_probe._timeline_for("player-a")
	expect(sanitized_timeline.size()==2 and not JSON.stringify(sanitized_timeline).contains("must not leak") and JSON.stringify(sanitized_timeline).contains("owner private"),"malformed private recipient values cannot bypass timeline filtering")
	session_probe.campaign.handouts="bad"
	expect(session_probe._handouts_for("player-a").is_empty(),"malformed handout container projects no handouts")
	session_probe.campaign.handouts=["bad",{"id":7,"public":true,"title":{},"body":[]}]
	var safe_handouts: Array = session_probe._handouts_for("player-a")
	expect(safe_handouts.size()==1 and safe_handouts[0].title is String and safe_handouts[0].body is String and safe_handouts[0].title.length()<=96 and safe_handouts[0].body.length()<=12000,"malformed handout fields are safely bounded as text")
	session_probe.campaign=Identity.new_campaign("Independent persistence fixture")
	session_probe.local_role="dm"
	session_probe.campaign.actors=[{"id":"persist-hero","name":"Persist Hero","is_hero":true,"owner_player_id":"player-a","scene_id":session_probe.campaign.scenes[0].id,"position":Vector2(2,2),"hidden":false,"token_size":1.0,"abilities":[16,14,12,10,10,10],"hp":31,"max_hp":40,"vision":{"enabled":true,"darkvision_feet":60.0,"bright_light_feet":10.0,"dim_light_feet":20.0},"movement_policy":Contracts.default_movement_policy("blocked",["player-a"])}]
	var public_handout: Dictionary = session_probe.share_handout("Public note","Shared table note",true)
	var private_handout: Dictionary = session_probe.share_handout("Private note","DM secret",false)
	var area: Dictionary = session_probe.place_template("circle",Vector2(1,1),Vector2(4,1))
	var removed: Dictionary = session_probe.remove_template(str(area.get("id","")))
	var restored: Dictionary = session_probe.undo_template_removal()
	session_probe.campaign.table_timeline=[{"type":"chat","visibility":"public","text":"Persisted table history"}]
	var persist_path := Identity.SAVE_ROOT+"/roll-vision-independent.h20campaign"
	var saved: Dictionary = Identity.save_campaign(session_probe.campaign,persist_path)
	var reopened: Dictionary = Identity.load_campaign(persist_path)
	var reopened_campaign: Dictionary = reopened.get("campaign",{})
	if not saved.ok or not reopened.ok: print("Persistence diagnostic save=%s reopen=%s" % [str(saved.get("errors",[])),str(reopened.get("errors",[]))])
	expect(public_handout.ok and private_handout.ok and session_probe._handouts_for("player-a").size()==1,"public handout shares while a private DM note stays out of player projection")
	expect(area.ok and removed.ok and restored.ok and session_probe.campaign.scenes[0].templates.size()==1,"DM measured area removal and undo restore the original template")
	expect(saved.ok and reopened.ok,"campaign with table sheet data can save and reopen")
	var actor_roundtrip: Dictionary = reopened_campaign.get("actors",[])[0] if reopened.ok and reopened_campaign.get("actors",[]).size()>0 else {}
	print("Persistence actor roundtrip: %s" % str(actor_roundtrip))
	var restored_scores: Array = actor_roundtrip.get("abilities", [])
	expect(reopened.ok and int(actor_roundtrip.get("hp",-1))==31 and float(actor_roundtrip.get("vision",{}).get("darkvision_feet",-1.0))==60.0 and restored_scores.map(func(score): return int(score))==[16,14,12,10,10,10],"sheet stats and every ability score survive campaign save and reopen")
	expect(reopened.ok and reopened_campaign.get("handouts",[]).size()==2 and reopened_campaign.get("table_timeline",[]) is Array and reopened_campaign.scenes[0].templates.size()==1,"handouts, timeline and measured areas survive save and reopen")
	print("Independent roll/vision checks: %d assertions, %d failures." % [checks,failures.size()])
	quit(1 if not failures.is_empty() else 0)
func _seeded_rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new(); rng.seed=seed; return rng
