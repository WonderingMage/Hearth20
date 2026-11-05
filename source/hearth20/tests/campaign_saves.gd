extends SceneTree
class BoardFixture extends Hearth20BoardCanvas:
	func _ready() -> void:set_process(false)
	func _draw() -> void:pass
class AppFixture extends Hearth20App:
	var last_status=""
	func _ready() -> void:
		set_process(false);campaign=Hearth20Identity.new_campaign("Save regression")
		lite_adapter=Hearth20LiteWorldAdapter.new(campaign);lite_bridge=Hearth20LiteRulesBridge.new();lite_bridge.attach(lite_adapter)
		session=Hearth20Session.new();add_child(session);session.configure(campaign)
		board=BoardFixture.new();add_child(board);board.set_campaign(campaign,session,"dm")
		dm_notes_editor=TextEdit.new();add_child(dm_notes_editor)
	func _on_status(text: String) -> void:last_status=text
	func _update_session_ui() -> void:pass
class ShellFixture extends Hearth20SeatedShell:
	func _ready() -> void:name="SeatedTable";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func until(predicate: Callable,note: String) -> void:
	var end=Time.get_ticks_msec()+12000
	while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
	expect(predicate.call(),note)
func click(window: Window,button: Control) -> void:
	var point=Vector2(window.position)+button.get_global_rect().get_center()
	var press=InputEventMouseButton.new();press.position=point;press.global_position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press)
	var release=press.duplicate();release.pressed=false;root.push_input(release);await process_frame;await process_frame
func vault_on(shell: Node) -> Hearth20CampaignVault:
	for child in shell.get_children():
		if child is Hearth20CampaignVault:return child
	return null
func run() -> void:
	var detached={"actors":[{"id":"old"}],"lite_state":{},"revision":7};var adapter=Hearth20LiteWorldAdapter.new(detached)
	detached.actors=[{"id":"new"}];adapter.sync_to_campaign()
	expect(detached.actors==[{"id":"new"}] and detached.revision==7 and adapter.actor("new").id=="new","replaced actor array stays authoritative through adapter reads and saving")
	detached.actors=[];adapter.sync_to_campaign();expect(detached.actors.is_empty(),"saving cannot resurrect removed tokens")
	root.size=Vector2i(1280,900);root.gui_embed_subwindows=true
	var shell=ShellFixture.new();root.add_child(shell);var surface=SubViewportContainer.new();surface.stretch=true;surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shell.add_child(surface)
	var viewport=SubViewport.new();viewport.gui_embed_subwindows=true;viewport.size=Vector2i(1440,900);surface.add_child(viewport)
	var app=AppFixture.new();app.seated_shell=shell;viewport.add_child(app);shell.app=app
	# The live bug follows a map import replacing the actor array after adapter creation.
	app.campaign.actors=app.campaign.actors.duplicate(true)
	var principal=Hearth20PlayerProfile.principal(Hearth20PlayerProfile.public_key());app.campaign.participants[principal]={"public_key":Hearth20PlayerProfile.public_key(),"display_name":"Save fixture player"}
	var image=Image.create(48,48,false,Image.FORMAT_RGBA8);image.fill(Color.GOLD);var png=image.save_png_to_buffer()
	expect(Hearth20JoinCharacter.submit(app.campaign,principal,{"name":"Saved adventurer"},png).ok,"fixture imports an owned PNG pawn after array replacement")
	var actor=Hearth20JoinCharacter.current(app.campaign,principal);actor.in_inventory=false;actor.position=Vector2(4.5,7.5)
	expect(app.session.create_inventory_token("Stored creature").ok,"fixture adds a separate inventory token")
	var before=var_to_bytes(app.campaign.actors);var revision=app.campaign.revision
	app.lite_bridge.sync_to_campaign()
	expect(var_to_bytes(app.campaign.actors)==before and app.campaign.revision==revision,"rules sync cannot replace tokens or alter the gameplay revision")
	expect(app.lite_adapter.data.actors==app.campaign.actors,"rules adapter reads the current actor collection")
	app._save_campaign();await process_frame;await process_frame
	var vault=vault_on(shell);expect(is_instance_valid(vault) and vault.get_parent()==shell,"Save opens the campaign vault on the main screen outside the map viewport")
	await until(func():return vault.listing==null,"saved-table list finishes loading")
	vault.name_field.text="Session One";await click(vault,vault.primary)
	var progress=app.campaign_progress;expect(is_instance_valid(progress) and progress.visible,"save immediately displays a progress popup")
	await until(func():return not progress.active,"background save finishes")
	expect(progress.bar.value==100 and "saved" in progress.caption.text and not progress.done_button.disabled,"successful save has explicit visible confirmation")
	var first_path=app.current_save_path;expect(Hearth20CampaignArchive.valid_path(first_path) and FileAccess.file_exists(first_path),"named table is written under the separate AppData campaign root")
	expect(var_to_bytes(app.campaign.actors)==before and app.campaign.revision==revision,"saving preserves placed/inventory tokens, positions and movement revision")
	var loaded=Hearth20Identity.load_campaign(first_path)
	expect(loaded.ok and loaded.campaign.title=="Session One" and loaded.campaign.actors.size()==2,"named save opens with the full token inventory")
	expect(loaded.ok and Hearth20JoinCharacter.current(loaded.campaign,principal).id==actor.id and Hearth20Assets.read_asset(loaded.campaign,actor.png_asset_id,"token")==png,"saved player ownership and original PNG survive exactly")
	await click(progress,progress.done_button);app._save_campaign();await process_frame;await process_frame;vault=vault_on(shell)
	await until(func():return vault.listing==null,"repeat-save vault loads")
	expect(vault.selected_path==first_path,"repeat save selects the current table instead of silently creating a new slot")
	await click(vault,vault.primary);progress=app.campaign_progress;await until(func():return not progress.active,"repeat save finishes")
	expect(FileAccess.file_exists(first_path+".previous") and var_to_bytes(app.campaign.actors)==before,"repeat save preserves both the previous file and all live tokens")
	await click(progress,progress.done_button)
	var second=app.campaign.duplicate(true);second.title="Session Two";var second_path=Hearth20CampaignArchive.new_path(second.title)
	expect(Hearth20Identity.save_campaign(second,second_path).ok,"a second named table can coexist")
	app.campaign.actors[0].position=Vector2(9.5,9.5);app._load_campaign();await process_frame;await process_frame;vault=vault_on(shell)
	await until(func():return vault.listing==null,"Open lists the saved tables")
	var records=Hearth20CampaignArchive.list_tables();expect(records.any(func(record):return record.path==first_path) and records.any(func(record):return record.path==second_path),"Open offers previous tables from AppData")
	vault.select_record(records.filter(func(record):return record.path==first_path)[0]);await click(vault,vault.primary);progress=app.campaign_progress
	await until(func():return not progress.active,"selected saved table loads")
	expect(app.current_save_path==first_path and Hearth20JoinCharacter.current(app.campaign,principal).position==Vector2(4.5,7.5),"selected table restores the saved pawn position and ownership")
	await click(progress,progress.done_button)
	expect(not Hearth20CampaignArchive.valid_path(Hearth20Identity.SAVE_ROOT+"/../other.h20scampaign"),"campaign slots cannot escape the AppData save root")
	var bad_path=Hearth20Identity.SAVE_ROOT+"/broken.h20scampaign";FileAccess.open(bad_path,FileAccess.WRITE).store_string("{incomplete")
	var previous=var_to_bytes(app.campaign);progress=Hearth20CampaignProgress.open(app,"load",bad_path)
	await until(func():return not progress.active,"unreadable save returns a result")
	expect(var_to_bytes(app.campaign)==previous and not progress.done_button.disabled and not progress.caption.text.is_empty(),"failed load leaves the active table intact and shows a readable message")
	progress.queue_free();shell.queue_free();await process_frame;await process_frame
	var legacy=Hearth20Identity.SAVE_ROOT+"/table."+Hearth20Identity.SAVE_EXTENSION
	second.title="Legacy table";expect(Hearth20Identity.save_campaign(second,legacy).ok,"legacy single-table file remains supported")
	var owner=Control.new();root.add_child(owner);var chosen=[""]
	var title_vault=Hearth20CampaignVault.open(owner,null,"open",func(path):chosen[0]=path)
	await until(func():return title_vault.listing==null,"title-menu vault lists AppData tables")
	var legacy_button: Button
	for row in title_vault.rows.get_children():
		if row is Button and row.get_meta("save_path","")==legacy:legacy_button=row
	expect(is_instance_valid(legacy_button),"legacy table appears as a selectable saved-table row")
	if is_instance_valid(legacy_button):await click(title_vault,legacy_button);await click(title_vault,title_vault.primary)
	expect(chosen[0]==legacy,"Open callback receives the selected AppData table rather than a hardcoded path")
	owner.queue_free();await process_frame
	var mapped=Hearth20Session.new();root.add_child(mapped);mapped.configure(Hearth20Identity.new_campaign("Saved inn"))
	expect(mapped.load_sample_map("lantern-larch-inn",false).ok,"a real sample map loads for the archive regression")
	var mapped_path=Hearth20CampaignArchive.new_path("Saved inn");var job=Hearth20CampaignJob.new();job.save(mapped.campaign.duplicate(true),mapped_path)
	await until(func():return job.done(),"real map save and preview finish in the background")
	expect(job.finish().ok and FileAccess.file_exists(mapped_path+".thumb.png"),"real map save includes a campaign-preview thumbnail")
	var mapped_loaded=Hearth20Identity.load_campaign(mapped_path)
	if not mapped_loaded.ok:print("MAP SAVE VALIDATION: ",mapped_loaded.get("errors",[]))
	var asset_bytes_match=mapped_loaded.ok and mapped_loaded.campaign.assets.size()==mapped.campaign.assets.size()
	if mapped_loaded.ok:
		for asset_id in mapped.campaign.assets:
			if Hearth20Assets.read_asset(mapped_loaded.campaign,asset_id)!=Hearth20Assets.read_asset(mapped.campaign,asset_id):asset_bytes_match=false
	expect(asset_bytes_match,"saved map image and lighting assets restore exactly")
	mapped.queue_free();await process_frame
	print("Campaign save workflow: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
