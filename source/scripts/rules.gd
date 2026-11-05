extends RefCounted
class_name Rules5e

const ABILITIES = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const SKILLS = {"Acrobatics":1,"Animal Handling":4,"Arcana":3,"Athletics":0,"Deception":5,"History":3,"Insight":4,"Intimidation":5,"Investigation":3,"Medicine":4,"Nature":3,"Perception":4,"Performance":5,"Persuasion":5,"Religion":3,"Sleight of Hand":1,"Stealth":1,"Survival":4}
const CONDITIONS = {
"Blinded":"Cannot see. Sight-based checks fail. Attacks against you have advantage; your attacks have disadvantage.",
"Charmed":"Cannot attack or harm the charmer. The charmer has advantage on social checks against you.",
"Deafened":"Cannot hear. Hearing-based checks fail.",
"Frightened":"Disadvantage on checks and attacks while the source is in sight. Cannot willingly move closer to it.",
"Grappled":"Speed is 0. Ends if the grappler is incapacitated or an effect separates you. Escape uses an action.",
"Incapacitated":"Cannot take actions or reactions.",
"Invisible":"Cannot be seen without magic or a special sense. Attacks against you have disadvantage; your attacks have advantage. Your location may still be detected.",
"Paralyzed":"Incapacitated, cannot move or speak, automatically fails STR/DEX saves. Attacks against you have advantage. Hits from within 5 feet are critical.",
"Petrified":"Transformed into solid substance; incapacitated and unaware. Automatically fails STR/DEX saves. Attacks against you have advantage. Resistance to all damage; immune to poison and disease.",
"Poisoned":"Disadvantage on attack rolls and ability checks.",
"Prone":"Crawl or spend half your speed to stand. Your attacks have disadvantage. Attacks against you have advantage within 5 feet, disadvantage from farther away.",
"Restrained":"Speed is 0. Your attacks and DEX saves have disadvantage. Attacks against you have advantage.",
"Stunned":"Incapacitated, cannot move, speaks only falteringly. Automatically fails STR/DEX saves. Attacks against you have advantage.",
"Unconscious":"Incapacitated, cannot move or speak, unaware; drops held objects and falls prone. Automatically fails STR/DEX saves. Attacks against you have advantage; hits from within 5 feet are critical.",
"Exhaustion":"2014 levels are cumulative: 1 disadvantage on checks; 2 half speed; 3 disadvantage on attacks/saves; 4 half HP maximum; 5 speed 0; 6 death. A long rest with food and drink removes one level. Track the level in notes.",
"Concentrating":"Not a condition: track one concentration spell. Damage requires a CON save, DC 10 or half the damage taken, whichever is higher. Incapacitation or death ends concentration."
}
const GUIDES = {
"Start here":"You describe what your hero tries. The Dungeon Master (DM) describes the world and decides whether a roll is needed. Most uncertain tasks use a d20 + an ability modifier, with proficiency added when relevant. Meet or beat the difficulty (DC) to succeed. You do not need to memorize the rules.\n\n1. Select a hero in the left roster.\n2. Drag their token on the map. Each square is 5 feet.\n3. Open Character to roll a skill or saving throw.\n4. For a fight, the DM clicks Roll initiative in Combat.\n5. On your turn, move, take one action, and take a bonus action only if a feature grants one.\n\nUse the starter adventure in Journal. The DM can change any result when the story or rules call for it.",
"A turn in combat":"On your turn: move up to your speed, take one action, and use a bonus action if a feature or spell lets you. You also get one reaction, refreshed at the start of your turn. You may split movement around actions.\n\nCommon actions: Attack, Cast a Spell, Dash (extra movement equal to speed), Disengage (movement does not provoke opportunity attacks this turn), Dodge (attacks against you have disadvantage if you can see the attacker; DEX saves have advantage), Help, Hide, Ready, Search, Use an Object.\n\nHearthtable tracks action/bonus/reaction markers as reminders. Range/solid barriers and supported spellcasting timing are checked; class features, opportunity attacks and other condition interactions need the DM. The DM adjudicates these.",
"Checks & saving throws":"Ability check: d20 + ability modifier + proficiency when you have the relevant skill or tool proficiency. Expertise doubles proficiency. Saving throw: d20 + ability modifier + proficiency if proficient in that save.\n\nTypical DCs: 5 very easy, 10 easy, 15 medium, 20 hard, 25 very hard, 30 nearly impossible. A natural 1 or 20 is not automatically a failure or success on an ordinary ability check or save.\n\nPassive Perception = 10 + Perception modifier. Advantage normally adds 5 to a passive score; disadvantage subtracts 5. The sheet shows the baseline.",
"Advantage & disadvantage":"Roll two d20s and keep the higher for advantage, or lower for disadvantage. Several sources do not stack. If both apply, roll one d20, regardless of the number of sources.\n\nSet the roll mode above the dice tray. It applies to sheet checks, saves, basic attacks and death saves. Initiative normally uses a straight DEX check here. Attack rolls also apply supported conditions and ranged penalties automatically; any advantage and disadvantage cancel regardless of source count. The DM sets the roll mode for checks/saves and other situational rulings.",
"Attacking & damage":"Choose an attacker, then a target in Character. A basic attack rolls d20 + attack bonus against target AC. A natural 20 hits and doubles damage dice; a natural 1 misses. Other rolls hit if the total meets or beats AC. Damage modifiers are not doubled on a critical.\n\nHearthtable checks the selected attack’s reach or ranged limit before rolling. Distance uses the closest occupied grid squares of both miniatures and the scene’s configured scale/metric. A Large token does not automatically gain longer reach: each monster attack uses its printed reach. Walls and closed doors block direct attacks. Unknown custom attacks need range configuration in Edit sheet.\n\nRanged attacks beyond normal range have disadvantage, and targets beyond maximum range cannot be attacked. An active hostile creature that can see the attacker within 5 feet also imposes ranged disadvantage, even when another creature is the target. The DM can configure applicable feature exceptions in Edit sheet.\n\nThe Character inspector shows distance, reach/range, the chosen attack and roll modifiers; red means the attack is blocked. No dice, damage or action marker is spent for a rejected attack. Select Bite, Claw, Tail, a bow or a thrown attack separately. Multiattack and Extra Attack composition remain DM-managed; the action marker is a reminder.\n\nSupported attack effects include blinded, poisoned, prone, restrained, invisible, stunned, paralyzed, petrified and unconscious states. Incapacitated attackers cannot attack. Hits against paralyzed/unconscious targets within 5 feet are critical. Special senses and other condition exceptions need DM rulings. The app applies basic damage and temporary HP; resistances, immunity, vulnerability, damage type, saving-throw riders, extra attacks and feature dice remain manual.\n\nHalf cover: +2 AC/DEX saves. Three-quarters cover: +5. Total cover normally prevents direct targeting.",
"Movement & distance":"The default grid is 5 feet per square. Diagonal movement also costs 5 feet per square, using the standard 2014 grid rule. Difficult terrain costs an additional foot per foot. The ruler uses this same grid distance.\n\nDrag miniatures to move. Turn movement is tracked, with a warning when speed is exceeded. The DM can reposition freely for Dash, teleportation or corrections. Players cannot drag through walls or closed doors; move around obstacles in shorter steps.\n\nPaint Wall and Door squares edge to edge to enclose rooms. They join and orient automatically. New construction enables room concealment: heroes share visibility of their rooms, and open doors reveal connected spaces. Closed doors conceal them again. Select + click a door to toggle it; players need an adjacent assigned hero. Grid… contains the room-concealment toggle. Manual fog adds another concealment layer. Light radius, darkvision and difficult terrain remain DM rulings.\n\nShift + drag rotates the isometric camera. Right-drag pans; the wheel zooms; F frames the map.",
"Death saves & 0 HP":"At 0 HP, a hero normally falls unconscious. At the start of their turn, roll a death saving throw: 10+ is a success, otherwise a failure. Three successes stabilize you; three failures mean death. A natural 1 counts as two failures. A natural 20 restores 1 HP. Successes and failures reset when you regain HP or become stable.\n\nDamage at 0 HP causes one failed death save, two if critical. Excess damage at least equal to maximum HP can kill instantly. Basic damage handles these cases. The DM can override the death state in Edit sheet. Stable heroes stay at 0 HP and do not roll death saves until destabilized. Monsters reaching 0 HP are marked defeated by default.",
"Spellcasting":"Open a character’s Spellbook. Add class/racial spells, prepare eligible leveled spells, then choose Cast. Cantrips spend no slots. For a leveled spell, choose a slot of its level or higher; a valid cast ticks that slot off automatically. Configure racial/feat/item casting under Read → Innate / feature uses, then select that option while casting.\n\nChoose targets with the quantity fields. Magic Missile, Eldritch Blast and Scorching Ray allow separate dart/beam allocation. For area spells, draw a map template, then set the origin column/row and choose affected creatures. The app checks range to the origin and the area’s maximum extent; the DM confirms the actual shape, height, coverage and cover. Columns start at 1 (A). Direct targeting checks walls and closed doors.\n\nThe casting dialog states what is automated. Supported spell attacks, damage saves and healing resolve on the host; a player target receives a pending-save button on their sheet. Complex spells spend resources and enter the log for DM resolution. Conditions, resistances/immunities, buffs such as Shield, and secondary effects need DM adjustment. Undo on the host can correct a result.\n\nIn combat, casting checks your action/bonus/reaction, your turn and the original 2014 bonus-action rule: another spell on that turn must be a cantrip with a casting time of 1 action. The DM may reset a marker for a feature/correction. Rituals require a configured ritual-casting class, take 10 extra minutes, use the base spell level and spend no slot; resolve them outside combat. Components, material costs, armor proficiency and reaction triggers require player/DM confirmation.\n\nImported spell DC/attack totals remain fixed unless the DM switches Casting settings to automatic ability + proficiency. Preparation limits have class defaults and a DM override; class access, spells known, study/rest eligibility, multiclass slot pools and class progression need DM review. Custom spells outside the SRD can be entered by the DM.",
"Concentration":"You can concentrate on one spell at a time. Casting another concentration spell replaces the previous one. The sheet displays the active spell, its duration and an End concentration button. The DM applies/removes its ongoing effects.\n\nEach damaging source queues a Constitution saving throw: DC 10 or half the incoming damage rounded down, whichever is higher. Damage absorbed by temporary HP still counts. Roll pending concentration saves on the sheet, using the roll-mode selector for applicable advantage/disadvantage. Failure, incapacitation, 0 HP or death ends the tracked concentration and clears its pending checks.\n\nDuration expiry, effect cleanup, special class features and concentration started with a manually added condition marker require DM handling.",
"Resting":"Short rest: at least 1 hour. Spend Hit Dice on the sheet one at a time to heal for the die + CON modifier (minimum 0). Complete short rest restores counters marked short rest and Warlock Pact Magic slots. Arcane Recovery and other slot-conversion choices need DM adjustment.\n\nLong rest: at least 8 hours under the 2014 rules, with at least 1 HP at the start and no benefit from another long rest in the previous 24 hours. The DM confirms sleep, interruptions, food and eligibility. Restore HP, ordinary slots, eligible feature/innate counters, and half the total Hit Dice rounded down (minimum 1). The rest controls are unavailable during combat. Exhaustion and class exceptions need DM rulings.",
"Building a hero":"Use Import hero PDF… to read a filled D&D Beyond Export to PDF character sheet, or create an editable level-1 starting sheet from a class loadout. Review extracted values before adding a new hero. Scanned and flattened print copies are unsupported. Imported skill/save totals stay fixed until you reimport or disable imported bonuses in Edit sheet.\n\nThe creator makes an editable level-1 starting sheet from a class loadout. The displayed abilities are final scores; adjust them for your chosen race and your DM's creation method. The standard array is 15, 14, 13, 12, 10, 8 before racial changes. A normal human adds 1 to all six.\n\nChoose skill proficiencies, equipment, background and racial traits with your DM. The editor supports final scores, skill proficiency/expertise, save proficiencies, attacks, armor, Hit Dice, slots, notes and inventory. It is a flexible sheet, not a complete automatic class/race/level-up rules engine. Level changes recalculate proficiency; update HP, class features and slots manually.",
"Hosting a table":"The DM opens Session, chooses a UDP port (default 24680) and passphrase, then hosts. Up to eight players run the same version, enter the host address/port/passphrase and join the player lobby. The DM assigns heroes. Players may submit reviewed original D&D Beyond character PDFs for the DM to accept. Ready status tells the DM when guests are set; the DM starts the table.\n\nPlayers control their assigned heroes, including HP, spells, slots, conditions, notes, equipment, limited counters and rolls. The DM controls scenes, creatures, fog, final sheet statistics and campaign saving. Rolls and spell validation run on the host. Only the active scene is transferred. Private DM notes, hidden enemy sheets and other characters’ private sheet text/spellbooks are omitted. Player room visibility is shared by the party.\n\nFor internet play, forward the selected UDP port on the DM’s router to the host computer’s LAN IPv4 address and allow the same port in Windows Firewall. Friends outside the LAN join the DM’s public IPv4/hostname and that port. LAN guests use the LAN address. Session → Internet / port-forwarding setup explains the steps and carrier-grade NAT limitations.\n\nThere is no relay, account service, voice/video or transport encryption. Invite trusted players. Router configuration is manual. LAN/loopback networking has been tested; the user’s internet/router path requires an external connection test. Disconnect restores the player’s original local campaign.",
"About & licenses":"Hearthtable 0.6 • A native Godot desktop tabletop for original 2014 fifth edition.\n\nThis work includes material taken from the System Reference Document 5.1 (\"SRD 5.1\") by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode.\n\nRules and stat blocks are adapted and summarized for this application. Original adventure, interface, maps and code were created for Hearthtable. Includes 2014 SRD JSON adapted from 5e-bits/5e-database; see THIRD_PARTY_NOTICES.txt. Godot is MIT licensed. Inter uses the SIL Open Font License. 3D assets by Kenney and Kay Lousberg (KayKit) are CC0. Hearthtable is independent and unaffiliated with virtual tabletop or game publishers."
}

static func modifier(score: int) -> int:
	return int(floor((score - 10) / 2.0))

static func proficiency(level: int) -> int:
	return 2 + int(floor((clampi(level,1,20)-1)/4.0))

static func signed_n(n: int) -> String:
	return ("+" if n >= 0 else "") + str(n)

static func roll(expression: String, critical: bool = false) -> Dictionary:
	var text = expression.to_lower().replace(" ", "")
	if text.is_valid_int() and int(text)>=0 and int(text)<=9999:return {"ok":true,"total":int(text),"dice":[],"bonus":int(text),"expression":expression,"sides":0}
	var regex = RegEx.new()
	regex.compile("^([0-9]{1,2})d([0-9]{1,3})([+-][0-9]{1,3})?$")
	var m = regex.search(text)
	if m == null:
		return {"ok":false,"error":"Use NdS+M (2d6+3) or a fixed amount (1). 1–40 dice, 2–100 sides."}
	var count = int(m.get_string(1))
	var sides = int(m.get_string(2))
	var bonus = int(m.get_string(3)) if m.get_string(3) != "" else 0
	if count < 1 or count > 40 or sides < 2 or sides > 100:
		return {"ok":false,"error":"Dice limits: 1–40 dice; 2–100 sides."}
	if critical: count *= 2
	var values: Array = []
	var total = bonus
	for i in count:
		var value = randi_range(1,sides)
		values.append(value)
		total += value
	return {"ok":true,"total":total,"dice":values,"bonus":bonus,"expression":expression,"sides":sides}

static func d20(bonus: int, mode: int = 0) -> Dictionary:
	var a = randi_range(1,20)
	var b = randi_range(1,20) if mode != 0 else a
	var natural = maxi(a,b) if mode == 1 else mini(a,b) if mode == 2 else a
	return {"natural":natural,"total":natural+bonus,"dice":[a,b] if mode != 0 else [a],"bonus":bonus}

static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x-b.x),absi(a.y-b.y))*5


static func grid_distance(a: Vector2i,b: Vector2i,cell_units: float=5.0,metric: String="5e") -> float:
	var delta=(a-b).abs()
	if metric=="euclidean":return Vector2(delta).length()*cell_units
	if metric=="5105":return (maxi(delta.x,delta.y)+floor(mini(delta.x,delta.y)/2.0))*cell_units
	return maxi(delta.x,delta.y)*cell_units

static func column_name(index: int) -> String:
	var result=""
	var n=index+1
	while n>0:
		n-=1;result=String.chr(65+n%26)+result;n=int(n/26)
	return result
