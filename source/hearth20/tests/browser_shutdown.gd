extends SceneTree
class SheetFixture extends Hearth20BeyondSheet:
	var release_count=0
	var released=false
	var allow_release=true
	var finished_count=0
	func release_for_shutdown() -> bool:
		release_count+=1;await get_tree().create_timer(.08).timeout;released=allow_release;return allow_release
	func _finish_quit() -> void:finished_count+=1
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	auto_accept_quit=true
	var sheet=SheetFixture.new();root.add_child(sheet);sheet.set_process(false)
	sheet._arm_quit_guard();sheet._arm_quit_guard()
	expect(not auto_accept_quit,"scene tree automatic quit is disabled before browser starts")
	expect(root.close_requested.is_connected(sheet._quit_with_browser),"root window close request reaches the browser release handler")
	var matching=root.close_requested.get_connections().filter(func(item):return item.callable==sheet._quit_with_browser)
	expect(matching.size()==1,"rearming the guard does not duplicate close handlers")
	root.close_requested.emit();root.close_requested.emit()
	expect(sheet.release_count==1 and sheet.finished_count==0,"repeated close requests wait for one browser release")
	await create_timer(.15).timeout
	expect(sheet.released and sheet.finished_count==1,"game exit occurs only after browser release succeeds")
	sheet.queue_free();await process_frame
	var blocked=SheetFixture.new();blocked.allow_release=false;root.add_child(blocked);blocked.set_process(false);blocked._arm_quit_guard();root.close_requested.emit()
	await create_timer(.15).timeout
	expect(blocked.finished_count==0 and not blocked.quitting,"failed release keeps the game window alive and permits retry")
	blocked.allow_release=true;root.close_requested.emit();await create_timer(.15).timeout
	expect(blocked.released and blocked.finished_count==1 and blocked.release_count==2,"retry can close once the browser is released")
	blocked.queue_free();await process_frame;auto_accept_quit=true
	print("Browser shutdown guard: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
