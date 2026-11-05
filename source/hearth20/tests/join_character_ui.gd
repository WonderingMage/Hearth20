extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool, text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error("FAIL: "+text)
func capture(window: Window, text: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw;window.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(text+".png"))
func run() -> void:
	root.size=Vector2i(1440,900);var app: Hearth20App=load("res://hearth20_main.tscn").instantiate();root.add_child(app);await process_frame
	var key=Hearth20PlayerProfile.public_key();var player=Hearth20PlayerProfile.principal(key);app.campaign.participants[player]={"public_key":key,"display_name":"First arrival"}
	app.session.local_role="player";app.session.local_player_id=player;app.board.set_role("player");app._update_session_ui()
	var snapshot=app.session._project_for(player);app.session.client_snapshot=snapshot;app._on_snapshot(snapshot);await process_frame
	var window=app.join_character_window;expect(is_instance_valid(window) and window.join_submission and window.exclusive,"first player's join opens the required private character review")
	window.dialog.hide();var path=OS.get_environment("H20_QA_SHEET_1")
	if not path.is_empty():
		window.import_path(path);var end=Time.get_ticks_msec()+25000
		while window.worker!=null and Time.get_ticks_msec()<end:await process_frame
	else:
		window.draft=Hearth20CharacterImport.new().from_fields({"CharacterName":"Synthetic joining adventurer","CLASS LEVEL":"Wizard 3","STR":"10","DEX":"14","CON":"12","INT":"18","WIS":"12","CHA":"10","AC":"12","MaxHP":"23","CurrentHP":"23","Speed":"30","GP":"25","AdditionalSenses":"Darkvision 60 ft."}).sheet;window._build();window.apply_button.disabled=false
	expect(not window.draft.is_empty() and not window.apply_button.disabled and window.tabs.get_tab_count()==8,"join flow reviews the complete imported sheet")
	expect(not window.fields.ac.editable and not window.fields.name.editable,"player review preserves printed values while DM retains later editing")
	var image=Image.create(96,96,false,Image.FORMAT_RGBA8);image.fill(Color("#9c4934"));var png=OS.get_environment("H20_QA_EVIDENCE").path_join("synthetic-join-token.png");image.save_png(png);window._choose_png(png)
	expect(not window.custom_png.is_empty(),"player chooses a self-contained PNG appearance")
	await capture(window,"join-character-private-review");window.tabs.current_tab=5;await capture(window,"join-character-imported-gold")
	window.tabs.current_tab=7;await capture(window,"join-character-token-png")
	var accepted=Hearth20JoinCharacter.submit(app.campaign,player,window.draft,window.custom_png);expect(accepted.ok,"reviewed PDF and PNG produce the campaign character")
	var actor=Hearth20JoinCharacter.current(app.campaign,player);expect(actor.token_size==1. and actor.in_inventory and actor.movement_policy.mode=="blocked","joining character is size one and awaits DM placement")
	actor.coins.gp=3;snapshot=app.session._project_for(player);app.session.client_snapshot=snapshot;app._on_snapshot(snapshot);await process_frame;await process_frame
	expect(not is_instance_valid(app.join_character_window) and not snapshot.character_required and snapshot.sheets[0].coins.gp==3,"saved character resumes without a new import or gold reset")
	expect(app.player_session_note.text.contains("inventory"),"player is told the DM has the stored character")
	await capture(root,"join-character-awaits-dm-placement")
	app.queue_free();await process_frame;await process_frame;print("Character onboarding UI: %d assertions, %d failures."%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
