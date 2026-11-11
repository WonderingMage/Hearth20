extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	root.size=Vector2i(1600,1000)
	expect(not OS.has_feature("debug"),"public Beta uses the release engine")
	expect(not Hearth20MultiplayerLab.enabled(),"multiplayer lab disabled")
	expect(not ResourceLoader.exists("res://hearth20/tests/multiplayer_lab_title.gd"),"debug test scripts excluded from public package")
	expect(not ResourceLoader.exists("res://hearth20/bestiary/catalog.json"),"retired startup showcases are excluded from the portable")
	expect(ResourceLoader.exists("res://hearth20/menu_art/party-original.jpg","Texture2D"),"the supplied party artwork is bundled")
	expect(not ResourceLoader.exists(Hearth20TitleDesert.CREATURE_PATH,"PackedScene"),"unused title creature assets are excluded")
	var boot=Hearth20Boot.new();root.add_child(boot);await create_timer(.8).timeout
	expect(not boot.debug_enabled,"title has no debug creature controls")
	expect(boot.find_children("*","Button",true,false).all(func(b):return not ("debug" in b.text.to_lower()) and not ("multiplayer lab" in b.text.to_lower())),"title buttons are player-facing")
	var key=InputEventKey.new();key.keycode=KEY_F6;key.pressed=true;boot._unhandled_key_input(key)
	expect(not is_instance_valid(boot.debug_dialog),"F6 does not open a debug window")
	boot.queue_free();await create_timer(.4).timeout
	var shell=Hearth20SeatedShell.new();root.add_child(shell)
	var deadline=Time.get_ticks_msec()+20000
	while not shell.ready_to_show and Time.get_ticks_msec()<deadline:await process_frame
	expect(shell.ready_to_show,"public Beta reaches the seated table")
	expect(not is_instance_valid(shell.app.multiplayer_lab.overlay),"no debug window switcher created")
	expect(shell.app.network_controls.find_children("MultiplayerLabButton","Button",true,false).is_empty(),"normal join/host controls omit test-player launcher")
	shell.app.multiplayer_lab.open_panel();expect(not is_instance_valid(shell.app.multiplayer_lab.panel),"lab cannot be opened in public release")
	expect(Hearth20Identity.PRODUCT_NAME=="Hearth20 Beta","Beta product name")
	shell.queue_free();await create_timer(.7).timeout
	print("Public Beta: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)
