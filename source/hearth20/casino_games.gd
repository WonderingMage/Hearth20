extends RefCounted
class_name Hearth20CasinoGames
## Host-owned dice, racing and wheel games. Every payout has a funded source.
const TYPES=["gambit_of_ord","run_of_luck","tymoras_spinner"]
const NAMES={"gambit_of_ord":"Gambit of Ord","run_of_luck":"Run of Luck","tymoras_spinner":"Tymora's Spinner"}
const RED=[1,3,5,7,9,12,14,16,18,19]
const MAX=100000000000
static func fail(message: String) -> Dictionary:return {"ok":false,"error":message}
static func integer(v: Variant, low=0, high=MAX) -> bool:return Hearth20Contracts._integer_number(v) and v>=low and v<=high
static func log_line(g: Dictionary, text: String) -> void:
	g.log.append(text.left(500))
	while g.log.size()>128:g.log.pop_front()
static func seat_index(g: Dictionary, id: String) -> int:
	for i in g.seats.size():
		if g.seats[i].actor_id==id:return i
	return -1
static func actor_for(campaign: Dictionary, g: Dictionary, principal: String, command: Dictionary) -> int:
	var index=seat_index(g,str(command.get("actor_id","")))
	if command.has("actor_id") and index<0:return -1
	if index<0 and g.game=="gambit_of_ord":index=int(g.turn)
	if index<0:
		for i in g.seats.size():
			if g.seats[i].player_id==principal:index=i;break
	if index<0 or index>=g.seats.size():return -1
	var a=Hearth20Contracts.find_actor(campaign,g.seats[index].actor_id)
	if a.is_empty() or (principal!="dm-local" and (g.seats[index].player_id!=principal or a.get("owner_player_id","")!=principal)):return -1
	return index
static func ledger(campaign: Dictionary, game_id: String, id: String, action: String, delta: int, before: int, after: int) -> void:
	if not campaign.get("tavern_ledger") is Array:campaign.tavern_ledger=[]
	campaign.tavern_ledger.append({"game_id":game_id,"actor_id":id,"action":action,"delta_cp":delta,"before_cp":before,"after_cp":after,"time":Time.get_datetime_string_from_system(true)})
	while campaign.tavern_ledger.size()>1000:campaign.tavern_ledger.pop_front()
static func terms(game: String) -> String:
	if game=="gambit_of_ord":return "Private d8, bet; hidden d6, bet; d4 showdown. Matched side pots pay 80%, with whole-chip house fees rounded down. Uncalled chips return in full. Tied remainders pass clockwise."
	if game=="run_of_luck":return "Tied first-place racers each return 2x the stake; second place returns half, rounded down, only behind one clear winner. Returns include the stake."
	return "D20 house wheel. Displayed payout ratios are profit; a winning stake also returns. Bets lock before the spin. The casino funds every possible result."
static func create(game: String, command: Dictionary) -> Dictionary:
	return {"id":"casino-"+Crypto.new().generate_random_bytes(12).hex_encode(),"game":game,"revision":0,"phase":"lobby","chip_cp":int(command.get("chip_cp",100)),"buyin":int(command.get("buyin",100)),"minimum":int(command.get("minimum",5 if game=="gambit_of_ord" else 25)),"fee_percent":20,"payouts":{"odd":1,"even":1,"red":1,"black":1,"ends":8,"number":18},"seats":[],"pot":0,"escrow_cp":0,"initial_cp":0,"house_in_cp":0,"house_out_cp":0,"house_escrow_cp":0,"player_paid_cp":0,"round":0,"stage":0,"turn":0,"dealer":0,"street_bet":0,"min_raise":0,"raise_epoch":0,"revealed":false,"result":0,"positions":[0,0,0,0,0],"last_moves":[0,0,0,0,0],"race_rolls":[],"winners":[],"last_payouts":[],"log":["The CM opened "+NAMES[game]+"."],"rules":terms(game)}
static func apply(campaign: Dictionary, principal: String, command: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if var_to_bytes(command).size()>8192 or not Hearth20JoinCharacter.primitive(command):return fail("Game request is invalid.")
	var dm=principal=="dm-local";var action=str(command.get("action",""));var g=campaign.get("tavern_game",{}).duplicate(true)
	var bank=campaign.get("casino_house_cp",0)
	if not integer(bank):return fail("The casino reserve is invalid.")
	var ctx={"house":int(bank),"deltas":[]}
	if action=="house_reserve":
		var amount=command.get("amount_cp")
		if not integer(amount):return fail("Choose a valid casino reserve.")
		var topup=Hearth20TavernGames.locked(g) and g.get("game","") in ["run_of_luck","tymoras_spinner"] and g.get("phase","")=="betting" and int(amount)>=int(bank)
		if not dm or (Hearth20TavernGames.locked(g) and not topup):return fail("The CM funds the reserve before play, or tops it up while house wagers are still open.")
		campaign.casino_house_cp=int(amount);ledger(campaign,str(g.get("id","casino-house")),"casino-house","CM reserve adjustment",int(amount)-int(bank),int(bank),int(amount));return {"ok":true}
	if action=="open":
		var game=str(command.get("game",""))
		if not dm or game not in TYPES:return fail("The CM chooses the party's game.")
		if Hearth20TavernGames.locked(g):return fail("Cash out or refund the current table first.")
		for field in ["chip_cp","buyin","minimum"]:
			if command.has(field) and not integer(command[field],1,1000000):return fail("Choose valid stakes.")
		g=create(game,command)
		if command.has("payouts"):
			if not command.payouts is Dictionary:return fail("Choose valid wheel payouts.")
			for key in command.payouts:
				if key not in g.payouts or not integer(command.payouts[key],1,100):return fail("Choose valid wheel payouts.")
				g.payouts[key]=int(command.payouts[key])
	elif g.is_empty():return fail("The CM has not opened a game.")
	else:
		if command.get("game_id","")!=g.id or not integer(command.get("revision")) or int(command.revision)!=int(g.revision):return fail("The table changed. Try the current action again.")
		match action:
			"join":
				if g.phase!="lobby":return fail("Seats are locked while the table holds gold.")
				var a=Hearth20Contracts.find_actor(campaign,str(command.get("actor_id","")))
				if a.is_empty() or not a.get("is_hero",false) or a.get("decorative",false) or (not dm and a.get("owner_player_id","")!=principal):return fail("Choose your own character token.")
				if g.seats.size()>=6 or seat_index(g,str(a.id))>=0 or (not dm and g.seats.any(func(s):return s.player_id==principal)):return fail("Choose one character in an available seat.")
				g.seats.append({"actor_id":str(a.id),"player_id":str(a.get("owner_player_id","")),"name":str(a.name).left(64),"ready":dm,"hoard":0,"buyin_cp":0,"dice":[],"folded":false,"all_in":false,"sitting_out":false,"committed":0,"street_paid":0,"acted_epoch":-1,"bets":[],"last_win":0})
			"ready","leave":
				var i=actor_for(campaign,g,principal,command)
				if i<0 or g.phase!="lobby":return fail("Change your own seat before the table starts.")
				if action=="leave":g.seats.remove_at(i)
				else:g.seats[i].ready=not g.seats[i].ready
			"start":
				var least=2 if g.game=="gambit_of_ord" else 1
				if not dm or g.phase!="lobby" or g.seats.size()<least or not g.seats.all(func(s):return s.ready):return fail("The CM starts after the seated characters are ready.")
				var cost=int(g.buyin)*int(g.chip_cp)
				if cost*g.seats.size()>MAX:return fail("The table's stakes are too large.")
				for s in g.seats:
					var a=Hearth20Contracts.find_actor(campaign,s.actor_id)
					if a.is_empty() or Hearth20TavernGames.purse(a)<cost:return fail(str(s.name)+" cannot fund the displayed buy-in.")
				for s in g.seats:s.hoard=int(g.buyin);s.buyin_cp=cost;ctx.deltas.append({"id":s.actor_id,"cp":-cost})
				g.initial_cp=cost*g.seats.size();g.escrow_cp=g.initial_cp
				if g.game=="gambit_of_ord":
					if not _ord_begin(g,rng):return fail("At least two characters need enough chips for the ante.")
				else:g.phase="betting";g.round=1
				log_line(g,"Buy-ins moved from declared balances to table hoards.")
			"check","call","raise","all_in","fold":
				var i=actor_for(campaign,g,principal,command)
				if i<0 or g.game!="gambit_of_ord" or g.phase!="betting" or i!=g.turn:return fail("Wait for your own betting turn.")
				var error=_ord_action(g,i,action,command,rng,ctx)
				if not error.is_empty():return fail(error)
			"roll_next":
				if not dm or g.game!="gambit_of_ord" or g.phase!="await_die":return fail("The CM rolls the next die after betting closes.")
				g.stage+=1
				for s in g.seats:
					if not s.folded and not s.sitting_out:s.dice.append(rng.randi_range(1,6 if g.stage==2 else 4))
				if g.stage==3:_ord_settle(g,ctx,true)
				else:
					g.street_bet=0;g.min_raise=g.minimum;g.raise_epoch=0
					for s in g.seats:s.street_paid=0;s.acted_epoch=-1
					g.phase="betting";g.turn=maxi(0,_ord_next(g,g.dealer));_ord_progress(g,ctx)
			"ruling_reroll","ruling_fold":
				var i=actor_for(campaign,g,principal,command)
				if not dm or i<0 or g.game!="gambit_of_ord" or g.phase not in ["betting","await_die"] or g.seats[i].folded or g.seats[i].sitting_out:return fail("The CM resolves private ability rulings before showdown.")
				if action=="ruling_fold":g.seats[i].folded=true;_ord_progress(g,ctx)
				else:
					var die=command.get("die_index")
					if not integer(die,0,g.seats[i].dice.size()-1):return fail("Choose one of the current private dice.")
					g.seats[i].dice[int(die)]=rng.randi_range(1,[8,6,4][int(die)])
				log_line(g,"The CM resolved a private character-ability ruling.")
			"wager","remove_wager":
				var i=actor_for(campaign,g,principal,command)
				if i<0 or g.game=="gambit_of_ord" or g.phase!="betting":return fail("Place your own wagers before the CM locks betting.")
				var s=g.seats[i]
				if action=="remove_wager":
					var slot=command.get("bet_index")
					if not integer(slot,0,s.bets.size()-1):return fail("Choose one of your current wagers.")
					var bet=s.bets[int(slot)];s.hoard+=int(bet.amount);g.pot-=int(bet.amount);s.bets.remove_at(int(slot))
				else:
					var amount=command.get("amount");var bet_kind=str(command.get("kind","racer"));var number=command.get("number",0)
					if not integer(amount,int(g.minimum),int(s.hoard)):return fail("Use a wager between the table minimum and your remaining chips.")
					
					if g.game=="run_of_luck":
						if bet_kind!="racer" or not integer(number,0,4) or not s.bets.is_empty():return fail("Back one of the five racers; remove your wager to change it.")
					elif bet_kind not in g.payouts or not integer(number,1 if bet_kind=="number" else 0,20 if bet_kind=="number" else 0):return fail("Choose a valid wheel wager.")
					var existing=-1
					for index in s.bets.size():
						if s.bets[index].kind==bet_kind and s.bets[index].number==int(number):existing=index;break
					if existing<0 and s.bets.size()>=12:return fail("Remove a wager before placing another.")
					s.hoard-=int(amount);g.pot+=int(amount)
					if existing>=0:s.bets[existing].amount+=int(amount)
					else:s.bets.append({"kind":bet_kind,"number":int(number),"amount":int(amount)})
			"lock_bets":
				if not dm or g.phase!="betting" or g.game=="gambit_of_ord" or g.pot<=0:return fail("The CM locks a table with placed wagers.")
				var reserve=_reserve(g)*int(g.chip_cp)
				if reserve>ctx.house:return fail("The casino needs "+str(reserve/100.)+" gp in its reserve to back these wagers.")
				ctx.house-=reserve;g.house_in_cp+=reserve;g.house_escrow_cp=reserve;g.phase="racing" if g.game=="run_of_luck" else "locked";g.stage=0
				log_line(g,"Wagers locked; every possible payout is backed.")
			"race_stage":
				if not dm or g.game!="run_of_luck" or g.phase!="racing" or g.stage>=3:return fail("The CM releases the next stage of the race.")
				g.stage+=1;g.last_moves=[]
				for i in 5:
					var roll=rng.randi_range(1,4);g.last_moves.append(roll);g.positions[i]+=roll
				g.race_rolls.append(g.last_moves.duplicate());log_line(g,"Race stage "+str(g.stage)+": "+str(g.last_moves)+" paces.")
				if g.stage==3:_house_settle(g,ctx)
			"spin":
				if not dm or g.game!="tymoras_spinner" or g.phase!="locked":return fail("The CM spins after wagers lock.")
				g.result=rng.randi_range(1,20);g.stage=1;_house_settle(g,ctx)
			"next":
				if not dm or g.phase!="between":return fail("The CM starts another round after settlement.")
				if g.game=="gambit_of_ord":
					g.dealer=(g.dealer+1)%g.seats.size()
					if not _ord_begin(g,rng):return fail("Two funded characters are needed; cash out this table instead.")
				else:
					g.round+=1;g.phase="betting";g.stage=0;g.result=0;g.positions=[0,0,0,0,0];g.last_moves=[0,0,0,0,0];g.race_rolls=[];g.winners=[];g.last_payouts=[]
					for s in g.seats:s.bets=[];s.last_win=0
			"cashout","cancel":
				if not dm or g.phase in ["complete","cancelled"]:return fail("Only the CM can settle this table once.")
				if action=="cashout" and g.phase!="between":return fail("Cash out between rounds, or refund the original buy-ins.")
				if action=="cancel":
					ctx.house+=int(g.house_in_cp)-int(g.house_out_cp)
					for s in g.seats:ctx.deltas.append({"id":s.actor_id,"cp":int(s.buyin_cp)});s.hoard=0;s.bets=[];s.committed=0
					g.house_out_cp=g.house_in_cp;g.player_paid_cp=g.initial_cp;g.phase="cancelled"
				else:
					for s in g.seats:
						var amount=int(s.hoard)*int(g.chip_cp);ctx.deltas.append({"id":s.actor_id,"cp":amount});g.player_paid_cp+=amount;s.hoard=0;s.committed=0;s.bets=[]
					g.phase="complete"
				g.escrow_cp=0;g.pot=0;g.house_escrow_cp=0;log_line(g,"Original buy-ins refunded." if action=="cancel" else "Table hoards paid back to declared balances.")
			"close":
				if not dm or Hearth20TavernGames.locked(g):return fail("Cash out or refund before returning everyone to the map.")
				campaign.tavern_game={};return {"ok":true}
			_:return fail("That action does not belong to this game.")
	if not valid(g) or not integer(ctx.house):return fail("The proposed game or reserve is invalid; nothing was changed.")
	for delta in ctx.deltas:
		var a=Hearth20Contracts.find_actor(campaign,delta.id);var cp=Hearth20TavernGames.purse(a)
		if a.is_empty() or not integer(cp+int(delta.cp)):return fail("A character purse changed; no money was committed.")
	for delta in ctx.deltas:
		var a=Hearth20Contracts.find_actor(campaign,delta.id);var cp=Hearth20TavernGames.purse(a);Hearth20TavernGames.set_purse(a,cp+int(delta.cp));ledger(campaign,g.id,delta.id,action,int(delta.cp),cp,cp+int(delta.cp))
	if ctx.house!=bank:ledger(campaign,g.id,"casino-house",action,int(ctx.house)-int(bank),int(bank),int(ctx.house))
	campaign.casino_house_cp=int(ctx.house);g.revision+=1;campaign.tavern_game=g;return {"ok":true}
static func _ord_begin(g: Dictionary, rng: RandomNumberGenerator) -> bool:
	var count=0
	for s in g.seats:
		s.dice=[];s.folded=false;s.sitting_out=s.hoard<g.minimum;s.all_in=false;s.committed=0;s.street_paid=0;s.acted_epoch=-1;s.last_win=0
		if not s.sitting_out:
			count+=1;s.hoard-=g.minimum;s.committed=g.minimum;s.dice=[rng.randi_range(1,8)];s.all_in=s.hoard==0;g.pot+=g.minimum
	if count<2:return false
	g.round+=1;g.stage=1;g.street_bet=0;g.min_raise=g.minimum;g.raise_epoch=0;g.revealed=false;g.winners=[];g.last_payouts=[];g.phase="betting";g.turn=_ord_next(g,g.dealer)
	if g.turn<0:g.turn=0;g.phase="await_die"
	log_line(g,"Gambit "+str(g.round)+": private d8 dealt; antes committed.");return true
static func _ord_next(g: Dictionary, after: int) -> int:
	for step in range(1,g.seats.size()+1):
		var i=(after+step)%g.seats.size();var s=g.seats[i]
		if not s.folded and not s.sitting_out and not s.all_in:return i
	return -1
static func _ord_action(g: Dictionary, i: int, action: String, command: Dictionary, _rng: RandomNumberGenerator, ctx: Dictionary) -> String:
	var s=g.seats[i];var call=maxi(0,int(g.street_bet)-int(s.street_paid));var amount=0
	if s.folded or s.all_in or s.sitting_out:return "This character cannot act now."
	if action=="fold":s.folded=true
	elif action=="check":
		if call>0:return "Call the current wager or fold."
	elif action=="call":
		amount=mini(call,int(s.hoard))
	elif action in ["raise","all_in"]:
		var target=command.get("total",0) if action=="raise" else int(s.street_paid)+int(s.hoard)
		if not integer(target,1,int(s.street_paid)+int(s.hoard)):return "Choose a funded total for this betting street."
		if action=="raise" and int(target)<=int(g.street_bet):return "A raise must exceed the current street wager. Call or fold instead."
		if int(target)>int(g.street_bet):
			if int(s.acted_epoch)==int(g.raise_epoch):return "A short all-in did not reopen your raising rights. Call or fold."
			var increase=int(target)-int(g.street_bet)
			if increase<int(g.min_raise) and action!="all_in":return "Raise by at least "+str(g.min_raise)+" chips, or choose all-in."
			if increase>=int(g.min_raise):g.min_raise=increase;g.raise_epoch+=1
			g.street_bet=int(target)
		amount=int(target)-int(s.street_paid)
	s.hoard-=amount;s.committed+=amount;s.street_paid+=amount;g.pot+=amount;s.all_in=s.hoard==0;s.acted_epoch=g.raise_epoch
	log_line(g,s.name+" "+action.replace("_"," ")+(" · "+str(amount)+" chips" if amount>0 else "")+".")
	_ord_progress(g,ctx);return ""
static func _ord_progress(g: Dictionary, ctx: Dictionary) -> void:
	var alive=[];var pending=[]
	for i in g.seats.size():
		var s=g.seats[i]
		if not s.folded and not s.sitting_out:
			alive.append(i)
			if not s.all_in and (s.street_paid<g.street_bet or s.acted_epoch<g.raise_epoch):pending.append(i)
	if alive.size()==1:_ord_settle(g,ctx,false);return
	if pending.is_empty():g.phase="await_die";return
	var next=_ord_next(g,int(g.turn))
	for step in g.seats.size():
		if next in pending:g.turn=next;return
		next=_ord_next(g,next)
static func _ord_settle(g: Dictionary, ctx: Dictionary, reveal: bool) -> void:
	g.revealed=reveal;g.winners=[];g.last_payouts=[]
	var levels=[]
	for s in g.seats:
		if s.committed>0 and not s.committed in levels:levels.append(int(s.committed))
	levels.sort();var previous=0
	for level in levels:
		var contributors=[];var eligible=[]
		for i in g.seats.size():
			var s=g.seats[i]
			if s.committed>=level:
				contributors.append(i)
				if not s.folded and not s.sitting_out:eligible.append(i)
		var layer=(int(level)-previous)*contributors.size();previous=int(level)
		if contributors.size()==1 or eligible.is_empty():
			for i in contributors:g.seats[i].hoard+=layer/contributors.size()
			continue
		var winners=[];var best=-1
		for i in eligible:
			var score=0
			for d in g.seats[i].dice:score+=int(d)
			if score>best:best=score;winners=[i]
			elif score==best:winners.append(i)
		var fee=layer*int(g.fee_percent)/100;var available=layer-fee;ctx.house+=fee*int(g.chip_cp);g.house_out_cp+=fee*int(g.chip_cp)
		winners.sort_custom(func(a,b):return posmod(a-int(g.dealer)-1,g.seats.size())<posmod(b-int(g.dealer)-1,g.seats.size()))
		for k in winners.size():
			var amount=available/winners.size()+(1 if k<available%winners.size() else 0);var i=winners[k];g.seats[i].hoard+=amount;g.seats[i].last_win+=amount
			if not i in g.winners:g.winners.append(i)
	for s in g.seats:s.committed=0;s.street_paid=0
	g.pot=0;g.phase="between";log_line(g,"Gambit settled. Matched pots paid 80%; whole-chip rounding and side pots applied.")
static func wheel_wins(kind: String, number: int, result: int) -> bool:
	match kind:
		"odd":return result%2==1
		"even":return result%2==0
		"red":return result in RED
		"black":return not result in RED
		"ends":return result in [1,20]
		"number":return result==number
	return false
static func _reserve(g: Dictionary) -> int:
	if g.game=="run_of_luck":return int(g.pot)
	var maximum=0
	for result in range(1,21):
		var gross=0
		for s in g.seats:
			for bet in s.bets:
				if wheel_wins(bet.kind,int(bet.number),result):gross+=int(bet.amount)*(int(g.payouts[bet.kind])+1)
		maximum=maxi(maximum,gross)
	return maxi(0,maximum-int(g.pot))
static func _house_settle(g: Dictionary, ctx: Dictionary) -> void:
	var gross=0;g.winners=[];g.last_payouts=[]
	var highest=0;var second=-1;var first_count=0
	if g.game=="run_of_luck":
		for score in g.positions:highest=maxi(highest,int(score))
		for score in g.positions:
			if score==highest:first_count+=1
			else:second=maxi(second,int(score))
	for i in g.seats.size():
		var s=g.seats[i];var amount=0
		for bet in s.bets:
			if g.game=="run_of_luck":
				var score=int(g.positions[int(bet.number)])
				if score==highest:amount+=int(bet.amount)*2
				elif first_count==1 and score==second:amount+=int(bet.amount)/2
			elif wheel_wins(bet.kind,int(bet.number),int(g.result)):amount+=int(bet.amount)*(int(g.payouts[bet.kind])+1)
		s.hoard+=amount;s.last_win=amount;gross+=amount;g.last_payouts.append(amount)
		if amount>0:g.winners.append(i)
	var house_return=int(g.pot)*int(g.chip_cp)+int(g.house_escrow_cp)-gross*int(g.chip_cp)
	ctx.house+=house_return;g.house_out_cp+=house_return;g.pot=0;g.house_escrow_cp=0;g.phase="between";g.revealed=true
	log_line(g,"Race settled." if g.game=="run_of_luck" else "The wheel lands on "+str(g.result)+". Wagers settled.")
static func project(campaign: Dictionary, principal: String) -> Dictionary:
	var g=campaign.get("tavern_game",{});var out={};var dm=principal=="dm-local"
	for key in ["id","game","revision","phase","chip_cp","buyin","minimum","fee_percent","payouts","pot","escrow_cp","round","stage","turn","dealer","street_bet","min_raise","revealed","result","positions","last_moves","race_rolls","winners","last_payouts","log","rules"]:out[key]=g[key].duplicate(true) if g[key] is Array or g[key] is Dictionary else g[key]
	out.seats=[];out.gambit=g.round;out.hole=0;out.choice={};out.ante=[];out.played=[];out.deck_count=0;out.discard_count=0
	if dm:out.house_cp=campaign.get("casino_house_cp",0);out.required_reserve_cp=_reserve(g)*int(g.chip_cp)
	for s in g.seats:
		var a=Hearth20Contracts.find_actor(campaign,s.actor_id);var own=s.player_id==principal and a.get("owner_player_id","")==principal
		var clean={"actor_id":s.actor_id,"name":s.name,"ready":s.ready,"hoard":s.hoard,"mine":own,"hand":[],"hand_count":0,"flight":[],"ante_chosen":false,"owed":0,"folded":s.folded,"all_in":s.all_in,"sitting_out":s.sitting_out,"committed":s.committed,"street_paid":s.street_paid,"bets":s.bets.duplicate(true),"last_win":s.last_win,"dice_count":s.dice.size()}
		if own or dm or (g.revealed and not s.folded and not s.sitting_out):clean.dice=s.dice.duplicate()
		if own or dm:clean.wallet_cp=Hearth20TavernGames.purse(a)
		out.seats.append(clean)
	return out
static func valid(g: Variant) -> bool:
	if not g is Dictionary or var_to_bytes(g).size()>524288 or not Hearth20JoinCharacter.primitive(g) or g.get("game","") not in TYPES:return false
	if not Hearth20Contracts.valid_identifier(g.get("id")) or g.get("phase","") not in ["lobby","betting","await_die","racing","locked","between","complete","cancelled"]:return false
	for key in ["revision","chip_cp","buyin","minimum","fee_percent","pot","escrow_cp","initial_cp","house_in_cp","house_out_cp","house_escrow_cp","player_paid_cp","round","stage","turn","dealer","street_bet","min_raise","raise_epoch","result"]:
		if not integer(g.get(key)):return false
	if int(g.chip_cp) not in [1,10,100,1000] or g.buyin<1 or g.minimum<1 or g.minimum>g.buyin or g.fee_percent!=20 or g.stage>3 or g.result>20 or not g.get("revealed") is bool:return false
	if not g.get("payouts") is Dictionary or g.payouts.size()!=6:return false
	for kind in ["odd","even","red","black","ends","number"]:
		if not integer(g.payouts.get(kind),1,100):return false
	for key in ["positions","last_moves"]:
		if not g.get(key) is Array or g[key].size()!=5 or not g[key].all(func(v):return integer(v,0,12 if key=="positions" else 4)):return false
	if not g.get("race_rolls") is Array or g.race_rolls.size()>3:return false
	for rolls in g.race_rolls:
		if not rolls is Array or rolls.size()!=5 or not rolls.all(func(v):return integer(v,1,4)):return false
	if not g.get("seats") is Array or g.seats.size()>6 or not g.get("log") is Array or g.log.size()>128 or not g.log.all(func(v):return v is String and v.length()<=500):return false
	if not g.get("rules") is String or g.rules.length()>1000 or not g.get("winners") is Array or not g.get("last_payouts") is Array:return false
	if g.seats.is_empty():
		if g.phase not in ["lobby","complete","cancelled"]:return false
	elif g.turn>=g.seats.size() or g.dealer>=g.seats.size():return false
	if not g.winners.all(func(v):return integer(v,0,g.seats.size()-1)) or not g.last_payouts.all(func(v):return integer(v)):return false
	var seen={};var buyins=0;var wagers=0;var held=int(g.pot)*int(g.chip_cp)+int(g.house_escrow_cp);var committed=0
	for s in g.seats:
		if not s is Dictionary or not Hearth20Contracts.valid_identifier(s.get("actor_id")) or seen.has(s.actor_id) or not s.get("player_id") is String or (not s.player_id.is_empty() and not Hearth20Contracts.valid_identifier(s.player_id)) or not s.get("name") is String or s.name.length()>64:return false
		seen[s.actor_id]=true;buyins+=int(s.get("buyin_cp",0))
		for key in ["ready","folded","all_in","sitting_out"]:
			if not s.get(key) is bool:return false
		for key in ["hoard","buyin_cp","committed","street_paid","last_win"]:
			if not integer(s.get(key)):return false
		if not integer(s.get("acted_epoch"),-1,MAX) or s.street_paid>s.committed or not s.get("dice") is Array or s.dice.size()>3 or not s.get("bets") is Array or s.bets.size()>12:return false
		for i in s.dice.size():
			if not integer(s.dice[i],1,[8,6,4][i]):return false
		var bet_keys={}
		for bet in s.bets:
			if not bet is Dictionary or not integer(bet.get("amount"),1) or not bet.get("kind") is String or not integer(bet.get("number"),0,20):return false
			if g.game=="run_of_luck":
				if bet.kind!="racer" or bet.number>4 or s.bets.size()>1:return false
			elif g.game=="tymoras_spinner":
				if bet.kind not in g.payouts or (bet.kind=="number" and bet.number<1) or (bet.kind!="number" and bet.number!=0):return false
			else:return false
			var key=bet.kind+":"+str(bet.number)
			if bet_keys.has(key):return false
			bet_keys[key]=true;wagers+=int(bet.amount)
		held+=int(s.hoard)*int(g.chip_cp);committed+=int(s.committed)
	if buyins!=g.initial_cp:return false
	var allowed=["lobby","betting","await_die","between","complete","cancelled"] if g.game=="gambit_of_ord" else ["lobby","betting","racing","between","complete","cancelled"] if g.game=="run_of_luck" else ["lobby","betting","locked","between","complete","cancelled"]
	if g.phase not in allowed:return false
	if g.game=="run_of_luck":
		if g.stage!=g.race_rolls.size() or g.result!=0:return false
		for i in 5:
			var sum_value=0
			for rolls in g.race_rolls:sum_value+=int(rolls[i])
			if g.positions[i]!=sum_value or g.last_moves[i]!=(g.race_rolls.back()[i] if g.stage>0 else 0):return false
	elif not g.race_rolls.is_empty() or not g.positions.all(func(v):return int(v)==0) or not g.last_moves.all(func(v):return int(v)==0):return false
	if g.game=="tymoras_spinner" and (g.stage>1 or (g.result>0)!=(g.stage==1)):return false
	if g.game=="gambit_of_ord":
		if g.result!=0 or g.house_escrow_cp!=0:return false
		for s in g.seats:
			if not s.sitting_out and not s.folded and s.dice.size()!=g.stage:return false
	if g.game!="gambit_of_ord" and g.phase in ["betting","racing","locked"] and wagers!=g.pot:return false
	if g.phase in ["complete","cancelled"] and (g.escrow_cp!=0 or g.pot!=0 or g.house_escrow_cp!=0):return false
	if held!=int(g.initial_cp)+int(g.house_in_cp)-int(g.house_out_cp)-int(g.player_paid_cp):return false
	if g.game=="gambit_of_ord" and committed!=int(g.pot):return false
	if g.phase=="lobby" and (g.initial_cp!=0 or g.escrow_cp!=0):return false
	if g.phase not in ["lobby","complete","cancelled"] and (g.escrow_cp!=g.initial_cp or g.initial_cp<=0):return false
	return true
