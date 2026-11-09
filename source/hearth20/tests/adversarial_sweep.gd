extends SceneTree
var checks=0
var errors=[]
var sequence=0
var rng=RandomNumberGenerator.new()
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func invalid_values() -> Array:
	return [null,true,false,-1,0.5,NAN,INF,-INF,"","0100","NaN","1e999",[],{},[null],{"unexpected":"value"}]
func casino(campaign: Dictionary,player: String,kind: String,fields: Dictionary={}) -> Dictionary:
	var game=campaign.get("tavern_game",{})
	var command={"action":kind,"game_id":game.get("id",""),"revision":game.get("revision",0)};command.merge(fields)
	return Hearth20TavernGames.apply(campaign,player,command,rng)
func reject_casino(campaign: Dictionary,player: String,kind: String,fields: Dictionary={}) -> void:
	var before=var_to_bytes(campaign);var result=casino(campaign,player,kind,fields)
	expect(not result.ok and var_to_bytes(campaign)==before,"casino rejects atomically · "+kind+" · "+str(fields).left(100))
func run() -> void:
	create_timer(12).timeout.connect(func():push_error("Adversarial sweep watchdog expired.");quit(2))
	rng.seed=49018
	var base=Hearth20Identity.new_campaign("Adversarial input fixture")
	for field in ["schema_version","scenes","actors","assets"]:
		for value in invalid_values():
			if field=="actors" and value is Array:continue
			if field=="assets" and value is Dictionary:continue
			var campaign=base.duplicate(true);campaign[field]=value
			expect(not Hearth20Contracts.validate_campaign(campaign).ok,"malformed saved field rejected · "+field+" · "+str(value))
	for field in ["width_cells","height_cells","feet_per_cell","cell_pixels","grid_opacity","grid_thickness"]:
		for value in invalid_values():
			if value is int and value>=1:continue
			if field=="grid_opacity" and value is float and value==.5:continue
			if field=="grid_thickness" and value is float and value==.5:continue
			if field in ["feet_per_cell","cell_pixels"] and value is float and value==.5:continue
			var scene=base.scenes[0].duplicate(true);scene[field]=value
			expect(not Hearth20Contracts.valid_scene(scene),"invalid map field rejected · "+field+" · "+str(value))
	for field in ["remaining_feet","revision","controllers","expiry","grant_id","expiry_id"]:
		for value in invalid_values():
			if field in ["grant_id","expiry_id"] and value is String:continue
			if field=="remaining_feet" and value is float and value==.5:continue
			if field=="controllers" and value is Array and value.is_empty():continue
			var policy=Hearth20Contracts.default_movement_policy("grant",["player-a"]);policy[field]=value
			expect(not Hearth20Contracts.valid_movement_policy(policy),"invalid movement policy rejected · "+field+" · "+str(value))
	for field in ["points","width","opacity","color","font_size","kind","font"]:
		for value in invalid_values():
			if field in ["opacity","width","font_size"] and value is float and value==.5:continue
			if field=="color" and value is String and Color.html_is_valid(value):continue
			var object={"kind":"line","points":[Vector2(1,1),Vector2(2,2)],"color":"#ffeedd","width":1.}
			object[field]=value
			expect(not Hearth20BoardTools.valid_object(object,base.scenes[0]),"invalid drawing field rejected · "+field+" · "+str(value))
	var session=Hearth20Session.new();root.add_child(session);session.configure(base)
	var players=["player-a","player-b"]
	for index in 2:
		var actor=Hearth20TokenInventory.new_actor("Guest "+str(index),true,base.scenes[0],Vector2(2.5+index,2.5));actor.id="adversarial-actor-"+str(index);actor.owner_player_id=players[index];actor.in_inventory=false
		actor.movement_policy=Hearth20Contracts.default_movement_policy("free_until_revoked",[players[index]])
		base.actors.append(actor);session.remote_players[players[index]]={"nickname":"Guest","peer_id":42+index}
	for command in [{"action":"mask_all","reveal":true},{"action":"mask","rect":Rect2(1,1,2,2)},{"action":"actor_layer","id":base.actors[0].id,"layer":"gm"},{"action":"save_fx_preset","name":"forged","settings":{}},{"action":"auto_vision","id":base.actors[0].id}]:
		sequence+=1;command.request_id="adversarial-board-"+str(sequence);session.request_rates.clear();var before=var_to_bytes(base)
		expect(not session._apply_board_action(command,players[0]).ok and var_to_bytes(base)==before,"player cannot perform DM board action · "+command.action)
	for destination in [Vector2(NAN,1),Vector2(INF,1),Vector2(-1,1),Vector2(99999,1)]:
		var before=var_to_bytes(base)
		var moved=Hearth20Contracts.authorize_and_apply_move(base,players[0],"player",base.actors[0].id,base.actors[0].position,destination,5.)
		expect(not moved.ok and var_to_bytes(base)==before,"invalid movement rejected without moving a token")
	var before=var_to_bytes(base)
	expect(not Hearth20Contracts.authorize_and_apply_move(base,players[1],"player",base.actors[0].id,base.actors[0].position,Vector2(4.5,2.5),10.).ok and var_to_bytes(base)==before,"player cannot move another player's token")
	base.actors[0].in_inventory=true;before=var_to_bytes(base)
	expect(not Hearth20Contracts.authorize_and_apply_move(base,players[0],"player",base.actors[0].id,base.actors[0].position,Vector2(4.5,2.5),10.).ok and var_to_bytes(base)==before,"stored token cannot be moved onto the board by its owner")
	base.actors[0].in_inventory=false
	for expression in ["0d20","51d20","1d1","1d1001","1d20+1001","999999d9999","1d20/0","1d20;quit()","", "1d20+NaN"]:
		var command={"action":"roll","request_id":"adversarial-roll-"+expression.sha256_text().left(20),"actor_id":"","kind":"dice","expression":expression,"mode":"normal","visibility":"self"};session.request_rates.clear();before=var_to_bytes(base)
		expect(not session._apply_table_request(command,players[0]).ok and var_to_bytes(base)==before,"invalid roll rejected · "+expression)
	for mode in ["advantage","disadvantage"]:
		expect(not Hearth20TableData.roll({},"dice","",mode,"1d6",rng).ok,"unsupported advantage dice give an error")
	for game in ["three_dragon_ante","gambit_of_ord","run_of_luck","tymoras_spinner"]:
		var campaign=Hearth20Identity.new_campaign("Casino adversarial "+game);campaign.casino_house_cp=1000000
		for index in 2:
			var actor=base.actors[index].duplicate(true);actor.coins={};campaign.actors.append(actor)
		expect(casino(campaign,"dm-local","open",{"game":game,"chip_cp":10,"buyin":100,"minimum":1}).ok,"fixture opens "+game)
		for index in 2:
			var actor=campaign.actors[index]
			expect(casino(campaign,players[index],"join",{"actor_id":actor.id}).ok,"fixture seats owner")
			expect(casino(campaign,players[index],"declare_balance",{"actor_id":actor.id,"gp":100,"sp":0,"cp":0}).ok,"fixture declares balance")
		reject_casino(campaign,players[0],"start")
		reject_casino(campaign,players[0],"declare_balance",{"actor_id":campaign.actors[1].id,"gp":9999,"sp":0,"cp":0})
		for value in invalid_values():reject_casino(campaign,players[0],"declare_balance",{"actor_id":campaign.actors[0].id,"gp":value,"sp":0,"cp":0})
		for index in 2:expect(casino(campaign,players[index],"ready",{"actor_id":campaign.actors[index].id}).ok,"fixture readies owner")
		expect(casino(campaign,"dm-local","start").ok,"fixture locks escrow")
		reject_casino(campaign,players[0],"cancel")
		reject_casino(campaign,"dm-local","open",{"game":"three_dragon_ante"})
		reject_casino(campaign,players[0],"leave",{"actor_id":campaign.actors[0].id})
		reject_casino(campaign,players[0],"house_reserve",{"amount_cp":999999})
		if game=="gambit_of_ord":
			var turn_player=campaign.tavern_game.seats[campaign.tavern_game.turn].player_id
			reject_casino(campaign,turn_player,"fold",{"actor_id":"unknown-actor"})
		else:reject_casino(campaign,players[0],"play",{"card_id":"forged-card"})
		expect(casino(campaign,"dm-local","cancel").ok,"CM refund succeeds once")
		reject_casino(campaign,"dm-local","cancel")
		expect(Hearth20TavernGames.purse(campaign.actors[0])==10000 and Hearth20TavernGames.purse(campaign.actors[1])==10000,"refund preserves original declared balances")
	session.queue_free();await process_frame;await process_frame
	print("Adversarial sweep: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
