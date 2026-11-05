extends RefCounted
class_name Hearth20CasinoGamesUI
const RACERS=["Ember","Jade","Saffron","Indigo","Pearl"]
static func number(parent: Node, minimum: int, maximum: int, value: int, step=1) -> SpinBox:
	var input=SpinBox.new();input.min_value=minimum;input.max_value=maxi(minimum,maximum);input.step=step;input.value=clampi(value,minimum,maxi(minimum,maximum));input.custom_minimum_size.y=38;input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(input);return input
static func view_seat(p: Hearth20CasinoPortal, i: int) -> void:p.selected_view_seat=i;p.signature="";p._refresh()
static func reserve(p: Hearth20CasinoPortal, parent: Node) -> void:
	var cp=int(p.app.campaign.get("casino_house_cp",0));p._text(parent,"Casino reserve · "+p._money(cp),15)
	var amount=SpinBox.new();amount.min_value=0;amount.max_value=1000000000;amount.step=25;amount.value=maxf(cp/100.,1000.);amount.prefix="Total ";amount.suffix=" gp";amount.custom_minimum_size.y=38;parent.add_child(amount)
	p._button(parent,"Set casino reserve",func():p._send("house_reserve",{"amount_cp":roundi(amount.value*100)}))
static func build(p: Hearth20CasinoPortal, mine: int) -> void:
	var g=p.game;var dm=p.app.session.local_role=="dm";var title=str(Hearth20CasinoGames.NAMES[g.game]);var ord_game=g.game=="gambit_of_ord"
	p.summary.text=("CASINO MASTER · DEALER\n" if dm else "")+title+"\n"+str(g.phase).replace("_"," ").capitalize()+" · Round "+str(g.round)+"\nEach chip = "+p._money(int(g.chip_cp))+"\nStakes "+str(g.pot)+" chips"
	for i in g.seats.size():
		var s=g.seats[i];var box=VBoxContainer.new();box.add_theme_constant_override("separation",5);p.roster.add_child(box)
		p._text(box,("✦ " if ord_game and g.phase=="betting" and g.turn==i else "")+str(s.name),16)
		p._text(box,str(s.hoard)+" chips"+(" · folded" if s.folded else " · all-in" if s.all_in else " · ready" if s.ready and g.phase=="lobby" else ""),13)
		if not ord_game:
			for bet in s.bets:p._text(box,bet_label(bet,g.game)+" · "+str(bet.amount)+" chips",12)
		if dm:
			var index=i;p._button(box,"View this seat",func():view_seat(p,index))
	if g.phase=="lobby":
		p._text(p.detail,"Take a seat",25);p._text(p.detail,"Buy-in: "+str(g.buyin)+" chips / "+p._money(int(g.buyin)*int(g.chip_cp))+" per character. Funds stay in the declared balance until the table starts.",14)
		var eligible=p.app.campaign.actors.filter(func(a):return a.get("is_hero",false) and not a.get("decorative",false)) if dm else p.app.session.client_snapshot.get("sheets",[])
		for a in eligible:
			var id=str(a.id)
			if not g.seats.any(func(s):return s.actor_id==id):p._button(p.actions,"Seat "+str(a.name),func():p._send("join",{"actor_id":id}))
		for s in g.seats:
			if dm or s.mine:
				p._wallet(s);var id=str(s.actor_id);p._button(p.actions,("Unready " if s.ready else "Ready ")+str(s.name),func():p._send("ready",{"actor_id":id}));p._button(p.actions,"Leave seat · "+str(s.name),func():p._send("leave",{"actor_id":id}))
		if dm:
			p._button(p.actions,"Deal private d8" if ord_game else "Open wagers",func():p._send("start"))
			if not ord_game:reserve(p,p.detail)
	elif ord_game:
		_ord(p,mine,dm)
	else:_house(p,mine,dm)
	if g.phase=="between" and dm:
		p._button(p.actions,"Begin another round",func():p._send("next"));p._button(p.actions,"Cash out declared coins",func():p._send("cashout"))
	if dm and g.phase not in ["complete","cancelled","lobby"]:p._button(p.actions,"Cancel & refund original buy-ins",func():p._send("cancel"))
	if dm and g.phase in ["complete","cancelled"]:p._button(p.actions,"Return the party to the map",func():p._send("close"))
	if dm:p._button(p.actions,"View gold ledger",p._ledger)
	if p.scene.game_view.animating:
		for button in p.actions.find_children("*","Button",true,false):button.disabled=true
		p._text(p.actions,"Let the table finish its animation…",14)
	p.status.text=str(g.log.back()) if not g.log.is_empty() else ""
static func _ord(p: Hearth20CasinoPortal, mine: int, dm: bool) -> void:
	var g=p.game;p._text(p.detail,"The hidden gambit",24);p._text(p.detail,"Private d8 · bet · private d6 · bet · d4 showdown. Matched pots pay 80%; the casino keeps 20%. Uncalled wagers return in full.",14)
	if mine>=0 and mine<g.seats.size():
		var s=g.seats[mine];p._text(p.detail,"Your dice are displayed in front of you. Other seats stay concealed until showdown.",13)
		if g.revealed and not s.folded:p._text(p.detail,"Total · "+str(_sum(s.get("dice",[]))),23)
	if g.phase=="betting":
		var s=g.seats[g.turn];p._text(p.detail,"To act · "+str(s.name),19)
		if dm or (mine==g.turn and s.mine):
			var actor_id=str(s.actor_id);var call=maxi(0,int(g.street_bet)-int(s.street_paid))
			p._button(p.actions,"Check" if call==0 else "Call · "+str(mini(call,int(s.hoard)))+" chips",func():p._send("check" if call==0 else "call",{"actor_id":actor_id}))
			var raise_min=int(g.street_bet)+int(g.min_raise);var maximum=int(s.street_paid)+int(s.hoard)
			p._text(p.actions,"Raise this street's total to",13);var amount=number(p.actions,raise_min,maximum,raise_min)
			var raise_button=p._button(p.actions,"Raise",func():p._send("raise",{"actor_id":actor_id,"total":int(amount.value)}));raise_button.disabled=maximum<raise_min
			p._button(p.actions,"All in · "+str(s.hoard)+" chips",func():p._send("all_in",{"actor_id":actor_id}));p._button(p.actions,"Fold this gambit",func():p._send("fold",{"actor_id":actor_id}))
	elif g.phase=="await_die":
		p._text(p.detail,"Betting is matched",19)
		if dm:p._button(p.actions,"Roll the hidden d6" if g.stage==1 else "Roll d4 & reveal totals",func():p._send("roll_next"))
	elif g.phase=="between":
		for s in g.seats:
			p._text(p.detail,str(s.name)+(" · folded" if s.folded else " · "+str(_sum(s.get("dice",[]))) if g.revealed else " · unrevealed")+"\nHoard "+str(s.hoard)+" chips",15)
	if dm and g.phase in ["betting","await_die"] and mine>=0 and mine<g.seats.size() and not g.seats[mine].folded:
		var s=g.seats[mine];var actor_id=str(s.actor_id);p._text(p.actions,"CM character-ability ruling",14);var die=OptionButton.new()
		for i in s.get("dice",[]).size():die.add_item(["d8","d6","d4"][i])
		p.actions.add_child(die);p._button(p.actions,"Allow a private reroll",func():p._send("ruling_reroll",{"actor_id":actor_id,"die_index":die.selected}));p._button(p.actions,"Resolve a forced fold",func():p._send("ruling_fold",{"actor_id":actor_id}))
static func _house(p: Hearth20CasinoPortal, mine: int, dm: bool) -> void:
	var g=p.game;var race=g.game=="run_of_luck";p._text(p.detail,"Five racers · three stages" if race else "Tymora's wheel",24)
	p._text(p.detail,"Winner returns 2× the wager; second place returns ½. Tied first-place racers each win; second-place refunds require one clear winner." if race else "Choose odd, even, red, black, the ends (1/20), or an exact number. Displayed ratios are profit; winning stakes return too.",14)
	if race:p._text(p.detail,"Lizard by Froggreen · CC BY 4.0 · Sketchfab. Model credit in Da Rolls.",12)
	if not race:
		for kind in ["odd","even","red","black","ends","number"]:p._text(p.detail,kind.capitalize()+" · "+str(g.payouts[kind])+":1",13)
	if g.phase=="betting" and mine>=0 and mine<g.seats.size() and (dm or g.seats[mine].mine):
		var s=g.seats[mine];var actor_id=str(s.actor_id);p._text(p.actions,"Place a wager · minimum "+str(g.minimum)+" chips",14)
		var prefs=p.bet_prefs.get(g.id,{});var choice=OptionButton.new();choice.name="WagerKind";p.actions.add_child(choice);var kinds=["odd","even","red","black","ends","number"]
		for item in (RACERS if race else kinds):choice.add_item(str(item).capitalize())
		choice.selected=clampi(int(prefs.get("number",0)),0,4) if race else maxi(0,kinds.find(prefs.get("kind","odd")))
		var exact=number(p.actions,1,20,int(prefs.get("number",1)));exact.name="WagerNumber";exact.visible=not race and kinds[choice.selected]=="number"
		var amount=number(p.actions,int(g.minimum),int(s.hoard),int(prefs.get("amount",g.minimum)));amount.name="WagerAmount"
		var remember=func():p.bet_prefs[g.id]={"kind":"racer" if race else kinds[choice.selected],"number":choice.selected if race else int(exact.value),"amount":int(amount.value)}
		choice.item_selected.connect(func(i):exact.visible=not race and kinds[i]=="number";remember.call());exact.value_changed.connect(func(_v):remember.call());amount.value_changed.connect(func(_v):remember.call())
		var button=p._button(p.actions,"Place wager",func():p._send("wager",{"actor_id":actor_id,"amount":int(amount.value),"kind":"racer" if race else kinds[choice.selected],"number":choice.selected if race else int(exact.value) if kinds[choice.selected]=="number" else 0}));button.disabled=s.hoard<g.minimum or (race and not s.bets.is_empty())
		for i in s.bets.size():
			var slot=i;p._button(p.actions,"Remove · "+bet_label(s.bets[i],g.game),func():p._send("remove_wager",{"actor_id":actor_id,"bet_index":slot}))
	if dm and g.phase=="betting":
		p._text(p.actions,"Backing needed · "+p._money(int(g.get("required_reserve_cp",0))),13);p._button(p.actions,"Lock wagers & release cages" if race else "Lock all wagers",func():p._send("lock_bets"));reserve(p,p.detail)
	if dm and g.phase=="racing":p._button(p.actions,"Roll stage "+str(int(g.stage)+1)+" / 3",func():p._send("race_stage"))
	if dm and g.phase=="locked":p._button(p.actions,"Spin the wheel",func():p._send("spin"))
	if g.phase in ["racing","between"] and race:
		for i in 5:p._text(p.detail,RACERS[i]+" · "+str(g.positions[i])+" paces",16)
	elif g.phase=="between":p._text(p.detail,"The wheel is turning…" if p.scene.game_view.animating else "The wheel lands on "+str(g.result),25)
static func bet_label(bet: Dictionary, game: String) -> String:
	return RACERS[int(bet.number)] if game=="run_of_luck" else "Number "+str(bet.number) if bet.kind=="number" else str(bet.kind).capitalize()
static func _sum(values: Array) -> int:
	var total=0
	for value in values:total+=int(value)
	return total
