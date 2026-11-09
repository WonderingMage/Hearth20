extends SceneTree
const Party=preload("party_onboarding.gd")
class TableFixture extends Hearth20CasinoTable:
	func _ready() -> void:set_process(false)
	func present(_state: Dictionary,_seat: int,_selection: String="") -> void:pass
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func settle() -> void:
	for frame in 5:await process_frame
func run() -> void:
	create_timer(15).timeout.connect(func():push_error("Layout controls watchdog");quit(1))
	root.gui_embed_subwindows=true;root.size=Vector2i(1000,650)
	var app=Party.AppFixture.new();root.add_child(app)
	var settings=Hearth20SettingsWindow.open(app,app);await settle()
	expect(settings.size.y<=root.size.y-64 and settings.position.y>=24,"settings fits a short window with its title visible")
	for tab in settings.tabs.get_tab_count():
		settings.tabs.current_tab=tab;await settle()
		expect(settings.get_ok_button().get_global_rect().end.y<=settings.size.y and settings.get_cancel_button().get_global_rect().end.y<=settings.size.y,"settings footer stays reachable on tab "+str(tab))
	settings._cancel();var reopened=Hearth20SettingsWindow.open(app,app)
	expect(reopened!=settings and not reopened.is_queued_for_deletion(),"same-frame settings reopen creates a live dialog")
	reopened._cancel();await settle()
	var guide=Hearth20PartyGuide.open(app);await settle()
	expect(guide.position.y>=24 and guide.position.y+guide.size.y<=root.size.y,"illustrated guide fits inside the game")
	guide.queue_free();var next=Hearth20PartyGuide.open(app,"join")
	expect(next!=guide and next.role_tabs.current_tab==1,"same-frame guide reopen preserves the requested role")
	next.queue_free();await settle()
	var portal=Hearth20CasinoPortal.new();root.add_child(portal);portal.app=app
	portal.layer=Control.new();portal.layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(portal.layer)
	portal.scene=TableFixture.new();portal.add_child(portal.scene);portal.scene.book=Hearth20CasinoBook.new();portal.scene.add_child(portal.scene.book)
	var image=Image.create(8,8,false,Image.FORMAT_RGBA8);image.fill(Color.BLACK);portal.assets.catalog=ImageTexture.create_from_image(image)
	portal._build_hud();portal._refresh();await settle()
	for dimensions in [Vector2i(1000,650),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=dimensions;await settle()
		expect(portal.catalog_panel.get_rect().end.y<portal.footer_panel.position.y,"casino catalog reserves footer space at "+str(dimensions))
		expect(portal.catalog_panel.get_rect().end.x<portal.right_panel.position.x,"casino catalog and reserve panel stay separate")
		var scroll=portal.catalog_panel.get_children().filter(func(child):return child is ScrollContainer)
		expect(scroll.size()==1 and scroll[0].size.y>200,"casino catalog scrolls within its assigned area")
		var controls=portal.footer_panel.find_children("*","Button",true,false).filter(func(b):return b.visible)
		expect(controls.all(func(b):return b.size.x>=100 and b.get_global_rect().end.x<=root.size.x),"casino footer actions retain readable widths")
	portal._book_ui(true);await settle()
	var picker=portal.book_nav.find_children("*","OptionButton",true,false)[0]
	expect(picker.item_count==5,"rulebook chapter picker covers contents and every game")
	portal.scene.book.chapter_changed.emit(2);expect(picker.selected==3,"book navigation follows chapter changes")
	portal.scene.book.chapter_changed.emit(-1);expect(picker.selected==0,"book navigation follows return to contents")
	portal._book_ui(false);await settle()
	expect(portal.scene.book.chapter_changed.get_connections().is_empty(),"closed rulebook navigation releases its signal callback")
	portal.layer.queue_free();portal.queue_free();app.queue_free();await settle()
	print("Layout controls: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
