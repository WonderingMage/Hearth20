extends RefCounted
class_name Hearth20CasinoWallet
## Explicit table declarations, never a claim of synchronization with a website.
const MAX_CP=100000000000
static func fail(message: String) -> Dictionary:return {"ok":false,"error":message}
static func coins(cp: int) -> Dictionary:return {"gp":cp/100,"sp":(cp%100)/10,"cp":cp%10}
static func label(cp: int) -> String:
	var c=coins(cp);return "%d gp · %d sp · %d cp"%[c.gp,c.sp,c.cp]
static func pending(campaign: Dictionary, principal: String) -> Array:
	return campaign.get("casino_receipts",[]).filter(func(r):return r.player_id==principal and not r.acknowledged).duplicate(true)
static func declared(g: Dictionary, actor_id: String) -> bool:return g.get("declarations",{}).has(actor_id)
static func before(campaign: Dictionary, principal: String, command: Dictionary) -> Dictionary:
	if var_to_bytes(command).size()>8192 or not Hearth20JoinCharacter.primitive(command):return fail("Invalid casino request.")
	var action=str(command.get("action",""));var g=campaign.get("tavern_game",{})
	if action=="acknowledge_balance":
		for r in campaign.get("casino_receipts",[]):
			if r.id!=command.get("receipt_id",""):continue
			if r.player_id!=principal:return fail("Only that player can confirm their D&D Beyond update.")
			if r.acknowledged:return fail("That balance was already confirmed.")
			r.acknowledged=true;return {"ok":true,"handled":true}
		return fail("That balance notice is unavailable.")
	if action in ["declare_balance","ready","start"]:
		if g.is_empty() or g.get("phase","")!="lobby":return fail("Declare coins before the table starts. Balances lock during play.")
		if command.get("game_id","")!=g.id or not Hearth20Contracts._integer_number(command.get("revision")) or int(command.revision)!=int(g.revision):return fail("The table changed. Review it and try again.")
	if action=="declare_balance":
		var id=str(command.get("actor_id",""));var actor=Hearth20Contracts.find_actor(campaign,id);var seat={}
		for s in g.seats:
			if s.actor_id==id:seat=s;break
		if actor.is_empty() or seat.is_empty():return fail("Take your character's seat before declaring coins.")
		var owner=str(actor.get("owner_player_id",""))
		if (owner!=principal or seat.player_id!=principal) and not (principal=="dm-local" and owner.is_empty()):return fail("Players declare their own balance. The CM can declare only an unowned house character.")
		if not pending(campaign,principal).is_empty():return fail("Confirm your previous D&D Beyond balance update first.")
		var total=0
		for pair in [["gp",100],["sp",10],["cp",1]]:
			var v=command.get(pair[0])
			if not Hearth20Contracts._integer_number(v) or v<0 or v>MAX_CP:return fail("Enter non-negative whole numbers for gold, silver and copper.")
			total+=int(v)*int(pair[1])
			if total>MAX_CP:return fail("The declared balance exceeds the table limit.")
		if not g.get("declarations") is Dictionary:g.declarations={}
		g.declarations[id]={"player_id":principal,"balance_cp":total}
		Hearth20TavernGames.set_purse(actor,total);seat.ready=false;g.revision+=1
		return {"ok":true,"handled":true}
	if action=="ready":
		var id=str(command.get("actor_id",""))
		if not declared(g,id):return fail("The player must declare their gold, silver and copper before readying.")
	if action=="start":
		for s in g.seats:
			if not declared(g,s.actor_id):return fail(str(s.name)+" must declare their gold, silver and copper first.")
			var declaration=g.declarations[s.actor_id]
			if not pending(campaign,str(declaration.player_id)).is_empty():return fail(str(s.name)+" must confirm their previous balance notice first.")
			if Hearth20TavernGames.purse(Hearth20Contracts.find_actor(campaign,s.actor_id))!=int(declaration.balance_cp):return fail("A declared balance changed. Ask the player to review and declare it again.")
	return {"ok":true,"handled":false}
static func after(campaign: Dictionary, previous: Dictionary) -> void:
	var g=campaign.get("tavern_game",{})
	if g.is_empty() or previous.get("escrow_cp",0)<=0 or g.get("escrow_cp",0)!=0 or g.get("phase","") not in ["complete","cancelled"]:return
	if not campaign.get("casino_receipts") is Array:campaign.casino_receipts=[]
	for s in g.seats:
		var declaration=g.get("declarations",{}).get(s.actor_id,{})
		if declaration.is_empty():continue
		var id=str(g.id)+"-"+str(s.actor_id)
		if campaign.casino_receipts.any(func(r):return r.id==id):continue
		var actor=Hearth20Contracts.find_actor(campaign,s.actor_id);var final_cp=Hearth20TavernGames.purse(actor)
		campaign.casino_receipts.append({"id":id,"game_id":str(g.id),"actor_id":str(s.actor_id),"player_id":str(declaration.player_id),"name":str(s.name),"kind":"refund" if g.phase=="cancelled" else "payout","before_cp":int(declaration.balance_cp),"after_cp":final_cp,"delta_cp":final_cp-int(declaration.balance_cp),"acknowledged":false})
	# Never evict an unacknowledged notice. Declarations cannot accumulate new ones
	# for that principal until it is confirmed, so this remains bounded by players.
	while campaign.casino_receipts.size()>1000:
		var index=campaign.casino_receipts.find_custom(func(r):return r.acknowledged)
		if index<0:break
		campaign.casino_receipts.remove_at(index)
static func project_seats(g: Dictionary, out: Dictionary) -> Dictionary:
	for s in out.get("seats",[]):
		s.balance_declared=declared(g,str(s.actor_id))
		if s.has("wallet_cp") and s.balance_declared:s.declared_cp=int(g.declarations[s.actor_id].balance_cp)
	return out
static func valid(campaign: Dictionary) -> bool:
	var g=campaign.get("tavern_game",{});var declarations=g.get("declarations",{})
	if not declarations is Dictionary or declarations.size()>256:return false
	for id in declarations:
		var d=declarations[id]
		if not Hearth20Contracts.valid_identifier(id) or not d is Dictionary or not Hearth20Contracts.valid_identifier(d.get("player_id")) or not Hearth20CasinoGames.integer(d.get("balance_cp")):return false
	var receipts=campaign.get("casino_receipts",[])
	if not receipts is Array or receipts.size()>1000 or var_to_bytes(receipts).size()>524288:return false
	var ids={}
	for r in receipts:
		if not r is Dictionary:return false
		for key in ["id","game_id","actor_id","player_id"]:
			if not r.get(key) is String or r[key].length()>256 or r[key].is_empty():return false
		if ids.has(r.id) or not r.get("acknowledged") is bool or not r.get("name") is String or r.name.length()>64 or r.get("kind") not in ["payout","refund"]:return false
		if not Hearth20CasinoGames.integer(r.get("before_cp")) or not Hearth20CasinoGames.integer(r.get("after_cp")) or not Hearth20Contracts._integer_number(r.get("delta_cp")) or r.delta_cp!=r.after_cp-r.before_cp:return false
		ids[r.id]=true
	return true
