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
		expect(act(c,"player-"+str(i),"declare_balance",{"actor_id":"hero-"+str(i),"gp":25,"sp":0,"cp":0}).ok,"own declared balance")
		expect(act(c,"player-"+str(i),"ready",{"actor_id":"hero-"+str(i)}).ok,"player readies buy-in")
	expect(act(c,"dm-local","start").ok,"DM deals ready seats")
func run() -> void:
	rng.seed=398434
	var c: Dictionary
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
	print("Beyond Three-Dragon Ante: %d assertions, %d failures; %d distinct triggered powers."%[checks,errors.size(),powers.size()]);quit(0 if errors.is_empty() else 1)
