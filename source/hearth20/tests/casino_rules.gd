extends SceneTree
var checks=0
var errors=[]
var rng=RandomNumberGenerator.new()
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error("FAIL: "+label)
func fixture() -> Dictionary:
	var c=Hearth20Identity.new_campaign("Synthetic casino")
	for i in 3:
		var a=Hearth20TokenInventory.new_actor("Adventurer "+str(i+1),true,c.scenes[0],Vector2(.5,.5));a.id="hero-"+str(i);a.owner_player_id="player-"+str(i);a.coins={"gp":25};c.actors.append(a)
	return c
func act(c: Dictionary, who: String, action: String, extra: Dictionary={}) -> Dictionary:
	var g=c.get("tavern_game",{});var command={"action":action,"game_id":g.get("id",""),"revision":g.get("revision",0)};command.merge(extra);return Hearth20TavernGames.apply(c,who,command,rng)
func table(c: Dictionary, n: int=3) -> void:
	expect(act(c,"dm-local","open",{"chip_cp":10}).ok,"DM opens gold-backed table")
	for i in n:
		expect(act(c,"player-"+str(i),"join",{"actor_id":"hero-"+str(i)}).ok,"player takes own seat")
		expect(act(c,"player-"+str(i),"ready",{"actor_id":"hero-"+str(i)}).ok,"player readies buy-in")
	expect(act(c,"dm-local","start").ok,"DM deals ready seats")
func run() -> void:
	rng.seed=398434
	var sheet=Hearth20CharacterImport.new().from_fields({"CharacterName":"Synthetic arriving cleric","CLASS LEVEL":"Cleric 3","STR":"13","DEX":"12","CON":"17","INT":"12","WIS":"18","CHA":"12","ProfBonus":"2","AC":"18","MaxHP":"30","CurrentHP":"30","Speed":"25","GP":"25","AdditionalSenses":"Darkvision 300 ft."}).sheet
	var c=Hearth20Identity.new_campaign();var key=Hearth20PlayerProfile.public_key();var player=Hearth20PlayerProfile.principal(key);c.participants[player]={"public_key":key,"display_name":"Returning player"}
	var image=Image.create(48,48,false,Image.FORMAT_RGBA8);image.fill(Color.CORAL);var png=image.save_png_to_buffer()
	expect(not Hearth20JoinCharacter.submit(c,"impostor",sheet,png).ok,"unauthenticated submission rejected")
	var forged=sheet.duplicate(true);forged.coins.gp=999;expect(not Hearth20JoinCharacter.submit(c,player,forged,png).ok and c.actors.is_empty(),"first-join purse must match printed source fields")
	var joined=Hearth20JoinCharacter.submit(c,player,sheet,png);expect(joined.ok,"first connection character accepted: "+str(joined))
	if not joined.ok:quit(1);return
	var a=Hearth20Contracts.find_actor(c,joined.get("id",""));expect(a.get("in_inventory",false) and a.get("owner_player_id","")==player and a.token_size==1.0,"unique owned size-one character lands in DM inventory")
	expect(a.movement_policy.mode=="blocked" and a.vision.darkvision_feet==300 and a.coins.gp==25,"sheet gold, senses and blocked movement retained")
	expect(Hearth20Assets.read_asset(c,a.png_asset_id,"token")==png,"chosen PNG bytes are self-contained")
	a.coins.gp=7;sheet.coins.gp=999;var retry=Hearth20JoinCharacter.submit(c,player,sheet,png);expect(retry.ok and retry.existing and c.actors.size()==1 and a.coins.gp==7,"repeat connection cannot duplicate token or reset spent gold")
	var path=Hearth20Identity.SAVE_ROOT+"/casino-onboarding."+Hearth20Identity.SAVE_EXTENSION;var saved=Hearth20Identity.save_campaign(c,path);var reopened=Hearth20Identity.load_campaign(path)
	expect(saved.ok and reopened.ok and Hearth20JoinCharacter.current(reopened.campaign,player).coins.gp==7,"player mapping and spent purse survive save/reopen")
	expect(Hearth20TavernGames.cards().size()==80,"traditional deck has all 80 unique cards")
	c=fixture();expect(not act(c,"player-0","open").ok,"players cannot launch a table")
	expect(act(c,"dm-local","open",{"chip_cp":10}).ok,"table opened")
	expect(not act(c,"player-0","join",{"actor_id":"hero-1"}).ok,"foreign character cannot fund a seat")
	c=fixture();table(c)
	var total=0
	for actor in c.actors:total+=Hearth20TavernGames.purse(actor)
	expect(total==6600 and c.tavern_game.escrow_cp==900,"exact buy-ins deducted once and held in escrow")
	var g=c.tavern_game;var hidden=str(g.seats[1].hand[0]);var view=Hearth20TavernGames.project(c,"player-0")
	expect(view.seats[0].hand.size()==6 and not view.seats[1].has("hand") and not view.has("deck") and not JSON.stringify(view).contains(hidden),"other hands and deck order absent from recipient packet")
	var corrupt=g.duplicate(true);corrupt.deck.append(corrupt.seats[0].hand[0]);expect(not Hearth20TavernGames.valid(corrupt),"saved duplicate-card state rejected")
	corrupt=g.duplicate(true);corrupt.seats[0].hoard=-1;expect(not Hearth20TavernGames.valid(corrupt),"saved negative hoard rejected")
	var old=g.duplicate(true);var bad=Hearth20TavernGames.apply(c,"player-0",{"action":"ante","game_id":g.id,"revision":0,"actor_id":"hero-0","card_id":g.seats[0].hand[0]},rng)
	expect(not bad.ok and c.tavern_game==old,"stale card command cannot mutate a hand or money")
	expect(act(c,"player-0","ante",{"actor_id":"hero-0","card_id":g.seats[0].hand[0]}).ok,"own face-down ante accepted")
	view=Hearth20TavernGames.project(c,"player-1");expect(view.seats[0].ante_chosen and not view.seats[0].has("private_ante") and view.ante.is_empty(),"pending ante reveals only glowing-back/count state")
	expect(act(c,"dm-local","cancel").ok,"DM can refund active escrow")
	expect(c.actors.all(func(actor):return Hearth20TavernGames.purse(actor)==2500) and c.tavern_game.escrow_cp==0,"cancel refunds original buy-ins in full")
	expect(not act(c,"dm-local","cancel").ok and c.actors.all(func(actor):return Hearth20TavernGames.purse(actor)==2500),"repeated refund cannot mint money")
	var powers={}
	for seed_value in 18:
		rng.seed=9151+seed_value;c=fixture();table(c,2+(seed_value%2));var steps=0
		while c.tavern_game.phase not in ["complete","cancelled"] and steps<600:
			steps+=1;g=c.tavern_game;var result={}
			if g.phase=="ante":
				for i in g.seats.size():
					if g.seats[i].ante.is_empty():result=act(c,"player-"+str(i),"ante",{"actor_id":"hero-"+str(i),"card_id":g.seats[i].hand[rng.randi_range(0,g.seats[i].hand.size()-1)]});break
			elif not g.choice.is_empty():
				var i=g.choice.seat;var options=g.choice.options;result=act(c,"player-"+str(i),"choose",{"option":options[rng.randi_range(0,options.size()-1)].id})
			elif g.phase=="play":
				var i=g.turn;result=act(c,"player-"+str(i),"play",{"card_id":g.seats[i].hand[rng.randi_range(0,g.seats[i].hand.size()-1)]})
			elif g.phase=="between":result=act(c,"dm-local","cashout" if g.gambit>=8 else "next")
			expect(result.get("ok",false),"legal integrated card sequence seed"+str(seed_value)+" step"+str(steps)+": "+str(result.get("error","")))
			if not result.get("ok",false):break
			expect(Hearth20TavernGames.valid(c.tavern_game),"80-card ownership and chip conservation remain valid")
			for line in c.tavern_game.log:
				if "triggers" in line:powers[line]=true
		if c.tavern_game.escrow_cp>0:act(c,"dm-local","cancel")
		total=0
		for actor in c.actors:total+=Hearth20TavernGames.purse(actor)
		expect(total==7500,"settlement/refund conserves all campaign funds seed"+str(seed_value))
	expect(powers.size()>=16,"broad card-power coverage across independent seeded hands")
	print("Casino rules and onboarding: %d assertions, %d failures; %d distinct triggered powers."%[checks,errors.size(),powers.size()]);quit(0 if errors.is_empty() else 1)
