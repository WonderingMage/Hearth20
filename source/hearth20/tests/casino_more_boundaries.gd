extends SceneTree
class Fixture extends RefCounted:
	var campaign: Dictionary
	var rng=RandomNumberGenerator.new()
	func fixture() -> void:
		campaign=Hearth20Identity.new_campaign("Synthetic boundary cases");campaign.casino_house_cp=100000
		for i in 3:
			var a=Hearth20TokenInventory.new_actor("Guest "+str(i),true,campaign.scenes[0],Vector2(.5,.5));a.id="more-"+str(i);a.coins={"gp":100};a.owner_player_id="player-"+str(i);campaign.actors.append(a)
	func act(action: String, extra: Dictionary={}) -> Dictionary:
		var g=campaign.get("tavern_game",{});var c={"action":action,"game_id":g.get("id",""),"revision":g.get("revision",0)};c.merge(extra);return Hearth20TavernGames.apply(campaign,"dm-local",c,rng)
	func setup_game(game: String) -> void:
		act("open",{"game":game,"chip_cp":10,"buyin":100,"minimum":1})
		for i in 3:act("join",{"actor_id":"more-"+str(i)})
		act("start")
var fixture: Fixture
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func run() -> void:
	fixture=Fixture.new()
	for game in Hearth20CasinoGames.TYPES:
		fixture.fixture();fixture.rng.seed=2734;fixture.setup_game(game)
		var original=fixture.campaign.tavern_game.duplicate(true)
		for changes in [{"phase":"racing" if game=="gambit_of_ord" else "await_die"},{"initial_cp":3001},{"house_escrow_cp":1},{"result":21},{"stage":3},{"positions":[4,0,0,0,0]}]:
			var invalid=original.duplicate(true);invalid.merge(changes,true);expect(not Hearth20CasinoGames.valid(invalid),"malformed saved "+game+": "+str(changes.keys()))
		var path=Hearth20Identity.SAVE_ROOT+"/boundary."+Hearth20Identity.SAVE_EXTENSION
		expect(Hearth20Identity.save_campaign(fixture.campaign,path).ok,"save valid active table");var loaded=Hearth20Identity.load_campaign(path);expect(loaded.ok,"load valid active table: "+str(loaded.get("errors",[])))
		if not loaded.ok:quit(1);return
		fixture.campaign=loaded.campaign
		if game=="gambit_of_ord":
			expect(fixture.act("raise",{"total":10}).ok,"opening raise")
			expect(fixture.act("call").ok,"second player calls")
			expect(fixture.act("raise",{"total":20}).ok,"third raises")
			var snapshot=var_to_bytes(fixture.campaign)
			for value in [1,9,10,19,20,-1,0,INF,NAN,"50"]:
				expect(not fixture.act("raise",{"total":value}).ok and snapshot==var_to_bytes(fixture.campaign),"raise cannot withdraw committed chips or undercall: "+str(value))
			while fixture.campaign.tavern_game.phase!="between":
				if fixture.campaign.tavern_game.phase=="await_die":expect(fixture.act("roll_next").ok,"resume saved private dice street")
				else:expect(fixture.act("call").ok,"resume saved betting and side-pot settlement")
		else:
			fixture.campaign.casino_house_cp=0
			var data={"actor_id":"more-0","amount":5,"kind":"racer" if game=="run_of_luck" else "number","number":0 if game=="run_of_luck" else 12}
			expect(fixture.act("wager",data).ok,"wager after save reload")
			if game=="tymoras_spinner":expect(fixture.act("wager",data).ok and fixture.campaign.tavern_game.seats[0].bets.size()==1 and fixture.campaign.tavern_game.seats[0].bets[0].amount==10,"matching wheel wagers merge into one chip stack")
			var snapshot=var_to_bytes(fixture.campaign);expect(not fixture.act("lock_bets").ok and snapshot==var_to_bytes(fixture.campaign),"unbacked payout cannot lock or debit anyone")
			expect(fixture.act("house_reserve",{"amount_cp":100000}).ok,"CM can top up reserve while wagers remain open")
			expect(fixture.act("lock_bets").ok,"backed wagers lock")
			snapshot=var_to_bytes(fixture.campaign);expect(not fixture.act("house_reserve",{"amount_cp":100001}).ok and snapshot==var_to_bytes(fixture.campaign),"reserve cannot change after betting locks")
			if game=="run_of_luck":
				for stage in 3:expect(fixture.act("race_stage").ok,"resume saved race")
			else:expect(fixture.act("spin").ok,"resume saved wheel")
		expect(Hearth20CasinoGames.valid(fixture.campaign.tavern_game),"resumed table remains valid")
		expect(fixture.act("cashout").ok,"resumed cashout succeeds once")
	# Explicit race tie and half-chip policies using complete saved roll history.
	for positions in [[6,6,3,3,3],[7,6,6,3,3]]:
		fixture.fixture();fixture.setup_game("run_of_luck")
		for i in 3:expect(fixture.act("wager",{"actor_id":"more-"+str(i),"amount":5,"kind":"racer","number":i}).ok,"tie test wager")
		expect(fixture.act("lock_bets").ok,"tie test reserve")
		var g=fixture.campaign.tavern_game;g.positions=positions;g.stage=3;g.race_rolls=[[2,2,1,1,1],[2,2,1,1,1],[positions[0]-4,positions[1]-4,positions[2]-2,1,1]];g.last_moves=g.race_rolls.back().duplicate();var ctx={"house":fixture.campaign.casino_house_cp};Hearth20CasinoGames._house_settle(g,ctx)
		expect(g.last_payouts==([10,10,0] if positions[0]==6 else [10,2,2]),"tied first pays both; tied seconds round half stakes down")
		expect(Hearth20CasinoGames.valid(g),"tie settlement conserves backed chips")
	print("Casino boundaries: %d assertions, %d failures."%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
