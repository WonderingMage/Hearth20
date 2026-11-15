extends SceneTree
var checks=0
var errors=[]
var output=""
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(file: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(file+".png"))
func run() -> void:
	root.size=Vector2i(1600,1000);var player=Hearth20AvatarStyle.defaults(false);var host=Hearth20AvatarStyle.defaults(true)
	expect(Hearth20AvatarStyle.valid(host,true) and not Hearth20AvatarStyle.valid(host,false),"D20 style accepted only for host")
	expect(Hearth20AvatarStyle.clean(host,false).pendant=="none","old or forged saved player pendant is stripped")
	for malformed in [null,[],{}, {"robe":[]}, {"robe":"../../arbitrary"}, {"role":"dm","pendant":"d20"}]:expect(not Hearth20AvatarStyle.valid(malformed,false),"reject malformed or role-claiming style "+str(malformed))
	Hearth20AvatarStyle.remember(host,true);Hearth20AvatarStyle.remember(player,false)
	expect(Hearth20AvatarStyle.remembered(true)==host and Hearth20AvatarStyle.remembered(false)==player,"separate host/player wardrobe preferences persist")
	var session=Hearth20Session.new();root.add_child(session);session.configure(Hearth20Identity.new_campaign("Wizard rule fixture"))
	var public_key=Hearth20PlayerProfile.public_key();var guest=Hearth20PlayerProfile.principal(public_key)
	session.campaign.participants={guest:{"public_key":public_key,"display_name":"Guest","avatar":host,"secret":"private"}}
	session.remote_players={guest:{"nickname":"Guest"}}
	expect(not session._apply_avatar_as(guest,host).ok,"authoritative boundary rejects a player's D20")
	expect(not session._apply_avatar_as("unknown",player).ok,"unknown identities cannot equip")
	expect(session._apply_avatar_as("dm-local",host).ok,"host equips their D20")
	expect(session._apply_avatar_as(guest,player).ok,"player equips an ordinary chain")
	var roster=session.presence_for(guest);expect(roster.size()==2 and roster[0].host and roster[1].mine and roster[1].style.pendant=="none","public roster preserves authoritative host and sanitized player")
	expect(not str(roster).contains("secret") and not str(roster).contains("public_key") and not str(roster).contains("sheet"),"presence contains no private sheet, token or signing data")
	var path=Hearth20Identity.SAVE_ROOT+"/wizard-fixture.h20scampaign";expect(Hearth20Identity.save_campaign(session.campaign,path).ok,"campaign saves avatar choices")
	var loaded=Hearth20Identity.load_campaign(path);expect(loaded.ok and loaded.campaign.host_avatar==host and loaded.campaign.participants[guest].avatar==player,"campaign restores host and participant appearance")
	await Hearth20GeneratedModels.prepare(self)
	var window=Hearth20AvatarWardrobe.open(root,session,true);await create_timer(.6).timeout
	expect(is_instance_valid(window.pendant) and window.pendant.item_count==2,"host sees D20 equip selector")
	expect(window.avatar.has_node("DMOnlyD20Pendant"),"host preview actually wears a modeled D20")
	await capture("host-wardrobe");window.queue_free();await process_frame
	window=Hearth20AvatarWardrobe.open(root,session,false);await create_timer(.5).timeout
	expect(window.pendant==null and not window.avatar.has_node("DMOnlyD20Pendant"),"player window contains no pendant selector or pendant model")
	await capture("player-wardrobe");window.queue_free();await process_frame
	var forced=Hearth20WizardAvatar.new();root.add_child(forced);forced.setup(host,false);expect(not forced.has_node("DMOnlyD20Pendant"),"renderer independently strips forged player pendant");forced.free()
	var shell=Hearth20SeatedShell.new();root.add_child(shell)
	var deadline=Time.get_ticks_msec()+30000
	while not shell.ready_to_show and Time.get_ticks_msec()<deadline:await process_frame
	expect(shell.ready_to_show,"seated room loads with wizard assets")
	var world_session=shell.app.session;world_session.campaign.participants={};world_session.remote_players={}
	for i in 4:
		var id="preview-"+str(i);var style=Hearth20AvatarStyle.defaults(false);style.robe=Hearth20AvatarStyle.ROBES.keys()[i];style.metal="silver" if i%2 else "gold";style.chain="layered" if i==0 else "cuban"
		world_session.campaign.participants[id]={"avatar":style};world_session.remote_players[id]={"nickname":["Aurelia","Bram","Sylas","Mira"][i]}
	world_session._broadcast_presence();await create_timer(.6).timeout
	expect(shell.company.avatars.size()==4,"DM sees four connected players without an own duplicate")
	expect(shell.company.find_children("GenericPublicSheet_*","Node3D",true,false).size()==4,"each other player has a generic sheet")
	for avatar in shell.company.avatars.values():expect(not avatar.has_node("DMOnlyD20Pendant") and avatar.position.z<shell.table.camera.position.z,"all player wizards sit in front without a D20")
	await capture("party-at-table")
	var guest_view=world_session.presence_for("preview-0");shell.company.rebuild(guest_view);await process_frame
	expect(shell.company.avatars.values().filter(func(avatar):return avatar.has_node("DMOnlyD20Pendant")).size()==1,"player sees the DM's pendant on the authoritative host avatar only")
	await capture("player-sees-host");world_session._broadcast_presence();await process_frame
	var previous=shell.company.avatars.values()[0].hood.transform;await create_timer(.25).timeout;expect(shell.company.avatars.values()[0].hood.transform==previous,"hood stays still with head rotation disabled")
	expect(shell.company.avatars.values().all(func(avatar):return not avatar.has_node("IndependentHood/VoiceMouth") and not avatar.has_method("set_voice_level") and not avatar.is_processing()),"avatars have no mouth, voice hook or per-frame head process")
	shell.focus_map();await process_frame;expect(shell.table.process_mode==Node.PROCESS_MODE_DISABLED,"focused map suspends table/avatar processing");shell.leave_focus()
	for count in range(1,9):
		for index in count:expect(Hearth20TableCompany.seat(index,count).z<2.45,"forward seat for "+str(count)+" guests")
	world_session.remote_players.clear();world_session._broadcast_presence();await process_frame;expect(shell.company.avatars.is_empty(),"disconnected players leave no ghost avatars")
	shell.queue_free();session.queue_free();await process_frame;await process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"  "));print("Wizard checks "+str(checks)+", errors "+str(errors));quit.call_deferred(0 if errors.is_empty() else 1)
