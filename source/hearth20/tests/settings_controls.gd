extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	root.size=Vector2i(1400,900);root.gui_embed_subwindows=true
	var previous=Hearth20Preferences.values.duplicate(true)
	Hearth20Preferences.save(Hearth20Preferences.DEFAULTS)
	var owner=Control.new();root.add_child(owner)
	var settings=Hearth20SettingsWindow.open(owner);await process_frame;await process_frame
	expect(settings.tabs.get_tab_count()==3,"existing Display, Audio and Updates pages remain available")
	expect(settings.update_channel.get_item_metadata(settings.update_channel.selected)==Hearth20Identity.UPDATE_CHANNEL_DEFAULT,"test portable selects its configured update channel")
	settings.updater.release={"version":"99.0.0"};settings.updater.verified=true
	settings.update_channel.select(0);settings.update_channel.item_selected.emit(0)
	expect(settings.pending.update_channel=="beta" and settings.updater.channel=="beta","changing visible channel changes the next update check")
	expect(settings.updater.release.is_empty() and not settings.updater.verified,"channel change clears an older staged install selection")
	settings._apply();await process_frame;await process_frame
	expect(Hearth20Preferences.read().update_channel=="beta","Apply remembers the chosen update channel")
	settings=Hearth20SettingsWindow.open(owner);await process_frame
	expect(settings.update_channel.selected==0,"reopened Settings displays the saved channel")
	settings.update_channel.select(1);settings.update_channel.item_selected.emit(1);settings._cancel();await process_frame
	expect(Hearth20Preferences.read().update_channel=="beta","Close without Apply preserves the previous channel")
	Hearth20Preferences.save(previous);owner.queue_free();await process_frame
	print("Settings controls: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
