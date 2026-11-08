extends SceneTree
class UpdateFixture extends Hearth20Updater:
	var check_count=0
	var download_count=0
	var install_count=0
	func _startup_allowed() -> bool:return true
	func check() -> void:check_count+=1;busy=true;stage="check"
	func download() -> void:download_count+=1;busy=true;stage="download";changed.emit()
	func _install_verified() -> void:
		install_count+=1
		await get_tree().process_frame
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	var previous=Hearth20Preferences.values.duplicate(true)
	Hearth20Preferences.values.startup_updates=true
	var updates=UpdateFixture.new();root.add_child(updates)
	updates.startup_check();updates.startup_check()
	expect(updates.check_count==1 and updates.startup_watch,"launch schedules one background check across scene changes")
	expect(not is_instance_valid(updates.startup_prompt),"loading stays usable while GitHub is checked")
	updates.busy=false;updates.stage="idle";updates.changed.emit()
	expect(not is_instance_valid(updates.startup_prompt),"no new release stays quiet")
	updates.startup_watch=true;updates.release={"version":"99.0.0-beta"};updates.message="A verified release is available.";updates.changed.emit();await process_frame
	expect(is_instance_valid(updates.startup_prompt) and updates.startup_prompt.visible,"new release opens a restart offer on the player's screen")
	expect(updates.startup_prompt.get_parent()==root,"offer survives the title-to-table transition")
	expect(updates.startup_prompt.size.y<root.size.y and updates.startup_prompt.get_ok_button().get_global_rect().end.y<root.size.y,"restart controls fit inside the screen")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("update-offer.png"))
	updates.startup_prompt.confirmed.emit()
	expect(updates.download_count==1 and updates.install_count==0,"first confirmation downloads before attempting a restart")
	expect(updates.startup_prompt.get_ok_button().disabled and updates.startup_progress.visible,"download displays progress and prevents duplicate actions")
	updates.busy=false;updates.stage="ready";updates.verified=true;updates.message="Verified and ready.";updates.changed.emit()
	expect(updates.startup_prompt.ok_button_text=="Restart & update" and not updates.startup_prompt.get_ok_button().disabled,"verified download offers an explicit restart")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("restart-offer.png"))
	updates.startup_prompt.confirmed.emit();updates.startup_prompt.confirmed.emit()
	expect(updates.install_count==1 and updates.install_requested,"repeated restart clicks create a single installation")
	await process_frame;await process_frame
	expect(not updates.install_requested,"installation failure or return permits a safe retry")
	updates._dismiss_startup_update();await process_frame
	expect(not is_instance_valid(updates.startup_prompt) and updates.verified,"Later retains the verified update for Settings")
	updates.release={};updates.startup_watch=true;updates._fail("Offline")
	expect(not is_instance_valid(updates.startup_prompt),"an offline startup check never blocks opening the table")
	updates.release={"version":"99.0.0-beta"};updates.show_startup_prompt();updates.set_channel("beta");await process_frame
	expect(not is_instance_valid(updates.startup_prompt) and updates.release.is_empty(),"changing channel removes a stale restart offer")
	var disabled=UpdateFixture.new();root.add_child(disabled);Hearth20Preferences.values.startup_updates=false;disabled.startup_check()
	expect(disabled.check_count==0,"startup checking can be disabled in Settings")
	var shared=root.get_node("Updates");shared.startup_check()
	expect(shared.startup_checked and not shared.busy,"background test never contacts GitHub automatically")
	var owner=Control.new();root.add_child(owner);var settings=Hearth20SettingsWindow.open(owner);await process_frame
	expect(settings.updater==shared,"Settings reuses the launch updater and its staged download")
	settings._close();await process_frame;expect(is_instance_valid(shared),"closing Settings keeps the launch updater alive")
	owner.queue_free();updates.queue_free();disabled.queue_free();Hearth20Preferences.values=previous;await process_frame
	print("Startup updates: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
