extends RefCounted
class_name Hearth20CharacterImport
## Sheet values are records, never executable instructions or automatically reapplied bonuses.
const MAX_BYTES:=1500000
const IMPORT_FIELDS: Array=["name","class","subclass","class_levels","race","background","alignment","level","xp","xp_text","rules_version","abilities","prof_bonus","save_profs","save_bonuses","skills","skill_bonuses","custom_skills","passives","hp","max_hp","temp","ac","speed","movement_speeds","initiative_bonus","inspiration","hit_die","hit_dice","hit_dice_text","death_success","death_failure","exhaustion","senses","special_senses","vision","defenses","save_modifiers","proficiencies","languages","features","custom_actions","conditional_notes","attack_profiles","inventory","equipment","coins","spell_resources","spellcasting","spellbook","prepared_spells","spells","slots","slots_max","spell_ability","spell_dc","spell_attack","resources","traits","ideals","bonds","flaws","backstory","description","notes","appearance","size_category","token_size","import_record"]
var fields: Dictionary={}
var originals: Dictionary={}
var used: Dictionary={}
var issues: Array=[]
static func normalized(value: String) -> String:
	var pattern:=RegEx.new();pattern.compile("[^a-z0-9]");return pattern.sub(value.to_lower(),"",true)
static func number(value: String, fallback: int=0) -> int:
	var regex:=RegEx.new();regex.compile("[+-]?[0-9]+");var found:=regex.search(value.replace("−","-").replace(",","").replace(" ","").replace(" ",""));return int(found.get_string()) if found else fallback
func pick(names: Array, fallback: String="") -> String:
	for name_value in names:
		var key:=normalized(str(name_value))
		if fields.has(key):used[originals[key]]=true;return fields[key]
	return fallback
func integer(names: Array, fallback: int=0) -> int:return number(pick(names),fallback)
static func read(path: String) -> Dictionary:
	var parsed:=Hearth20PdfReader.new().read(path)
	if not parsed.ok:return parsed
	var result:=Hearth20CharacterImport.new().from_fields(parsed.fields,parsed.get("positions",{}),path.get_file())
	if result.ok:
		result.portraits=parsed.get("portraits",[])
		result.sheet.import_record.sha256=parsed.sha256
		if not parsed.conflicts.is_empty():result.issues.append("Conflicting PDF values: "+", ".join(parsed.conflicts)+". Verify these in Source before applying.")
	return result
func from_fields(raw: Dictionary, positions: Dictionary={}, filename: String="character.pdf") -> Dictionary:
	for key in raw:
		if not key is String or not raw[key] is String:continue
		var value: String=raw[key].strip_edges();var id:=normalized(key)
		if not value.is_empty() and value!="Off" and not fields.has(id):fields[id]=value;originals[id]=key
	if fields.size()>4096:return {"ok":false,"error":"Too many character fields."}
	var name_value:=pick(["CharacterName","CharacterName2","CharacterName4","character name"])
	if name_value.is_empty():return {"ok":false,"error":"Character name not found. Choose the original D&D Beyond Export to PDF or a filled official sheet. Scanned/flattened pages need a form export."}
	var sheet: Dictionary={"name":name_value,"abilities":[],"save_profs":[],"save_bonuses":{},"skills":{},"skill_bonuses":{},"custom_skills":[],"class_levels":[],"equipment":[],"coins":{},"spell_resources":[],"spellcasting":[],"spellbook":[],"prepared_spells":[],"resources":{},"slots":[0,0,0,0,0,0,0,0,0],"slots_max":[0,0,0,0,0,0,0,0,0],"attack_profiles":[]}
	var classes:=pick(["CLASS LEVEL","ClassLevel","Class and Level","Class"]);var class_pattern:=RegEx.new();class_pattern.compile("(?i)([a-z][a-z ()]{1,50}?)\\s*([0-9]{1,2})(?=\\s*(?:[-–—/;,(]|$))")
	var total_level:=0
	for found in class_pattern.search_all(classes):sheet.class_levels.append({"class":found.get_string(1).strip_edges(),"level":int(found.get_string(2))});total_level+=int(found.get_string(2))
	sheet.class=classes;sheet.level=integer(["Level","CharacterLevel","TotalLevel"],total_level if total_level>0 else 1);sheet.subclass=pick(["Subclass","SubClass"],classes.get_slice(" - ",1) if " - " in classes else "")
	if total_level==0:issues.append("Class/level needs review; no class defaults or equipment were added.")
	for pair in [["race",["RACE","Species"]],["background",["BACKGROUND"]],["alignment",["ALIGNMENT"]],["xp_text",["EXPERIENCE POINTS","XP"]],["size_category",["SIZE"]]]:sheet[pair[0]]=pick(pair[1])
	sheet.xp=number(sheet.xp_text);sheet.rules_version="2014" if "2014" in (sheet.race+pick(["FeaturesTraits1"])) else "2024" if "2024" in (sheet.race+pick(["FeaturesTraits1"])) else "Unspecified"
	sheet.prof_bonus=integer(["ProfBonus","ProficiencyBonus"],2+floori((sheet.level-1)/4.0))
	for i in 6:
		var short: String=Hearth20TableData.ABILITIES[i].to_upper();var full: String=["Strength","Dexterity","Constitution","Intelligence","Wisdom","Charisma"][i]
		var value:=pick([short,full,full+"Score"])
		if value.is_empty():issues.append("Missing "+full+" score; review the value.")
		sheet.abilities.append(number(value,10))
		var save:=pick(["ST "+full,full+"Save",short+"Save"]);var flag:=pick([short.capitalize()+"Prof",full+"SaveProf"])
		if trained(flag):sheet.save_profs.append(i)
		if not save.is_empty():sheet.save_bonuses[short]=number(save)
	for label in Hearth20TableData.SKILLS:
		var aliases: Array=[label]
		if label=="Animal Handling":aliases.append("Animal")
		var value:=pick(aliases);var flag:=pick([label+"Prof",label+"Proficiency"])
		if trained(flag):sheet.skills[label]=2 if flag.to_upper() in ["E","EXPERTISE","2"] else 1
		if not value.is_empty():sheet.skill_bonuses[label]=number(value)
	for i in range(1,9):
		var label:=pick(["CustomSkill%d"%i])
		if not label.is_empty():sheet.custom_skills.append({"name":label,"bonus":integer(["Custom Skill Bonus %d"%i]),"training":pick(["CustomProf%d"%i])})
	sheet.passives={"Perception":integer(["Passive1","PassivePerception","Passive"] ,10+int(sheet.skill_bonuses.get("Perception",0))),"Insight":integer(["Passive2","PassiveInsight"],10+int(sheet.skill_bonuses.get("Insight",0))),"Investigation":integer(["Passive3","PassiveInvestigation"],10+int(sheet.skill_bonuses.get("Investigation",0)))}
	for spec in [["max_hp",["MaxHP","HPMax"],1],["ac",["AC","ArmorClass"],10],["speed",["Speed","WalkingSpeed"],30],["temp",["TempHP","HPTemp"],0],["initiative_bonus",["Init","Initiative"],floori((float(sheet.abilities[1])-10)/2)]]:sheet[spec[0]]=integer(spec[1],spec[2])
	var current:=pick(["CurrentHP","HPCurrent"]);sheet.hp=number(current,sheet.max_hp)
	if current.is_empty():issues.append("Current HP was blank; the draft starts at the printed maximum.")
	sheet.movement_speeds={"walking":sheet.speed}
	for mode in ["Fly","Swim","Climb","Burrow"]:
		var value:=pick([mode+"Speed",mode+"ingSpeed","SwimmingSpeed" if mode=="Swim" else mode+"ingSpeed"])
		if not value.is_empty():sheet.movement_speeds[mode.to_lower()]=number(value)
	var printed_speed:=pick(["Speed"])
	for pair in [["walking","Walk(?:ing)?"],["fly","Fly(?:ing)?"],["swim","Swim(?:ming)?"],["climb","Climb(?:ing)?"],["burrow","Burrow(?:ing)?"]]:
		var pattern:=RegEx.new();pattern.compile("(?i)(?:"+pair[1]+"[^0-9,;]{0,12}([0-9]{1,4})\\s*(?:ft|feet)|([0-9]{1,4})\\s*(?:ft\\.?|feet)\\s*\\(?"+pair[1]+")")
		var found:=pattern.search(printed_speed)
		if found:sheet.movement_speeds[pair[0]]=number(found.get_string(1) if not found.get_string(1).is_empty() else found.get_string(2))
	sheet.speed=int(sheet.movement_speeds.walking)
	sheet.inspiration=trained(pick(["Inspiration","HeroicInspiration"]))
	sheet.hit_dice_text=pick(["Total","TotalHitDice","HitDice"]);sheet.hit_dice=integer(["HD","HitDiceRemaining"],sheet.level)
	var hit_pattern:=RegEx.new();hit_pattern.compile("d([0-9]{1,2})");var hit:=hit_pattern.search(sheet.hit_dice_text);sheet.hit_die=int(hit.get_string(1)) if hit else 0
	sheet.death_success=integer(["DeathSaveSuccesses","DeathSuccess"]);sheet.death_failure=integer(["DeathSaveFailures","DeathFailure"])
	if fields.has("additionalsenses") and fields.has("profbonus"):
		for index in 3:
			if not fields.has("deathsavesuccesses") and not fields.has("deathsuccess") and trained(pick(["Check Box %d"%(12+index)])):sheet.death_success+=1
			if not fields.has("deathsavefailures") and not fields.has("deathfailure") and trained(pick(["Check Box %d"%(15+index)])):sheet.death_failure+=1
	sheet.exhaustion=integer(["Exhaustion"])
	for spec in [["senses",["AdditionalSenses","Senses"]],["defenses",["Defenses","Resistances"]],["save_modifiers",["SaveModifiers"]],["proficiencies",["ProficienciesLang","OtherProficienciesLanguages","Proficiencies"]],["features",["FeaturesTraits1","FeaturesAndTraits","Features and Traits","ClassFeatures"]],["traits",["PersonalityTraits"]],["ideals",["Ideals"]],["bonds",["Bonds"]],["flaws",["Flaws"]],["backstory",["Backstory"]],["description",["Appearance","CharacterAppearance"]]]:sheet[spec[0]]=pick(spec[1])
	for key in ["FeaturesTraits2","FeaturesTraits3","FeaturesTraits4","SpeciesTraits","Feats"]:
		var value:=pick([key])
		if not value.is_empty():sheet.features+="\n\n"+value
	sheet.custom_actions=(pick(["Actions1","Actions"])+"\n\n"+pick(["Actions2","BonusActions"])+"\n\n"+pick(["Reactions"])).strip_edges()
	sheet.notes=(pick(["AdditionalNotes1","Notes"])+"\n\n"+pick(["AdditionalNotes2"])).strip_edges()
	sheet.conditional_notes=sheet.save_modifiers
	sheet.appearance={}
	for key in ["Age","Gender","Height","Weight","Eyes","Skin","Hair","Faith","Allies"]:sheet.appearance[key]=pick([key])
	sheet.languages=pick(["Languages"])
	if sheet.languages.is_empty():
		var language_text:=RegEx.new();language_text.compile("(?is)LANGUAGES\\s*\\n(.+?)(?:\\n\\n|$)");var language_match:=language_text.search(sheet.proficiencies)
		if language_match:sheet.languages=language_match.get_string(1).strip_edges()
	sheet.special_senses=parse_senses(sheet.senses,sheet.features)
	sheet.vision={"enabled":true,"darkvision_feet":sheet.special_senses.darkvision,"darkvision_override":true,"blindsight_feet":sheet.special_senses.blindsight,"truesight_feet":sheet.special_senses.truesight,"tremorsense_feet":sheet.special_senses.tremorsense,"bright_light_feet":0.0,"dim_light_feet":0.0}
	sheet.token_size=1.0
	for i in range(1,13):
		var label:=pick(["Wpn Name"+("" if i==1 else " "+str(i)),"Wpn%d Name"%i,"WeaponName%d"%i])
		if label.is_empty():continue
		var attack:=pick(["Wpn%d AtkBonus"%i,"WeaponAttack%d"%i]);var save_pattern:=RegEx.new();save_pattern.compile("(?i)(STR|DEX|CON|INT|WIS|CHA)\\s*([0-9]+)");var save:=save_pattern.search(attack)
		sheet.attack_profiles.append({"name":label,"attack_text":attack,"bonus":number(attack),"kind":"save" if save else "attack","save_ability":save.get_string(1).to_upper() if save else "","dc":int(save.get_string(2)) if save else 0,"damage":pick(["Wpn%d Damage"%i]),"notes":pick(["Wpn Notes %d"%i,"Wpn%d Notes"%i])})
	for i in 256:
		var label:=pick(["Eq Name%d"%i,"EquipmentName%d"%i])
		if label.is_empty():continue
		var state:=pick(["Eq Equipped%d"%i]);var attuned:=pick(["Eq Attuned%d"%i]);var weight:=pick(["Eq Weight%d"%i])
		sheet.equipment.append({"name":label,"quantity":integer(["Eq Qty%d"%i],1),"weight_text":weight,"equipped":trained(state) or " - worn" in label.to_lower() or " - equipped" in label.to_lower(),"attuned":trained(attuned),"notes":pick(["Eq Notes%d"%i])})
	var equipment_text:=pick(["Equipment","Equipment2"]);sheet.inventory=equipment_text
	if not sheet.equipment.is_empty():sheet.inventory="\n".join(sheet.equipment.map(func(item):return item.name+" × "+str(item.quantity)+(" · "+item.weight_text if not item.weight_text.is_empty() else "")))+"\n"+equipment_text
	for coin in ["CP","SP","EP","GP","PP"]:sheet.coins[coin.to_lower()]=integer([coin])
	parse_spells(sheet,positions)
	for i in 64:
		var label:=pick(["ResourceName%d"%i,"LimitedUseName%d"%i])
		if not label.is_empty():sheet.resources[label]={"current":integer(["ResourceCurrent%d"%i]),"maximum":integer(["ResourceMax%d"%i]),"reset":pick(["ResourceReset%d"%i])}
	var limited:=RegEx.new();limited.compile("(?is)(CHANNEL DIVINITY|KI POINTS|FOCUS POINTS|SORCERY POINTS|BARDIC INSPIRATION|RAGES?|SECOND WIND|WILD SHAPE|SUPERIORITY DICE|PSIONIC ENERGY DICE)\\s*\\n\\s*([0-9]{1,3})\\s*(?:uses?|points?|dice|die)[^\\n.]{0,100}")
	for found in limited.search_all(sheet.custom_actions+"\n"+sheet.features):
		var label:=found.get_string(1).capitalize()
		if not sheet.resources.has(label):sheet.resources[label]={"maximum":int(found.get_string(2)),"current":null,"reset":found.get_string().get_slice(";",1).strip_edges(),"source":found.get_string(),"confirmed":false};issues.append(label+" capacity found; remaining uses are not stated. Confirm in Equipment → Limited-use resources.")
	var raw_copy: Dictionary={}
	for id in fields:raw_copy[originals[id]]=fields[id]
	sheet.import_record={"filename":filename,"format":"fillable-pdf","field_count":raw_copy.size(),"fields":raw_copy,"unmapped":raw_copy.keys().filter(func(key):return not used.has(key)),"issues":issues.duplicate()}
	var valid:=validate(sheet)
	if not valid.ok:return valid
	return {"ok":true,"sheet":sheet,"issues":issues,"portraits":[]}
static func trained(flag: String) -> bool:return not flag.strip_edges().to_lower() in ["","off","false","0","no","-","none"]
func parse_senses(senses: String, features: String) -> Dictionary:
	var result: Dictionary={"darkvision":0.0,"blindsight":0.0,"truesight":0.0,"tremorsense":0.0}
	for sense in result:
		var regex:=RegEx.new();regex.compile("(?i)"+sense+"[^0-9\\n]{0,45}([0-9]{1,4})\\s*(?:ft|feet|foot|['’])")
		for found in regex.search_all(senses):result[sense]=maxf(result[sense],float(found.get_string(1)))
		if result[sense]>0:continue
		regex.compile("(?i)([0-9]{1,4})[ -]*(?:ft\\.?|feet|foot)[ -]+"+sense+"|"+sense+"[^0-9\\n]{0,25}([0-9]{1,4})[ -]*(?:ft|feet|foot)")
		for found in regex.search_all(features):
			var surrounding:=features.substr(maxi(0,found.get_start()-65),found.get_end()-maxi(0,found.get_start()-65)+25).to_lower()
			if "increase" in surrounding or "share" in surrounding or "willing" in surrounding:continue
			result[sense]=maxf(result[sense],float(found.get_string(1) if not found.get_string(1).is_empty() else found.get_string(2)))
		if result[sense]>0:issues.append(sense.capitalize()+" inferred from feature text; confirm its range and any conditions.")
	return result
func parse_spells(sheet: Dictionary, positions: Dictionary) -> void:
	var headers: Array=[]
	for id in fields:
		if not id.begins_with("spellheader"):continue
		var label: String=fields[id];var level:=0 if "cantrip" in label.to_lower() else number(label,-1);var position: Dictionary=positions.get(originals[id],{})
		headers.append({"level":level,"position":position});used[originals[id]]=true
		var suffix: String=id.trim_prefix("spellheader");var slot_text:=pick(["spellSlotHeader"+suffix]);var slots_pattern:=RegEx.new();slots_pattern.compile("(?i)([0-9]+)\\s*(?:pact\\s+)?slots?");var slots:=slots_pattern.search(slot_text)
		sheet.spell_resources.append({"level":level,"text":slot_text,"pact":slot_text.to_lower().contains("pact")})
		if level>=1 and level<=9 and slots:
			var capacity:=int(slots.get_string(1));var remaining_text:=pick(["spellSlotsRemaining"+suffix,"spellSlotRemaining"+suffix]);var remaining:=number(remaining_text,capacity);var known:=not remaining_text.is_empty()
			if ":" in slot_text:
				var marks:=slot_text.get_slice(":",1);var open_count:=0;var spent_count:=0
				for mark in marks:
					if mark in ["O","o","○","◯"]:open_count+=1
					elif mark in ["X","x","●","■","✓","✔"]:spent_count+=1
				if open_count+spent_count==capacity:remaining=open_count;known=true
			if not slot_text.to_lower().contains("pact"):sheet.slots_max[level-1]=capacity;sheet.slots[level-1]=remaining
			sheet.spell_resources.back().maximum=capacity;sheet.spell_resources.back().remaining=remaining;sheet.spell_resources.back().remaining_known=known
			if not known:issues.append("Level%d remaining slots not stated; draft starts full. Confirm the remaining slots."%level)
	for i in 30:
		var casting:=pick(["spellCastingClass%d"%i,"SpellcastingClass%d"%i,"SpellcastingClass" if i==0 else "missingclass%d"%i])
		if casting.is_empty():continue
		sheet.spellcasting.append({"class":casting,"ability":pick(["spellCastingAbility%d"%i,"SpellcastingAbility"]),"dc":integer(["spellSaveDC%d"%i,"SpellSaveDC"]),"attack":integer(["spellAtkBonus%d"%i,"SpellAttackBonus"])})
	if not sheet.spellcasting.is_empty():sheet.spell_ability=sheet.spellcasting[0].ability;sheet.spell_dc=sheet.spellcasting[0].dc;sheet.spell_attack=sheet.spellcasting[0].attack
	for id in fields.keys():
		if not id.begins_with("spellname"):continue
		var suffix: String=id.trim_prefix("spellname");var name_value:=pick([originals[id]]);var state:=pick(["spellPrepared"+suffix]);var position: Dictionary=positions.get(originals[id],{});var level:=integer(["spellLevel"+suffix],-1);var nearest:=INF
		if level<0 and position.has("rect"):
			var y: float=(float(position.rect[1])+float(position.rect[3]))*.5
			for header in headers:
				var hp: Dictionary=header.position
				if hp.has("rect") and hp.get("page",0)==position.get("page",0):
					var distance: float=(float(hp.rect[1])+float(hp.rect[3]))*.5-y
					if distance>=0 and distance<nearest:nearest=distance;level=header.level
		var record: Dictionary={"name":name_value,"level":level,"prepared":state.to_upper() in ["P","D","A","ALWAYS","PREPARED","YES","ON","TRUE","1","*","●","■","✓","✔","X"] or level==0,"always_prepared":state.to_upper() in ["D","A","ALWAYS"],"preparation_mark":state}
		for pair in [["source","spellSource"],["save_hit","spellSaveHit"],["casting_time","spellCastingTime"],["range","spellRange"],["components","spellComponents"],["duration","spellDuration"],["reference","spellPage"],["notes","spellNotes"]]:record[pair[0]]=pick([pair[1]+suffix])
		record.concentration="conc" in record.duration.to_lower() or "concentration" in record.notes.to_lower() or trained(pick(["spellConcentration"+suffix]));record.ritual="ritual" in record.notes.to_lower() or "[r]" in record.name.to_lower() or trained(pick(["spellRitual"+suffix]))
		sheet.spellbook.append(record)
		if record.prepared:sheet.prepared_spells.append(name_value)
		if level<0:issues.append("Spell level not stated for "+name_value+"; review it rather than guessing from its row number.")
	sheet.spells="\n".join(sheet.spellbook.map(func(spell):return spell.name+" · "+("Cantrip" if spell.level==0 else "Level "+str(spell.level) if spell.level>0 else "Level not stated")+" · "+spell.source+" · "+spell.notes))
static func validate(sheet: Variant) -> Dictionary:
	if not sheet is Dictionary or var_to_bytes(sheet).size()>MAX_BYTES:return {"ok":false,"error":"The extracted sheet exceeds the character data limit."}
	if not sheet.get("name") is String or sheet.name.strip_edges().is_empty() or sheet.name.length()>96:return {"ok":false,"error":"Review the character name (1–96 characters)."}
	if not sheet.get("abilities") is Array or sheet.abilities.size()!=6:return {"ok":false,"error":"Six ability scores are required."}
	for score in sheet.abilities:
		if not Hearth20Contracts._integer_number(score) or int(score)<1 or int(score)>100:return {"ok":false,"error":"Ability scores must be between1 and100."}
	if not Hearth20Vision.valid_settings(sheet.get("vision",{})):return {"ok":false,"error":"Review vision ranges (0–1000 feet)."}
	for key in ["blindsight_feet","truesight_feet","tremorsense_feet"]:
		if not Hearth20Contracts._finite_number(sheet.vision.get(key,0)) or float(sheet.vision.get(key,0))<0 or float(sheet.vision.get(key,0))>1000:return {"ok":false,"error":"Review the special-sense ranges."}
	for key in ["level","hp","max_hp","temp","ac","speed","prof_bonus","initiative_bonus"]:
		if not Hearth20Contracts._integer_number(sheet.get(key)) or absi(int(sheet[key]))>100000:return {"ok":false,"error":"Review invalid "+key+"."}
	for key in ["hp","max_hp","temp","ac","speed","level","prof_bonus"]:
		if int(sheet[key])<0 or (key=="level" and int(sheet[key])<1):return {"ok":false,"error":"Review negative or missing "+key+"."}
	if not sheet.get("resources",{}) is Dictionary:return {"ok":false,"error":"Review the limited-use resource records."}
	return {"ok":true}
static func target_signature(actor: Dictionary) -> String:
	var fields: Dictionary={}
	for key in IMPORT_FIELDS:
		if actor.has(key):fields[key]=actor[key]
	return Hearth20Contracts.sha256(var_to_bytes(fields))
