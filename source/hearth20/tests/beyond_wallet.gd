extends SceneTree
var checks=0
var errors=[]
var c: Dictionary
var rng=RandomNumberGenerator.new()
func _initialize() -> void:call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func act(action: String, data: Dictionary={}, principal="dm-local") -> Dictionary:
	var g=c.get("tavern_game",{});var cmd={"action":action,"game_id":g.get("id",""),"revision":g.get("revision",0)};cmd.merge(data)
	return Hearth20TavernGames.apply(c,principal,cmd,rng)
func fixture(game: String) -> void:
	c=Hearth20Identity.new_campaign("Declared coins")
	for i in 2:
		var a=Hearth20TokenInventory.new_actor("Player "+str(i),true,c.scenes[0],Vector2(.5,.5));a.id="pawn-"+str(i);a.owner_player_id="player-"+str(i);a.coins={};a.in_inventory=true;c.actors.append(a)
	c.casino_house_cp=1000000
	expect(act("open",{"game":game,"chip_cp":10,"buyin":100,"minimum":1}).ok,"open "+game)
	for i in 2:expect(act("join",{"actor_id":"pawn-"+str(i)},"player-"+str(i)).ok,"own pawn takes seat")
func declaration(i: int) -> Dictionary:return act("declare_balance",{"actor_id":"pawn-"+str(i),"gp":125,"sp":3,"cp":7},"player-"+str(i))
func run() -> void:
	for game in ["three_dragon_ante","gambit_of_ord","run_of_luck","tymoras_spinner"]:
		fixture(game)
		expect(not act("ready",{"actor_id":"pawn-0"},"player-0").ok,"ready requires explicit declaration")
		var before=var_to_bytes(c)
		expect(not act("declare_balance",{"actor_id":"pawn-0","gp":900,"sp":0,"cp":0}).ok and before==var_to_bytes(c),"CM cannot declare a player's money")
		expect(not act("declare_balance",{"actor_id":"pawn-1","gp":900,"sp":0,"cp":0},"player-0").ok and before==var_to_bytes(c),"cannot declare somebody else's money")
		for v in [-1,0.1,INF,"5",null,100000000001]:
			expect(not act("declare_balance",{"actor_id":"pawn-0","gp":v,"sp":0,"cp":0},"player-0").ok and before==var_to_bytes(c),"invalid declaration is atomic")
		for i in 2:
			expect(declaration(i).ok,"own coins declared without a PDF")
			expect(Hearth20TavernGames.purse(c.actors[i])==12537,"whole copper conversion")
			expect(act("ready",{"actor_id":"pawn-"+str(i)},"player-"+str(i)).ok,"player confirms buy-in")
		expect(act("start").ok,"all declarations fund the game")
		before=var_to_bytes(c);expect(not declaration(0).ok and before==var_to_bytes(c),"balance locked during play")
		var view=Hearth20TavernGames.project(c,"player-0")
		expect(view.seats[0].declared_cp==12537 and not view.seats[1].has("declared_cp") and not view.seats[1].has("wallet_cp"),"other player's balance is private")
		expect(act("cancel").ok,"CM refunds the table")
		expect(c.casino_receipts.size()==2 and Hearth20CasinoWallet.valid(c),"one valid receipt per seat")
		var receipts=Hearth20CasinoWallet.pending(c,"player-0")
		expect(receipts.size()==1 and receipts[0].after_cp==12537 and receipts[0].delta_cp==0,"refund states exact final balance")
		before=var_to_bytes(c);expect(not act("cancel").ok and before==var_to_bytes(c),"repeat refund cannot pay twice")
		expect(act("close").ok and Hearth20CasinoWallet.pending(c,"player-0").size()==1,"receipt survives returning to map")
		var receipt=receipts[0];before=var_to_bytes(c)
		expect(not act("acknowledge_balance",{"receipt_id":receipt.id},"player-1").ok and before==var_to_bytes(c),"only owner acknowledges")
		var serialized=Hearth20Identity._encode_variant(c);var decoded=Hearth20Identity._decode_variant(serialized)
		expect(Hearth20CasinoWallet.pending(decoded,"player-0").size()==1,"notice survives saved-data serialization")
		expect(act("open",{"game":game,"chip_cp":10,"buyin":100,"minimum":1}).ok,"new lobby opens")
		expect(act("join",{"actor_id":"pawn-0"},"player-0").ok,"player can take next seat")
		before=var_to_bytes(c);expect(not declaration(0).ok and before==var_to_bytes(c),"pending update prevents redeclaration")
		expect(act("acknowledge_balance",{"receipt_id":receipt.id},"player-0").ok,"owner confirms website update")
		expect(Hearth20CasinoWallet.pending(c,"player-0").is_empty() and declaration(0).ok,"confirmation unlocks next balance declaration")
	print("Beyond casino balances: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
