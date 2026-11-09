extends SceneTree
const Fakes=preload("steam_fakes.gd")
const Party=preload("party_onboarding.gd")
var checks=0
var errors=[]
var case_name=""
var output=""
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note)
func finish(code=-1) -> void:
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"case":case_name,"checks":checks,"errors":errors},"  "))
	print("Adversarial case ",case_name,": %d checks, %d failures"%[checks,errors.size()])
	quit((0 if errors.is_empty() else 1) if code<0 else code)
func session_fixture() -> Hearth20Session:
	var session=Hearth20Session.new();root.add_child(session);session.configure(Hearth20Identity.new_campaign("Synthetic adversarial campaign"));return session
func run() -> void:
	var args=OS.get_cmdline_user_args();output=args[0];case_name=args[1]
	create_timer(8).timeout.connect(func():errors.append("Operation failed to return before the watchdog.");finish(2))
	match case_name:
		"missing-drawing-points":
			expect(not Hearth20BoardTools.valid_object({"kind":"line"},Hearth20Identity.new_campaign().scenes[0]),"missing drawing coordinates are rejected")
		"missing-measure-points":
			expect(not Hearth20BoardTools.valid_measure({},Hearth20Identity.new_campaign().scenes[0]),"missing measurement coordinates are rejected")
		"malformed-schema":
			var campaign=Hearth20Identity.new_campaign();campaign.schema_version={}
			expect(not Hearth20Identity.validate_campaign(campaign).ok,"an invalid schema type produces a normal validation failure")
		"nonfinite-map-scale":
			var scene=Hearth20Identity.new_campaign().scenes[0];scene.feet_per_cell=NAN
			expect(not Hearth20Contracts.valid_scene(scene),"nonfinite map scales are rejected")
		"bad-movement-policy", "bad-turn-budget", "bad-campaign-revision":
			var campaign=Hearth20Identity.new_campaign()
			var actor=Hearth20TokenInventory.new_actor("Guest",true,campaign.scenes[0],Vector2(2.5,2.5));actor.id="edge-actor";actor.owner_player_id="player-fixture";campaign.actors.append(actor)
			actor.movement_policy=Hearth20Contracts.default_movement_policy("grant",["player-fixture"]);actor.movement_policy.remaining_feet={}
			if case_name=="bad-campaign-revision":actor.movement_policy=Hearth20Contracts.default_movement_policy("blocked");campaign.revision={}
			elif case_name=="bad-turn-budget":
				actor.movement_policy=Hearth20Contracts.default_movement_policy("turn_allowance",["player-fixture"]);actor.turn_allowance_turn_id="edge-turn";campaign.turn_id="edge-turn";campaign.active_turn_actor=actor.id;campaign.turn_remaining_feet={actor.id:{}}
			expect(not Hearth20Contracts.validate_campaign(campaign).ok,"malformed movement/campaign state is rejected before loading")
			if case_name!="bad-campaign-revision":
				var before=var_to_bytes(campaign)
				var moved=Hearth20Contracts.authorize_and_apply_move(campaign,"player-fixture","player",actor.id,actor.position,Vector2(3.5,2.5),5.)
				expect(not moved.ok and var_to_bytes(campaign)==before,"invalid movement budgets fail atomically")
		"failed-direct-join":
			var session=session_fixture();var previous=session.campaign.duplicate(true)
			Engine.print_error_messages=false
			var result=session.join_host("not a valid host",28930,"fixture-invite","Guest")
			Engine.print_error_messages=true
			expect(not result.ok and session.local_role=="dm" and session.local_player_id=="dm-local","a failed connection preserves the offline DM role")
			expect(session.campaign==previous and session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"a failed connection preserves the current table")
			session.queue_free()
		"replace-active-direct":
			var session=session_fixture();var peer=ENetMultiplayerPeer.new();expect(peer.create_server(0,2)==OK,"local fixture host opens")
			session.multiplayer.multiplayer_peer=peer
			var result=session.start_host(35000+randi()%1000)
			expect(not result.ok and session.multiplayer.multiplayer_peer==peer,"another host action cannot replace an active table")
			session.stop_session();session.queue_free()
		"oversized-image-file":
			var path=output.path_join("oversized.png");var file=FileAccess.open(path,FileAccess.WRITE);file.seek(Hearth20Assets.MAP_MAX_BYTES);file.store_8(0);file.close()
			var peak=OS.get_static_memory_peak_usage()
			var token=Hearth20Assets.inspect_token_png(path);var after=OS.get_static_memory_peak_usage()
			expect(not token.ok and after-peak<2*Hearth20Assets.TOKEN_MAX_BYTES,"oversized portraits are rejected before allocating their full file")
			expect(not Hearth20Assets.inspect_map_file(path).ok,"oversized maps are rejected")
			DirAccess.remove_absolute(path)
		"blocked-update-plan":
			var folder=Hearth20Identity.UPDATE_ROOT;DirAccess.make_dir_recursive_absolute(folder.path_join("install-plan.json"))
			var updater=Hearth20Updater.new();root.add_child(updater);updater.verified=true;updater.release={"version":"99.0.0-beta"};updater.manifest={"sha256":"0".repeat(64)};updater.staged_path=folder.path_join("missing-staged.exe")
			await updater.install()
			expect(not updater.install_requested and not updater.busy and "plan" in updater.message.to_lower(),"an unwritable update plan returns a recoverable error")
			updater.queue_free()
		"interrupted-save-recovery", "corrupt-save-recovery":
			var path=Hearth20Identity.SAVE_ROOT+"/recovery-edge."+Hearth20Identity.SAVE_EXTENSION
			var campaign=Hearth20Identity.new_campaign("Recoverable adventure")
			expect(Hearth20Identity.save_campaign(campaign,path).ok,"fixture writes a valid campaign")
			if case_name=="interrupted-save-recovery":DirAccess.rename_absolute(path,path+".previous")
			else:
				DirAccess.copy_absolute(path,path+".previous")
				FileAccess.open(path,FileAccess.WRITE).store_string("{incomplete")
			var tables=Hearth20CampaignArchive.list_tables()
			expect(tables.any(func(table):return table.path==path and not table.get("invalid",false)),"vault offers a recoverable save after interruption")
			expect(Hearth20CampaignArchive.read_table(path).get("ok",false),"table reader recovers the previous copy")
			expect(Hearth20Identity.load_campaign(path).get("ok",false),"title-screen campaign loading recovers the previous copy")
		"expired-steam-invite", "incompatible-steam-invite", "host-over-stale-invite", "late-foreign-lobby":
			var app=Party.AppFixture.new();root.add_child(app);var link=root.get_node("SteamLink");var api=Fakes.Api.new();root.add_child(api)
			link.api=api;link.fake_backend=true;link.peer_factory=func():return Fakes.Peer.new()
			var id=109775240000000002
			if case_name=="host-over-stale-invite":
				link.pending_invite=id;var window=app.open_connections("host")
				for frame in 4:await process_frame
				expect(link.state=="creating" and link.pending_invite==0,"explicit hosting supersedes a stale invitation")
				window._close()
			elif case_name=="late-foreign-lobby":
				link.host();api.lobby_owner=76561198000000002;api.lobby_joined.emit(id,0,false,1)
				expect(api.calls.any(func(value):return value[0]=="leave" and value[1]==id),"a late foreign join is released while a new host is being created")
			else:
				link.pending_invite=id;link.join(str(id),"Guest")
				if case_name=="expired-steam-invite":api.lobby_joined.emit(id,0,false,2)
				else:api.lobby_owner=76561198000000002;api.data={"h20_product":"another-product"};api.lobby_joined.emit(id,0,false,1)
				expect(link.state=="error" and link.pending_invite==0 and not link.busy(),"failed invitations clear automatic retry state")
			link.cancel();link._steam_shutdown();app.queue_free();api.queue_free()
		_:
			errors.append("Unknown adversarial case.")
	await process_frame;await process_frame;finish()
