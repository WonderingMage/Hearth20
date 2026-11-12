extends SceneTree
const Fakes=preload("steam_fakes.gd")
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func metrics(rate: int,ping=40,quality=1.) -> Dictionary:
	return {"send_rate":rate,"bytes_out_per_second":float(rate)*.95,"pending_reliable":65536,"sent_unacknowledged_reliable":131072,"ping":ping,"local_quality":quality,"remote_quality":quality}
func run() -> void:
	create_timer(15).timeout.connect(func():push_error("Rate test watchdog");quit(1))
	var rate=Hearth20SteamRate.new()
	expect(rate.sample(metrics(65536),true,1,0) and rate.target==4*1024*1024,"initial low SDK estimate is explicitly raised to a useful chosen rate")
	rate.applied=rate.target
	for second in range(1,11):
		var data=metrics(rate.target);rate.sample(data,true,1,second*1000);rate.applied=rate.target
	expect(rate.target>=40*1024*1024,"healthy loaded connection can grow beyond a 300 Mbps-class payload rate")
	var fast=rate.target
	rate.sample(metrics(rate.target,40,.8),true,1,11000)
	expect(rate.target<fast,"packet loss backs off instead of flooding a weak link")
	rate.applied=rate.target;var low=rate.target;rate.sample(metrics(rate.target,300),true,1,12000)
	expect(rate.target<low,"large RTT inflation also reduces the chosen rate")
	rate.applied=rate.target;var idle=rate.target;rate.sample(metrics(rate.target),false,1,13000)
	expect(rate.target==idle,"idle control traffic does not trigger bandwidth growth")
	var shared=Hearth20SteamRate.new();shared.sample(metrics(65536),true,8,0)
	expect(shared.target==Hearth20SteamRate.START/8,"multiple peers share the initial upload allowance")
	for second in range(1,20):shared.applied=shared.target;shared.sample(metrics(shared.target),true,8,second*1000)
	expect(shared.target<=Hearth20SteamRate.MAXIMUM/8,"peer controllers retain an aggregate upper bound")
	for second in range(20,60):shared.applied=shared.target;shared.sample(metrics(shared.target,40,.5),true,8,second*1000)
	expect(shared.target>=Hearth20SteamRate.MINIMUM,"severely congested links retain a bounded minimum")
	rate.last=metrics(32*1024*1024,200)
	expect(rate.window_bytes()>4*1024*1024 and rate.window_bytes()<=16*1024*1024,"long-distance fast links get a larger bounded acknowledgement window")
	var session=Hearth20Session.new();root.add_child(session);session.configure(Hearth20Identity.new_campaign("Rate verification"))
	var link=Hearth20SteamLink.new();root.add_child(link);var api=Fakes.Api.new();root.add_child(api);link.api=api;link.fake_backend=true
	link.peer_factory=func():return Fakes.Peer.new()
	link.attach(session)
	link.initialize();link.host();api.lobby_created.emit(1,109775240000000001)
	link.can_send(44)
	expect(api.configured_rates.get(10)==api.configured_rates.get(11) and api.send_rate==link.rate_controllers[44].target,"connection-level min and max both reach the fake SDK")
	api.apply_connection_rate=false;session.multiplayer.multiplayer_peer.packet.handle=8;api.send_rate=65536;link.can_send(44)
	var report=link.rate_controllers[44].report()
	expect(report.config_ok and report.effective_bps==65536 and report.requested_bps>65536,"an accepted setting is not falsely reported as an effective speed")
	api.connection_config_ok=false;session.multiplayer.multiplayer_peer.packet.handle=9;link.can_send(44)
	expect(not link.rate_controllers[44].config_ok,"a refused native rate setting remains visible in diagnostics")
	expect(api.calls.any(func(call):return call==["connection-config",8,10,Hearth20SteamRate.START]),"a replacement native connection reapplies settings even with a reused peer ID")
	link.disconnect_table();expect(link.rate_controllers.is_empty(),"disconnect releases rate estimates and diagnostics")
	link._steam_shutdown();session.queue_free();link.queue_free();api.queue_free();await process_frame
	expect(not Engine.has_singleton("Steam"),"rate simulation never initializes a real Steam account")
	print("Steam rate: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
