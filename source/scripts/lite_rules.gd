extends RefCounted
## Lite's host boundary. Intentions and dice never invoke combat automation.
const R=preload("res://scripts/rules.gd")
const CREATURE=preload("res://scripts/lite_creature.gd")
const SHEET_TEXT=["subclass","multiclass","background","alignment","age","height_text","weight_text","eyes","skin","hair","languages","proficiencies","senses","personality_traits","ideals","bonds","flaws","backstory","allies","organizations","treasure","personal_notes","extras","custom_actions"]
const ACTIONS={
	"Attack":"Make an attack with a weapon or an unarmed strike. The DM determines hit, damage and any Extra Attack or Multiattack.",
	"Cast a Spell":"Use the spell's printed casting time, range, components and duration. The DM resolves targets, saves, damage and effects.",
	"Dash":"Gain extra movement equal to your speed for the current turn.",
	"Disengage":"Your movement does not provoke opportunity attacks for the rest of the turn.",
	"Dodge":"Until your next turn, attacks you can see have disadvantage and DEX saves have advantage. Benefit ends if incapacitated or speed becomes 0.",
	"Help":"Aid an ability check, or distract a creature within 5 feet so an ally's next attack before your next turn has advantage. The DM checks eligibility.",
	"Hide":"Make a Dexterity (Stealth) check when the DM permits hiding. The DM decides who can see or hear you.",
	"Ready":"Choose a perceivable trigger and an action, or movement up to your speed, then use your reaction when the trigger occurs. Readying a spell requires concentration.",
	"Search":"Devote attention to finding something; the DM chooses Wisdom (Perception) or Intelligence (Investigation).",
	"Use an Object":"Interact with an object that requires your action, or make an additional object interaction. Magic item activation can use its own rules.",
	"Grapple":"Replace one attack with a free-hand grapple against a creature no more than one size larger, within reach: Athletics vs Athletics or Acrobatics. A tie leaves the situation unchanged.",
	"Shove prone":"Replace one attack with Athletics vs Athletics or Acrobatics against a creature within reach, no more than one size larger; success knocks it prone.",
	"Shove push":"As a shove, but push the creature 5 feet away on success.",
	"Escape grapple":"Use an action: Athletics or Acrobatics contested by the grappler's Athletics. The DM resolves the contest.",
	"Release grapple":"Release a creature you are grappling whenever you like; no action required.",
	"Opportunity attack":"When a hostile creature you can see leaves your reach, use your reaction for one melee attack just before it leaves. Teleportation and forced movement normally do not trigger this.",
	"Bonus action":"Take a bonus action only when a spell, class feature or other rule grants one. You have at most one per turn.",
	"Reaction":"Use a reaction only for a specified trigger. It refreshes at the start of your next turn.",
	"Improvise":"Describe your intention. The DM decides whether it is possible and what roll, time or resources it needs."
}
const HOST_PASS=["lighting","build_edit","build_scene","elevation","tile","room_visibility","door","fog","fog_all","remove_actor","hidden","journal","template","clear_templates","new_campaign","campaign_name","scene_name","image","import_image","resize","grid_settings","new_scene","guide","lobby_start","lobby_return","review_hero","import_scene","import_prepared_scene","duplicate_scene","delete_scene","feature_set","spell_settings","spell_useset","custom_spell","inspiration"]
const PERSONAL_PASS=["customize_mini","sheet_notes","inventory_item","coins","learn_spell","prepare_spell","forget_spell","lobby_ready","submit_hero"]
var w
var image_cache={}
static func sneak_attack_dice(rogue_level: int) -> int:
	return mini(10,ceili(float(rogue_level)/2.0)) if rogue_level>0 else 0
static func lay_on_hands_eligible(a: Dictionary) -> bool:
	return not a.is_empty() and bool(a.get("hero",false)) and str(a.get("class",""))=="Paladin" and str(a.get("multiclass","" )).is_empty() and int(a.get("level",0))>0
static func lay_on_hands_type_restricted(target: Dictionary) -> bool:
	return str(target.get("race","")).strip_edges().to_lower() in ["undead","construct"]
static func lay_on_hands_max(a: Dictionary) -> int:
	return int(a.get("level",0))*5 if lay_on_hands_eligible(a) else 0
static func lay_on_hands_remaining(a: Dictionary) -> int:
	return maxi(0,lay_on_hands_max(a)-mini(lay_on_hands_max(a),int(a.get("lay_on_hands_spent",0))))
static func bardic_eligible(a: Dictionary) -> bool:
	return not a.is_empty() and bool(a.get("hero",false)) and str(a.get("class",""))=="Bard" and str(a.get("multiclass","" )).is_empty() and int(a.get("level",0))>0
static func bardic_die(level: int) -> String:return "d6" if level<5 else "d8" if level<10 else "d10" if level<15 else "d12"
static func bardic_pool(a: Dictionary) -> int:return maxi(1,R.modifier(int(a.get("abilities",[10,10,10,10,10,10])[5]))) if bardic_eligible(a) else 0
static func second_wind_eligible(a: Dictionary) -> bool:
	return not a.is_empty() and bool(a.get("hero",false)) and str(a.get("class",""))=="Fighter" and str(a.get("multiclass","" )).is_empty() and int(a.get("level",0))>0
static func second_wind_feature(a: Dictionary) -> int:
	for i in a.get("features",[]).size():
		if a.features[i].get("name","")=="Second Wind":return i
	return -1
static func monk_ki_eligible(a: Dictionary) -> bool:
	return not a.is_empty() and bool(a.get("hero",false)) and str(a.get("class",""))=="Monk" and str(a.get("multiclass","" )).is_empty() and int(a.get("level",0))>=2 and monk_ki_feature(a)>=0
static func monk_ki_feature(a: Dictionary) -> int:
	for i in a.get("features",[]).size():
		if str(a.features[i].get("name",""))=="Ki":return i
	return -1
var rates={}
func _init(world):w=world
static func valid_state(value) -> bool:
	if not value is Dictionary:return false
	if value.has("public") and not value.public is bool:return false
	if value.has("blackout") and not value.blackout is bool:return false
	if value.has("combat") and not value.combat is bool:return false
	for field in ["serial","round"]:
		if value.has(field) and (not (value[field] is int or value[field] is float) or not is_finite(float(value[field])) or value[field]<0 or value[field]>2147483647):return false
	if value.has("active") and not value.active is String:return false
	for field in ["requests","rolls","prompts","events","order","concentration_decisions"]:
		if not value.get(field,[]) is Array or value.get(field,[]).size()>200:return false
		for item in value.get(field,[]):
			if field=="order":
				if not item is String:return false
				continue
			if not item is Dictionary:return false
			if field=="events":
				if not item.get("text") is String or not item.get("time") is String:return false
				continue
			if field=="concentration_decisions":
				if not item.get("id","") is String or item.id.is_empty() or item.id.length()>100 or not item.get("actor","") is String or item.actor.is_empty() or item.actor.length()>100:return false
				if not item.get("reason","") in ["expired","lost","incapacitated","ended","transfer","maintained","check"] or not item.get("spell","") is String or item.spell.length()>200 or not item.get("time","") is String or item.time.length()>64:return false
				if item.has("concentration_id") and (not item.concentration_id is String or item.concentration_id.is_empty() or item.concentration_id.length()>100):return false
				if item.reason=="check":
					if not item.get("outcome","") in ["maintained","failed","unclear"]:return false
					for field_name in ["dc","total"]:
						if item.has(field_name):
							var numeric_value=item[field_name]
							if not (numeric_value is int or numeric_value is float) or not is_finite(float(numeric_value)) or float(numeric_value)!=floor(float(numeric_value)) or numeric_value<-10000 or numeric_value>10000:return false
					if item.has("damage"):
						var damage_value=item.damage
						if not (damage_value is int or damage_value is float) or not is_finite(float(damage_value)) or float(damage_value)!=floor(float(damage_value)) or damage_value<1 or damage_value>10000:return false
					if item.has("context") and (not item.context is String or item.context.length()>300):return false
					for linked_field in ["prompt_id","roll_id"]:
						if item.has(linked_field) and (not item[linked_field] is String or item[linked_field].is_empty() or item[linked_field].length()>100):return false
					if item.has("prompt_id")!=item.has("roll_id"):return false
				if item.has("check_id") and (not item.check_id is String or item.check_id.is_empty() or item.check_id.length()>100):return false
				if item.has("check_id") and item.reason!="lost":return false
				if not item.get("previous_targets",[]) is Array or item.previous_targets.size()>100:return false
				for target_id in item.previous_targets:
					if not target_id is String or target_id.is_empty() or target_id.length()>100:return false
				if not item.get("target","") is String or item.target.length()>100:return false
				if item.reason=="transfer" and item.target.is_empty():return false
				if not item.get("confirmed_eligibility",false) is bool:return false
				if item.reason=="transfer" and not item.confirmed_eligibility:return false
				if item.has("note") and (not item.note is String or item.note.length()>300):return false
				continue
			for key in ["id","actor"]:
				if not item.get(key) is String:return false
			if field=="requests":
				if item.get("status","") not in ["pending","approved","declined"] or not item.get("label") is String or not item.get("reply") is String:return false
				if value.get("public",false):continue
				for key in ["kind","note","details","formula","mode"]:
					if not item.get(key) is String:return false
				for key in ["peer","slot","feature","item"]:
					if not (item.get(key) is int or item.get(key) is float):return false
				if item.slot<0 or item.slot>9 or not item.get("targets") is Array or item.targets.size()>100 or not item.get("proposal") is Dictionary:return false
				if item.kind=="lay_on_hands" and (not item.get("target") is String or item.target.is_empty() or item.target.length()>100 or not (item.get("amount") is int or item.get("amount") is float) or not is_finite(float(item.amount)) or item.amount!=floor(item.amount) or item.amount<1 or item.amount>1000):return false
				if item.kind=="bardic_inspiration_assign" and (not item.get("target") is String or item.target.is_empty() or item.target.length()>100):return false
				if item.kind=="bardic_inspiration_use" and (not item.get("roll_id") is String or item.roll_id.is_empty() or item.roll_id.length()>100 or not item.get("die_roll") is int or item.die_roll<1 or item.die_roll>12):return false
				if item.kind=="second_wind" and (not item.get("target") is String or item.target!=item.actor or not item.get("die_roll") is int or item.die_roll<1 or item.die_roll>10):return false
				if item.kind=="monk_ki" and (not item.get("technique") is String or item.technique not in ["Flurry of Blows","Patient Defense","Step of the Wind · Dash","Step of the Wind · Disengage"]):return false
			elif field=="rolls":
				if not item.get("name") is String or not item.get("label") is String or not item.get("result") is Dictionary or not (item.get("peer") is int or item.get("peer") is float):return false
				if not (item.result.get("total") is int or item.result.get("total") is float) or not is_finite(float(item.result.total)) or not item.result.get("dice") is Array:return false
			elif field=="prompts":
				if item.get("type","") not in ["initiative","save","ability","skill","death"] or not item.get("done") is bool or not item.get("label") is String:return false
				if not (item.get("ability") is int or item.get("ability") is float) or not is_finite(float(item.ability)) or float(item.ability)!=floor(float(item.ability)) or item.ability<0 or item.ability>5:return false
				if item.has("purpose") and item.purpose not in ["concentration"]:return false
				if item.get("purpose","")=="concentration" and (item.type!="save" or int(item.ability)!=2):return false
				if item.has("concentration_spell") and (not item.concentration_spell is String or item.concentration_spell.length()>200):return false
				if item.has("concentration_id") and (not item.concentration_id is String or item.concentration_id.is_empty() or item.concentration_id.length()>100):return false
				if item.has("concentration_owner") and (not (item.concentration_owner is int or item.concentration_owner is float) or not is_finite(float(item.concentration_owner)) or float(item.concentration_owner)!=floor(float(item.concentration_owner)) or item.concentration_owner<1 or item.concentration_owner>2147483647):return false
				if item.has("concentration_recorded") and not item.concentration_recorded is bool:return false
				if item.has("concentration_invalidated") and (not item.concentration_invalidated is bool or item.get("purpose","")!="concentration"):return false
				if item.get("concentration_recorded",false) and (not item.get("done",false) or item.get("purpose","")!="concentration"):return false
				if item.has("dc") and (not (item.dc is int or item.dc is float) or not is_finite(float(item.dc)) or float(item.dc)!=floor(float(item.dc)) or item.dc<0 or item.dc>10000):return false
				if item.get("purpose","")=="concentration" and item.has("dc") and item.dc<10:return false
	var linked_roll_ids={};var linked_check_ids={}
	for decision in value.get("concentration_decisions",[]):
		if decision.get("reason","")=="check" and decision.has("roll_id"):
			if linked_roll_ids.has(decision.roll_id):return false
			linked_roll_ids[decision.roll_id]=true
		if decision.has("check_id"):
			if linked_check_ids.has(decision.check_id):return false
			linked_check_ids[decision.check_id]=true
			var matching_ids=value.get("concentration_decisions",[]).filter(func(item):return str(item.get("id",""))==str(decision.check_id))
			if matching_ids.size()!=1 or matching_ids[0].get("reason","")!="check":return false
			var linked_check=matching_ids[0]
			if linked_check.get("outcome","")!="failed" or str(linked_check.get("actor",""))!=str(decision.get("actor","")) or not decision.has("concentration_id") or str(linked_check.get("concentration_id",""))!=str(decision.concentration_id) or str(linked_check.get("spell",""))!=str(decision.get("spell","")):return false
	return true
func ensure():
	if not w.data.get("lite") is Dictionary:w.data.lite={}
	var s=w.data.lite
	for field in ["requests","rolls","prompts","events","order","concentration_decisions"]:
		if not s.get(field) is Array:s[field]=[]
	if not s.get("blackout") is bool:s.blackout=true
	if not s.get("combat") is bool:s.combat=false
	if not s.get("serial") is int:s.serial=0
	if not s.get("round") is int:s.round=1
	if not s.get("active") is String:s.active=""
	s.order=s.order.filter(func(id):return id is String and not w.actor(id).is_empty())
	if not s.active.is_empty() and not s.order.has(s.active):s.active=s.order[0] if not s.order.is_empty() else ""
	if s.order.is_empty():s.combat=false
	w.data.automation={"auto_saves":false,"auto_initiative":false,"auto_encounters":false,"strict_turns":false}
	w.data.combat={"active":false,"order":[],"turn":0,"round":1}
func state() -> Dictionary:return w.data.lite
func blackout() -> bool:return bool(w.data.get("lite",{}).get("blackout",true))
func next_id(prefix: String) -> String:
	state().serial+=1;return prefix+str(state().serial)
func reject(peer: int,text: String):w.reject_command(peer,text)
func changed():w.mark_changed()
func own(a: Dictionary,peer: int) -> bool:return not a.is_empty() and (peer==1 or (a.get("hero",false) and w.can_control(a,peer)))
func dire_wolf_eligible(a: Dictionary) -> bool:
	if a.is_empty() or not a.get("hero",false) or str(a.get("class",""))!="Druid" or not str(a.get("multiclass","")).is_empty():return false
	var moon=str(a.get("subclass",""))=="Circle of the Moon"
	if int(a.get("level",0))<(2 if moon else 8):return false
	return true
static func turn_undead_feature(a: Dictionary) -> int:
	if a.is_empty() or not a.get("hero",false) or str(a.get("class",""))!="Cleric" or not str(a.get("multiclass","")).is_empty() or int(a.get("level",0))<2:return -1
	for i in a.get("features",[]).size():
		if str(a.features[i].get("name",""))=="Channel Divinity":return i
	return -1
static func turn_undead_eligible(a: Dictionary) -> bool:
	var index=turn_undead_feature(a)
	return index>=0 and int(a.features[index].get("remaining",0))>0
func can_cast_in_wild_shape(a: Dictionary,spell: Dictionary) -> bool:
	if a.get("wild_shape",{}).is_empty():return true
	if str(a.get("class",""))!="Druid" or int(a.get("level",0))<18:return false
	var components=spell.get("components",[])
	if components is Array:return not components.has("M")
	return not str(components).contains("M")
static func concentration_duration(spell_key: String,spell: Dictionary,slot: int) -> String:
	if (spell_key=="huntersmark" or str(spell.get("index",""))=="hunters-mark") and not spell.get("custom",false):
		return "Up to 1 hour" if slot<3 else "Up to 8 hours" if slot<5 else "Up to 24 hours"
	return str(spell.get("duration","See spell text"))
static func concentration_damage_dc(damage: int) -> int:
	return maxi(10,floori(float(damage)/2.0))
static func rage_damage_bonus(level: int) -> int:return 2 if level<9 else 3 if level<16 else 4
func movement_status(a: Dictionary) -> Dictionary:
	if w.client:return a.get("lite_movement",{"combat":false,"turn":false,"spent":0.0,"allowance":0.0,"remaining":0.0})
	var combat=bool(state().get("combat",false));var speed=maxf(0,float(a.get("speed",0)))
	if int(a.get("hp",0))<=0 or a.get("conditions",[]).any(func(c):return c in ["Grappled","Restrained","Petrified","Stunned","Paralyzed","Unconscious","Incapacitated"]):speed=0
	var allowance=maxf(0,float(a.get("lite_allowance",speed)));var spent=maxf(0,float(a.get("moved",0))) if combat else 0.0
	return {"combat":combat,"turn":not combat or state().active==a.get("id",""),"spent":spent,"allowance":allowance,"remaining":maxf(0,allowance-spent)}
func rebase_movement_allowance(a: Dictionary,old_speed: float,new_speed: float):
	if a.has("lite_allowance"):
		var allowance=maxf(0,float(a.lite_allowance))
		# DM-set caps below base speed remain absolute; larger totals carry their bonus across forms.
		a.lite_allowance=new_speed+(allowance-old_speed) if allowance>=old_speed else allowance
func reset_movement(id: String):
	var a=w.actor(id)
	if not a.is_empty():a.moved=0.0;a.movement_diagonals=0;a.erase("lite_allowance")
func movement_route(a: Dictionary,destination: Vector2i) -> Dictionary:
	var result={"ok":false,"reason":"No clear revealed route.","cost":0.0,"path":[],"diagonals":0}
	if a.is_empty() or not a.hero or a.get("public_token",false) or a.scene!=w.data.scene:return result
	if blackout():result.reason="The DM has obscured the board.";return result
	var status=movement_status(a)
	if status.combat and not status.turn:result.reason="Wait for your turn. The DM controls initiative.";return result
	var from=Vector2i(a.x,a.y);var footprint=int(a.get("token_size",1));var scene=w.scene().duplicate(true);scene.id="lite_player_route"
	for x in footprint:
		for y in footprint:
			if not w.cell_visible(destination+Vector2i(x,y)):result.reason="The DM has not revealed that destination.";return result
	for field in ["tiles","doors_open","surfaces","terrain_blocks","elevations"]:
		for key in scene.get(field,{}).keys():
			var xy=str(key).split(",")
			if not w.cell_visible(Vector2i(int(xy[0]),int(xy[1]))):scene[field].erase(key)
	# Concealed story objects and creatures do not reveal themselves through path tests.
	scene.props=scene.get("props",[]).filter(func(prop):
		if prop.get("concealed",false):return false
		var rect=w.BUILD.rect(prop,scene)
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y):
				if not w.cell_visible(Vector2i(x,y)):return false
		return true)
	w.BUILD.invalidate()
	if not w.ROOMS.clear_footprint(scene,destination,footprint):result.reason="A wall, closed door or solid object blocks that square.";return result
	for unit in w.data.actors:
		if unit.id==a.id or unit.scene!=a.scene or not w.visible(unit):continue
		if w.COMBAT.cells(unit).any(func(cell):return w.COMBAT.cells({"x":destination.x,"y":destination.y,"token_size":footprint}).has(cell)):result.reason="Choose an unoccupied destination.";return result
	var frontier=[from];var costs={w.ROOMS.key(from):0.0};var paths={w.ROOMS.key(from):[]};var diagonals={w.ROOMS.key(from):int(a.get("movement_diagonals",0)) if status.combat else 0};var iterations=0
	while not frontier.is_empty() and iterations<int(scene.width)*int(scene.height):
		frontier.sort_custom(func(x,y):return float(costs[w.ROOMS.key(x)])<float(costs[w.ROOMS.key(y)]));var current=frontier.pop_front();var current_key=w.ROOMS.key(current);iterations+=1
		if current==destination:result={"ok":true,"reason":"Clear route.","cost":float(costs[current_key]),"path":paths[current_key],"diagonals":int(diagonals[current_key])};break
		for dx in range(-1,2):
			for dy in range(-1,2):
				if dx==0 and dy==0:continue
				var next=current+Vector2i(dx,dy);var key=w.ROOMS.key(next)
				if dx!=0 and dy!=0 and (not w.cell_visible(current+Vector2i(dx,0)) or not w.cell_visible(current+Vector2i(0,dy))):continue
				if not w.ROOMS.inside(scene,next) or not w.ROOMS.clear_path(scene,current,next,footprint):continue
				var shown=true
				for x in footprint:
					for y in footprint:
						if not w.cell_visible(next+Vector2i(x,y)):shown=false
				if not shown:continue
				var tile=int(scene.tiles.get(key,0));var climb=absf(w.encounter.elevation(next)-w.encounter.elevation(current))
				if climb>w.encounter.feet_per_cell()+.001 and tile!=11:continue
				var cost=w.movement_feet(current,next)
				if scene.get("grid_metric","5e")=="5105" and dx!=0 and dy!=0 and int(diagonals[current_key])%2==1:cost+=w.encounter.feet_per_cell()
				if ((tile in [4,12] or w.BUILD.collision(scene).difficult.has(key)) and not w.BUILD.collision(scene).walkable.has(key)) or (status.combat and a.conditions.has("Prone")):cost*=2
				if tile!=11:cost+=climb
				var value=float(costs[current_key])+cost
				if costs.has(key) and float(costs[key])<=value:continue
				costs[key]=value;diagonals[key]=int(diagonals[current_key])+int(dx!=0 and dy!=0);paths[key]=paths[current_key].duplicate();paths[key].append({"x":next.x,"y":next.y,"cost":value})
				if not frontier.has(next):frontier.append(next)
	w.BUILD.invalidate()
	if result.ok and status.combat and result.cost>status.remaining+.001:result.ok=false;result.reason="Not enough movement remains this turn. Ask the DM to grant extra movement."
	return result
func player_move(a: Dictionary,p: Dictionary,peer: int):
	if not own(a,peer) or not a.hero or w.session.phase!="table":reject(peer,"Move only your assigned hero after the DM starts the table.");return
	if not w.visible(a):reject(peer,"The DM has concealed this piece. Wait for it to be revealed.");return
	if not integer(p,"x",0,int(w.scene().width)-1) or not integer(p,"y",0,int(w.scene().height)-1):return
	var route=movement_route(a,Vector2i(p.x,p.y))
	if not route.ok:reject(peer,route.reason);return
	a.x=int(p.x);a.y=int(p.y);a.last_path=route.path;a.elevation_ft=w.encounter.elevation(Vector2i(a.x,a.y))
	if state().combat:a.moved=float(a.get("moved",0))+float(route.cost);a.movement_diagonals=int(route.diagonals)
	changed()
func integer(p: Dictionary,key: String,minimum: int,maximum: int) -> bool:
	var value=p.get(key)
	return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=minimum and value<=maximum
func text(p: Dictionary,key: String,limit: int) -> bool:return p.get(key) is String and p[key].length()<=limit
func permit_rate(peer: int) -> bool:
	if peer==1:return true
	var now=Time.get_ticks_msec();var window=rates.get(peer,{"start":now,"count":0})
	if now-int(window.start)>10000:window={"start":now,"count":0}
	window.count+=1;rates[peer]=window;return int(window.count)<=40
static func roll_expression(expression: String,mode: int=0) -> Dictionary:
	var compact=expression.to_lower().replace(" ","")
	if compact.is_empty() or compact.length()>120:return {"ok":false,"error":"Enter dice such as 2d6+1d4+3."}
	if compact.begins_with("-"):compact="0"+compact
	var regex=RegEx.new();regex.compile("[+-]?(?:[0-9]{1,2}d[0-9]{1,3}|[0-9]{1,4})")
	var matches=regex.search_all(compact);var joined="";var total=0;var count=0;var dice=[];var bonus=0
	var d20_groups=matches.filter(func(found):return found.get_string().trim_prefix("+").trim_prefix("-")=="1d20").size()
	if matches.size()>20:return {"ok":false,"error":"Use at most 20 dice/modifier groups."}
	for found in matches:
		var token=found.get_string();joined+=token
		if joined.length()>token.length() and token[0] not in ["+","-"]:return {"ok":false,"error":"Separate dice groups with + or −."}
		var sign_value=-1 if token.begins_with("-") else 1;var term=token.trim_prefix("+").trim_prefix("-")
		if term.contains("d"):
			var parts=term.split("d");var n=int(parts[0]);var sides=int(parts[1]);count+=n
			if n<1 or n>40 or sides<2 or sides>100 or count>80:return {"ok":false,"error":"Use 1–40 dice per group, 2–100 sides, at most 80 dice."}
			for i in n:
				var value=R.d20(0,mode) if sides==20 and n==1 and d20_groups==1 else {"dice":[randi_range(1,sides)]}
				var chosen=maxi(value.dice[0],value.dice[-1]) if mode==1 else mini(value.dice[0],value.dice[-1]) if mode==2 else value.dice[0]
				dice.append({"sides":sides,"dice":value.dice,"kept":chosen,"sign":sign_value});total+=sign_value*chosen
		else:bonus+=sign_value*int(term);total+=sign_value*int(term)
	if joined!=compact or matches.is_empty():return {"ok":false,"error":"Use NdS groups and fixed modifiers, for example 2d6+1d4+3."}
	return {"ok":true,"expression":expression,"total":total,"dice":dice,"bonus":bonus}
func record_roll(a: Dictionary,label: String,result: Dictionary,peer: int,source: String="") -> Dictionary:
	var entry={"id":next_id("roll_"),"actor":a.get("id",""),"name":a.get("name","DM" if peer==1 else w.peers.get(peer,{}).get("name","Player")),"label":label,"result":result,"peer":peer,"source":source,"session":str(w.session.get("lite_id","offline")),"time":Time.get_time_string_from_system().substr(0,5)}
	state().rolls.append(entry)
	while state().rolls.size()>200:state().rolls.pop_front()
	return entry
func public_event(message: String):
	state().events.append({"time":Time.get_time_string_from_system().substr(0,5),"text":message.left(1500)})
	while state().events.size()>150:state().events.pop_front()
func decision_log(actor: Dictionary,reason: String,concentration: Dictionary,target_id: String="",confirmed_eligibility: bool=false,note: String="",check_id: String=""):
	var previous_targets=concentration.get("targets",[]).duplicate(true) if concentration.get("targets",[]) is Array else []
	var entry={"id":next_id("conc_"),"actor":str(actor.id),"reason":reason,"spell":str(concentration.get("spell","")),"previous_targets":previous_targets,"target":target_id,"confirmed_eligibility":confirmed_eligibility,"note":note,"time":Time.get_datetime_string_from_system(false,true)}
	if concentration.has("concentration_id"):entry.concentration_id=str(concentration.concentration_id)
	if not check_id.is_empty():entry.check_id=check_id
	append_concentration_decision(entry)
func append_concentration_decision(entry: Dictionary):
	var decisions=state().get("concentration_decisions",[])
	decisions.append(entry)
	while decisions.size()>200:
		var removed=decisions.pop_front()
		if removed.get("reason","")=="check":
			var lost_decisions=decisions.filter(func(item):return str(item.get("check_id",""))==str(removed.get("id","")))
			for linked_loss in lost_decisions:decisions.erase(linked_loss)
	state().concentration_decisions=decisions
func command(kind: String,p: Dictionary,peer: int) -> bool:
	ensure()
	# Local DM imports contain embedded PNGs. Remote commands keep their strict cap;
	# the normal scene/image validators still validate the DM's imported content.
	if peer!=1 and JSON.stringify(p).length()>1500000:reject(peer,"This command is too large.");return true
	if peer!=1 and not w.peers.has(peer):return true
	if not permit_rate(peer):reject(peer,"Please slow down before submitting another action.");return true
	var a=w.actor(str(p.get("id","")))
	if kind=="chat":
		if text(p,"text",1000):public_event(("DM" if peer==1 else str(w.peers.get(peer,{}).get("name","Player")))+": "+p.text);changed()
		return true
	if kind=="lite_roll":make_roll(a,p,peer);return true
	if kind=="lite_request":submit(a,p,peer);return true
	if kind=="end_concentration":
		if peer!=1:
			reject(peer,"Only the DM can end recorded concentration.")
			return true
		if a.is_empty() or a.get("concentration",{}).is_empty():
			reject(peer,"There is no recorded concentration to end.")
			return true
		var reason=str(p.get("reason",""))
		if reason not in ["expired","lost","incapacitated","ended","maintained"]:
			reject(peer,"Choose maintained, expired, lost, DM-confirmed incapacitation, or another DM end decision.")
			return true
		var note=""
		if p.has("note"):
			if not p.note is String or p.note.length()>300:
				reject(peer,"The private DM note must be 300 characters or fewer.")
				return true
			note=p.note.strip_edges()
		var prior=a.concentration.duplicate(true)
		var check_id=""
		if p.has("check_id"):
			if not p.check_id is String:
				reject(peer,"Choose a valid failed concentration check ID.");return true
			check_id=p.check_id
			if reason!="lost" or check_id.is_empty() or check_id.length()>100:
				reject(peer,"Link a valid failed concentration check only to a DM loss decision.");return true
			var current_id=prior.get("concentration_id","")
			if not current_id is String or current_id.is_empty() or current_id.length()>100:
				reject(peer,"This concentration has no saved identity, so an older check cannot be linked.");return true
			var matching_ids=state().concentration_decisions.filter(func(item):return str(item.get("id",""))==check_id)
			if matching_ids.size()!=1 or matching_ids[0].get("reason","")!="check":
				reject(peer,"Choose one previously recorded concentration check.");return true
			var linked_check=matching_ids[0]
			if str(linked_check.get("actor",""))!=str(a.id) or str(linked_check.get("concentration_id",""))!=current_id or str(linked_check.get("spell",""))!=str(prior.get("spell","")) or linked_check.get("outcome","")!="failed":
				reject(peer,"That check is not a failed result for this actor's active concentration instance.");return true
			if state().concentration_decisions.any(func(item):return str(item.get("check_id",""))==check_id):
				reject(peer,"That failed check is already linked to a concentration-loss decision.");return true
		decision_log(a,reason,prior,"",false,note,check_id)
		if reason!="maintained":w.magic.end_concentration(a)
		changed();return true
	if kind=="record_concentration_check":
		if peer!=1:
			reject(peer,"Only the DM can record a concentration check.")
			return true
		if a.is_empty() or a.get("concentration",{}).is_empty():
			reject(peer,"There is no recorded concentration to check.")
			return true
		var outcome=str(p.get("outcome",""))
		if outcome not in ["maintained","failed","unclear"]:
			reject(peer,"Choose a manually reviewed check outcome.")
			return true
		var concentration_id=""
		if a.concentration.has("concentration_id"):
			if not a.concentration.concentration_id is String or a.concentration.concentration_id.is_empty() or a.concentration.concentration_id.length()>100:
				reject(peer,"This concentration has an invalid saved identity and cannot record a check.");return true
			concentration_id=a.concentration.concentration_id
		var record={"actor":str(a.id),"reason":"check","spell":str(a.concentration.get("spell","")),"previous_targets":[],"target":"","confirmed_eligibility":false,"outcome":outcome,"time":Time.get_datetime_string_from_system(false,true)}
		if not concentration_id.is_empty():record.concentration_id=concentration_id
		var bound_prompt={}
		if p.has("roll_id"):
			var linked_roll_id=str(p.get("roll_id",""))
			if linked_roll_id.is_empty() or linked_roll_id.length()>100:
				reject(peer,"Choose a valid completed concentration roll.");return true
			var matching_rolls=state().rolls.filter(func(item):return str(item.get("id",""))==linked_roll_id)
			if matching_rolls.size()!=1:
				reject(peer,"That concentration roll is missing or ambiguous.");return true
			var linked_roll=matching_rolls[0]
			var matching_prompts=state().prompts.filter(func(item):return str(item.get("id",""))==str(linked_roll.get("source","")))
			if matching_prompts.size()!=1:
				reject(peer,"That roll is not linked to a unique concentration prompt.");return true
			var linked_prompt=matching_prompts[0]
			bound_prompt=linked_prompt
			var current_concentration=a.get("concentration",{})
			var active_owner=int(a.get("owner",1))
			if linked_prompt.get("purpose","")!="concentration" or linked_prompt.get("type","")!="save" or int(linked_prompt.get("ability",-1))!=2 or str(linked_prompt.get("actor",""))!=str(a.id):
				reject(peer,"That roll does not belong to this hero's Constitution concentration prompt.");return true
			if not linked_prompt.has("concentration_owner") or int(linked_prompt.get("concentration_owner",-1))!=active_owner or int(linked_roll.get("peer",-1))!=active_owner:
				reject(peer,"That concentration roll was not submitted by the hero's assigned owner.");return true
			if not linked_prompt.has("concentration_spell") or not linked_prompt.has("concentration_id") or str(linked_prompt.get("concentration_id","" )).is_empty() or str(current_concentration.get("concentration_id","" )).is_empty() or str(linked_prompt.get("concentration_spell",""))!=str(current_concentration.get("spell","")) or str(linked_prompt.get("concentration_id",""))!=str(current_concentration.get("concentration_id","")):
				reject(peer,"That concentration prompt belongs to a stale spell record.");return true
			if not bool(linked_prompt.get("done",false)) or str(linked_prompt.get("roll",""))!=linked_roll_id or str(linked_roll.get("source",""))!=str(linked_prompt.get("id","")):
				reject(peer,"That concentration prompt has not been completed by its owner.");return true
			if str(linked_roll.get("actor",""))!=str(a.id) or str(linked_roll.get("label",""))!="CON save":
				reject(peer,"That linked result is not this hero's Constitution save.");return true
			if state().concentration_decisions.any(func(item):return str(item.get("roll_id",""))==linked_roll_id):
				reject(peer,"That concentration roll already has a recorded outcome.");return true
			if bool(linked_prompt.get("concentration_recorded",false)):
				reject(peer,"That concentration roll already has a recorded outcome.");return true
			var roll_total=linked_roll.get("result",{}).get("total")
			var prompt_dc=linked_prompt.get("dc")
			if not (roll_total is int or roll_total is float) or not is_finite(float(roll_total)) or float(roll_total)!=floor(float(roll_total)) or not (prompt_dc is int or prompt_dc is float) or not is_finite(float(prompt_dc)) or float(prompt_dc)!=floor(float(prompt_dc)):
				reject(peer,"The saved prompt or roll does not contain a valid whole-number DC and total.");return true
			record["prompt_id"]=str(linked_prompt.id);record["roll_id"]=linked_roll_id;record["dc"]=int(prompt_dc);record["total"]=int(roll_total)
		if p.has("damage"):
			var damage_value=p.damage
			if not (damage_value is int or damage_value is float) or not is_finite(float(damage_value)) or float(damage_value)!=floor(float(damage_value)) or damage_value<1 or damage_value>10000:
				reject(peer,"Damage taken must be a positive whole number from 1 to 10000.")
				return true
			record.damage=int(damage_value)
		for field_name in ([] if p.has("roll_id") else ["dc","total"]):
			if p.has(field_name):
				if not p[field_name] is int or p[field_name]<-10000 or p[field_name]>10000:
					reject(peer,"Check DC and total must be whole numbers from -10000 to 10000.")
					return true
				record[field_name]=int(p[field_name])
		var context=""
		if p.has("context"):
			if not p.context is String or p.context.length()>300:
				reject(peer,"Private check context must be 300 characters or fewer.")
				return true
			context=p.context.strip_edges()
		record["context"]=context
		if concentration_id.is_empty():concentration_id=next_id("conc_active_");a.concentration.concentration_id=concentration_id
		record.concentration_id=concentration_id
		record["id"]=next_id("conc_")
		if not bound_prompt.is_empty():bound_prompt.concentration_recorded=true
		append_concentration_decision(record)
		changed();return true
	if kind=="lite_mark_transfer":
		if peer!=1:
			reject(peer,"Only the DM can transfer a recorded Hunter's Mark target.")
			return true
		if a.is_empty() or a.get("concentration",{}).is_empty():return true
		var active=a.concentration
		var spell_name=str(active.get("spell","" )).to_lower().replace("'","").replace(" ","")
		var current_mark_definition=w.magic.definition(a,"huntersmark")
		if spell_name!="huntersmark" or active.get("custom",false) or current_mark_definition.get("custom",false):
			reject(peer,"Target transfer is available only for recorded bundled Hunter's Mark concentration.")
			return true
		var current_targets=active.get("targets",[])
		if not current_targets is Array or current_targets.size()!=1 or not current_targets[0] is String or current_targets[0].is_empty():
			reject(peer,"Transfer requires exactly one currently recorded Hunter's Mark target.")
			return true
		var target=w.actor(str(p.get("target","")))
		if target.is_empty() or target.scene!=w.data.scene or not w.visible(target):
			reject(peer,"Choose a creature visible in the current scene as the new Hunter's Mark target.")
			return true
		if target.id==current_targets[0]:
			reject(peer,"Choose a different creature than the currently marked target.")
			return true
		if not p.get("confirmed_eligibility",false) is bool or not p.get("confirmed_eligibility",false):
			reject(peer,"Confirm that the old target dropped to 0 HP and this transfer is on a subsequent turn using an available bonus action.")
			return true
		var next=active.duplicate(true);next.targets=[target.id];next.transfer_dm_confirmed=true
		decision_log(a,"transfer",active,target.id,true);a.concentration=next;changed();return true
	if kind=="move" and peer!=1:player_move(a,p,peer);return true
	if kind=="lite_sheet":
		if not own(a,peer) or not p.get("fields") is Dictionary:return true
		for key in p.fields:
			if key not in SHEET_TEXT or not p.fields[key] is String or p.fields[key].length()>30000:return true
		for key in p.fields:a[key]=p.fields[key]
		changed();return true
	if kind in PERSONAL_PASS:
		if peer!=1 and kind not in ["lobby_ready","submit_hero"] and not own(a,peer):return true
		if peer!=1 and not a.get("wild_shape",{}).is_empty() and kind in ["inventory_item","coins"]:reject(peer,"Gear cannot be changed while shaped; ask the DM.");return true
		return false
	if peer!=1:reject(peer,"The DM controls movement, initiative, resources and outcomes. Submit an intention from your sheet.");return true
	match kind:
		"lite_remove_template":
			var areas=w.scene().get("areas",[])
			if not integer(p,"index",0,areas.size()-1) or not p.get("area") is Dictionary:return true
			# An old list/hover must not delete a different area after another edit.
			if areas[int(p.index)]!=p.area or (areas[int(p.index)].has("id") and str(areas[int(p.index)].id)!=str(p.area.get("id",""))):return true
			if not areas[int(p.index)].has("id") and areas.filter(func(candidate):return candidate==p.area).size()!=1:return true
			w.history.append(w.data.duplicate(true));areas.remove_at(int(p.index));changed()
		"lite_blackout":
			if not p.get("enabled") is bool:return true
			state().blackout=p.enabled;changed()
		"lite_prompt":prompt(p)
		"lite_resolve":resolve(p)
		"lite_rage_end":end_rage(a)
		"lite_bardic_clear":clear_bardic(a,p)
		"lite_proposal_roll":proposal_roll(p)
		"lite_order":set_order(p)
		"lite_combat":
			if not p.get("active") is bool:return true
			if p.active and state().order.is_empty():reject(1,"Add pieces to the initiative order before starting combat.");return true
			state().combat=p.active
			if p.active and not state().order.has(state().active):state().active=state().order[0]
			for unit in w.data.actors:reset_movement(unit.id)
			changed()
		"lite_allowance":
			if a.is_empty() or not integer(p,"amount",0,10000) or not p.get("reset_spent",false) is bool:return true
			a.lite_allowance=int(p.amount)
			if p.get("reset_spent",false):a.moved=0.0;a.movement_diagonals=0
			changed()
		"lite_next":
			var order=state().order.filter(func(id):return not w.actor(id).is_empty())
			if not order.is_empty():
				var index=order.find(state().active)+1
				if index>=order.size():index=0;state().round+=1
				state().active=order[index];state().order=order;reset_movement(state().active);changed()
		"lite_prop":
			if not text(p,"uid",100) or not p.get("concealed") is bool:return true
			for prop in w.scene().get("props",[]):
				if prop.uid==p.uid:prop.concealed=p.concealed;changed();break
		"lite_announce":
			if text(p,"text",1500):public_event(p.text);changed()
		"move":
			if a.is_empty() or a.scene!=w.data.scene or not integer(p,"x",0,int(w.scene().width)-1) or not integer(p,"y",0,int(w.scene().height)-1):return true
			var destination=Vector2i(mini(int(p.x),int(w.scene().width)-int(a.get("token_size",1))),mini(int(p.y),int(w.scene().height)-int(a.get("token_size",1))))
			w.history.append(w.data.duplicate(true));var distance=w.measure_cells(Vector2i(a.x,a.y),destination);a.x=destination.x;a.y=destination.y;a.last_path=[];a.elevation_ft=w.encounter.elevation(destination)
			w.message.emit(a.name+" moved "+w.format_distance(distance)+" · DM placement");changed()
		"door":
			if not integer(p,"x",0,int(w.scene().width)-1) or not integer(p,"y",0,int(w.scene().height)-1):return true
			var cell=Vector2i(p.x,p.y);var key=w.cell_key(cell.x,cell.y)
			if int(w.scene().tiles.get(key,0))!=6:return true
			if not w.scene().get("doors_open") is Dictionary:w.scene().doors_open={}
			var opening=not bool(w.scene().doors_open.get(key,false))
			if p.has("open"):
				if not p.open is bool:return true
				opening=p.open
			for point in w.ROOMS.door_cells(w.scene(),cell):w.scene().doors_open[w.ROOMS.key(point)]=opening
			changed()
		"hp","temp","condition","slot","resource":manual_value(a,kind,p)
		"scene":
			for scene in w.data.scenes:
				if scene.id==p.get("scene",""):
					w.history.append(w.data.duplicate(true));w.data.scene=scene.id;state().blackout=true;state().combat=false;state().order=[];state().active=""
					for hero in w.data.actors:
						if hero.hero:hero.scene=scene.id;hero.x=clampi(int(hero.x),0,int(scene.width)-int(hero.get("token_size",1)));hero.y=clampi(int(hero.y),0,int(scene.height)-int(hero.get("token_size",1)))
					changed();break
		"update_actor":
			if a.is_empty() or not p.get("actor") is Dictionary:return true
			if p.actor.has("owner") and (not p.actor.owner is int or p.actor.owner<1 or p.actor.owner>2147483647):reject(peer,"Choose a valid whole-number owner ID.");return true
			if p.actor.has("owner") and int(p.actor.owner)!=int(a.get("owner",1)) and peer!=1:reject(peer,"Only the DM can reassign character ownership.");return true
			var candidate=a.duplicate(true)
			for key in p.actor:
				if key not in ["id","hero"]:candidate[key]=p.actor[key]
			var check=w.data.duplicate(true);check.actors=[candidate]
			if not w.valid_campaign(check):reject(peer,"The sheet contains invalid values.");return true
			w.history.append(w.data.duplicate(true))
			for key in candidate:
				if key=="owner":w.set_actor_owner(a,int(candidate.owner))
				else:a[key]=candidate[key]
			changed()
		"add_actor":
			if not p.get("actor") is Dictionary:return true
			var check=w.data.duplicate(true);check.actors=[p.actor]
			if not w.valid_campaign(check):reject(peer,"Invalid creature or character sheet.");return true
			p.actor.erase("lite_allowance");p.actor.erase("lite_movement");p.actor.moved=0.0;p.actor.movement_diagonals=0
			if not p.actor.hero:p.actor.hidden=not p.get("reveal",false)
			return false
		_:
			if kind in HOST_PASS:return false
			reject(peer,"Lite uses DM adjudication. Use the request inbox, private dice and manual sheet controls.")
	return true
func manual_value(a: Dictionary,kind: String,p: Dictionary):
	if a.is_empty():return
	if kind in ["hp","temp"]:
		if not integer(p,"amount",-9999,9999):return
		w.history.append(w.data.duplicate(true))
		if kind=="hp":a.hp=clampi(int(a.hp)+int(p.amount),0,int(a.max_hp))
		else:a.temp=maxi(0,int(p.amount))
	elif kind=="condition":
		if p.get("condition","") not in R.CONDITIONS:return
		if a.conditions.has(p.condition):a.conditions.erase(p.condition)
		else:a.conditions.append(p.condition)
	elif kind=="slot":
		if not integer(p,"level",0,8) or not integer(p,"delta",-99,99):return
		a.slots[int(p.level)]=clampi(int(a.slots[int(p.level)])+int(p.delta),0,int(a.slots_max[int(p.level)]))
	elif kind=="resource":
		if p.get("resource","") not in ["action","bonus","reaction"]:return
		a[p.resource]=not a.get(p.resource,false)
	changed()
func make_roll(a: Dictionary,p: Dictionary,peer: int):
	if p.has("mode") and not integer(p,"mode",0,2):return
	var type=str(p.get("type","custom"));var label="";var expression="";var source=str(p.get("prompt",""));var mode=clampi(int(p.get("mode",0)),0,2)
	if type!="custom" and not own(a,peer):reject(peer,"Roll only for your assigned character.");return
	var linked_prompt={}
	if not source.is_empty():
		var linked=state().prompts.filter(func(task):return str(task.get("id",""))==source)
		if linked.size()!=1:
			reject(peer,"That roll prompt is missing or no longer available.");return
		linked_prompt=linked[0]
		if str(linked_prompt.get("actor",""))!=str(a.get("id","")) or bool(linked_prompt.get("done",false)):
			reject(peer,"That roll prompt belongs to another hero or was already used.");return
		if str(linked_prompt.get("type",""))!=type:
			reject(peer,"Roll the type requested by that prompt.");return
		if type in ["save","ability"] and (not (p.get("ability") is int or p.get("ability") is float) or int(linked_prompt.get("ability",-1))!=int(p.get("ability",-2))):
			reject(peer,"Roll the ability requested by that prompt.");return
		if type=="skill" and str(linked_prompt.get("skill",""))!=str(p.get("skill","")):
			reject(peer,"Roll the skill requested by that prompt.");return
		if linked_prompt.get("purpose","")=="concentration":
			var current_concentration=a.get("concentration",{})
			if linked_prompt.get("concentration_invalidated",false) or not linked_prompt.has("concentration_owner") or not linked_prompt.has("concentration_id") or str(linked_prompt.get("concentration_id","" )).is_empty() or int(linked_prompt.get("concentration_owner",-1))!=peer or current_concentration.is_empty() or str(current_concentration.get("concentration_id","" )).is_empty() or str(current_concentration.get("spell",""))!=str(linked_prompt.get("concentration_spell","")) or str(current_concentration.get("concentration_id",""))!=str(linked_prompt.get("concentration_id","")):
				reject(peer,"That concentration prompt is stale or missing its identity. Ask the DM for a fresh concentration prompt.");return
	var bonus=0
	match type:
		"ability","save":
			if not integer(p,"ability",0,5):return
			var index=int(p.ability);bonus=R.modifier(int(a.abilities[index]));label=R.ABILITIES[index]+(" save" if type=="save" else " check")
			if type=="save":bonus=int(a.get("save_bonuses",{}).get(R.ABILITIES[index],bonus+(R.proficiency(a.level) if a.save_profs.has(index) else 0)))
		"skill":
			if p.get("skill","") not in R.SKILLS:return
			label=p.skill;bonus=int(a.get("skill_bonuses",{}).get(label,R.modifier(int(a.abilities[R.SKILLS[label]]))+int(a.skills.get(label,0))*R.proficiency(a.level)))
		"initiative":
			var task=state().prompts.filter(func(t):return t.id==source and t.actor==a.id and not t.done and t.type=="initiative")
			if peer!=1 and task.is_empty():reject(peer,"Wait for the DM's initiative prompt.");return
			bonus=int(a.get("initiative_bonus",R.modifier(int(a.abilities[1]))));label="Initiative"
		"attack","damage":
			var profiles=w.attack_profiles(a)
			if not integer(p,"index",0,profiles.size()-1):return
			var profile=profiles[int(p.index)];label=str(profile.label)+(" attack" if type=="attack" else " damage")
			if type=="attack":bonus=int(profile.bonus)
			else:expression=str(profile.damage)
		"death":label="Death saving throw"
		"hitdie":expression="1d"+str(a.hit_die)+R.signed_n(R.modifier(int(a.abilities[2])));label="Hit Die · proposed healing"
		"custom":
			if peer!=1 and not own(a,peer):reject(peer,"Select your assigned hero before rolling.");return
			if not text(p,"expr",120) or not text(p,"label",100):return
			expression=p.expr;label=p.label
		_:return
	if expression.is_empty():expression="1d20"+R.signed_n(bonus)
	var result=roll_expression(expression,mode)
	if not result.ok:reject(peer,result.error);return
	var entry=record_roll(a,label,result,peer,source)
	if not source.is_empty():
		linked_prompt.done=true;linked_prompt.roll=entry.id
	changed()
func prompt(p: Dictionary):
	if p.get("type","") not in ["initiative","save","ability","skill","death"] or not p.get("actors") is Array or p.actors.size()>100:return
	if not integer(p,"ability",0,5) or not text(p,"label",150) or not integer(p,"dc",0,10000):return
	if p.type=="skill" and p.get("skill","") not in R.SKILLS:return
	var purpose=str(p.get("purpose",""))
	if purpose not in ["","concentration"] or (purpose=="concentration" and (p.type!="save" or int(p.ability)!=2 or int(p.dc)<10)):return
	if state().prompts.filter(func(t):return not t.done).size()+p.actors.size()>100:reject(1,"Finish existing roll prompts first.");return
	for id in p.actors:
		var a=w.actor(str(id))
		if a.is_empty() or not a.hero:continue
		if purpose=="concentration" and a.get("concentration",{}).is_empty():continue
		var task={"id":next_id("prompt_"),"actor":a.id,"type":p.type,"ability":int(p.ability),"skill":str(p.get("skill","")),"label":p.label,"dc":int(p.dc),"done":false}
		if purpose=="concentration":
			if str(a.concentration.get("concentration_id","" )).is_empty():a.concentration.concentration_id=next_id("conc_active_")
			task.concentration_spell=str(a.concentration.get("spell",""));task.concentration_id=str(a.concentration.concentration_id);task.concentration_owner=int(a.get("owner",1));task.concentration_recorded=false
		if not purpose.is_empty():task.purpose=purpose
		state().prompts.append(task)
	while state().prompts.size()>200:state().prompts.pop_front()
	changed()
func submit(a: Dictionary,p: Dictionary,peer: int):
	if not own(a,peer) or not text(p,"kind",30) or not text(p,"note",2000):return
	if peer!=1 and w.session.phase!="table":reject(peer,"Wait for the DM to start the table.");return
	if state().requests.filter(func(q):return q.status=="pending").size()>=100:reject(peer,"The DM's inbox is full. Wait for existing requests to be reviewed.");return
	var targets=p.get("targets",[])
	if not targets is Array or targets.size()>100:return
	if p.kind=="turn_undead" and not targets.is_empty():reject(peer,"Turn Undead has no player target list; the DM reviews affected creatures privately.");return
	var approved=[]
	for id in targets:
		if not id is String:return
		var target=w.actor(id)
		if target.is_empty() or target.scene!=w.data.scene or (peer!=1 and not w.visible(target) and not w.can_control(target,peer)):reject(peer,"Choose only creatures the DM has revealed.");return
		if not approved.has(id):approved.append(id)
	var request={"id":next_id("request_"),"actor":a.id,"peer":peer,"kind":p.kind,"session":str(w.session.get("lite_id","offline")),"note":p.note,"targets":approved,"status":"pending","label":"","details":"","formula":"","slot":0,"feature":-1,"item":-1,"mode":"ordinary","proposal":{},"reply":""}
	match p.kind:
		"spell":
			if not text(p,"spell",100):return
			var definition=w.magic.definition(a,p.spell);var known=w.magic.entry(a,p.spell)
			if definition.is_empty() or known.is_empty() or not integer(p,"slot",int(definition.level),9):return
			if not can_cast_in_wild_shape(a,definition):reject(peer,"Wild Shape prevents this spell; only Druids with Beast Spells can propose spells without material components.");return
			if int(definition.level)==0 and int(p.slot)!=0:return
			if definition.get("needs_review",false):reject(peer,"The DM must finish reviewing this imported spell first.");return
			request.spell=p.spell;request.label=definition.name;request.slot=int(p.slot);request.mode=str(p.get("mode","ordinary"))
			if definition.has("area_of_effect") and str(definition.get("range","Self")).strip_edges().to_lower()!="self":
				var has_origin_x=p.has("origin_x");var has_origin_y=p.has("origin_y")
				if has_origin_x!=has_origin_y:reject(peer,"Choose both coordinates for the area origin.");return
				var origin_x=int(a.x);var origin_y=int(a.y)
				if has_origin_x:
					if not integer(p,"origin_x",0,int(w.scene().width)-1) or not integer(p,"origin_y",0,int(w.scene().height)-1):reject(peer,"Choose an area origin inside the current scene.");return
					origin_x=int(p.origin_x);origin_y=int(p.origin_y)
				elif origin_x<0 or origin_x>=int(w.scene().width) or origin_y<0 or origin_y>=int(w.scene().height):reject(peer,"Choose an area origin inside the current scene.");return
				request.origin={"x":origin_x,"y":origin_y}
				if str(definition.area_of_effect.get("type","")) in ["cone","line"] and (p.has("direction_x") or p.has("direction_y")):
					if not integer(p,"direction_x",0,int(w.scene().width)-1) or not integer(p,"direction_y",0,int(w.scene().height)-1):reject(peer,"Choose a direction point inside the current scene.");return
					if int(p.direction_x)==origin_x and int(p.direction_y)==origin_y:reject(peer,"Choose a direction point different from the ranged area origin.");return
					request.direction={"x":int(p.direction_x),"y":int(p.direction_y)}
			elif definition.has("area_of_effect") and str(definition.get("range","Self")).strip_edges().to_lower()=="self" and str(definition.area_of_effect.get("type","")) in ["cone","line","cube"]:
				if p.has("direction_x") or p.has("direction_y"):
					if not integer(p,"direction_x",0,int(w.scene().width)-1) or not integer(p,"direction_y",0,int(w.scene().height)-1):reject(peer,"Choose a direction point inside the current scene.");return
					if int(p.direction_x)==int(a.x) and int(p.direction_y)==int(a.y):reject(peer,"Choose a direction point different from the caster.");return
					request.direction={"x":int(p.direction_x),"y":int(p.direction_y)}
			request.concentration=bool(definition.get("concentration",false));request.concentration_name=str(definition.get("name",request.label));request.concentration_duration=str(definition.get("duration","See spell text"));request.concentration_custom=bool(definition.get("custom",false))
			if request.mode not in ["ordinary","ritual","innate"]:return
			if request.mode=="ritual" and not definition.get("ritual",false):return
			if request.mode=="innate" and int(known.get("uses_max",0))<=0:return
			if request.mode!="ordinary" and request.slot!=int(definition.level):return
			request.details=spell_details(a,definition,request.slot)+"\n\nPrepared on sheet: "+str(known.get("prepared",false))+" · Components confirmed: "+str(p.get("components",false))+" · Casting mode: "+request.mode
			if request.has("origin"):
				request.details+="\n"+("Player-aimed area origin: " if p.has("origin_x") else "Area origin defaults to the caster: ")+w.RULES.column_name(request.origin.x)+str(request.origin.y+1)+" (DM confirms actual targets, spread and cover)."
			if request.has("direction"):
				request.details+="\nPlayer-aimed direction point: "+w.RULES.column_name(request.direction.x)+str(request.direction.y+1)
				request.details+=" (ranged area starts at its recorded origin; DM confirms alignment)." if request.has("origin") else " (area remains centered on the caster; DM confirms alignment)."
			elif definition.has("area_of_effect") and str(definition.get("range","Self")).strip_edges().to_lower()=="self" and str(definition.area_of_effect.get("type","")) in ["cone","line","cube"]:
				request.details+="\nNo direction point submitted; the preview defaults to board-forward and the DM confirms alignment."
			elif definition.has("area_of_effect") and str(definition.area_of_effect.get("type","")) in ["cone","line"]:
				request.details+="\nNo direction point submitted; preview points from the caster toward the selected origin (board-forward if that origin defaults to the caster). The DM confirms alignment."
			request.formula=w.magic.formula(definition,a,request.slot,w.magic.mode(definition)=="heal")
		"attack":
			var profiles=w.attack_profiles(a)
			if not integer(p,"index",0,profiles.size()-1):return
			var profile=profiles[int(p.index)];request.label=str(profile.label);request.formula=str(profile.damage);request.details=R.signed_n(int(profile.bonus))+" to hit · "+str(profile.damage)+" · "+w.COMBAT.summary(profile)+". DM decides hit, critical, damage and riders."
		"action":
			if p.get("action","") not in ACTIONS:return
			request.label=p.action;request.details=ACTIONS[p.action]
		"cunning_action":
			if p.get("action","") not in ["Dash","Disengage","Hide"] or str(a.get("class",""))!="Rogue" or int(a.get("level",0))<2:return
			request.label="Cunning Action · "+str(p.action);request.details="2014 Rogue Cunning Action: propose "+str(p.action)+" as a bonus action. The DM verifies Rogue-level eligibility (including multiclass), circumstances and outcome; no movement, hiding state or other result is applied automatically."
		"lay_on_hands":
			if not lay_on_hands_eligible(a) or not integer(p,"amount",1,lay_on_hands_remaining(a)) or approved.size()!=1:return
			request.target=str(approved[0]);request.amount=int(p.amount);request.label="Lay on Hands · "+str(w.actor(request.target).get("name","creature"));request.details="2014 Paladin Lay on Hands · proposed "+str(request.amount)+" HP for "+str(w.actor(request.target).get("name","creature"))+" (currently "+str(w.actor(request.target).hp)+" / "+str(w.actor(request.target).max_hp)+" HP). Pool: "+str(lay_on_hands_remaining(a))+" / "+str(lay_on_hands_max(a))+". The DM chooses a target and amount; effective healing cannot exceed the remaining pool or missing HP. The 2014 SRD excludes Undead and Constructs. Disease and poison cures are not supported in this slice."
		"bardic_inspiration_assign":
			if not bardic_eligible(a) or not integer(p,"index",0,a.features.size()-1) or a.features[int(p.index)].get("name","")!="Bardic Inspiration" or int(a.features[int(p.index)].get("remaining",0))<=0 or approved.size()!=1:return
			var target=w.actor(approved[0])
			if target.id==a.id or not target.get("hero",false) or not w.visible(target) or not target.get("bardic_inspiration",{}).is_empty():reject(peer,"Choose another visible hero without an active Bardic Inspiration die.");return
			request.feature=int(p.index);request.target=target.id;request.label="Bardic Inspiration · "+str(target.name);request.details="2014 Bardic Inspiration · "+bardic_die(int(a.level))+" · bonus action. DM confirms this other visible hero is within 60 feet and can hear the Bard. Die expires after 10 minutes (DM-tracked); a creature can hold only one Bardic Inspiration die. Approval spends one use; no roll or outcome is applied."
		"bardic_inspiration_use":
			if a.get("bardic_inspiration",{}).is_empty() or not text(p,"roll_id",100) or not integer(p,"die_roll",1,12):return
			var status=a.bardic_inspiration;var die_size=int(status.get("sides",0));var roll=find_roll(str(p.roll_id))
			if die_size not in [6,8,10,12] or int(p.die_roll)>die_size or roll.is_empty() or roll.actor!=a.id or int(roll.peer)!=peer or str(roll.get("session",""))!=str(w.session.get("lite_id","offline")) or not eligible_bardic_roll(roll):reject(peer,"Choose your own recent ability check, attack or saving throw roll and a result within the stored die.");return
			request.roll_id=str(p.roll_id);request.die_roll=int(p.die_roll);request.label="Bardic Inspiration · "+str(roll.label);request.details="2014 Bardic Inspiration use · stored "+str(status.get("die","d"+str(die_size)))+" from "+str(status.get("source_name","the Bard"))+". Player-supplied die result: "+str(request.die_roll)+"; original d20 result: "+str(roll.result.total)+". DM verifies the check/attack/save has not been resolved and decides whether to consume this die. No total or outcome is changed automatically."
		"second_wind":
			var feature_index=second_wind_feature(a)
			if not second_wind_eligible(a) or not integer(p,"index",0,a.features.size()-1) or int(p.index)!=feature_index or feature_index<0 or not integer(p,"die_roll",1,10) or int(a.features[feature_index].get("remaining",0))<=0 or int(a.hp)>=int(a.max_hp):return
			request.feature=feature_index;request.die_roll=int(p.die_roll);request.target=a.id;request.label="Second Wind · "+str(a.name);request.details="2014 Fighter Second Wind · bonus action on your turn. Player-supplied d10 result: "+str(request.die_roll)+"; maximum proposed healing is "+str(request.die_roll+int(a.level))+" HP (Fighter level "+str(a.level)+"). DM verifies turn eligibility, chooses exact HP restored up to this roll plus Fighter level and missing HP, and explicitly spends one use. Short or long rest restores the use. No healing or use is applied before approval."
		"monk_ki":
			var submit_ki_index=monk_ki_feature(a);var technique=str(p.get("technique",""))
			if not monk_ki_eligible(a):return
			if submit_ki_index<0 or int(a.features[submit_ki_index].get("remaining",0))<=0 or technique not in ["Flurry of Blows","Patient Defense","Step of the Wind · Dash","Step of the Wind · Disengage"]:return
			request.feature=submit_ki_index;request.technique=technique;request.label="Ki · "+technique
			match technique:
				"Flurry of Blows":request.details="2014 Monk Flurry of Blows · after you take the Attack action on your turn, spend 1 Ki to make two unarmed strikes as a bonus action. DM confirms the Attack action and timing. Lite does not make attacks, roll hits or apply damage."
				"Patient Defense":request.details="2014 Monk Patient Defense · bonus action on your turn; spend 1 Ki to take the Dodge action. DM confirms timing and adjudicates its effects; Lite does not set Dodge or change attacks."
				_:request.details="2014 Monk Step of the Wind · bonus action on your turn; spend 1 Ki to take the "+("Dash" if technique.ends_with("Dash") else "Disengage")+" action and double your jump distance for the turn. DM confirms timing and adjudicates movement/action; Lite changes no movement allowance, jump or outcomes."
			request.details+=" Ki pool: "+str(a.features[submit_ki_index].get("remaining",0))+" / "+str(a.level)+". DM approval spends exactly 1 Ki; no effect is applied automatically. Short/long rest recovery requires at least 30 minutes of meditation during the rest, confirmed by the DM."
		"turn_undead":
			var feature_index=turn_undead_feature(a)
			if not turn_undead_eligible(a) or feature_index<0 or not approved.is_empty():return
			request.feature=feature_index;request.label="Channel Divinity · Turn Undead";request.details="2014 Cleric Channel Divinity: Turn Undead · action. Present a holy symbol and speak a prayer. Each undead that can see or hear you within 30 feet makes a Wisdom saving throw against your Cleric spell save DC ("+str(w.magic.dc(a))+"). On a failed save, it is turned for 1 minute or until it takes any damage. A turned creature must spend turns moving as far away as possible, cannot willingly move within 30 feet, cannot take reactions, and can use only Dash or attempt to escape an effect that prevents movement; if it cannot move, it may Dodge. DM privately checks visibility, creature type, distance and each result. Lite does not identify targets, roll saves or apply effects. Approval spends exactly one Channel Divinity use."
		"feature":
			if not integer(p,"index",0,a.features.size()-1):return
			request.feature=int(p.index);request.label=a.features[request.feature].name
			if request.label=="Rage":
				if str(a.get("class",""))!="Barbarian" or not str(a.get("multiclass","")).is_empty() or not a.get("rage_state",{}).is_empty() or int(a.features[request.feature].get("remaining",0))<=0:return
				var damage_bonus=rage_damage_bonus(int(a.get("level",1)))
				request.details="2014 Rage status proposal (bonus action). If the DM approves, mark Rage active and spend one use. While active and not wearing heavy armor: advantage on Strength checks and Strength saving throws; +"+str(damage_bonus)+" damage on melee weapon attacks using Strength (by Barbarian level); resistance to bludgeoning, piercing and slashing damage; cannot cast spells or concentrate. Rage lasts up to 1 minute and can end early if incapacitated or if your turn ends without attacking a hostile creature or taking damage. Lite records status only: the DM adjudicates every roll, attack, damage amount, armor restriction and duration, then explicitly ends the state."
			else:request.details=str(a.features[request.feature].get("description",a.features[request.feature].get("notes","")))+" · "+str(a.features[request.feature].remaining)+" / "+str(a.features[request.feature].max)+" uses; recharge "+str(a.features[request.feature].recharge)
		"item":
			if not integer(p,"index",0,a.inventory_items.size()-1):return
			request.item=int(p.index);var item=a.inventory_items[request.item];request.label=item.name;request.details=item.notes+" · quantity "+str(item.quantity)
		"rest":
			if p.get("rest","") not in ["short","long"]:return
			request.label=p.rest.capitalize()+" rest";request.rest=p.rest;request.details="DM confirms eligibility and applies recovery. Short: at least 1 hour. Long: at least 8 hours, at least 1 HP at start, at most once per 24 hours."
		"manual":request.label="Describe an intention";request.details="DM adjudication / homebrew request."
		"wild_shape":
			if not dire_wolf_eligible(a) or not a.get("wild_shape",{}).is_empty():return
			request.label="Wild Shape · Dire Wolf";request.details="Supported form: Dire Wolf CR 1 (2014 rules). "+("Circle of the Moon: level 2+ is eligible for this CR 1 form; this feature slice supports only Dire Wolf." if str(a.get("subclass",""))=="Circle of the Moon" else "Standard Wild Shape: single-class Druid level 8+ for this CR 1 form.")+" DM must confirm this form has been seen and rule whether gear melds or falls. Maximum duration is half your Druid level, rounded down (1 hour at level 2; 4 hours at level 8). "+("Archdruid grants unlimited uses at Druid level 20; no charge is spent." if int(a.get("level",0))>=20 else "Wild Shape uses one feature charge.")+" The DM decides when the form takes effect. Other forms and homebrew eligibility are not implemented. Bite: +3 Strength modifier plus the higher of Druid/beast proficiency; 2d6+3 piercing. On a hit, DM may resolve the local SRD DC 13 Strength save or prone rider."
		"wild_revert":
			if not a.hero or a.get("wild_shape",{}).is_empty():return
			request.label="Revert from Wild Shape";request.details="The DM restores the original sheet and records any damage exceeding remaining Dire Wolf HP as damage to the original form. DM approval required."
		_:return
	state().requests.append(request)
	while state().requests.size()>200:
		var index=state().requests.find_custom(func(q):return q.status!="pending")
		if index<0:break
		state().requests.remove_at(index)
	changed()
func spell_details(a: Dictionary,s: Dictionary,slot: int) -> String:
	var result=str(s.name)+" · "+("Cantrip" if int(s.level)==0 else "Level "+str(s.level)+" / proposed slot "+str(slot))+"\n"+str(s.casting_time)+" · Range "+str(s.range)+" · "+str(s.duration)+(" · Concentration" if s.get("concentration",false) else "")+(" · Ritual available" if s.get("ritual",false) else "")
	result+="\nComponents: "+", ".join(s.get("components",[]))+" · "+str(s.get("material",""))
	if s.has("dc"):result+="\nSaving throw: "+str(s.dc.get("dc_type",{}).get("name",""))+" DC "+str(w.magic.dc(a))+" · On success: "+str(s.dc.get("dc_success","See spell text"))
	if s.has("attack_type"):result+="\nSpell attack: "+R.signed_n(w.magic.attack_bonus(a))+" · "+str(s.attack_type)
	if s.has("area_of_effect"):
		var area_size=float(s.area_of_effect.get("radius",s.area_of_effect.size)) if str(s.area_of_effect.type)=="cylinder" else float(s.area_of_effect.size)
		result+="\nArea: "+str(int(area_size))+" ft "+str(s.area_of_effect.type)
		if s.area_of_effect.has("height"):result+=" · height "+str(s.area_of_effect.height)+" ft"
		elif str(s.area_of_effect.type)=="cylinder":result+=" · height unspecified in the spell data"
		if s.area_of_effect.has("width"):result+=" · width "+str(s.area_of_effect.width)+" ft"
	var formula=w.magic.formula(s,a,slot,w.magic.mode(s)=="heal")
	if not formula.is_empty():result+="\nProposed dice: "+formula+" · The DM chooses who is affected and the amount to apply."
	for section in ["desc","higher_level"]:
		for line in s.get(section,[]):result+="\n\n"+str(line)
	return result.left(30000)
func find_request(id: String) -> Dictionary:
	for request in state().requests:
		if request.id==id:return request
	return {}
func find_roll(id: String) -> Dictionary:
	for roll in state().rolls:
		if roll.id==id:return roll
	return {}
func eligible_bardic_roll(roll: Dictionary) -> bool:
	var label=str(roll.get("label","")).to_lower();var dice=roll.get("result",{}).get("dice",[])
	return (label.contains("check") or label.contains("attack") or label.contains("save") or R.SKILLS.has(str(roll.get("label","")))) and dice is Array and dice.any(func(d):return int(d.get("sides",0))==20)
func proposal_roll(p: Dictionary):
	var request=find_request(str(p.get("request","")))
	if request.is_empty() or request.status!="pending" or not request.proposal.is_empty():return
	var result=roll_expression(str(request.formula))
	if not result.ok:reject(1,"Enter a manual amount; this intention has no supported damage/healing expression.");return
	request.proposal=result;record_roll(w.actor(request.actor),request.label+" · proposed dice",result,1,request.id);changed()
func end_rage(a: Dictionary):
	if a.is_empty() or not a.get("hero",false) or a.get("rage_state",{}).is_empty():return
	w.history.append(w.data.duplicate(true));a.erase("rage_state");public_event("The DM ended Rage for "+str(a.name)+".");changed()
func clear_bardic(a: Dictionary,p: Dictionary):
	if a.is_empty() or not a.get("hero",false) or a.get("bardic_inspiration",{}).is_empty() or not p.get("confirm_expired",false) is bool or not p.confirm_expired:return
	w.history.append(w.data.duplicate(true));a.erase("bardic_inspiration");public_event("The DM cleared an expired Bardic Inspiration die for "+str(a.name)+".");changed()
func resolve(p: Dictionary):
	var request=find_request(str(p.get("request","")))
	if request.is_empty() or request.status!="pending" or not p.get("accept") is bool or not text(p,"reply",2000):return
	var a=w.actor(request.actor)
	if a.is_empty():return
	var effects=p.get("effects",[]);var consume=bool(p.get("consume",false));var seen={}
	if not effects is Array or effects.size()>100:return
	# Validate the complete decision before changing any HP, conditions or resources.
	for effect in effects:
		if not effect is Dictionary or not text(effect,"id",100) or seen.has(effect.id) or w.actor(effect.id).is_empty() or w.actor(effect.id).scene!=w.data.scene:return
		seen[effect.id]=true
		if effect.get("operation","") not in ["Damage","Half damage","Healing","No effect"] or not integer(effect,"amount",0,9999):return
		if effect.get("condition","")!="" and effect.condition not in R.CONDITIONS:return
		if effect.operation in ["Damage","Half damage"] and not w.actor(effect.id).get("wild_shape",{}).is_empty() and int(w.actor(effect.id).hp)==0 and int(effect.amount)>0:reject(1,"Resolve the zero-HP Wild Shape reversion before applying more damage.");return
	if p.accept and (consume or request.kind=="wild_shape" or request.kind=="wild_revert" or request.kind=="turn_undead" or request.kind=="monk_ki" or (request.kind=="feature" and request.label=="Rage") or request.kind in ["bardic_inspiration_assign","bardic_inspiration_use"]):
		if request.kind=="monk_ki":
			var approval_ki_index=monk_ki_feature(a)
			if not consume or not monk_ki_eligible(a) or approval_ki_index<0 or request.feature!=approval_ki_index or request.technique not in ["Flurry of Blows","Patient Defense","Step of the Wind · Dash","Step of the Wind · Disengage"] or int(a.features[approval_ki_index].get("remaining",0))<=0 or not effects.is_empty():reject(1,"This Ki proposal is stale or no Ki remains. Approve only by spending one point; Lite applies no action or outcome.");return
		if request.kind=="turn_undead":
			var channel_index=turn_undead_feature(a)
			if not turn_undead_eligible(a) or channel_index!=int(request.feature) or channel_index<0 or str(a.features[channel_index].get("name",""))!="Channel Divinity":reject(1,"Turn Undead is stale or no Channel Divinity use remains; no use was spent.");return
			if not consume or not effects.is_empty():reject(1,"Approve Turn Undead only by spending one use; this review cannot apply targets or outcomes.");return
		if request.kind=="wild_shape":
			if not dire_wolf_eligible(a) or not a.get("wild_shape",{}).is_empty() or not p.get("confirm_seen",false) or p.get("gear_ruling","") not in ["melded","fell"]:reject(1,"Confirm a supported level-eligible Druid, seen form and gear ruling before approving.");return
			var archdruid=int(a.get("level",0))>=20
			if archdruid and consume:reject(1,"Archdruid has unlimited Wild Shape uses; do not spend a feature charge.");return
			if not archdruid:
				if not consume:reject(1,"Spend a Wild Shape use before approving.");return
				var feature=-1
				for i in a.get("features",[]).size():
					if a.features[i].get("name","")=="Wild Shape":feature=i;break
				if feature<0 or int(a.features[feature].get("remaining",0))<=0:reject(1,"No Wild Shape uses remain.");return
		if request.kind=="wild_revert" and a.get("wild_shape",{}).is_empty():reject(1,"This character is not transformed.");return
		if request.kind=="spell":
			var known=w.magic.entry(a,str(request.get("spell","")))
			if known.is_empty():reject(1,"The spell is no longer on this sheet. Resolve without spending or decline.");return
			if consume and request.mode=="innate" and int(known.get("uses",0))<=0:reject(1,"No innate uses remain. Resolve without spending or decline.");return
			if consume and request.mode=="ordinary" and request.slot>0 and int(a.slots[int(request.slot)-1])<=0:reject(1,"No selected slots remain. Resolve without spending or decline.");return
		if request.kind=="feature" and (request.feature>=a.features.size() or a.features[int(request.feature)].name!=request.label or int(a.features[int(request.feature)].remaining)<=0):reject(1,"This feature changed or has no uses remaining.");return
		if request.kind=="feature" and request.label=="Rage" and (str(a.get("class",""))!="Barbarian" or not str(a.get("multiclass","")).is_empty() or not a.get("rage_state",{}).is_empty()):reject(1,"Rage is no longer eligible or is already active.");return
		if request.kind=="feature" and request.label=="Rage" and not consume:reject(1,"Spend one Rage use to approve the active status.");return
		if request.kind=="item" and (request.item>=a.inventory_items.size() or a.inventory_items[int(request.item)].name!=request.label or int(a.inventory_items[int(request.item)].quantity)<=0):reject(1,"This item changed or is no longer available.");return
		if request.kind=="bardic_inspiration_assign":
			if not consume or not bardic_eligible(a) or request.feature>=a.features.size() or a.features[int(request.feature)].get("name","")!="Bardic Inspiration" or int(a.features[int(request.feature)].get("remaining",0))<=0:reject(1,"Bardic Inspiration is no longer available; spend one use to approve or decline.");return
			var recipient=w.actor(str(request.get("target","")))
			if recipient.is_empty() or recipient.scene!=w.data.scene or recipient.id==a.id or not recipient.get("hero",false) or not w.visible(recipient) or not recipient.get("bardic_inspiration",{}).is_empty() or not p.get("confirm_heard_60ft",false):reject(1,"Confirm another visible hero within 60 feet who can hear the Bard and has no active die.");return
		if request.kind=="bardic_inspiration_use":
			var status=a.get("bardic_inspiration",{});var roll=find_roll(str(request.get("roll_id","")))
			if not consume or status.is_empty() or int(request.get("die_roll",0))>int(status.get("sides",0)) or roll.is_empty() or roll.actor!=a.id or int(roll.peer)!=int(request.peer) or str(roll.get("session",""))!=str(w.session.get("lite_id","offline")) or not eligible_bardic_roll(roll):reject(1,"The die or qualifying unresolved player roll changed; confirm consuming the stored die or decline.");return
	if p.accept and request.kind=="lay_on_hands":
		if not lay_on_hands_eligible(a) or lay_on_hands_remaining(a)<=0:reject(1,"Lay on Hands is no longer available for this single-class Paladin.");return
		if not text(p,"heal_target",100) or not integer(p,"heal_amount",0,lay_on_hands_remaining(a)):return
		if p.has("allow_homebrew_type") and not p.get("allow_homebrew_type") is bool:return
		var heal_target=w.actor(str(p.heal_target))
		if heal_target.is_empty() or heal_target.scene!=w.data.scene:reject(1,"Choose a current-scene creature for the DM-approved healing decision.");return
		if heal_target.get("dead",false):reject(1,"Lay on Hands cannot restore a dead creature.");return
		if lay_on_hands_type_restricted(heal_target) and not p.get("allow_homebrew_type",false):reject(1,"The 2014 SRD bars Lay on Hands healing for Undead and Constructs; the DM must explicitly approve a homebrew override.");return
	if p.accept and request.kind=="second_wind":
		var feature_index=second_wind_feature(a)
		if not second_wind_eligible(a) or feature_index<0 or request.feature!=feature_index or request.get("target","")!=a.id or int(a.features[feature_index].get("remaining",0))<=0 or int(request.get("die_roll",0)) not in range(1,11) or int(a.hp)>=int(a.max_hp):reject(1,"Second Wind is no longer eligible, has no missing HP, or has no remaining use.");return
		if not consume:reject(1,"Spend one Second Wind use to approve healing.");return
		var max_heal=mini(int(request.die_roll)+int(a.level),maxi(0,int(a.max_hp)-int(a.hp)))
		if not text(p,"heal_target",100) or str(p.heal_target)!=a.id or not integer(p,"heal_amount",1,max_heal):reject(1,"Second Wind must restore at least 1 HP and cannot exceed the submitted d10 plus Fighter level or missing HP.");return
		if a.get("dead",false):reject(1,"Second Wind cannot restore a dead character.");return
	if request.kind=="rest" and p.has("confirm_ki_meditation") and not p.confirm_ki_meditation is bool:return
	var approved_concentration={}
	if p.accept and request.kind=="spell":
		var concentration_spell=w.magic.definition(a,str(request.get("spell","")))
		var tracks_concentration=bool(request.get("concentration",concentration_spell.get("concentration",false)))
		if tracks_concentration:
			var confirm_concentration=p.get("confirm_concentration",false)
			if p.has("confirm_concentration") and not confirm_concentration is bool:
				reject(1,"The concentration decision must be an explicit boolean.")
				return
			if confirm_concentration:
				if w.magic.entry(a,str(request.get("spell",""))).is_empty():
					reject(1,"The spell is no longer on this sheet; concentration cannot be activated.")
					return
				if not p.has("consume") or not p.consume is bool:
					reject(1,"Confirm whether the selected slot or innate use is spent or explicitly waived before activating concentration.")
					return
				var selected_targets=[]
				for effect in effects:
					selected_targets.append(str(effect.id))
				var spell_is_custom=bool(request.get("concentration_custom",concentration_spell.get("custom",false)))
				var spell_name=str(request.get("concentration_name",concentration_spell.get("name",request.label)))
				var hunter_mark=(str(request.get("spell",""))=="huntersmark" or spell_name.to_lower().replace("'","").replace(" ","")=="huntersmark") and not spell_is_custom
				if hunter_mark:
					if selected_targets.size()!=1:reject(1,"Hunter's Mark requires exactly one DM-selected target.");return
					var marked=w.actor(selected_targets[0])
					if marked.is_empty() or marked.scene!=w.data.scene or not w.visible(marked):reject(1,"Hunter's Mark target must be a creature visible to the caster in the current scene.");return
				var duration_source={"name":spell_name,"duration":str(request.get("concentration_duration",concentration_spell.get("duration","See spell text"))),"custom":spell_is_custom}
				var effective_duration=concentration_duration(str(request.get("spell","")),duration_source,int(request.get("slot",1)))
				var cost_expected=request.mode=="innate" or (request.mode=="ordinary" and int(request.get("slot",0))>0)
				approved_concentration={"spell":spell_name,"targets":selected_targets,"duration":effective_duration,"dm_tracked":true,"cost_waived":cost_expected and not consume,"custom":spell_is_custom,"concentration_id":next_id("conc_active_")}
	w.history.append(w.data.duplicate(true))
	if p.accept:
		if not approved_concentration.is_empty():
			w.magic.end_concentration(a)
			a.concentration=approved_concentration
			if not a.conditions.has("Concentrating"):a.conditions.append("Concentrating")
		if request.kind=="bardic_inspiration_assign" and consume:
			var recipient=w.actor(str(request.target));recipient.bardic_inspiration={"die":bardic_die(int(a.level)),"sides":int(bardic_die(int(a.level)).substr(1)),"source":a.id,"source_name":str(a.name),"rules":"2014","expires":"DM-tracked 10 minutes"}
			for i in a.features.size():
				if i==int(request.feature):a.features[i].remaining-=1;break
		elif request.kind=="bardic_inspiration_use" and consume:
			a.erase("bardic_inspiration")
		elif request.kind=="second_wind" and consume:
			a.features[int(request.feature)].remaining-=1
			for pending in state().requests:
				if pending.id!=request.id and pending.actor==a.id and pending.kind=="second_wind" and pending.status=="pending":pending.status="declined";pending.reply="Another Second Wind request was approved."
		elif request.kind=="monk_ki" and consume:
			a.features[int(request.feature)].remaining-=1
			for pending in state().requests:
				if pending.id!=request.id and pending.actor==a.id and pending.kind=="monk_ki" and pending.status=="pending":pending.status="declined";pending.reply="Another Ki proposal was approved."
		if request.kind=="wild_shape":
			var original={};var absent=[];var original_speed=float(a.get("speed",0))
			for field in ["hp","max_hp","ac","speed","abilities","weapon","attack","damage","attack_profiles","token_size","size_category","skill_bonuses","save_bonuses","save_profs","skills"]:
				if a.has(field):original[field]=a[field].duplicate(true) if a[field] is Array or a[field] is Dictionary else a[field]
				else:absent.append(field)
			a.wild_shape={"form":"dire-wolf","original":original,"absent":absent,"seen_by_dm":true,"gear_ruling":str(p.gear_ruling),"duration_hours":floori(float(a.level)/2.0),"overflow_pending":0}
			a.max_hp=37;a.hp=37;a.ac=14;a.speed=50;a.abilities[0]=17;a.abilities[1]=15;a.abilities[2]=15;a.weapon="Bite";var wolf=w.monster_lookup.get("dire-wolf",{});a.attack=3+maxi(R.proficiency(a.level),int(wolf.get("proficiency_bonus",2)));a.damage="2d6+3";a.attack_profiles=w.COMBAT.monster_profiles(wolf)
			rebase_movement_allowance(a,original_speed,float(a.speed))
			for attack_profile in a.attack_profiles:
				if attack_profile.get("name","")=="Bite":attack_profile.bonus=a.attack
			a.token_size=2;a.size_category="Large"
			var old_abilities=original.abilities;var new_abilities=a.abilities;var skills=a.get("skill_bonuses",{}).duplicate(true);var wolf_skills={}
			for proficiency in wolf.get("proficiencies",[]):
				var skill_name=str(proficiency.get("proficiency",{}).get("name","")).replace("Skill: ","")
				if skill_name in R.SKILLS:wolf_skills[skill_name]=true
			for skill_name in R.SKILLS:
				var ability=int(R.SKILLS[skill_name]);var original_bonus=int(skills.get(skill_name,R.modifier(old_abilities[ability])+int(a.skills.get(skill_name,0))*R.proficiency(a.level)))
				var effective=original_bonus+R.modifier(new_abilities[ability])-R.modifier(old_abilities[ability])
				if wolf_skills.has(skill_name):effective=maxi(effective,R.modifier(new_abilities[ability])+int(wolf.get("proficiency_bonus",2)))
				skills[skill_name]=effective
			a.skill_bonuses=skills
			var saves=a.get("save_bonuses",{}).duplicate(true)
			for ability in 6:
				var key=R.ABILITIES[ability];var original_bonus=int(saves.get(key,R.modifier(old_abilities[ability])+(R.proficiency(a.level) if a.save_profs.has(ability) else 0)))
				saves[key]=original_bonus+R.modifier(new_abilities[ability])-R.modifier(old_abilities[ability])
			a.save_bonuses=saves
			if int(a.get("level",0))<20:
				for i in a.features.size():
					if a.features[i].get("name","")=="Wild Shape":a.features[i].remaining-=1;break
		elif request.kind=="wild_revert":
			var form=a.wild_shape;var original=form.original;var form_speed=float(a.get("speed",0));var overflow=int(form.get("overflow_pending",0)) if int(a.hp)==0 else 0
			for field in form.get("absent",[]):a.erase(field)
			for field in original:a[field]=original[field].duplicate(true) if original[field] is Array or original[field] is Dictionary else original[field]
			a.hp=maxi(0,int(a.hp)-overflow);a.erase("wild_shape")
			rebase_movement_allowance(a,form_speed,float(a.get("speed",0)))
			if a.hp==0 and not a.conditions.has("Unconscious"):a.conditions.append("Unconscious")
		elif request.kind=="feature" and request.label=="Rage" and consume:
			a.rage_state={"active":true,"source":"DM-approved Rage","rules":"2014","damage_bonus":rage_damage_bonus(int(a.get("level",1)))}
			for pending in state().requests:
				if pending.id!=request.id and pending.actor==a.id and pending.kind=="feature" and pending.label=="Rage" and pending.status=="pending":pending.status="declined";pending.reply="Another Rage request was approved."
		elif request.kind=="turn_undead" and consume:
			a.features[int(request.feature)].remaining-=1
			for pending in state().requests:
				if pending.id!=request.id and pending.actor==a.id and pending.kind=="turn_undead" and pending.status=="pending":pending.status="declined";pending.reply="Another Turn Undead request was approved."
		if consume:
			match request.kind:
				"spell":
					if request.mode=="ordinary" and request.slot>0:a.slots[int(request.slot)-1]-=1
					elif request.mode=="innate":w.magic.entry(a,request.spell).uses-=1
				"feature":a.features[int(request.feature)].remaining-=1
				"second_wind":pass
				"item":a.inventory_items[int(request.item)].quantity-=1
		for effect in effects:
			var target=w.actor(effect.id);var amount=int(effect.amount)
			if effect.operation in ["Damage","Half damage"]:
				if effect.operation=="Half damage":amount=int(amount/2.0)
				var absorbed=mini(int(target.temp),amount);target.temp-=absorbed;var applied=amount-absorbed
				if not target.get("wild_shape",{}).is_empty() and int(target.hp)>0 and applied>=int(target.hp):target.wild_shape.overflow_pending+=applied-int(target.hp)
				target.hp=maxi(0,int(target.hp)-applied)
			elif effect.operation=="Healing":target.hp=mini(int(target.max_hp),int(target.hp)+amount)
			if effect.get("condition","")!="" and not target.conditions.has(effect.condition):target.conditions.append(effect.condition)
		if request.kind=="rest" and consume:
			var recovery_ki_index=monk_ki_feature(a);var ki_before=int(a.features[recovery_ki_index].get("remaining",0)) if recovery_ki_index>=0 else 0;var ki_max_before=int(a.features[recovery_ki_index].get("max",0)) if recovery_ki_index>=0 else 0;var recover_ki=monk_ki_eligible(a) and bool(p.get("confirm_ki_meditation",false))
			w.magic.recover(a,request.rest)
			if recovery_ki_index>=0:
				a.features[recovery_ki_index].max=int(a.level) if recover_ki else ki_max_before
				a.features[recovery_ki_index].remaining=int(a.level) if recover_ki else ki_before
			if request.rest=="long":
				a.hp=a.max_hp;a.slots=a.slots_max.duplicate();a.hit_dice=mini(int(a.level),int(a.hit_dice)+maxi(1,int(a.level)/2));a.death_success=0;a.death_failure=0
				if lay_on_hands_eligible(a):a.lay_on_hands_spent=0
	if p.accept and request.kind=="lay_on_hands":
		var target=w.actor(str(p.heal_target));var missing=0 if target.get("dead",false) else maxi(0,int(target.max_hp)-int(target.hp));var effective=mini(int(p.heal_amount),mini(lay_on_hands_remaining(a),missing))
		if effective>0:w.heal(target,effective);a.lay_on_hands_spent=int(a.get("lay_on_hands_spent",0))+effective
	if p.accept and request.kind=="second_wind":
		var effective=mini(int(p.heal_amount),maxi(0,int(a.max_hp)-int(a.hp)))
		if effective>0:w.heal(a,effective)
	request.status="approved" if p.accept else "declined";request.reply=p.reply
	changed()
func set_order(p: Dictionary):
	if not p.get("order") is Array or p.order.size()>200 or not text(p,"active",100) or not integer(p,"round",1,999):return
	var seen={}
	for id in p.order:
		if not id is String or seen.has(id) or w.actor(id).is_empty():return
		seen[id]=true
	if not p.active.is_empty() and not seen.has(p.active):return
	if state().active!=p.active:reset_movement(p.active)
	state().order=p.order.duplicate();state().active=p.active;state().round=int(p.round);changed()
func token(a: Dictionary) -> Dictionary:
	var copy={"id":a.id,"name":str(a.get("public_name",a.name)),"hero":bool(a.hero),"scene":a.scene,"x":a.x,"y":a.y,"color":a.color,"token_size":a.get("token_size",1),"miniature":a.get("miniature","Auto"),"class":"Hero" if a.hero else "Creature","race":"","weapon":"","damage":"0","notes":"","inventory":"","owner":0,"hp":1,"max_hp":1,"ac":0,"speed":0,"level":1,"attack":0,"hit_die":8,"hit_dice":0,"temp":0,"death_success":0,"death_failure":0,"abilities":[10,10,10,10,10,10],"conditions":[],"skills":{},"save_profs":[],"slots":[0,0,0,0,0,0,0,0,0],"slots_max":[0,0,0,0,0,0,0,0,0],"public_token":true}
	for field in ["appearance","lite_model","elevation_ft"]:
		if a.has(field):copy[field]=a[field].duplicate(true) if a[field] is Array or a[field] is Dictionary else a[field]
	return copy
func snapshot(peer: int) -> Dictionary:
	ensure();w.refresh_rooms()
	var source=w.scene();var copy={"schema":1,"title":w.data.title,"scene":source.id,"actors":[],"scenes":[],"combat":{"active":false,"order":[],"turn":0,"round":1},"journal_dm":"","journal_public":str(w.data.get("journal_public","")),"log":state().events.duplicate(true),"session":w.session.duplicate(true),"lite":{"public":true,"blackout":blackout(),"combat":bool(state().combat),"requests":[],"rolls":[],"prompts":[]}}
	copy.session.erase("requests")
	for a in w.data.actors:
		if a.hero and int(a.owner)==peer:
			var hero=a.duplicate(true)
			hero.erase("dm_notes");hero.effects=[];hero.pending_saves=[];hero.concentration_checks=[]
			var concentration=hero.get("concentration",{})
			if concentration is Dictionary and concentration.has("targets") and concentration.get("targets",[]) is Array:
				var visible_targets=[]
				for target_id in concentration.targets:
					var target=w.actor(str(target_id))
					if not target.is_empty() and target.scene==w.data.scene and w.visible(target):visible_targets.append(target_id)
				concentration.targets=visible_targets
			hero.lite_movement=movement_status(a)
			if a.scene!=w.data.scene or not w.visible(a):hero.scene="offboard";hero.x=0;hero.y=0;hero.erase("last_path")
			copy.actors.append(hero)
		elif a.scene==w.data.scene and w.visible(a):copy.actors.append(token(a))
	var owned=copy.actors.filter(func(a):return int(a.owner)==peer).map(func(a):return a.id)
	for request in state().requests:
		if int(request.peer)==peer and owned.has(request.actor) and str(request.get("session","offline"))==str(w.session.get("lite_id","offline")):copy.lite.requests.append({"id":request.id,"actor":request.actor,"label":request.label,"status":request.status,"reply":request.reply})
	copy.lite.rolls=state().rolls.filter(func(roll):return int(roll.peer)==peer and owned.has(roll.actor) and str(roll.get("session","offline"))==str(w.session.get("lite_id","offline"))).duplicate(true)
	for task in state().prompts:
		if owned.has(task.actor):
			var visible=task.duplicate(true);visible.erase("dc");visible.erase("concentration_spell");visible.erase("concentration_id");visible.erase("concentration_owner");visible.erase("concentration_recorded");visible.erase("concentration_stale");visible.erase("concentration_invalidated")
			if task.get("purpose","")=="concentration":
				visible["label"]="Constitution save · Concentration"
				if not task.get("done",false):
					var prompted_actor=w.actor(str(task.get("actor","")))
					var active_concentration=prompted_actor.get("concentration",{})
					var stale=bool(task.get("concentration_invalidated",false)) or prompted_actor.is_empty() or not active_concentration is Dictionary or active_concentration.is_empty() or not task.has("concentration_spell") or not task.has("concentration_id") or not task.has("concentration_owner")
					if not stale:
						stale=int(task.get("concentration_owner",-1))!=int(prompted_actor.get("owner",-2)) or str(task.get("concentration_spell",""))!=str(active_concentration.get("spell","")) or str(task.get("concentration_id",""))!=str(active_concentration.get("concentration_id",""))
					visible["concentration_stale"]=stale
			copy.lite.prompts.append(visible)
	if blackout():
		copy.scene="obscured";copy.scenes=[{"id":"obscured","name":"The DM has obscured the table","theme":"blank","width":4,"height":4,"tiles":{},"fog":{},"dm_notes":"","image":""}];return copy
	var scene={"id":source.id,"name":source.name,"theme":source.theme,"width":source.width,"height":source.height,"tiles":{},"fog":{},"dm_notes":"","image":"","props":[],"areas":[],"asset_pack":[],"room_visibility":false}
	for area in source.get("areas",[]):
		if scene.areas.size()>=40:break
		if not area is Dictionary:continue
		var shape=str(area.get("shape",""))
		if shape not in ["Circle","Cone","Square","Sphere","Cylinder","Line","Cube"]:continue
		var ax=float(clampi(int(area.get("x",0)),0,int(source.width)-1));var ay=float(clampi(int(area.get("y",0)),0,int(source.height)-1))
		var bx=float(clampi(int(area.get("ex",0)),0,int(source.width)-1));var by=float(clampi(int(area.get("ey",0)),0,int(source.height)-1))
		var min_x=minf(ax,bx);var max_x=maxf(ax,bx);var min_y=minf(ay,by);var max_y=maxf(ay,by)
		var radius=Vector2(bx-ax,by-ay).length()
		if shape=="Circle":min_x=ax-radius;max_x=ax+radius;min_y=ay-radius;max_y=ay+radius
		elif shape=="Cone":min_x-=radius/2;max_x+=radius/2;min_y-=radius/2;max_y+=radius/2
		var all_visible=true
		for x in range(clampi(int(floor(min_x)),0,int(source.width)-1),clampi(int(ceil(max_x)),0,int(source.width)-1)+1):
			for y in range(clampi(int(floor(min_y)),0,int(source.height)-1),clampi(int(ceil(max_y)),0,int(source.height)-1)+1):
				if not w.cell_visible(Vector2i(x,y)):all_visible=false;break
			if not all_visible:break
		if not all_visible:continue
		var visible_area={"id":str(area.get("id","" )).left(80),"shape":shape}
		for field in ["x","y","ex","ey"]:
			visible_area[field]=clampi(int(area.get(field,0)),0,int(source.width if field in ["x","ex"] else source.height)-1)
		scene.areas.append(visible_area)
	for field in ["grid_distance","grid_unit","grid_metric","grid_pixels","grid_offset_x","grid_offset_y","wall_height_ft","preserve_map_art","lighting"]:
		if source.has(field):scene[field]=source[field]
	for x in int(source.width):
		for y in int(source.height):
			var key=w.cell_key(x,y)
			if not w.cell_visible(Vector2i(x,y)):scene.fog[key]=true
	for field in ["tiles","doors_open","surfaces","terrain_blocks","elevations"]:
		scene[field]={}
		for key in source.get(field,{}):
			if not scene.fog.has(key):scene[field][key]=source[field][key]
	var assets={}
	for prop in source.get("props",[]):
		if prop.get("concealed",false):continue
		var rect=w.BUILD.rect(prop,source);var shown=true
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y):
				if not w.cell_visible(Vector2i(x,y)):shown=false
		if shown:var visible=prop.duplicate(true);visible.erase("concealed");scene.props.append(visible);assets[prop.asset]=true
	for asset in source.get("asset_pack",[]):
		if assets.has(asset.id):scene.asset_pack.append(asset.duplicate(true))
	scene.image=redacted_image(source,scene.fog);copy.scenes=[scene];return copy
func redacted_image(source: Dictionary,fog: Dictionary) -> String:
	var encoded=str(source.get("image",""))
	if encoded.is_empty():return ""
	var signature=str([encoded.sha256_text(),fog.hash(),source.width,source.height,source.get("grid_pixels",0),source.get("grid_offset_x",0),source.get("grid_offset_y",0)])
	if image_cache.has(signature):return image_cache[signature]
	var image=Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(encoded))!=OK or image.get_width()>8192 or image.get_height()>8192:return ""
	var safe=Image.create(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8);safe.fill(Color.BLACK);image.convert(Image.FORMAT_RGBA8)
	var calibrated=float(source.get("grid_pixels",0));var scale=Vector2(calibrated,calibrated) if calibrated>0 else Vector2(float(image.get_width())/source.width,float(image.get_height())/source.height)
	var offset=Vector2(source.get("grid_offset_x",0),source.get("grid_offset_y",0)) if calibrated>0 else Vector2.ZERO
	for x in int(source.width):
		for y in int(source.height):
			if fog.has(w.cell_key(x,y)):continue
			var origin=(Vector2(x,y)*scale+offset).ceil();var end=(Vector2(x+1,y+1)*scale+offset).floor()
			var rect=Rect2i(Vector2i(origin),Vector2i(end-origin)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
			if rect.has_area():safe.blit_rect(image,rect,rect.position)
	var png=safe.save_png_to_buffer();var result=Marshalls.raw_to_base64(png) if png.size()<=12582912 else ""
	image_cache={signature:result};return result
