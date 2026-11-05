extends RefCounted
class_name Hearth20Refreshments
## Server-owned servings and one-hour beer doses. No character-sheet changes.
const BEER_SECONDS=3600.
const BLACKOUT_SECONDS=300.
const MAX_BEER_DOSES=6
const MAX_PLAYERS=256
const BITE_SECONDS=3.60
const SIP_SECONDS=3.25
static func empty_state() -> Dictionary:
	return {"order":{},"food_bites":0,"drink_sips":0,"pending":{},"beers":[],"blackout_until":0.,"woke_at":0.,"updated_at":0.}
static func state(campaign: Dictionary,player: String) -> Dictionary:
	return campaign.get("refreshments",{}).get(player,empty_state())
static func active_beers(value: Dictionary,now: float) -> Array:
	return value.get("beers",[]).filter(func(time):return float(time)+BEER_SECONDS>now)
static func spectating(campaign: Dictionary,player: String,now: float=-1.) -> bool:
	if now<0.:now=Time.get_unix_time_from_system()
	return float(state(campaign,player).get("blackout_until",0.))>now
static func menu_available(value: Dictionary) -> bool:
	return value.get("pending",{}).is_empty() and (value.get("order",{}).is_empty() or (int(value.food_bites)>=2 and int(value.drink_sips)>=3))
static func view(campaign: Dictionary,player: String,now: float) -> Dictionary:
	var value=state(campaign,player).duplicate(true);value.beers=active_beers(value,now);value.server_now=now;value.menu_available=menu_available(value);value.spectating=float(value.get("blackout_until",0.))>now
	value.wake_at=float(value.get("blackout_until",0.));value.scope=str(campaign.get("refreshment_scope",""))
	return value
static func fail(message: String) -> Dictionary:return {"ok":false,"error":message}
static func apply(campaign: Dictionary,player: String,command: Dictionary,now: float) -> Dictionary:
	if player!="dm-local" and not campaign.get("participants",{}).has(player):return fail("Join the table before ordering refreshments.")
	if command.size()>5 or var_to_bytes(command).size()>1024:return fail("Invalid refreshment request.")
	if spectating(campaign,player,now):return fail("You are resting for five minutes after a blackout.")
	var value=state(campaign,player).duplicate(true);var action=str(command.get("action",""))
	if not value.pending.is_empty():return fail("Finish the current bite or sip first.")
	var event={}
	if action=="order":
		if not menu_available(value):return fail("Finish both your food and drink before ordering again.")
		var food=str(command.get("food",""));var drink=str(command.get("drink",""))
		if not Hearth20RefreshmentCatalog.FOODS.has(food) or not Hearth20RefreshmentCatalog.DRINKS.has(drink):return fail("Choose one food and one drink.")
		value.order={"id":"order-"+Crypto.new().generate_random_bytes(8).hex_encode(),"food":food,"drink":drink,"arrived_at":now};value.food_bites=0;value.drink_sips=0
		event={"kind":"order","food":food,"drink":drink,"duration":.8}
	elif action in ["bite","sip"]:
		if value.order.is_empty() or command.get("order_id","")!=value.order.id:return fail("That serving is no longer on your table.")
		if now<float(value.order.arrived_at)+.8:return fail("Your refreshments are appearing.")
		if action=="bite" and int(value.food_bites)>=2:return fail("You finished your food.")
		if action=="sip" and int(value.drink_sips)>=3:return fail("You finished your drink.")
		var duration=BITE_SECONDS if action=="bite" else SIP_SECONDS
		value.pending={"action":action,"started_at":now,"ends_at":now+duration}
		event={"kind":action,"food":value.order.food,"drink":value.order.drink,"number":value.food_bites if action=="bite" else value.drink_sips,"duration":duration}
	else:return fail("Unknown refreshment action.")
	value.updated_at=now
	if not campaign.get("refreshments") is Dictionary:campaign.refreshments={}
	if campaign.refreshments.size()>=MAX_PLAYERS and not campaign.refreshments.has(player):return fail("This campaign's refreshment inventory is full.")
	campaign.refreshments[player]=value
	event.id="snack-"+Crypto.new().generate_random_bytes(8).hex_encode();event.player_id=player
	return {"ok":true,"event":event}
static func advance(campaign: Dictionary,now: float) -> bool:
	var changed=false
	for player in campaign.get("refreshments",{}):
		var value: Dictionary=campaign.refreshments[player];var active=active_beers(value,now)
		if active.size()!=value.beers.size():value.beers=active;value.updated_at=now;changed=true
		var until=float(value.get("blackout_until",0.))
		if until>0. and now>=until and float(value.get("woke_at",0.))<until:value.woke_at=until;value.beers=[];value.updated_at=now;changed=true
		if value.pending.is_empty() or now<float(value.pending.ends_at):continue
		if value.pending.action=="bite":value.food_bites=mini(2,int(value.food_bites)+1)
		else:
			value.drink_sips=mini(3,int(value.drink_sips)+1)
			if value.drink_sips==3 and value.order.get("drink","")=="beer" and float(value.pending.ends_at)+BEER_SECONDS>now:
				value.beers.append(float(value.pending.ends_at))
				if value.beers.size()>=6:value.blackout_until=float(value.pending.ends_at)+BLACKOUT_SECONDS
				# A late host restart can cross both the sip and wake deadlines.
				if float(value.get("blackout_until",0.))>0. and now>=float(value.blackout_until):value.woke_at=float(value.blackout_until);value.beers=[]
		value.pending={};value.updated_at=now;changed=true
	return changed
static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()>MAX_PLAYERS or var_to_bytes(value).size()>524288:return false
	for player in value:
		if player!="dm-local" and not Hearth20Contracts.valid_identifier(player):return false
		var s=value[player]
		if not s is Dictionary or not s.get("order") is Dictionary or not s.get("pending") is Dictionary or not s.get("beers") is Array or s.beers.size()>MAX_BEER_DOSES:return false
		if not Hearth20Contracts._integer_number(s.get("food_bites")) or s.food_bites<0 or s.food_bites>2:return false
		if not Hearth20Contracts._integer_number(s.get("drink_sips")) or s.drink_sips<0 or s.drink_sips>3:return false
		if not s.get("updated_at") is float and not s.get("updated_at") is int:return false
		if not is_finite(float(s.updated_at)) or float(s.updated_at)<0.:return false
		for field in ["blackout_until","woke_at"]:
			if not (s.get(field,0.) is float or s.get(field,0.) is int) or not is_finite(float(s.get(field,0.))) or float(s.get(field,0.))<0.:return false
		for time in s.beers:
			if not (time is float or time is int) or not is_finite(float(time)) or time<0.:return false
		if not s.order.is_empty():
			if not Hearth20Contracts.valid_identifier(s.order.get("id")) or not Hearth20RefreshmentCatalog.FOODS.has(s.order.get("food")) or not Hearth20RefreshmentCatalog.DRINKS.has(s.order.get("drink")):return false
			if not (s.order.get("arrived_at") is float or s.order.get("arrived_at") is int) or not is_finite(float(s.order.arrived_at)):return false
		if not s.pending.is_empty():
			if s.pending.get("action","") not in ["bite","sip"] or s.order.is_empty():return false
			for field in ["started_at","ends_at"]:
				if not (s.pending.get(field) is float or s.pending.get(field) is int) or not is_finite(float(s.pending[field])):return false
			if float(s.pending.ends_at)<float(s.pending.started_at) or float(s.pending.ends_at)-float(s.pending.started_at)>4.:return false
	return true
