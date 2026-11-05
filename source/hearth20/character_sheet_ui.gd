extends Window
class_name Hearth20CharacterSheetWindow
var app: Hearth20App
var target_id: String=""
var expected: String=""
var draft: Dictionary={}
var editable:=false
var join_submission:=false
var custom_png:=PackedByteArray()
var png_dialog: FileDialog
var worker: Thread
var cancelled:=false
var view_revision:=-1
var title_label: Label
var status: Label
var tabs: TabContainer
var apply_button: Button
var file_button: Button
var edit_button: Button
var dialog: FileDialog
var portrait: TextureRect
var portraits: Array=[]
var use_portrait: CheckBox
var portrait_index:=-1
var fields: Dictionary={}
var spell_list: ItemList
var spell_detail: VBoxContainer
var visible_spells: Array=[]
func setup(owner_app: Hearth20App, actor_id: String, importing: bool) -> void:
	app=owner_app;target_id=actor_id;editable=importing;title="Hearth20 · Character folio";size=Vector2i(1240,870);min_size=Vector2i(980,680);theme=Hearth20Design.theme();close_requested.connect(_close)
	var actor:=_actor();expected=Hearth20CharacterImport.target_signature(actor)
	var background:=ColorRect.new();background.color=Hearth20Regal.swatch(Hearth20Regal.BG);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);margin.add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	title_label=_label("Import a character sheet" if editable else str(actor.get("name","Character")),30);title_label.add_theme_font_override("font",Hearth20Design.font(true));title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title_label)
	file_button=_button(header,"Choose PDF…",func():dialog.popup_centered_ratio(.8));file_button.visible=editable
	if editable:_button(header,"Token PNG…",func():png_dialog.popup_centered_ratio(.7))
	if not editable and app.session.local_role=="dm" and actor.has("import_record"):edit_button=_button(header,"Edit recorded sheet",_begin_edit)
	status=_label("Review a private draft, then apply it to "+str(actor.get("name","a new inventory token"))+". Player assignment and movement grants stay under DM control." if editable else "Your recorded sheet · values and conditional features are preserved as printed.",13);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	var footer:=HBoxContainer.new();footer.add_theme_constant_override("separation",12);column.add_child(footer)
	_button(footer,"Cancel" if editable else "Close",_close)
	var note:=_label("No campaign changes until Apply. Imported totals are not recalculated from equipment or class features." if editable else "Features remain DM-resolved; recorded senses drive the authorized board view.",12);note.size_flags_horizontal=Control.SIZE_EXPAND_FILL;note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;footer.add_child(note)
	apply_button=_button(footer,"Apply to token" if not target_id.is_empty() else "Create inventory character",_apply);apply_button.visible=editable;apply_button.disabled=true
	dialog=FileDialog.new();dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.current_dir=OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS);dialog.filters=PackedStringArray(["*.pdf ; D&D Beyond / character-sheet PDF"]);dialog.file_selected.connect(import_path);add_child(dialog)
	png_dialog=FileDialog.new();png_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;png_dialog.access=FileDialog.ACCESS_FILESYSTEM;png_dialog.filters=PackedStringArray(["*.png ; Character token PNG"]);png_dialog.file_selected.connect(_choose_png);add_child(png_dialog)
	if join_submission:
		transient=true;exclusive=true;title="Hearth20 · Bring your character";title_label.text="Bring your character to the table"
		status.text="Import your character sheet, review its gold and senses, and choose an optional token PNG. Your unique character goes to the DM's inventory at one-square size. Returning characters keep their saved purse."
		apply_button.text="Send character to DM inventory"
		app.session.character_submission_result.connect(_submission_result)
	if not editable:
		draft=actor.duplicate(true);_build()
	popup_centered()
	if editable:dialog.popup_centered_ratio(.8)
func _actor() -> Dictionary:
	if app.session.local_role=="dm":return Hearth20Contracts.find_actor(app.campaign,target_id)
	for actor in app.session.client_snapshot.get("sheets",[]):
		if str(actor.id)==target_id:return actor
	return {}
func import_path(path: String) -> void:
	if (app.session.local_role!="dm" and not join_submission) or worker!=null:return
	status.text="Reading the PDF's data fields… Your campaign is unchanged.";file_button.disabled=true;apply_button.disabled=true
	worker=Thread.new();worker.start(func():return Hearth20CharacterImport.read(path))
func _process(_delta: float) -> void:
	Hearth20Regal.sync(self)
	if app==null:return
	if editable and app.session.local_role!="dm" and not join_submission:_close();return
	if not editable:
		var actor:=_actor()
		if actor.is_empty():queue_free();return
		var revision_value: int=app.campaign.get("revision",0) if app.session.local_role=="dm" else app.session.client_snapshot.get("revision",0)
		if view_revision!=revision_value:
			view_revision=revision_value;var signature:=Hearth20CharacterImport.target_signature(actor)
			if signature!=expected:
				var page:=tabs.current_tab;draft=actor.duplicate(true);expected=signature;title_label.text=str(actor.get("name","Character"));_build();tabs.current_tab=clampi(page,0,tabs.get_tab_count()-1)
	if worker!=null and not worker.is_alive():
		var result: Dictionary=worker.wait_to_finish();worker=null;file_button.disabled=false
		if cancelled:queue_free();return
		if not result.get("ok",false):status.text=str(result.get("error","Unable to read the sheet."));return
		draft=result.sheet
		var existing:=_actor()
		for key in ["bright_light_feet","dim_light_feet"]:
			if existing.get("vision",{}).has(key):draft.vision[key]=existing.vision[key]
		portraits=result.get("portraits",[]);portrait_index=0 if not portraits.is_empty() else -1;title_label.text=str(draft.name);_build();apply_button.disabled=false
		status.text="%s · %d filled fields · %d spells · darkvision %d ft. %s"%[draft.import_record.filename,draft.import_record.field_count,draft.spellbook.size(),draft.vision.darkvision_feet,"Review notes on the Source tab." if not result.issues.is_empty() else "Ready for your review."]
func _close() -> void:
	if join_submission and not cancelled and app!=null and app.session.local_role=="player":
		cancelled=true;app.session.stop_session()
	if worker!=null and worker.is_alive():cancelled=true;hide();return
	if worker!=null:worker.wait_to_finish();worker=null
	queue_free()
func _choose_png(path: String) -> void:
	var image=Hearth20Assets.inspect_token_png(path)
	if not image.ok:status.text=str(image.error);return
	custom_png=image.bytes;status.text="Token appearance: "+path.get_file()+" · default size 1 square."
	if not draft.is_empty():var page=tabs.current_tab;_build();tabs.current_tab=page
func _submission_result(result: Dictionary) -> void:
	if not join_submission:return
	if result.get("ok",false):cancelled=true;_close()
	else:status.text=str(result.get("error","The host could not accept that character."));apply_button.disabled=false
func _label(text: String, size_value: int=14) -> Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size_value);label.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.INK));return label
func _button(parent: Node, text: String, action: Callable) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=38;button.pressed.connect(action);parent.add_child(button);return button
func _page(text: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.name=text;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",10);scroll.add_child(box);return box
func _heading(parent: Node, text: String) -> void:
	var label:=_label(text,19);label.add_theme_font_override("font",Hearth20Design.font(true));parent.add_child(label)
func _text(parent: Node, text: String) -> void:
	var label:=_label(text,13);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label)
func _line(parent: Node, title_value: String, value: String, setter: Callable) -> LineEdit:
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(box);box.add_child(_label(title_value,12));var line:=LineEdit.new();line.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.text=value;line.editable=editable and not join_submission;line.custom_minimum_size.y=36;line.text_changed.connect(setter);box.add_child(line);return line
func _number(parent: Node, title_value: String, value: float, setter: Callable, low: float=-1000, high: float=100000) -> SpinBox:
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(box);box.add_child(_label(title_value,12));var spin:=SpinBox.new();spin.min_value=low;spin.max_value=high;spin.value=value;spin.editable=editable and not join_submission;spin.custom_minimum_size.y=36;spin.value_changed.connect(setter);box.add_child(spin);return spin
func _memo(parent: Node, title_value: String, value: String, setter: Callable, height: int=170) -> TextEdit:
	parent.add_child(_label(title_value,13));var text:=TextEdit.new();text.text=value;text.editable=editable and not join_submission;text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;text.custom_minimum_size.y=height;text.text_changed.connect(func():setter.call(text.text));parent.add_child(text);return text
func _build() -> void:
	fields.clear()
	for child in tabs.get_children():tabs.remove_child(child);child.queue_free()
	var overview:=_page("Overview");_heading(overview,str(draft.get("name","Character")))
	var identity:=GridContainer.new();identity.columns=3;identity.add_theme_constant_override("h_separation",16);overview.add_child(identity)
	for spec in [["name","Character name"],["class","Classes / levels"],["subclass","Subclass"],["race","Species / ancestry"],["background","Background"],["rules_version","Rules edition"],["alignment","Alignment"],["size_category","Size"],["xp_text","Experience / milestone"]]:
		var key: String=spec[0];fields[key]=_line(identity,spec[1],str(draft.get(key,"")),func(value):draft[key]=value)
	var stats:=HBoxContainer.new();stats.add_theme_constant_override("separation",12);overview.add_child(stats)
	for spec in [["level","Level"],["ac","Armor class"],["hp","Current HP"],["max_hp","Max HP"],["temp","Temp HP"],["speed","Speed (ft.)"],["prof_bonus","Proficiency"]]:
		var key: String=spec[0];fields[key]=_number(stats,spec[1],float(draft.get(key,0)),func(value):draft[key]=int(value),0)
	_heading(overview,"Ability scores · printed totals")
	var scores:=HBoxContainer.new();scores.add_theme_constant_override("separation",12);overview.add_child(scores)
	for i in 6:fields[Hearth20TableData.ABILITIES[i]]=_number(scores,Hearth20TableData.ABILITIES[i].to_upper(),float(draft.get("abilities",[10,10,10,10,10,10])[i]),func(value):draft.abilities[i]=int(value),1,100)
	var details:=HBoxContainer.new();details.add_theme_constant_override("separation",12);overview.add_child(details)
	for spec in [["initiative_bonus","Initiative"],["hit_dice","Hit dice remaining"],["death_success","Death successes"],["death_failure","Death failures"],["exhaustion","Exhaustion"]]:
		var key: String=spec[0];_number(details,spec[1],float(draft.get(key,0)),func(value):draft[key]=int(value))
	_text(overview,"Movement: "+" · ".join(draft.get("movement_speeds",{}).keys().map(func(key):return str(key).capitalize()+" "+str(draft.movement_speeds[key])+" ft.")))
	_line(overview,"Printed hit-dice pools",str(draft.get("hit_dice_text","")),func(value):draft.hit_dice_text=value)
	_text(overview,"Equipment and racial/class bonuses are already included in the printed totals. They are retained without being added a second time.")
	_training();_senses();_features();_spells();_gear();_story();_source()
func _training() -> void:
	var page:=_page("Training");_heading(page,"Saving throws & skill totals")
	_text(page,"Printed bonuses stay authoritative. Conditional advantages, expertise and situational features remain visible for the DM to apply to the relevant roll.")
	var saves:=HBoxContainer.new();saves.add_theme_constant_override("separation",12);page.add_child(saves)
	for i in 6:
		var key: String=Hearth20TableData.ABILITIES[i].to_upper();var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;saves.add_child(box)
		_number(box,key+" save",float(draft.get("save_bonuses",{}).get(key,0)),func(value):draft.save_bonuses[key]=int(value),-1000,1000)
		var check:=CheckBox.new();check.text="Proficient";check.button_pressed=draft.get("save_profs",[]).has(i);check.disabled=not editable or join_submission;check.toggled.connect(func(enabled):
			if enabled and not draft.save_profs.has(i):draft.save_profs.append(i)
			elif not enabled:draft.save_profs.erase(i));box.add_child(check)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",22);page.add_child(grid)
	for name_value in Hearth20TableData.SKILLS:
		var label: String=name_value;var box:=HBoxContainer.new();grid.add_child(box)
		_number(box,label,float(draft.get("skill_bonuses",{}).get(label,0)),func(value):draft.skill_bonuses[label]=int(value),-1000,1000)
		var tier:=OptionButton.new()
		for text in ["Untrained","Proficient","Expertise"]:tier.add_item(text)
		tier.selected=clampi(int(draft.get("skills",{}).get(label,0)),0,2);tier.disabled=not editable or join_submission;tier.item_selected.connect(func(value):draft.skills[label]=value);box.add_child(tier)
	var passive:=HBoxContainer.new();page.add_child(passive)
	for name_value in ["Perception","Insight","Investigation"]:
		var label: String=name_value;_number(passive,"Passive "+label,float(draft.get("passives",{}).get(label,10)),func(value):draft.passives[label]=int(value))
	_memo(page,"Training, tools & languages",str(draft.get("proficiencies","")),func(value):draft.proficiencies=value,220)
	_line(page,"Languages",str(draft.get("languages","")),func(value):draft.languages=value)
	_memo(page,"Conditional save / roll notes",str(draft.get("save_modifiers","")),func(value):draft.save_modifiers=value,100)
func _senses() -> void:
	var page:=_page("Senses & vision");_heading(page,"This token's eyes")
	_text(page,"Darkvision sees unlit areas within its range in gray. It emits no light. Walls, closed doors, DM masks and blackout still block disclosure. A token without darkvision cannot see unlit areas through normal sight.")
	if not draft.get("vision") is Dictionary:draft.vision={"enabled":true}
	var check:=CheckBox.new();check.text="Vision enabled for this token";check.button_pressed=bool(draft.vision.get("enabled",true));check.disabled=not editable or join_submission;check.toggled.connect(func(value):draft.vision.enabled=value);page.add_child(check)
	var ranges:=HBoxContainer.new();ranges.add_theme_constant_override("separation",15);page.add_child(ranges)
	for spec in [["darkvision_feet","Darkvision (ft.)"],["blindsight_feet","Blindsight (ft.)"],["truesight_feet","Truesight (ft.)"],["tremorsense_feet","Tremorsense (reference)"]]:
		var key: String=spec[0];fields[key]=_number(ranges,spec[1],float(draft.vision.get(key,0)),func(value):draft.vision[key]=value;draft.vision.darkvision_override=true,0,1000)
	_memo(page,"Senses as printed",str(draft.get("senses","")),func(value):draft.senses=value,120)
	_text(page,"Blindsight and truesight support perception in darkness within their recorded range. Tremorsense is preserved as a reference; it does not grant map sight. Temporary spells and shared senses require DM changes rather than being activated merely because their description appears in the sheet.")
	_heading(page,"Carried light · separate from vision")
	_text(page,"Importing darkvision does not turn on a torch. These light settings are preserved for an existing token.")
	var light_row:=HBoxContainer.new();page.add_child(light_row)
	for key in ["bright_light_feet","dim_light_feet"]:_number(light_row,key.replace("_"," ").capitalize(),float(draft.vision.get(key,0)),func(value):draft.vision[key]=value,0,1000)
func _features() -> void:
	var page:=_page("Features & actions")
	for spec in [["features","Features, feats & species traits",350],["custom_actions","Actions · bonus actions · reactions",230],["defenses","Resistances, immunities & defenses",130]]:
		var key: String=spec[0];_memo(page,spec[1],str(draft.get(key,"")),func(value):draft[key]=value,spec[2])
	if not draft.get("attack_profiles",[]).is_empty():_text(page,"Printed weapon / cantrip attacks:\n"+"\n".join(draft.attack_profiles.map(func(item):return str(item.get("name",""))+" · "+str(item.get("attack_text",""))+" · "+str(item.get("damage",""))+" · "+str(item.get("notes","")))))
func _spells() -> void:
	var page:=_page("Spellbook");_heading(page,"Spells & preparation")
	_text(page,"Spell rows retain source, level, preparation marks, always-prepared status, casting time, range, components, duration, concentration, ritual, reference and notes. Importing a spell never activates its effect.")
	for block in draft.get("spellcasting",[]):
		_heading(page,str(block.get("class","Spellcasting"))+" · "+str(block.get("ability","")))
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);page.add_child(row)
		_number(row,"Spell save DC",float(block.get("dc",0)),func(value):block.dc=int(value);draft.spell_dc=int(value),0,99)
		_number(row,"Spell attack bonus",float(block.get("attack",0)),func(value):block.attack=int(value);draft.spell_attack=int(value),-100,100)
	for resource in draft.get("spell_resources",[]):_text(page,("Pact magic" if resource.get("pact",false) else "Cantrips" if resource.get("level",-1)==0 else "Level "+str(resource.get("level","?")))+" · "+str(resource.get("text","")))
	var slots:=HBoxContainer.new();page.add_child(slots)
	if not draft.get("slots_max") is Array:draft.slots_max=[0,0,0,0,0,0,0,0,0];draft.slots=draft.slots_max.duplicate()
	for i in 9:_number(slots,"Level%d slots"%(i+1),float(draft.slots_max[i]),func(value):draft.slots_max[i]=int(value);draft.slots[i]=mini(int(draft.slots[i]),int(value)),0,99)
	var remaining:=HBoxContainer.new();page.add_child(remaining)
	for i in 9:_number(remaining,"L%d remaining"%(i+1),float(draft.slots[i]),func(value):draft.slots[i]=int(value),0,99)
	var search:=LineEdit.new();search.placeholder_text="Search spells, sources or notes…";page.add_child(search)
	var row:=HBoxContainer.new();row.custom_minimum_size.y=310;page.add_child(row)
	spell_list=ItemList.new();spell_list.custom_minimum_size=Vector2(370,300);row.add_child(spell_list);spell_detail=VBoxContainer.new();spell_detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(spell_detail)
	search.text_changed.connect(_filter_spells);spell_list.item_selected.connect(_select_spell);_filter_spells("")
func _filter_spells(query: String) -> void:
	spell_list.clear();visible_spells.clear()
	for spell in draft.get("spellbook",[]):
		if not query.to_lower() in JSON.stringify(spell).to_lower():continue
		visible_spells.append(spell);spell_list.add_item(("✦ " if spell.get("always_prepared",false) else "● " if spell.get("prepared",false) else "○ ")+str(spell.name)+" · "+("cantrip" if spell.get("level",-1)==0 else str(spell.get("level","?"))))
	if not visible_spells.is_empty():spell_list.select(0);_select_spell(0)
func _select_spell(index: int) -> void:
	for child in spell_detail.get_children():spell_detail.remove_child(child);child.queue_free()
	if index<0 or index>=visible_spells.size():return
	var spell: Dictionary=visible_spells[index];_heading(spell_detail,str(spell.name))
	_number(spell_detail,"Spell level · -1 means not stated",float(spell.get("level",-1)),func(value):spell.level=int(value),-1,9)
	var prep:=CheckBox.new();prep.text="Always prepared" if spell.get("always_prepared",false) else "Prepared";prep.button_pressed=spell.get("prepared",false);prep.disabled=not editable or join_submission or spell.get("always_prepared",false);prep.toggled.connect(func(value):spell.prepared=value);spell_detail.add_child(prep)
	for pair in [["source","Source"],["save_hit","Attack / save"],["casting_time","Cast"],["range","Range"],["components","Components"],["duration","Duration"],["reference","Reference"],["notes","Notes"]]:_text(spell_detail,pair[1]+": "+str(spell.get(pair[0],"")))
func _gear() -> void:
	var page:=_page("Equipment");_heading(page,"Inventory & attunement")
	_text(page,"Equipped and attuned choices are records for the table. Printed AC, bonuses and ability scores remain unchanged when these boxes change.")
	var coins:=HBoxContainer.new();page.add_child(coins)
	for name_value in ["cp","sp","ep","gp","pp"]:
		var key: String=name_value;_number(coins,key.to_upper(),float(draft.get("coins",{}).get(key,0)),func(value):draft.coins[key]=int(value),0,9999999)
	for item in draft.get("equipment",[]):
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);page.add_child(row);var label:=_label(str(item.name)+" · "+str(item.get("weight_text","")),14);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
		_number(row,"Quantity",float(item.get("quantity",1)),func(value):item.quantity=int(value),0,9999)
		for field in ["equipped","attuned"]:
			var key: String=field;var check:=CheckBox.new();check.text=key.capitalize();check.button_pressed=item.get(key,false);check.disabled=not editable or join_submission;check.toggled.connect(func(value):item[key]=value);row.add_child(check)
	_memo(page,"Additional equipment text",str(draft.get("inventory","")),func(value):draft.inventory=value,180)
	_heading(page,"Limited-use resources")
	for name_value in draft.get("resources",{}):
		var name_key: String=str(name_value);var state: Variant=draft.resources[name_key]
		if not state is Dictionary:_text(page,name_key+": "+str(state));continue
		var resource: Dictionary=state;_heading(page,name_key);var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);page.add_child(row)
		_number(row,"Maximum",float(resource.get("maximum",0)),func(value):resource.maximum=int(value),0,999)
		var current_value:=_number(row,"Remaining",float(resource.get("current",0)) if resource.get("current")!=null else float(resource.get("maximum",0)),func(value):resource.current=int(value),0,999)
		current_value.editable=editable and not join_submission and resource.get("current")!=null
		var known:=CheckBox.new();known.text="Remaining uses confirmed";known.button_pressed=resource.get("current")!=null;known.disabled=not editable or join_submission;known.toggled.connect(func(value):resource.current=int(current_value.value) if value else null;resource.confirmed=value;current_value.editable=editable and not join_submission and value);row.add_child(known)
		_line(page,"Resets on",str(resource.get("reset","")),func(value):resource.reset=value)
	if draft.get("resources",{}).is_empty():_text(page,"No limited-use capacity was explicitly recorded. Feature text remains available under Features & actions.")

func _story() -> void:
	var page:=_page("Character");_heading(page,"Personal details & story")
	var appearance_grid:=GridContainer.new();appearance_grid.columns=3;appearance_grid.add_theme_constant_override("h_separation",16);page.add_child(appearance_grid)
	for key_value in draft.get("appearance",{}):
		var key: String=key_value;_line(appearance_grid,key,str(draft.appearance[key]),func(value):draft.appearance[key]=value)
	for spec in [["description","Appearance"],["traits","Personality"],["ideals","Ideals"],["bonds","Bonds"],["flaws","Flaws"],["backstory","Backstory"],["notes","Additional notes"]]:
		var key: String=spec[0];_memo(page,spec[1],str(draft.get(key,"")),func(value):draft[key]=value,160)
func _source() -> void:
	var page:=_page("Source & review");var record: Dictionary=draft.get("import_record",{})
	_heading(page,"Import evidence & unmapped information")
	if not custom_png.is_empty():
		var preview=TextureRect.new();var image=Image.new();image.load_png_from_buffer(custom_png);preview.texture=ImageTexture.create_from_image(image);preview.custom_minimum_size=Vector2(160,160);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;page.add_child(preview);_text(page,"Custom token PNG selected · 1-square default size for joining characters.")
	_text(page,str(record.get("filename","Recorded character"))+" · "+str(record.get("field_count",0))+" filled fields · "+str(record.get("unmapped",[]).size())+" retained as source fields")
	for issue in record.get("issues",[]):_text(page,"• "+str(issue))
	_text(page,"All filled source fields are retained with the character. Unfamiliar/homebrew fields are preserved here. PDF scripts, links, attachments and document instructions are never executed.")
	if editable and not portraits.is_empty():
		_heading(page,"Embedded portrait")
		portrait=TextureRect.new();portrait.texture=ImageTexture.create_from_image(_portrait_image());portrait.custom_minimum_size=Vector2(180,180);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;page.add_child(portrait)
		use_portrait=CheckBox.new();use_portrait.text="Use this portrait as the token image";use_portrait.button_pressed=target_id.is_empty();page.add_child(use_portrait)
	var search:=LineEdit.new();search.placeholder_text="Find a source field…";page.add_child(search)
	var source_text:=TextEdit.new();source_text.editable=false;source_text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;source_text.custom_minimum_size.y=440;page.add_child(source_text)
	var update:=func(query):
		var output:=PackedStringArray()
		for key in record.get("fields",{}):
			var value: String=str(record.fields[key])
			if query.to_lower() in (str(key)+" "+value).to_lower():output.append(str(key)+"\n"+value+"\n")
		source_text.text="\n".join(output)
	search.text_changed.connect(update);update.call("")
func _portrait_image() -> Image:
	var image:=Image.new();image.load_png_from_buffer(portraits[portrait_index]);return image
func _apply() -> void:
	if not editable or (app.session.local_role!="dm" and not join_submission):return
	if draft.get("spellbook") is Array:draft.prepared_spells=draft.spellbook.filter(func(spell):return spell.get("prepared",false) or spell.get("always_prepared",false) or spell.get("level",-1)==0).map(func(spell):return str(spell.name))
	var png: PackedByteArray=portraits[portrait_index] if portrait_index>=0 and use_portrait!=null and use_portrait.button_pressed else PackedByteArray()
	if not custom_png.is_empty():png=custom_png
	if join_submission:
		draft.token_size=1.0;var sent=app.session.submit_join_character(draft,png)
		if not sent.ok:status.text=str(sent.error);return
		apply_button.disabled=true;status.text="Sending your character to the DM's campaign inventory…";return
	var result: Dictionary=app.session.apply_character_sheet(target_id,draft,expected,png)
	if not result.ok:status.text=str(result.error);return
	app.board.selected_actor_id=result.id;app.board.selection_changed.emit(result.id);app.board.queue_redraw();app._on_status("Character sheet saved. Assign the token's player and movement grant in Tokens → Controlled by.")
	app.open_token_inventory();queue_free()

func _begin_edit() -> void:
	if app.session.local_role!="dm":return
	draft=_actor().duplicate(true);expected=Hearth20CharacterImport.target_signature(draft);editable=true;file_button.show();apply_button.show();apply_button.disabled=false
	if edit_button!=null:edit_button.hide()
	status.text="Editing the recorded sheet. Changes stay in this draft until Apply; the original PDF is unchanged.";_build()

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and worker!=null:
		worker.wait_to_finish();worker=null
