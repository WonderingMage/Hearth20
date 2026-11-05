extends Node
class_name Hearth20Preferences
const PATH="user://hearth20/settings.cfg"
const DEFAULTS={"window_mode":0,"width":1280,"height":800,"monitor":0,"vsync":true,"fps":60,"background_fps":30,"quality":1,"master":.8,"effects":1.,"party":1.,"showcase":1.,"wake":1.,"mute_unfocused":false,"audio_device":"Default","update_channel":Hearth20Identity.UPDATE_CHANNEL_DEFAULT}
const BUSES={"effects":"Table FX","party":"Tavern & Party","showcase":"Creature Showcase","wake":"Wake Voice"}
static var values: Dictionary=DEFAULTS.duplicate()
static var preview_values: Dictionary={}
var focused=true
func _ready() -> void:
	values=read();ensure_buses();apply_audio(values);apply_display(values)
	get_tree().node_added.connect(_node_added)
	_node_added(get_window())
static func sanitized(input: Dictionary) -> Dictionary:
	var result=DEFAULTS.duplicate()
	for key in DEFAULTS:
		if not input.has(key):continue
		var value=input[key]
		if DEFAULTS[key] is bool:
			if value is bool:result[key]=value
		elif DEFAULTS[key] is String:
			if value is String and value.length()<=128:result[key]=value
		elif value is int or value is float:
			if is_finite(float(value)):result[key]=value
	result.window_mode=clampi(int(result.window_mode),0,2);result.width=clampi(int(result.width),960,7680);result.height=clampi(int(result.height),640,4320);result.monitor=maxi(0,int(result.monitor));result.quality=clampi(int(result.quality),0,2)
	for key in ["fps","background_fps"]:
		if int(result[key]) not in [0,30,45,60,90,120,144,165,240]:result[key]=DEFAULTS[key]
	for key in ["master","effects","party","showcase","wake"]:result[key]=clampf(float(result[key]),0.,1.)
	if result.update_channel not in ["beta","steam-test"]:result.update_channel=DEFAULTS.update_channel
	return result
static func read() -> Dictionary:
	var file=ConfigFile.new();var data={}
	if file.load(PATH)==OK:
		for key in DEFAULTS:data[key]=file.get_value("preferences",key,DEFAULTS[key])
	return sanitized(data)
static func save(input: Dictionary) -> Error:
	var clean=sanitized(input);var file=ConfigFile.new()
	for key in clean:file.set_value("preferences",key,clean[key])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()));var error=file.save(PATH)
	if error==OK:values=clean;preview_values={}
	return error
static func ensure_buses() -> void:
	for bus in BUSES.values():
		if AudioServer.get_bus_index(bus)>=0:continue
		AudioServer.add_bus();var index=AudioServer.bus_count-1;AudioServer.set_bus_name(index,bus);AudioServer.set_bus_send(index,"Master")
static func apply_audio(input: Dictionary) -> void:
	ensure_buses();var data=sanitized(input)
	if data.audio_device in AudioServer.get_output_device_list() and AudioServer.output_device!=data.audio_device:AudioServer.output_device=data.audio_device
	for key in ["master","effects","party","showcase","wake"]:
		var index=AudioServer.get_bus_index("Master" if key=="master" else BUSES[key]);var level=float(data[key])
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,level)));AudioServer.set_bus_mute(index,level<=.0001)
static func apply_focus(active: bool) -> void:
	var data=values if preview_values.is_empty() else preview_values;var limit=int(data.fps if active else data.background_fps)
	Engine.max_fps=0 if not OS.get_environment("H20_PERFORMANCE_OUTPUT").is_empty() else limit
	AudioServer.set_bus_mute(0,float(data.master)<=.0001 or (bool(data.mute_unfocused) and not active))
static func apply_display(input: Dictionary) -> void:
	if DisplayServer.get_name()=="headless":return
	var data=sanitized(input);var window=Engine.get_main_loop().root
	window.current_screen=clampi(int(data.monitor),0,maxi(0,DisplayServer.get_screen_count()-1))
	window.mode=Window.MODE_WINDOWED if int(data.window_mode)==0 else Window.MODE_FULLSCREEN if int(data.window_mode)==1 else Window.MODE_EXCLUSIVE_FULLSCREEN
	if int(data.window_mode)==0:
		var usable=DisplayServer.screen_get_usable_rect(window.current_screen);window.size=Vector2i(data.width,data.height).min(usable.size-Vector2i(32,64));window.position=usable.position+(usable.size-window.size)/2
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=int(data.fps);apply_graphics(data)
static func apply_graphics(data: Dictionary) -> void:
	for viewport in Engine.get_main_loop().root.find_children("*","SubViewport",true,false):
		if viewport.disable_3d:continue
		if not viewport.has_meta("original_msaa"):viewport.set_meta("original_msaa",viewport.msaa_3d)
		viewport.msaa_3d=Viewport.MSAA_DISABLED if int(data.quality)==0 else Viewport.MSAA_4X if int(data.quality)==2 else int(viewport.get_meta("original_msaa"))
func _node_added(node: Node) -> void:
	if node is SubViewport:call_deferred("_apply_viewports")
	if node is Window:
		if not node.focus_entered.is_connected(_focus_changed):node.focus_entered.connect(_focus_changed)
		if not node.focus_exited.is_connected(_focus_changed):node.focus_exited.connect(_focus_changed)
func _apply_viewports() -> void:apply_graphics(values if preview_values.is_empty() else preview_values)
func _focus_changed() -> void:call_deferred("_refresh_focus")
func _refresh_focus() -> void:
	focused=get_window().has_focus()
	for window in get_tree().root.find_children("*","Window",true,false):focused=focused or window.has_focus()
	apply_focus(focused)
