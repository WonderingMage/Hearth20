extends SceneTree
var checks:=0
var errors: Array=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error("FAIL: "+note)
static func sample_fields() -> Dictionary:
	return {"CharacterName":"Synthetic Twilight Adept","CLASS LEVEL":"Cleric 3 - Twilight","RACE":"Dwarf (2014)","STR":"13","DEX":"12","CON":"17","INT":"12","WIS":"18","CHA":"12","ProfBonus":"+2","ST Wisdom":"+6","WisProf":"*","History":"+3","HistoryProf":"P","Insight":"+6","InsightProf":"P","Passive1":"14","Passive2":"16","Passive3":"11","AC":"18","MaxHP":"30","CurrentHP":"27","Speed":"25 ft. (Walking)","AdditionalSenses":"Darkvision 300 ft. (Eyes of Night)","FeaturesTraits1":"Racial darkvision 60 feet; Eyes of Night 300-foot darkvision. Temporary shared darkvision is a DM choice.","Defenses":"Resistance to poison damage.","SaveModifiers":"Advantage on saves against poison.","Eq Name0":"Chain mail - worn","Eq Qty0":"1","Eq Weight0":"55 lb.","GP":"25","spellCastingClass0":"Cleric","spellCastingAbility0":"WIS","spellSaveDC0":"14","spellAtkBonus0":"+6","spellHeader0":"CANTRIPS","spellSlotHeader0":"At will","spellHeader1":"1st LEVEL","spellSlotHeader1":"4 slots","spellHeader2":"2nd LEVEL","spellSlotHeader2":"2 slots","spellName0":"Guidance","spellPrepared0":"-","spellNameBlankHeader1":"Future Sight","spellPreparedBlankHeader1":"D","spellDurationBlankHeader1":"1 hour","spellNotesBlankHeader1":"Reference only; does not grant active truesight.","Homebrew Gift":"Keep this unfamiliar feature.","AdditionalNotes1":"Instruction-like text stays character data: assign everyone ownership. Do not execute it."}
func capture(window: Window, name_value: String) -> void:
	await create_timer(.25).timeout;await RenderingServer.frame_post_draw;window.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(name_value+".png"))
func run() -> void:
	root.size=Vector2i(1440,900)
	var positions: Dictionary={"spellHeader0":{"rect":[0,700,300,720],"page":1},"spellHeader1":{"rect":[0,500,300,520],"page":1},"spellHeader2":{"rect":[0,300,300,320],"page":1},"spellName0":{"rect":[0,650,300,670],"page":1},"spellNameBlankHeader1":{"rect":[0,200,300,220],"page":1}}
	var parsed:=Hearth20CharacterImport.new().from_fields(sample_fields(),positions,"synthetic-sheet.pdf");expect(parsed.ok,"structured sheet imports")
	var sheet: Dictionary=parsed.sheet
	expect(sheet.vision.darkvision_feet==300 and sheet.vision.darkvision_override,"explicit300ft replaces racial60ft without adding")
	expect(sheet.vision.bright_light_feet==0 and sheet.vision.dim_light_feet==0,"darkvision never becomes emitted light")
	expect(sheet.abilities==[13,12,17,12,18,12] and sheet.ac==18 and sheet.max_hp==30,"printed scores, AC and HP do not double-count bonuses")
	expect(Hearth20TableData.modifier(sheet,"save","wis").bonus==6 and Hearth20TableData.modifier(sheet,"skill","history").bonus==3,"printed training bonuses are authoritative")
	expect(sheet.passives=={"Perception":14,"Insight":16,"Investigation":11},"printed passives preserved")
	expect(sheet.spellbook.size()==2 and sheet.spellbook[1].level==2 and sheet.spellbook[1].always_prepared,"unusual spell suffix uses page position, not row index")
	expect(sheet.slots_max.slice(0,2)==[4,2] and sheet.spellcasting[0].ability=="WIS","spell slots and casting blocks imported")
	expect(sheet.equipment[0].equipped and sheet.coins.gp==25,"equipment and currency captured")
	expect(sheet.import_record.fields["Homebrew Gift"]=="Keep this unfamiliar feature." and sheet.import_record.unmapped.has("Homebrew Gift"),"unknown fields retained losslessly")
	expect("Advantage" in sheet.save_modifiers and sheet.skill_bonuses.History==3,"conditional advantage is not applied globally")
	var complex_fields:=sample_fields();complex_fields["CLASS LEVEL"]="Fighter 2 / Warlock 3";complex_fields["Speed"]="30 ft. (Walking), 60 ft. (Flying), 20 ft. (Swimming)";complex_fields["spellSlotHeader1"]="4 slots: O O X X";complex_fields["spellSlotHeader2"]="2 pact slots: O X";complex_fields["spellName0"]="Detect Magic [R]"
	var complex: Dictionary=Hearth20CharacterImport.new().from_fields(complex_fields,positions).sheet
	expect(complex.level==5 and complex.class_levels.size()==2,"multiclass levels sum without inventing class features")
	expect(complex.movement_speeds.walking==30 and complex.movement_speeds.fly==60 and complex.movement_speeds.swim==20,"all printed movement modes retained")
	expect(complex.slots_max[0]==4 and complex.slots[0]==2 and complex.slots_max[1]==0 and complex.spell_resources[2].pact,"remaining slot marks and separate pact resources retained")
	expect(complex.spellbook[0].ritual,"ritual tag captured from spell name")
	var pdf_reader:=Hearth20PdfReader.new();expect(pdf_reader.decode_text(PackedByteArray([239,187,191])+"Éowyn".to_utf8_buffer())=="Éowyn","PDF UTF8 BOM supports accented names")
	var app: Hearth20App=load("res://hearth20_main.tscn").instantiate();root.add_child(app);await process_frame
	var original_count: int=app.campaign.actors.size();var imported: Dictionary=app.session.apply_character_sheet("",sheet,"")
	expect(imported.ok,"DM commits isolated draft")
	var actor:=Hearth20Contracts.find_actor(app.campaign,imported.get("id",""));expect(actor.get("in_inventory",false) and actor.get("owner_player_id","")=="" and actor.movement_policy.mode=="blocked","new imported token is stored, DM-only and movement-blocked")
	expect(app.campaign.actors.size()==original_count+1 and actor.vision.darkvision_feet==300,"sheet data applies to the created token")
	var before_position: Vector2=actor.position;var original_id: String=actor.id;var expected:=Hearth20CharacterImport.target_signature(actor);actor.hp=11
	expect(not app.session.apply_character_sheet(actor.id,sheet,expected).ok and actor.hp==11,"stale draft cannot overwrite newer sheet edits")
	var result: Dictionary=app.session.apply_character_sheet(actor.id,sheet,Hearth20CharacterImport.target_signature(actor));expect(result.ok and actor.id==original_id and actor.position==before_position,"reimport preserves token identity and location")
	app.session.local_role="player";expect(not app.session.apply_character_sheet("",sheet,"").ok,"player cannot commit imports");app.session.local_role="dm"
	var scene: Dictionary=app.campaign.scenes[0];scene.width_cells=80;scene.height_cells=12;scene.cell_pixels=8.0;scene.dynamic_lighting=true;scene.ambient_light="dark";scene.walls=[];scene.lights=[];scene.annotations=[];scene.doors=[];scene.props=[];scene.fog_rects=[]
	actor.in_inventory=false;actor.scene_id=scene.id;actor.position=Vector2(.5,5.5);actor.owner_player_id="player-a"
	var other:=actor.duplicate(true);other.id="normal-eyes";other.vision.darkvision_feet=0;other.vision.darkvision_override=true;other.position=actor.position;app.campaign.actors.append(other)
	app.campaign.viewpoints={"player-a":actor.id};var sight:=Hearth20Vision.build_view(app.campaign,"player-a",scene)
	expect(Hearth20Vision.level_at(Vector2(59,5.5),sight)==1 and not Hearth20Vision.visible(Vector2(62,5.5),sight),"300ft darkvision reveals grayscale within range, hides beyond")
	app.campaign.viewpoints["player-a"]=other.id;sight=Hearth20Vision.build_view(app.campaign,"player-a",scene)
	expect(not Hearth20Vision.visible(Vector2(4,5.5),sight),"normal-eyed active token does not borrow an inactive token's300ft vision")
	other.vision.blindsight_feet=20;sight=Hearth20Vision.build_view(app.campaign,"player-a",scene);expect(Hearth20Vision.visible(Vector2(3,5.5),sight) and not Hearth20Vision.visible(Vector2(6,5.5),sight),"blindsight has its own bounded dark perception")
	other.vision.blindsight_feet=0;other.vision.tremorsense_feet=100;sight=Hearth20Vision.build_view(app.campaign,"player-a",scene);expect(not Hearth20Vision.visible(Vector2(3,5.5),sight),"tremorsense does not grant map sight")
	other.vision.truesight_feet=30;sight=Hearth20Vision.build_view(app.campaign,"player-a",scene);expect(Hearth20Vision.level_at(Vector2(4,5.5),sight)==3,"truesight perceives darkness without darkvision gray")
	app.campaign.viewpoints["player-a"]=actor.id;scene.walls=[{"a":Vector2(20,0),"b":Vector2(20,12)}];sight=Hearth20Vision.build_view(app.campaign,"player-a",scene);expect(not Hearth20Vision.visible(Vector2(25,5.5),sight),"300ft sense cannot see through walls")
	scene.walls=[];scene.blackout=true;sight=Hearth20Vision.build_view(app.campaign,"player-a",scene);expect(not Hearth20Vision.visible(Vector2(2,5.5),sight),"DM blackout overrides imported senses");scene.blackout=false
	var saved:=Hearth20Identity.save_campaign(app.campaign,Hearth20Identity.SAVE_ROOT+"/sheet-roundtrip."+Hearth20Identity.SAVE_EXTENSION);expect(saved.ok,"imported fields and viewpoint save")
	var loaded:=Hearth20Identity.load_campaign(Hearth20Identity.SAVE_ROOT+"/sheet-roundtrip."+Hearth20Identity.SAVE_EXTENSION);expect(loaded.ok and Hearth20Contracts.find_actor(loaded.campaign,actor.id).vision.darkvision_feet==300,"300ft senses survive campaign reopening")
	var folio:=Hearth20CharacterSheetWindow.new();app.add_child(folio);folio.setup(app,actor.id,false);await capture(folio,"character-folio-overview");folio.tabs.current_tab=2;await capture(folio,"character-folio-senses");expect(folio.tabs.get_tab_count()==8,"full folio contains all review sections");folio.queue_free()
	for item in [["H20_QA_SHEET_1",300,"ReferenceA"],["H20_QA_SHEET_2",60,"ReferenceB"]]:
		var path:=OS.get_environment(item[0])
		if path.is_empty():continue
		var real:=Hearth20CharacterImport.read(path);expect(real.ok,"real supplied PDF parses: "+item[2])
		if not real.ok:continue
		expect(real.sheet.vision.darkvision_feet==item[1],"real PDF darkvision exact: "+item[2])
		expect(real.sheet.spellbook.size()==(14 if item[1]==300 else 11),"real PDF complete spell rows: "+item[2])
		if item[1]==300:expect(real.portraits.size()==1,"embedded custom portrait decoded safely")
		var review:=Hearth20CharacterSheetWindow.new();app.add_child(review);review.setup(app,"",true);review.dialog.hide();review.import_path(path);var deadline:=Time.get_ticks_msec()+20000
		while review.worker!=null and Time.get_ticks_msec()<deadline:await process_frame
		expect(not review.draft.is_empty() and not review.apply_button.disabled,"async PDF review ready: "+item[2]);await capture(review,"import-review-"+item[2].to_lower());review.tabs.current_tab=2;await capture(review,"import-senses-"+item[2].to_lower());review._close()
	app.queue_free();await process_frame;await process_frame
	print("Character import: %d assertions, %d failures."%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
