extends SceneTree
class AppFixture extends Hearth20App:
	func _ready() -> void:
		inspector_tabs=TabContainer.new();add_child(inspector_tabs);sheet_page=ScrollContainer.new();sheet_page.name="Sheet";inspector_tabs.add_child(sheet_page)
		beyond_sheet=Hearth20BeyondSheet.new();sheet_page.add_child(beyond_sheet);beyond_sheet.setup(self);beyond_sheet.set_process(false)
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	var app=AppFixture.new();root.add_child(app);await process_frame;var sheet=app.beyond_sheet
	expect(sheet.host_mode=="native" and sheet.backend.selected==0,"sheet defaults to the actual Windows browser")
	var url="https://www.dndbeyond.com/characters/123456";sheet.navigate(url)
	await sheet._change_backend("embedded")
	var profile=ConfigFile.new();profile.load("user://beyond-sheet.cfg")
	expect(sheet.host_mode=="embedded" and profile.get_value("sheet","browser","")=="embedded","browser backend can be changed and remembered")
	expect(profile.get_value("sheet","url","")==url,"browser mode changes retain the personal character URL")
	await sheet._change_backend("native")
	expect(sheet.host_mode=="native" and await sheet.release_for_shutdown(),"native backend can be restored and no-process shutdown completes")
	sheet._go("twilight cleric")
	expect(sheet.requested=="https://www.dndbeyond.com/search?q=twilight%20cleric","browser navigation retains D&D Beyond search")
	var before=sheet.requested;sheet._go("https://unrelated.invalid/")
	expect(sheet.requested==before,"sheet navigation cannot silently launch an unrelated site")
	app.queue_free();await process_frame
	print("Sheet browser UI: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
