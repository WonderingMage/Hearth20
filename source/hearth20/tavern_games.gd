extends RefCounted
class_name Hearth20TavernGames
## Traditional 80-card deck. Campaign money is escrowed once, then cashed out once.
const SUITS={"Black":[1,2,3,5,6,7,9],"Blue":[1,2,4,6,7,9,11],"Brass":[1,2,3,4,5,7,9],"Bronze":[1,3,6,7,8,9,11],"Copper":[1,3,5,6,7,8,10],"Gold":[2,4,6,8,9,11,13],"Green":[1,2,4,5,6,8,10],"Red":[2,3,5,7,8,10,12],"Silver":[2,3,6,7,8,10,12],"White":[1,2,3,4,5,6,8]}
const GOOD=["Brass","Bronze","Copper","Gold","Silver","Bahamut"]
const SPECIAL={"Bahamut":13,"Dracolich":10,"Tiamat":13,"Archmage":9,"Dragonslayer":8,"Druid":6,"Fool":3,"Priest":5,"Princess":4,"Thief":7}
const TINTS=["#6b6265","#4477a8","#be984b","#7f8c68","#ad724b","#cfad55","#4d7947","#b74b35","#a1adbc","#b6c5c8"]
const POWER={"Black":"Take 3 from the stakes.","Blue":"Choose tribute or a larger pot.","Brass":"Right neighbor: stronger good card or 5 coins.","Bronze":"Take two lowest ante cards.","Copper":"Replace with a triggered draw.","Gold":"Draw for your good dragons.","Green":"Left neighbor: weaker evil card or 5 coins.","Red":"Strongest opponent: 1 coin and a random card.","Silver":"Good flights draw a card.","White":"Weakest opponent pays 2.","Bahamut":"Mixed opponents pay 10; avoid evil allies.","Dracolich":"Triggered: +2 per evil dragon at scoring.","Tiamat":"Five evil colors; avoid good allies.","Archmage":"Later plays always trigger.","Dragonslayer":"Remove a dragon below 8.","Druid":"Lowest flight wins this gambit.","Fool":"Draw for stronger opposing flights.","Priest":"Winner shares stakes with left neighbor.","Princess":"Retrigger your good dragons in chosen order.","Thief":"Take 7 from the stakes."}
const MAX_CP=100000000000
static var catalog: Dictionary={}
static func cards() -> Dictionary:
	if not catalog.is_empty():return catalog
	var out={};var art=0
	for suit in SUITS:
		for strength in SUITS[suit]:
			var id=suit.to_lower()+"-"+str(strength);out[id]={"id":id,"name":suit+" Dragon","suit":suit,"strength":strength,"type":"good" if suit in GOOD else "evil","art":art,"text":POWER[suit]}
		art+=1
	for name_value in SPECIAL:
		var id=name_value.to_lower();out[id]={"id":id,"name":name_value,"suit":name_value,"strength":SPECIAL[name_value],"type":"good" if name_value=="Bahamut" else "evil" if name_value in ["Tiamat","Dracolich"] else "mortal","art":art,"text":POWER[name_value]};art+=1
	catalog=out;return out
static func card(id: String) -> Dictionary:return cards().get(id,{})
static func purse(actor: Dictionary) -> int:
	var coins=actor.get("coins",{});var total=0
	if not coins is Dictionary:return -1
	for spec in [["cp",1],["sp",10],["ep",50],["gp",100],["pp",1000]]:
		var value=coins.get(spec[0],0)
		if not Hearth20Contracts._integer_number(value) or value<0 or value>MAX_CP:return -1
		total+=int(value)*int(spec[1])
	return total if total<=MAX_CP else -1
static func set_purse(actor: Dictionary, cp: int) -> void:
	actor.coins={"pp":0,"gp":cp/100,"ep":0,"sp":(cp%100)/10,"cp":cp%10}
static func locked(g: Dictionary) -> bool:return not g.is_empty() and g.get("escrow_cp",0)>0
static func _fail(text: String) -> Dictionary:return {"ok":false,"error":text}
static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size()-1,0,-1):var j=rng.randi_range(0,i);var tmp=a[i];a[i]=a[j];a[j]=tmp
static func _draw(g: Dictionary, rng: RandomNumberGenerator) -> String:
	if g.deck.is_empty():g.deck=g.discard.duplicate();g.discard.clear();_shuffle(g.deck,rng)
	return str(g.deck.pop_back()) if not g.deck.is_empty() else ""
static func _draw_to(g: Dictionary, i: int, n: int, rng: RandomNumberGenerator) -> void:
	for _k in n:
		if g.seats[i].hand.size()>=10:return
		var id=_draw(g,rng)
		if id.is_empty():return
		g.seats[i].hand.append(id)
static func _log(g: Dictionary, text: String) -> void:
	g.log.append(text)
	while g.log.size()>100:g.log.pop_front()
static func _pay(g: Dictionary, from: int, to: int, amount: int) -> void:
	var paid=mini(amount,int(g.seats[from].hoard));g.seats[from].hoard-=paid;g.seats[from].owed+=amount-paid
	if to>=0:g.seats[to].hoard+=paid
	else:g.pot+=paid
static func _steal(g: Dictionary, i: int, n: int) -> void:
	var value=mini(n,int(g.pot));g.pot-=value;g.seats[i].hoard+=value
static func _power(g: Dictionary, i: int, id: String) -> void:g.jobs.push_front({"kind":"effect","seat":i,"card":id})
static func _prompt(g: Dictionary, i: int, kind: String, options: Array, data: Dictionary={}) -> void:
	if options.is_empty():return
	g.choice={"seat":i,"kind":kind,"options":options,"data":data}
static func _opt(id: String, label: String) -> Dictionary:return {"id":id,"label":label}
static func _score(seat: Dictionary, scoring: bool=false) -> int:
	var n=0
	for id in seat.flight:
		var c=card(id);n+=int(c.strength)
		if scoring and seat.flags.get("dracolich",false) and c.type=="evil":n+=2
	return n
static func _neighbors(g: Dictionary, i: int, left: bool) -> int:return (i+(1 if left else g.seats.size()-1))%g.seats.size()
static func _extreme(g: Dictionary, i: int, lowest: bool) -> Array:
	var indexes=[];var value=1000000 if lowest else -1
	for j in g.seats.size():
		if j==i:continue
		var s=_score(g.seats[j])
		if (s<value if lowest else s>value):indexes=[j];value=s
		elif s==value:indexes.append(j)
	return indexes
static func _take_random(g: Dictionary, target: int, receiver: int, rng: RandomNumberGenerator) -> void:
	if g.seats[target].hand.is_empty() or g.seats[receiver].hand.size()>=10:return
	var hand=g.seats[target].hand;g.seats[receiver].hand.append(hand.pop_at(rng.randi_range(0,hand.size()-1)))
static func _buy(g: Dictionary, i: int, rng: RandomNumberGenerator) -> void:
	var id=_draw(g,rng)
	if id.is_empty():return
	g.discard.append(id);_pay(g,i,-1,int(card(id).strength));_draw_to(g,i,4-g.seats[i].hand.size(),rng);_log(g,str(g.seats[i].name)+" buys replacement cards.")
static func _winner_indexes(g: Dictionary, scoring: bool=true) -> Array:
	var values={};var low=g.flags.get("druid",false);var best=1000000 if low else -1000000
	for i in g.seats.size():
		var s=g.seats[i];var mixed_good=false;var mixed_evil=false
		for id in s.flight:
			mixed_good=mixed_good or card(id).type=="good";mixed_evil=mixed_evil or card(id).type=="evil"
		if (s.flight.has("bahamut") and mixed_evil) or (s.flight.has("tiamat") and mixed_good):continue
		var total=_score(s,scoring);values[i]=total
		best=mini(best,total) if low else maxi(best,total)
	var result=[]
	for i in values:
		if values[i]==best:result.append(i)
	return result
static func _award_hole(g: Dictionary) -> void:
	var best=-1;var winners=[]
	for i in g.seats.size():
		if g.seats[i].hoard>best:best=g.seats[i].hoard;winners=[i]
		elif g.seats[i].hoard==best:winners.append(i)
	var remainder=int(g.hole)%winners.size();var each=int(g.hole)/winners.size()
	for i in winners:g.seats[i].hoard+=each+(1 if remainder>0 else 0);remainder=maxi(0,remainder-1)
	g.hole=0;g.winners=winners;g.phase="complete"
static func _end_gambit(g: Dictionary, winners: Array) -> void:
	if winners.is_empty():
		for i in g.seats.size():winners.append(i)
	var total=int(g.pot);g.pot=0
	if winners.size()==1 and g.flags.get("priest",false):
		var w=int(winners[0]);g.seats[w].hoard+=(total+1)/2;g.seats[_neighbors(g,w,true)].hoard+=total/2
	else:
		var each=total/winners.size();var remainder=total%winners.size()
		for i in winners:g.seats[i].hoard+=each+(1 if remainder>0 else 0);remainder=maxi(0,remainder-1)
	g.last_winners=winners;_log(g,"Gambit "+str(g.gambit)+" awarded to "+", ".join(winners.map(func(i):return g.seats[i].name))+".")
	for s in g.seats:
		var paid=mini(int(s.hoard),int(s.owed));s.hoard-=paid;g.hole+=paid;s.owed=0
	g.jobs.clear();g.choice={};g.phase="between"
	if g.seats.any(func(s):return s.hoard==0):_award_hole(g)
static func _begin_ante(g: Dictionary, rng: RandomNumberGenerator) -> void:
	for s in g.seats:
		g.discard.append_array(s.flight);s.flight=[];s.ante="";s.flags={};s.rewards=[]
	g.discard.append_array(g.ante);g.ante=[];g.round=1;g.gambit+=1;g.played=[];g.flags={};g.choice={};g.jobs=[];g.phase="ante"
	if g.gambit>1:
		var start=int(g.last_winners[0])
		for k in g.seats.size():_draw_to(g,(start+k)%g.seats.size(),2,rng)
static func _reveal_ante(g: Dictionary, rng: RandomNumberGenerator) -> void:
	var values=[]
	for s in g.seats:values.append(int(card(s.ante).strength))
	var best=-1;var leader=-1
	for i in values.size():
		if values.count(values[i])==1 and values[i]>best:best=values[i];leader=i
	for s in g.seats:g.ante.append(s.ante);s.ante=""
	if leader<0:
		g.discard.append_array(g.ante);g.ante=[]
		for i in g.seats.size():_draw_to(g,i,1,rng)
		_log(g,"Every ante tied. Draw again and choose a new ante.");return
	var price=int(values.max())
	for i in g.seats.size():_pay(g,i,-1,price)
	g.leader=leader;g.turn=leader;g.played=[];g.phase="play";_log(g,"Ante: "+str(price)+" coins each.")
	if g.seats[g.turn].hand.size()==1:_buy(g,g.turn,rng)
static func _effect(g: Dictionary, i: int, id: String, rng: RandomNumberGenerator) -> void:
	var c=card(id);var suit=str(c.suit);var s=g.seats[i];_log(g,c.name+" triggers.")
	match suit:
		"Black","Thief":_steal(g,i,3 if suit=="Black" else 7)
		"Gold":_draw_to(g,i,s.flight.filter(func(k):return card(k).type=="good").size(),rng)
		"Silver":
			for k in g.seats.size():
				var j=(i+k)%g.seats.size()
				if g.seats[j].flight.any(func(k):return card(k).type=="good"):_draw_to(g,j,1,rng)
		"Copper":
			if s.flight.has(id):
				var index=s.flight.find(id);s.flight.remove_at(index);g.discard.append(id);var replacement=_draw(g,rng)
				if not replacement.is_empty():s.flight.insert(index,replacement);_power(g,i,replacement);_replace_played(g,i,id,replacement)
		"Blue":_prompt(g,i,"blue",[_opt("tribute","Each opponent pays you 1 coin"),_opt("stakes","Each opponent adds "+str(s.flight.size())+" coins to stakes")])
		"Brass","Green":
			var target=_neighbors(g,i,suit=="Green");var options=[_opt("pay","Pay 5 coins")]
			for k in g.seats[target].hand:
				var other=card(k)
				if (other.type=="good" and other.strength>c.strength) if suit=="Brass" else (other.type=="evil" and other.strength<c.strength):options.append(_opt(k,"Give "+other.name+" "+str(other.strength)))
			_prompt(g,target,"tribute",options,{"receiver":i})
		"Red","White":
			var targets=_extreme(g,i,suit=="White");var opts=targets.map(func(j):return _opt(str(j),str(g.seats[j].name)))
			_prompt(g,i,"opponent",opts,{"power":suit})
		"Bronze":g.jobs.push_front({"kind":"ante_pick","seat":i,"remaining":2,"lowest":true})
		"Archmage","Dracolich":s.flags[suit.to_lower()]=true
		"Druid","Priest":g.flags[suit.to_lower()]=true
		"Fool":_draw_to(g,i,g.seats.filter(func(other):return _score(other)>_score(s)).size(),rng)
		"Bahamut":
			for j in g.seats.size():
				if j!=i and g.seats[j].flight.any(func(k):return card(k).type=="good") and g.seats[j].flight.any(func(k):return card(k).type=="evil"):_pay(g,j,i,10)
		"Dragonslayer":
			var opts=[]
			for j in g.seats.size():
				for k in g.seats[j].flight:
					if card(k).type!="mortal" and card(k).strength<8:opts.append(_opt(k,str(g.seats[j].name)+": "+card(k).name+" "+str(card(k).strength)))
			_prompt(g,i,"slay",opts)
		"Princess":g.jobs.push_front({"kind":"princess","seat":i,"cards":s.flight.filter(func(k):return card(k).type=="good")})
static func _replace_played(g: Dictionary, i: int, old: String, replacement: String) -> void:
	for entry in g.played:
		if entry.seat==i and entry.card==old:entry.card=replacement
static func _resolve(g: Dictionary, chosen: String, rng: RandomNumberGenerator) -> bool:
	var choice=g.choice;var i=int(choice.seat);var s=g.seats[i]
	if not choice.options.any(func(o):return o.id==chosen):return false
	g.choice={}
	match choice.kind:
		"blue":
			for j in g.seats.size():
				if j!=i:_pay(g,j,i if chosen=="tribute" else -1,1 if chosen=="tribute" else s.flight.size())
		"tribute":
			var receiver=int(choice.data.receiver)
			if chosen=="pay":_pay(g,i,receiver,5)
			else:
				s.hand.erase(chosen)
				if g.seats[receiver].hand.size()<10:g.seats[receiver].hand.append(chosen)
				else:s.hand.append(chosen)
				_log(g,s.name+" offers "+card(chosen).name+" "+str(card(chosen).strength)+".")
		"opponent":
			var target=int(chosen);_pay(g,target,i,2 if choice.data.power=="White" else 1)
			if choice.data.power=="Red":_take_random(g,target,i,rng)
		"slay":
			for target in g.seats:
				if target.flight.has(chosen):target.flight.erase(chosen);g.discard.append(chosen);break
		"ante":
			g.ante.erase(chosen);s.hand.append(chosen)
			if int(choice.data.remaining)>1:g.jobs.push_front({"kind":"ante_pick","seat":i,"remaining":int(choice.data.remaining)-1,"lowest":bool(choice.data.lowest)})
		"princess":
			var remaining=choice.data.cards.duplicate();remaining.erase(chosen)
			g.jobs.push_front({"kind":"princess","seat":i,"cards":remaining});_power(g,i,chosen)
	return true
static func _specials(g: Dictionary, i: int) -> void:
	var s=g.seats[i]
	for suit in SUITS:
		var matching=s.flight.filter(func(id):return card(id).suit==suit or (id=="tiamat" and suit not in GOOD))
		var key="color:"+suit
		if matching.size()>=3 and not s.rewards.has(key):
			s.rewards.append(key);var values=matching.map(func(id):return int(card(id).strength));values.sort();var value=int(values[-2])
			for j in g.seats.size():
				if j!=i:_pay(g,j,i,value)
			_log(g,s.name+" completes a "+suit+" color flight.")
	var mortals=s.flight.filter(func(id):return card(id).type=="mortal")
	if mortals.size()>=3 and not s.rewards.has("color:mortal"):
		s.rewards.append("color:mortal");var values=mortals.map(func(id):return int(card(id).strength));values.sort()
		for j in g.seats.size():
			if j!=i:_pay(g,j,i,int(values[-2]))
	for n in range(1,14):
		if s.flight.filter(func(id):return int(card(id).strength)==n).size()>=3 and not s.rewards.has("strength:"+str(n)):
			s.rewards.append("strength:"+str(n));_steal(g,i,n);g.jobs.push_front({"kind":"ante_pick","seat":i,"remaining":2,"lowest":false});_log(g,s.name+" completes a strength flight.")
static func _advance(g: Dictionary, rng: RandomNumberGenerator) -> void:
	var guard=0
	while g.choice.is_empty() and not g.jobs.is_empty() and guard<256:
		guard+=1;var job=g.jobs.pop_front();var i=int(job.get("seat",0))
		match job.kind:
			"effect":
				_effect(g,i,str(job.card),rng)
				if g.pot==0:_end_gambit(g,_winner_indexes(g))
			"princess":
				var available=job.cards.filter(func(id):return g.seats[i].flight.has(id))
				_prompt(g,i,"princess",available.map(func(id):return _opt(id,card(id).name+" "+str(card(id).strength))),{"cards":available})
			"ante_pick":
				if g.seats[i].hand.size()<10 and not g.ante.is_empty():
					var available=g.ante.duplicate()
					if job.lowest:
						var low=available.map(func(id):return int(card(id).strength)).min();available=available.filter(func(id):return card(id).strength==low)
					_prompt(g,i,"ante",available.map(func(id):return _opt(id,card(id).name+" "+str(card(id).strength))),{"remaining":job.remaining,"lowest":job.lowest})
			"finish":
				g.jobs.push_front({"kind":"after_special","seat":i})
				for offset in g.seats.size():_specials(g,(i+offset)%g.seats.size())
			"after_special":
				for j in g.seats.size():
					if g.seats[j].hand.is_empty():_buy(g,j,rng)
				if g.pot==0:_end_gambit(g,_winner_indexes(g));continue
				if g.played.size()>=g.seats.size():
					var winners=_winner_indexes(g)
					if g.round>=3 and winners.size()==1:_end_gambit(g,winners);continue
					var values=[];var indexes=[]
					for entry in g.played:
						if g.seats[int(entry.seat)].flight.has(entry.card):values.append(int(card(entry.card).strength));indexes.append(entry.seat)
					var best=-1
					for k in values.size():
						if values.count(values[k])==1 and values[k]>best:g.leader=indexes[k];best=values[k]
					g.round+=1;g.turn=g.leader;g.played=[]
				else:g.turn=(int(g.turn)+1)%g.seats.size()
				if g.seats[g.turn].hand.size()==1:_buy(g,g.turn,rng)
				if g.seats[g.turn].hand.is_empty():_end_gambit(g,_winner_indexes(g))
	if guard>=256:_log(g,"Interaction limit reached; DM can cancel and refund.")
static func _seat(g: Dictionary, actor_id: String) -> int:
	for i in g.get("seats",[]).size():
		if g.seats[i].actor_id==actor_id:return i
	return -1
static func apply(campaign: Dictionary, principal: String, command: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var check=Hearth20CasinoWallet.before(campaign,principal,command)
	if not check.ok or check.get("handled",false):return check
	var previous=campaign.get("tavern_game",{}).duplicate(true)
	var result=_apply_game(campaign,principal,command,rng)
	if result.ok:Hearth20CasinoWallet.after(campaign,previous)
	return result
static func _apply_game(campaign: Dictionary, principal: String, command: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var action=str(command.get("action",""));var selected=str(command.get("game","three_dragon_ante"))
	if action=="house_reserve" or (action=="open" and selected in Hearth20CasinoGames.TYPES) or (action!="open" and campaign.get("tavern_game",{}).get("game","") in Hearth20CasinoGames.TYPES):return Hearth20CasinoGames.apply(campaign,principal,command,rng)
	if var_to_bytes(command).size()>8192:return _fail("Game request is too large.")
	var before=campaign.get("tavern_game",{});var g=before.duplicate(true);var kind=str(command.get("action",""));var dm=principal=="dm-local";var deltas=[]
	if kind=="open":
		if not dm:return _fail("Only the DM opens a game for the party.")
		if locked(g):return _fail("Finish or refund the current game first.")
		var chip=command.get("chip_cp",100)
		if not Hearth20Contracts._integer_number(chip) or int(chip) not in [1,10,100,1000]:return _fail("Choose copper, silver, gold or platinum stakes.")
		g={"id":"casino-"+Crypto.new().generate_random_bytes(12).hex_encode(),"game":"three_dragon_ante","revision":0,"phase":"lobby","chip_cp":int(chip),"seats":[],"deck":[],"discard":[],"ante":[],"choice":{},"jobs":[],"pot":0,"hole":0,"escrow_cp":0,"initial_chips":0,"gambit":0,"round":0,"leader":0,"turn":0,"played":[],"flags":{},"log":["The DM opened Three-Dragon Ante."],"winners":[],"last_winners":[]}
	elif g.is_empty():return _fail("The DM has not opened a game.")
	else:
		if command.get("game_id","")!=g.id or not Hearth20Contracts._integer_number(command.get("revision")) or int(command.revision)!=int(g.revision):return _fail("The table changed. Use the current hand and try again.")
		match kind:
			"join":
				if g.phase!="lobby":return _fail("Seats are locked for this game.")
				var actor=Hearth20Contracts.find_actor(campaign,str(command.get("actor_id","")))
				if actor.is_empty() or not actor.get("is_hero",false) or actor.get("decorative",false) or (not dm and actor.get("owner_player_id","")!=principal):return _fail("Choose your own character token.")
				if _seat(g,str(actor.id))>=0:return _fail("That character already has a seat.")
				if not dm and g.seats.any(func(s):return s.player_id==principal):return _fail("Choose one character for this game.")
				if g.seats.size()>=6 or purse(actor)<0:return _fail("This table supports two to six funded characters.")
				g.seats.append({"actor_id":str(actor.id),"player_id":str(actor.get("owner_player_id","")),"name":str(actor.name).left(64),"ready":dm,"hand":[],"flight":[],"ante":"","hoard":0,"owed":0,"buyin_cp":0,"flags":{},"rewards":[]})
			"leave","ready":
				if g.phase!="lobby":return _fail("The DM must finish or refund before changing seats.")
				var index=_seat(g,str(command.get("actor_id","")))
				if index<0 or (not dm and g.seats[index].player_id!=principal):return _fail("Choose your own seat.")
				if kind=="leave":g.seats.remove_at(index)
				else:g.seats[index].ready=not g.seats[index].ready
			"start":
				if not dm or g.phase!="lobby" or g.seats.size()<2 or not g.seats.all(func(s):return s.ready):return _fail("The DM can deal when two to six seated characters are ready.")
				var chips=g.seats.size()*10;var buyin=chips*int(g.chip_cp)
				for s in g.seats:
					var actor=Hearth20Contracts.find_actor(campaign,s.actor_id)
					if actor.is_empty() or purse(actor)<buyin:return _fail(str(s.name)+" needs "+str(buyin/100.)+" gp in their declared balance.")
				for s in g.seats:s.hoard=chips;s.buyin_cp=buyin;deltas.append({"id":s.actor_id,"cp":-buyin})
				g.initial_chips=chips*g.seats.size();g.escrow_cp=g.initial_chips*int(g.chip_cp);g.deck=cards().keys();_shuffle(g.deck,rng)
				for i in g.seats.size():_draw_to(g,i,6,rng)
				_begin_ante(g,rng);_log(g,"Purses committed to escrow. Six private cards dealt to each player.")
			"ante","play","choose":
				var index=int(g.choice.seat) if kind=="choose" and not g.choice.is_empty() else int(g.turn) if kind=="play" else _seat(g,str(command.get("actor_id","")))
				if index<0 or index>=g.seats.size():return _fail("There is no action for that seat.")
				var actor=Hearth20Contracts.find_actor(campaign,g.seats[index].actor_id)
				if not dm and (g.seats[index].player_id!=principal or actor.get("owner_player_id","")!=principal):return _fail("Wait for your own turn.")
				var id=str(command.get("card_id",""))
				if kind=="choose":
					if g.choice.is_empty() or not _resolve(g,str(command.get("option","")),rng):return _fail("Choose a current card-power option.")
				elif kind=="ante":
					if g.phase!="ante" or not g.seats[index].ante.is_empty() or not g.seats[index].hand.has(id):return _fail("Choose an ante from your own hand.")
					g.seats[index].hand.erase(id);g.seats[index].ante=id
					if g.seats.all(func(s):return not s.ante.is_empty()):_reveal_ante(g,rng)
				else:
					if g.phase!="play" or not g.choice.is_empty() or not g.seats[index].hand.has(id):return _fail("Choose a playable card from your own hand.")
					var trigger=g.played.is_empty() or card(id).strength<=card(g.played.back().card).strength or g.seats[index].flags.get("archmage",false)
					g.seats[index].hand.erase(id);g.seats[index].flight.append(id);g.played.append({"seat":index,"card":id});_log(g,g.seats[index].name+" plays "+card(id).name+" "+str(card(id).strength)+".")
					g.jobs=[{"kind":"finish","seat":index}]
					if trigger:_power(g,index,id)
				_advance(g,rng)
			"next":
				if not dm or g.phase!="between":return _fail("The DM can begin the next gambit after scoring.")
				_begin_ante(g,rng)
			"cashout":
				if not dm or g.phase!="between":return _fail("Cash out between gambits, or cancel for a full refund.")
				_award_hole(g);_log(g,"The DM ended the session between gambits.")
			"cancel":
				if not dm or g.phase in ["complete","cancelled"]:return _fail("Only the DM can cancel an unsettled table.")
				if locked(g):
					for s in g.seats:deltas.append({"id":s.actor_id,"cp":s.buyin_cp})
				g.phase="cancelled";g.escrow_cp=0;g.choice={};g.jobs=[];_log(g,"Cancelled. Original buy-ins refunded; no losses or winnings applied.")
			"close":
				if not dm or locked(g):return _fail("Finish or refund this game before returning the party to the map.")
				campaign.tavern_game={};return {"ok":true}
			_:return _fail("Unknown casino action.")
	if g.phase=="complete" and locked(g):
		for s in g.seats:deltas.append({"id":s.actor_id,"cp":int(s.hoard)*int(g.chip_cp)})
		g.escrow_cp=0;_log(g,"Final hoards paid back to declared balances.")
	if locked(g):
		var total=int(g.pot)+int(g.hole)
		for s in g.seats:total+=int(s.hoard)
		if total!=int(g.initial_chips):return _fail("Accounting mismatch. The previous game state was preserved.")
	if not valid(g):return _fail("The card state is invalid. The previous state was preserved.")
	for delta in deltas:
		var actor=Hearth20Contracts.find_actor(campaign,str(delta.id));var balance=purse(actor)
		if actor.is_empty() or balance<0 or balance+int(delta.cp)<0 or balance+int(delta.cp)>MAX_CP:return _fail("The character purse changed or is unavailable. No transaction was committed.")
	for delta in deltas:
		var actor=Hearth20Contracts.find_actor(campaign,str(delta.id));var balance=purse(actor);set_purse(actor,balance+int(delta.cp))
		if not campaign.get("tavern_ledger") is Array:campaign.tavern_ledger=[]
		campaign.tavern_ledger.append({"game_id":g.id,"actor_id":delta.id,"action":kind,"delta_cp":delta.cp,"before_cp":balance,"after_cp":purse(actor),"time":Time.get_datetime_string_from_system(true)})
		while campaign.tavern_ledger.size()>1000:campaign.tavern_ledger.pop_front()
	g.revision=int(g.revision)+1;campaign.tavern_game=g;return {"ok":true}
static func project(campaign: Dictionary, principal: String) -> Dictionary:
	var g=campaign.get("tavern_game",{})
	if g.is_empty():return {}
	if g.get("game","") in Hearth20CasinoGames.TYPES:return Hearth20CasinoWallet.project_seats(g,Hearth20CasinoGames.project(campaign,principal))
	var dm=principal=="dm-local";var out={}
	for key in ["id","game","revision","phase","chip_cp","pot","hole","gambit","round","leader","turn","played","log","winners","last_winners","ante","escrow_cp"]:out[key]=g[key].duplicate(true) if g[key] is Array or g[key] is Dictionary else g[key]
	out.deck_count=g.deck.size();out.discard_count=g.discard.size();out.seats=[];out.choice={}
	for s in g.seats:
		var actor=Hearth20Contracts.find_actor(campaign,s.actor_id);var owns=not actor.is_empty() and actor.get("owner_player_id","")==principal and s.player_id==principal
		var clean={"actor_id":s.actor_id,"name":s.name,"ready":s.ready,"flight":s.flight.duplicate(),"hoard":s.hoard,"owed":s.owed,"hand_count":s.hand.size(),"ante_chosen":not s.ante.is_empty(),"mine":owns}
		if dm or owns:clean.hand=s.hand.duplicate();clean.private_ante=s.ante;clean.wallet_cp=purse(actor)
		out.seats.append(clean)
	if not g.choice.is_empty():
		out.choice={"seat":g.choice.seat,"kind":g.choice.kind}
		var s=g.seats[int(g.choice.seat)];var actor=Hearth20Contracts.find_actor(campaign,s.actor_id)
		if dm or (s.player_id==principal and actor.get("owner_player_id","")==principal):out.choice.options=g.choice.options.duplicate(true)
	return Hearth20CasinoWallet.project_seats(g,out)
static func _index(value: Variant, count: int) -> bool:return Hearth20Contracts._integer_number(value) and int(value)>=0 and int(value)<count
static func valid(g: Variant) -> bool:
	if g is Dictionary and g.get("game","") in Hearth20CasinoGames.TYPES:return Hearth20CasinoGames.valid(g)
	if not g is Dictionary or var_to_bytes(g).size()>524288 or not Hearth20JoinCharacter.primitive(g):return false
	if g.is_empty():return true
	if not Hearth20Contracts.valid_identifier(g.get("id")) or g.get("game","")!="three_dragon_ante" or g.get("phase","") not in ["lobby","ante","play","between","complete","cancelled"]:return false
	if not g.get("seats") is Array or g.seats.size()>6 or not g.get("deck") is Array or not g.get("discard") is Array or not g.get("ante") is Array:return false
	for key in ["revision","pot","hole","escrow_cp","initial_chips","chip_cp","gambit","round","turn","leader"]:
		if not Hearth20Contracts._integer_number(g.get(key)) or g[key]<0 or g[key]>MAX_CP:return false
	if int(g.chip_cp) not in [1,10,100,1000]:return false
	for key in ["choice","flags"]:
		if not g.get(key) is Dictionary:return false
	for key in ["jobs","played","log","winners","last_winners"]:
		if not g.get(key) is Array or g[key].size()>256:return false
	if not g.flags.values().all(func(v):return v is bool):return false
	if not g.log.all(func(v):return v is String and v.length()<=512):return false
	var seen={};var held=g.deck.duplicate();held.append_array(g.discard);held.append_array(g.ante);var total=int(g.pot)+int(g.hole);var actors={}
	for seat in g.seats:
		if not seat is Dictionary or not seat.get("hand") is Array or not seat.get("flight") is Array or not seat.get("ante") is String or seat.hand.size()>10 or not seat.get("flags") is Dictionary or not seat.get("rewards") is Array:return false
		if not Hearth20Contracts.valid_identifier(seat.get("actor_id")) or actors.has(seat.actor_id) or not seat.get("player_id") is String or not seat.get("name") is String or seat.name.length()>64 or not seat.get("ready") is bool:return false
		if not seat.player_id.is_empty() and not Hearth20Contracts.valid_identifier(seat.player_id):return false
		if not seat.flags.values().all(func(v):return v is bool) or not seat.rewards.all(func(v):return v is String and v.length()<40):return false
		actors[seat.actor_id]=true
		for key in ["hoard","owed","buyin_cp"]:
			if not Hearth20Contracts._integer_number(seat.get(key)) or seat[key]<0 or seat[key]>MAX_CP:return false
		held.append_array(seat.hand);held.append_array(seat.flight)
		if not seat.ante.is_empty():held.append(seat.ante)
		total+=int(seat.hoard)
	for id in held:
		if not id is String or not cards().has(id) or seen.has(id):return false
		seen[id]=true
	var count=g.seats.size()
	if g.phase in ["ante","play","between"] and (count<2 or not locked(g)):return false
	if g.phase=="play" and (not _index(g.turn,count) or not _index(g.leader,count)):return false
	for key in ["winners","last_winners"]:
		if not g[key].all(func(v):return _index(v,count)):return false
	for play in g.played:
		if not play is Dictionary or not _index(play.get("seat"),count) or not play.get("card") is String or not cards().has(play.card):return false
	for job in g.jobs:
		if not job is Dictionary or not _index(job.get("seat"),count) or job.get("kind","") not in ["effect","princess","ante_pick","finish","after_special"]:return false
		if job.kind=="effect" and (not job.get("card") is String or not cards().has(job.card)):return false
		if job.kind=="princess" and (not job.get("cards") is Array or not job.cards.all(func(v):return v is String and cards().has(v))):return false
		if job.kind=="ante_pick" and (job.get("remaining",0) not in [1,2] or not job.get("lowest") is bool):return false
	if not g.choice.is_empty():
		var choice=g.choice
		if g.phase!="play" or not _index(choice.get("seat"),count) or not choice.get("data") is Dictionary or not choice.get("options") is Array or choice.options.is_empty() or choice.options.size()>80:return false
		if choice.get("kind","") not in ["blue","tribute","opponent","slay","ante","princess"]:return false
		for option in choice.options:
			if not option is Dictionary or not option.get("id") is String or option.id.length()>96 or not option.get("label") is String or option.label.length()>160:return false
		match choice.kind:
			"blue":
				if not choice.options.all(func(o):return o.id in ["tribute","stakes"]):return false
			"tribute":
				if not _index(choice.data.get("receiver"),count) or not choice.options.all(func(o):return o.id=="pay" or g.seats[int(choice.seat)].hand.has(o.id)):return false
			"opponent":
				if choice.data.get("power","") not in ["Red","White"] or not choice.options.all(func(o):return o.id.is_valid_int() and _index(int(o.id),count) and int(o.id)!=choice.seat):return false
			"slay":
				if not choice.options.all(func(o):return cards().has(o.id) and g.seats.any(func(seat):return seat.flight.has(o.id))):return false
			"ante":
				if choice.data.get("remaining",0) not in [1,2] or not choice.data.get("lowest") is bool or not choice.options.all(func(o):return g.ante.has(o.id)):return false
			"princess":
				if not choice.data.get("cards") is Array or not choice.options.all(func(o):return g.seats[int(choice.seat)].flight.has(o.id) and card(o.id).type=="good"):return false
	return not locked(g) or (total==int(g.initial_chips) and seen.size()==80 and g.escrow_cp==g.initial_chips*g.chip_cp)
