extends CanvasLayer
class_name Hearth20JaxAlert
## Fixed, bounded table gag. No arbitrary remote text, URL, volume or duration.
const STEAM_ID=76561199404933498
const DURATION=5.0
const PHASE_SECONDS=.4 # 1.25 complete white/black cycles per second.
const COOLDOWN_MSEC=10000
var background: ColorRect
var message: Label
var dismiss_button: Button
var audio: AudioStreamPlayer
var started_msec=-1
var last_msec=-COOLDOWN_MSEC
var active=false
func _ready() -> void:
	name="JaxTableAlert";layer=2000;process_mode=Node.PROCESS_MODE_ALWAYS
	var surface=Control.new();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(surface)
	background=ColorRect.new();background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;surface.add_child(background)
	message=Label.new();message.text="STOP IT JAX";message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;message.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;message.mouse_filter=Control.MOUSE_FILTER_IGNORE;message.add_theme_font_override("font",Hearth20Design.font(true));surface.add_child(message)
	dismiss_button=Button.new();dismiss_button.text="Dismiss · Esc";dismiss_button.anchor_left=.5;dismiss_button.anchor_right=.5;dismiss_button.anchor_top=1.;dismiss_button.anchor_bottom=1.;dismiss_button.offset_left=-100;dismiss_button.offset_right=100;dismiss_button.offset_top=-74;dismiss_button.offset_bottom=-26;surface.add_child(dismiss_button);dismiss_button.pressed.connect(dismiss)
	audio=AudioStreamPlayer.new();audio.bus=Hearth20Preferences.BUSES.party;audio.volume_db=-8.;audio.stream=load("res://hearth20/window_worlds/jax-siren.wav");add_child(audio)
	hide();set_process(false)
func trigger() -> bool:
	var now=Time.get_ticks_msec()
	if active or now-last_msec<COOLDOWN_MSEC or not Hearth20Preferences.values.get("table_alerts",true):return false
	started_msec=now;last_msec=now;active=true;show();set_process(true);_paint(0.);audio.play();return true
func _process(_delta: float) -> void:
	var elapsed=float(Time.get_ticks_msec()-started_msec)/1000.
	if elapsed>=DURATION or not Hearth20Preferences.values.get("table_alerts",true):dismiss();return
	_paint(elapsed)
func _paint(elapsed: float) -> void:
	var white=not Hearth20Preferences.values.get("reduce_flashes",false) and int(elapsed/PHASE_SECONDS)%2==0
	background.color=Color.WHITE if white else Color.BLACK
	message.add_theme_color_override("font_color",Color.BLACK if white else Color.WHITE)
	message.add_theme_font_size_override("font_size",clampi(int(get_viewport().get_visible_rect().size.x/9.),48,180))
func dismiss() -> void:
	active=false;hide();set_process(false)
	if is_instance_valid(audio):audio.stop()
func _input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:dismiss();get_viewport().set_input_as_handled()
static func find_peer(connected: PackedInt32Array,admitted: Dictionary,lookup: Callable,allowed: Callable) -> int:
	# Native Steam peer identity, never a display name or saved player-supplied ID.
	# One bounded pass over current admitted connections; no timers or retries.
	if connected.size()>Hearth20Session.MAX_CLIENTS:return 0
	for peer in connected:
		if admitted.has(peer) and int(lookup.call(peer))==STEAM_ID and allowed.call(peer):return peer
	return 0
