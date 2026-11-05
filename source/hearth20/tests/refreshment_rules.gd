extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func consume(c: Dictionary,kind: String,time: float) -> float:
	var s=Hearth20Refreshments.state(c,"dm-local");var result=Hearth20Refreshments.apply(c,"dm-local",{"action":kind,"order_id":s.order.id},time)
	expect(result.ok,"accepted "+kind);var duration=Hearth20Refreshments.BITE_SECONDS if kind=="bite" else Hearth20Refreshments.SIP_SECONDS
	expect(not Hearth20Refreshments.apply(c,"dm-local",{"action":kind,"order_id":s.order.id},time+.1).ok,"overlapping serving rejected")
	expect(not Hearth20Refreshments.advance(c,time+duration-.01),"no early serving completion")
	expect(Hearth20Refreshments.advance(c,time+duration),"serving finishes on deadline")
	expect(not Hearth20Refreshments.advance(c,time+duration),"completion is idempotent")
	return time+duration+.1
func run() -> void:
	for food in Hearth20RefreshmentCatalog.FOODS:
		for drink in Hearth20RefreshmentCatalog.DRINKS:
			var c={};var time=10000.
			expect(Hearth20Refreshments.apply(c,"dm-local",{"action":"order","food":food,"drink":drink},time).ok,"catalog order "+food+" + "+drink)
			var id=c.refreshments["dm-local"].order.id
			expect(not Hearth20Refreshments.apply(c,"dm-local",{"action":"sip","order_id":id},time+.1).ok,"arrival protects animation")
			time+=1.
			var sequence=["bite","bite","sip","sip","sip"] if food.length()%2==0 else ["sip","sip","sip","bite","bite"]
			for i in sequence.size():
				time=consume(c,sequence[i],time)
				expect(Hearth20Refreshments.menu_available(c.refreshments["dm-local"])==(i==4),"menu waits for BOTH servings: "+str(i))
				if i<4:expect(not Hearth20Refreshments.apply(c,"dm-local",{"action":"order","food":food,"drink":drink},time).ok,"unfinished companion serving prevents another order")
			var s=c.refreshments["dm-local"]
			expect(s.food_bites==2 and s.drink_sips==3,"exactly two bites and three sips")
			expect(s.beers.size()==(1 if drink=="beer" else 0),"only a finished beer adds alcohol")
			expect(not Hearth20Refreshments.apply(c,"dm-local",{"action":"sip","order_id":id},time).ok,"no fourth sip")
			expect(not Hearth20Refreshments.apply(c,"dm-local",{"action":"bite","order_id":id},time).ok,"no third bite")
			expect(Hearth20Refreshments.valid(c.refreshments),"save shape valid")
	var c={};var t=20000.
	for dose in 6:
		expect(Hearth20Refreshments.apply(c,"dm-local",{"action":"order","food":"chips","drink":"beer"},t).ok,"beer order "+str(dose));t+=1.
		for action in ["bite","sip","bite","sip","sip"]:t=consume(c,action,t)
		expect(Hearth20Refreshments.spectating(c,"dm-local",t)==(dose==5),"six completed beers cause spectating")
	var saved=JSON.parse_string(JSON.stringify(c));expect(Hearth20Refreshments.valid(saved.refreshments),"reopened order and beer timestamps valid")
	expect(Hearth20Refreshments.spectating(saved,"dm-local",t),"reopen retains blackout")
	expect(not Hearth20Refreshments.apply(saved,"dm-local",{"action":"order","food":"chips","drink":"water"},t).ok,"blackout blocks orders")
	var wake=float(c.refreshments["dm-local"].blackout_until)
	saved.refreshments["other-player"]=Hearth20Refreshments.empty_state();saved.refreshments["other-player"].beers=[t,t]
	expect(absf(wake-float(c.refreshments["dm-local"].beers.back())-300.)<.001,"blackout is exactly five minutes")
	Hearth20Refreshments.advance(saved,wake-.01);expect(Hearth20Refreshments.spectating(saved,"dm-local",wake-.01),"blackout lasts until wake deadline")
	Hearth20Refreshments.advance(saved,wake+.001)
	expect(saved.refreshments["dm-local"].beers.is_empty() and not Hearth20Refreshments.spectating(saved,"dm-local",wake+.001),"waking clears ALL one-hour beer effects")
	expect(saved.refreshments["other-player"].beers.size()==2,"waking one player leaves another player's effects unchanged")
	expect(is_equal_approx(float(saved.refreshments["dm-local"].woke_at),wake) and not Hearth20Refreshments.advance(saved,wake+1.),"wake publishes exactly once without retriggering")
	expect(Hearth20Refreshments.apply(saved,"dm-local",{"action":"order","food":"cake","drink":"water"},wake+1.).ok,"player can order again after waking")
	var ordinary={"refreshments":{"dm-local":Hearth20Refreshments.empty_state()}};ordinary.refreshments["dm-local"].beers=[100.,200.,300.]
	Hearth20Refreshments.advance(ordinary,3700.);expect(ordinary.refreshments["dm-local"].beers==[200.,300.],"below blackout threshold oldest hour expires independently")
	Hearth20Refreshments.advance(ordinary,3800.);expect(ordinary.refreshments["dm-local"].beers==[300.],"each subsequent beer has its own hour")
	var malformed=c.refreshments.duplicate(true);malformed["dm-local"].updated_at=NAN;expect(not Hearth20Refreshments.valid(malformed),"nonfinite saved time rejected")
	expect(not Hearth20Refreshments.apply({},"unknown-player",{"action":"order","food":"chips","drink":"water"},t).ok,"unknown principal rejected")
	var session=Hearth20Session.new();root.add_child(session);session.configure(Hearth20Identity.new_campaign("Blackout contract"));session.campaign.refreshments=c.refreshments
	# Use present timestamps to exercise every server boundary, not only the domain.
	session.campaign.refreshments["dm-local"].beers=[Time.get_unix_time_from_system(),Time.get_unix_time_from_system(),Time.get_unix_time_from_system(),Time.get_unix_time_from_system(),Time.get_unix_time_from_system(),Time.get_unix_time_from_system()]
	session.campaign.refreshments["dm-local"].blackout_until=Time.get_unix_time_from_system()+300.
	expect(not session.set_table_mode("casino").ok,"blackout DM cannot pull mode rope")
	expect(not session._casino_action_as("dm-local",{"action":"open","game":"gambit_of_ord"}).ok,"blackout blocks casino actions")
	expect(not session._apply_table_request({"action":"roll","expression":"1d20"},"dm-local").ok,"blackout blocks dice rolls")
	expect(not session._apply_board_action({"action":"draw"},"dm-local").ok,"blackout blocks shared tools")
	session._save_refreshment_ledger();var copy=session.campaign.duplicate(true);copy.erase("refreshments");session.configure(copy);expect(session.is_spectating(),"persistent ledger prevents reconnect/save rollback clearing alcohol")
	session.queue_free();await process_frame
	print("Refreshment rules: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
