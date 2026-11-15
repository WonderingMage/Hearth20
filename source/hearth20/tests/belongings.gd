extends SceneTree
var checks=0
var errors=[]
var output=""
func _initialize() -> void:output=OS.get_cmdline_user_args()[0];call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:errors.append(note);push_error(note)
func run() -> void:
	root.size=Vector2i(1280,800);root.gui_embed_subwindows=true;Hearth20Preferences.values.startup_updates=false
	var app=load("res://hearth20_main.tscn").instantiate();root.add_child(app);await process_frame
	var session: Hearth20Session=app.session;var c: Dictionary=app.campaign;var scene: Dictionary=c.scenes[0]
	var public_a=Crypto.new().generate_rsa(2048).save_to_string(true);var public_b=Crypto.new().generate_rsa(2048).save_to_string(true)
	var pa=Hearth20PlayerProfile.principal(public_a);var pb=Hearth20PlayerProfile.principal(public_b)
	c.participants={pa:{"display_name":"Mira","public_key":public_a},pb:{"display_name":"Bram","public_key":public_b}};session.remote_players={pa:{"nickname":"Mira"},pb:{"nickname":"Bram"}}
	for player in c.participants:
		var hero=Hearth20TokenInventory.new_actor(player,true,scene,Vector2(2.5,2.5));hero.owner_player_id=player;c.actors.append(hero)
	var image=Image.create(768,384,false,Image.FORMAT_RGBA8);image.fill(Color("#e89b32"));var png=image.save_png_to_buffer()
	var created=session.create_custom_item("Orange key","orange",png);expect(created.ok,"DM creates custom item from PNG")
	var id=str(created.get("id",""));var item=Hearth20Belongings.find(c,id);expect(item.holder=="dm-local" and item.hidden,"new item starts in private DM vault")
	expect(c.assets[item.png_asset_id].width==512 and c.assets[item.png_asset_id].height==256,"item art is optimized proportionally")
	expect(not JSON.stringify(session._project_for(pa)).contains("Orange key"),"vault name, description and PNG stay hidden")
	for action in [{"action":"place","id":id,"position":Vector2(3.5,3.5)},{"action":"hide","id":id,"hidden":false},{"action":"give","id":id,"target":pb},{"action":"stow","id":id}]:expect(not session._belongings_as(pa,action).ok,"player cannot perform DM action "+action.action)
	expect(session.belongings_action({"action":"place","id":id,"position":Vector2(3.2,3.3)}).ok and item.position==Vector2(3.5,3.5),"DM placement snaps to centre")
	expect(not session._belongings_as(pa,{"action":"pickup","id":id}).ok,"concealed item cannot be claimed by guessing ID")
	expect(session.belongings_action({"action":"hide","id":id,"hidden":false}).ok,"DM reveals item")
	var a=session._project_for(pa);expect(a.board_items.size()==1 and a.board_items[0].description=="orange" and a.assets.has(item.png_asset_id),"visible board item includes description and image")
	c.map_covered=true;expect(session._project_for(pa).board_items.is_empty(),"cover removes item metadata");expect(not session._belongings_as(pa,{"action":"pickup","id":id}).ok,"cover blocks forged pickup");c.map_covered=false
	scene.fog_rects=[{"x":3.,"y":3.,"width":1.,"height":1.}];expect(session._project_for(pa).board_items.is_empty(),"fog masks item metadata");scene.fog_rects=[]
	c.actors[0].in_inventory=true;expect(not session._belongings_as(pa,{"action":"pickup","id":id}).ok,"stored hero cannot claim board item");c.actors[0].in_inventory=false
	expect(session._belongings_as(pa,{"action":"pickup","id":id}).ok,"player picks up revealed item")
	expect(not session._belongings_as(pb,{"action":"pickup","id":id}).ok,"second player cannot double-claim item")
	a=session._project_for(pa);var b=session._project_for(pb);expect(a.item_inventory.size()==1 and a.board_items.is_empty() and b.item_inventory.is_empty() and not JSON.stringify(b).contains("Orange key"),"picked-up item is private to its owner and absent from board")
	c.map_covered=true;a=session._project_for(pa);expect(a.item_inventory.size()==1 and a.assets.has(item.png_asset_id),"inventory remains readable under map cover");var loading=Hearth20Session._map_loading_view(a);expect(loading.assets.has(item.png_asset_id) and loading.board_items.is_empty(),"own inventory art survives map loading");c.map_covered=false
	expect(session._belongings_as(pa,{"action":"notes","text":"HOME BREW: the centipede bracelet is lucky."}).ok,"player personal notes accepted")
	expect(not session._belongings_as(pb,{"action":"notes","text":"hacked","target":pa}).ok,"player cannot edit another journal")
	expect(not session._belongings_as(pa,{"action":"notes","text":"x".repeat(20001)}).ok,"oversized journal rejected without truncating existing notes")
	expect(not JSON.stringify(session._project_for(pb)).contains("HOME BREW"),"other player's snapshot excludes personal journal")
	expect(session.belongings_action({"action":"notes","target":pb,"text":"DM gift: moonstone charm."}).ok,"DM may add homebrew notes for saved players")
	for bad in [{"action":"pickup","id":id,"holder":pb},{"action":"hide","id":id,"hidden":"false"},{"action":"place","id":id,"position":Vector2(NAN,0)},{"action":"destroy","id":{}},{"action":"unknown"}]:expect(not session._belongings_as(pb,bad).ok,"malformed item action rejected")
	expect(Hearth20Contracts.validate_campaign(c).ok,"extended campaign validates")
	var path=Hearth20Identity.SAVE_ROOT+"/items-and-journals.h20scampaign";expect(Hearth20Identity.save_campaign(c,path).ok,"manual save includes journals, ownership and embedded image")
	var loaded=Hearth20Identity.load_campaign(path);expect(loaded.ok and loaded.campaign.player_journals[pa].begins_with("HOME BREW") and loaded.campaign.custom_items[0].holder==pa,"load restores journal and unique inventory ownership")
	expect(Hearth20Autosave.write_snapshot(c.duplicate(true),Hearth20Autosave.PATH).ok,"single autosave persists the same item/journal schema")
	var automatic=Hearth20Identity.load_campaign(Hearth20Autosave.PATH);expect(automatic.ok and automatic.campaign.custom_items[0].description=="orange","autosave restores item description")
	var bad_save=c.duplicate(true);bad_save.custom_items.append(bad_save.custom_items[0].duplicate(true));expect(not Hearth20Contracts.validate_campaign(bad_save).ok,"duplicate saved item IDs are rejected")
	var old=Hearth20Identity.new_campaign();expect(Hearth20Contracts.validate_campaign(old).ok,"older campaigns without new optional fields still load")
	app._show_sidebar_page(app.journal_page);app.personal_journal.refresh(true);app.personal_journal.editor.text="DM personal note before autosave";app.personal_journal.editor.text_changed.emit();app.personal_journal.flush();expect(c.player_journals["dm-local"]=="DM personal note before autosave","journal editor sends current text to campaign")
	var titles=[]
	for i in app.workspace_tabs.get_tab_count():titles.append(app.workspace_tabs.get_tab_title(i))
	expect(not "Token Sheet" in titles,"Token Sheet tab removed")
	var window=Hearth20ItemsWindow.open(app,id);await process_frame;await process_frame
	expect(window.entries.size()==1 and window.body.text=="orange","DM inventory inspector shows saved item and description")
	window.size=Vector2i(780,580);await process_frame;await process_frame
	expect(Rect2(Vector2.ZERO,window.size).encloses(window.listing.get_global_rect()),"item list fits minimum window")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("dm-items.png"))
	window.queue_free();await process_frame
	var point=app.board._world_to_screen(Vector2(3.5,3.5),float(scene.cell_pixels));item.holder="";item.scene_id=scene.id;item.position=Vector2(3.5,3.5);item.hidden=false
	var right=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true;right.position=point;app.board._gui_input(right);await process_frame
	var menus=app.board.find_children("*","PopupMenu",false,false);expect(menus.size()==1 and menus[0].visible,"right-click item opens its own context menu")
	if not menus.is_empty():
		menus[0].id_pressed.emit(2);menus[0].hide();await process_frame;expect(item.hidden,"context-menu conceal is applied and popup closes")
	app.board.activate_tool("item_place",true);app.board.pending_item_id=id
	var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=false;click.position=app.board.size*.5;app.board._gui_input(click)
	expect(item.holder.is_empty() and app.board.tool_name=="select","map placement finishes and returns input control")
	app.board.activate_tool("item_place",true);var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;app.board._gui_input(escape);expect(app.board.tool_name=="select","Escape cancels item placement")
	session.belongings_action({"action":"give","id":id,"target":pa})
	expect(not session._belongings_as(pb,{"action":"destroy","id":id}).ok,"other player cannot destroy owned item")
	var player_view=session._project_for(pa);session.local_role="player";session.local_player_id=pa;session.client_snapshot=player_view;app.board.set_role("player");app.board.set_player_snapshot(player_view)
	var inventory=Hearth20ItemsWindow.open(app,id);await process_frame;await process_frame;expect(inventory.entries.size()==1 and inventory.body.text=="orange","player reads own saved item in inventory")
	inventory.confirm_destroy();await process_frame;var dialogs=inventory.find_children("*","ConfirmationDialog",false,false);expect(dialogs.size()==1,"destruction asks before removing the unique item")
	if not dialogs.is_empty():dialogs[0].canceled.emit();await process_frame
	expect(c.custom_items.size()==1,"cancelling destruction keeps the item")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("player-inventory.png"))
	inventory.queue_free();await process_frame;session.local_role="dm";session.local_player_id="dm-local";app.board.set_role("dm")
	expect(session._belongings_as(pa,{"action":"destroy","id":id}).ok and c.custom_items.is_empty(),"owner destroys item once")
	expect(not session._belongings_as(pa,{"action":"destroy","id":id}).ok,"replayed destruction cannot affect another item")
	expect(Hearth20Identity.save_campaign(c,path).ok and Hearth20Identity.load_campaign(path).campaign.custom_items.is_empty(),"destruction persists after another save")
	app.queue_free();await process_frame;await process_frame
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"  "));print("Belongings: %d checks, %d failures"%[checks,errors.size()]);quit.call_deferred(0 if errors.is_empty() else 1)
