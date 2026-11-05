extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func run() -> void:
	root.size=Vector2i(1600,1000);root.gui_embed_subwindows=true
	var shell=Hearth20SeatedShell.new();root.add_child(shell)
	while not shell.ready_to_show:await process_frame
	shell.focus_map();var app=shell.app;var revision=app.campaign.revision
	expect(app.map_dialog.get_parent()==shell,"map chooser belongs to main window rather than embedded map")
	expect(app.map_dialog.use_native_dialog== (OS.get_name()=="Windows"),"Windows uses native cancelable file chooser")
	app.map_dialog.use_native_dialog=false;app._open_map_dialog();await process_frame
	expect(app.map_dialog.visible and shell.has_modal(),"map import opens a modal")
	app.map_dialog.canceled.emit();await process_frame
	expect(not app.map_dialog.visible and app.campaign.revision==revision,"cancel dismisses picker without changing campaign")
	shell.leave_focus();expect(shell.focus_state=="table" and shell.table.visible,"player can return to table after cancel")
	app._open_map_dialog();await process_frame;app.map_dialog.close_requested.emit();await process_frame
	expect(not app.map_dialog.visible,"window close also dismisses chooser");shell.leave_focus()
	var settings=Hearth20SettingsWindow.open(shell,app);await create_timer(.2).timeout
	expect(settings.tabs.get_tab_count()==3,"settings has Display, Audio and Updates")
	expect(Hearth20SettingsWindow.open(shell,app)==settings,"settings uses a single dialog")
	expect(shell.has_modal(),"settings shields table camera input")
	var input=InputEventMouseButton.new();input.pressed=true;input.button_index=MOUSE_BUTTON_RIGHT;shell._input(input);expect(not shell.looking,"settings does not start camera dragging")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join("settings-display.png") if not OS.get_environment("H20_QA_EVIDENCE").is_empty() else OS.get_cmdline_user_args()[0].path_join("settings-display.png"))
	settings.tabs.current_tab=1;await process_frame
	var previous=Hearth20Preferences.values.duplicate(true);settings.pending.master=.31;Hearth20Preferences.apply_audio(settings.pending);settings._cancel();await process_frame
	expect(Hearth20Preferences.values==previous and absf(db_to_linear(AudioServer.get_bus_volume_db(0))-.8)<.01,"closing without Apply restores saved audio")
	settings=Hearth20SettingsWindow.open(shell,app);settings.pending.fps=45;settings._apply();await process_frame
	expect(is_instance_valid(settings.preview) and Hearth20Preferences.preview_values.fps==45 and Engine.max_fps in [30,45],"display Apply starts a timed preview")
	settings.preview_until=Time.get_ticks_msec()-1;await create_timer(.15).timeout
	expect(not is_instance_valid(settings.preview) and Hearth20Preferences.values==previous,"unconfirmed display preview reverts")
	settings._cancel();await process_frame;shell.queue_free();await create_timer(.5).timeout
	print("Settings UI: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)
