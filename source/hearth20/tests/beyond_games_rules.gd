extends SceneTree
var checks=0
var errors=[]
var campaign: Dictionary
var rng=RandomNumberGenerator.new()
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error(text)
func fixture() -> void:
	campaign=Hearth20Identity.new_campaign("New casino rules fixture")
	for i in 3:
		var a=Hearth20TokenInventory.new_actor("Guest "+str(i),true,campaign.scenes[0],Vector2(.5,.5));a.id="more-"+str(i);a.owner_player_id="player-"+str(i);a.coins={"gp":100};a.in_inventory=true;campaign.actors.append(a)
	campaign.casino_house_cp=100000
func act(action: String, values: Dictionary={}, principal="dm-local") -> Dictionary:
	var g=campaign.get("tavern_game",{});var command={"action":action,"game_id":g.get("id",""),"revision":g.get("revision",0)};command.merge(values)
	return Hearth20TavernGames.apply(campaign,principal,command,rng)
func total() -> int:
	var count=int(campaign.get("casino_house_cp",0));var g=campaign.get("tavern_game",{})
	for a in campaign.actors:count+=Hearth20TavernGames.purse(a)
	if not g.is_empty():
		count+=int(g.get("pot",0))*int(g.chip_cp)+int(g.get("house_escrow_cp",0))
		for s in g.seats:count+=int(s.hoard)*int(g.chip_cp)
	return count
func setup_game(game: String) -> void:
	expect(act("open",{"game":game,"chip_cp":10,"buyin":100,"minimum":1}).ok,"open "+game)
	for i in 3:
		expect(act("join",{"actor_id":"more-"+str(i)}).ok,"seat campaign character")
		expect(act("declare_balance",{"actor_id":"more-"+str(i),"gp":100,"sp":0,"cp":0},"player-"+str(i)).ok,"own balance declaration")
		expect(act("ready",{"actor_id":"more-"+str(i)},"player-"+str(i)).ok,"own confirmation")
	expect(act("start").ok,"fund buy-ins once")
func check_state(text: String) -> void:
	expect(Hearth20TavernGames.valid(campaign.tavern_game),"valid saved state: "+text)
	expect(total()==130000,"purses, escrow and house conserve money: "+text)
func run() -> void:
	for game in Hearth20CasinoGames.TYPES:
		for seed_value in 48:
			fixture();rng.seed=seed_value+41;setup_game(game);check_state(game)
			if game=="gambit_of_ord":
				var actions=0
				while campaign.tavern_game.phase!="between" and actions<250:
					var g=campaign.tavern_game;var result={}
					if g.phase=="await_die":result=act("roll_next")
					else:
						var s=g.seats[g.turn];var pick=rng.randi_range(0,9);var action="call" if g.street_bet>s.street_paid else "check";var values={}
						if pick==0:action="fold"
						elif pick==1 and s.acted_epoch!=g.raise_epoch:action="all_in"
						elif pick==2 and s.acted_epoch!=g.raise_epoch and s.hoard>g.street_bet-s.street_paid+g.min_raise:action="raise";values.total=g.street_bet+g.min_raise
						result=act(action,values)
					if not result.ok:push_error(str(result));errors.append("Ord legal simulation failed");break
					check_state("Ord step");actions+=1
				expect(campaign.tavern_game.phase=="between","Ord betting and all-in side pots reach settlement")
				var view=Hearth20TavernGames.project(campaign,"player-0")
				expect(not view.has("house_cp") and not view.seats[1].has("wallet_cp"),"bank and other purses stay private")
			else:
				for i in 3:
					var wager={"actor_id":"more-"+str(i),"amount":5+i,"kind":"racer" if game=="run_of_luck" else ["odd","ends","number"][i],"number":i if game=="run_of_luck" else 12 if i==2 else 0}
					expect(act("wager",wager).ok,"fund an owned wager")
				var saved=var_to_bytes(campaign)
				expect(not act("wager",{"actor_id":"more-1","amount":1,"kind":"racer","number":0},"player-0").ok and saved==var_to_bytes(campaign),"other characters cannot be wagered")
				expect(act("lock_bets").ok,"house backs the worst possible outcome")
				if game=="run_of_luck":
					for stage in 3:expect(act("race_stage").ok,"host rolls the next five d4 pace counts");check_state("race stage")
				else:expect(act("spin").ok,"host wheel result settles funded payouts")
				check_state("house game settled")
			if seed_value%2==0:
				expect(act("cancel").ok,"CM can refund original buy-ins and undo net house flows")
				expect(campaign.casino_house_cp==100000 and campaign.actors.all(func(a):return Hearth20TavernGames.purse(a)==10000),"full refund restores all original purses and house")
			else:expect(act("cashout").ok,"cashout pays only the actual hoards")
			check_state("external settlement")
			expect(not act("cashout").ok,"second payout rejected")
			expect(act("close").ok and campaign.tavern_game.is_empty(),"table closes after payout")
	for kind in ["odd","even","red","black","ends","number"]:
		var wins=0
		for n in range(1,21):wins+=int(Hearth20CasinoGames.wheel_wins(kind,12,n))
		expect(wins==(1 if kind=="number" else 2 if kind=="ends" else 10),"complete D20 outcome coverage: "+kind)
	fixture();setup_game("gambit_of_ord");var private_view=Hearth20TavernGames.project(campaign,"player-0")
	expect(private_view.seats[0].has("dice") and not private_view.seats[1].has("dice"),"private Ord dice do not enter another player's packet")
	var bytes=var_to_bytes(campaign);expect(not act("house_reserve",{"amount_cp":9999999},"player-0").ok and bytes==var_to_bytes(campaign),"player cannot create house money")
	expect(not act("house_reserve",{"amount_cp":1}).ok,"CM cannot change backing while escrow is active")
	print("Additional casino games: %d assertions, %d failures."%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
