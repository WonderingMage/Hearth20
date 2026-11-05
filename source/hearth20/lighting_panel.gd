extends RefCounted
class_name Hearth20LightingPanel
class Compass extends Control:
	signal direction_changed(value: float)
	var north:=0.0
	var sky_azimuth:=0.0
	var daylight:=true
	var dragging:=false
	func _ready() -> void:
		custom_minimum_size=Vector2(180,174)
		focus_mode=Control.FOCUS_ALL
		tooltip_text="Drag the compass to set which way is north on this board. Arrow keys rotate 5 degrees."
	func _draw() -> void:
		var center:=size*0.5
		var r:=minf(size.x,size.y)*0.38
		draw_circle(center,r,Hearth20Regal.resolve(Color("#101824")))
		draw_arc(center,r,0,TAU,96,Hearth20Regal.swatch(Hearth20Regal.BORDER),1.5,true)
		for i in 24:
			var direction:=Vector2.from_angle(float(i)*TAU/24.0)
			draw_line(center+direction*(r-5),center+direction*r,Hearth20Regal.swatch(Hearth20Regal.MUTED),1,true)
		for pair in [["N",-90],["E",0],["S",90],["W",180]]:
			var dir:=Vector2.from_angle(deg_to_rad(float(pair[1])+north))
			var pos:=center+dir*(r-18)
			draw_string(ThemeDB.fallback_font,pos+Vector2(-5,5),str(pair[0]),HORIZONTAL_ALIGNMENT_CENTER,12,14,Hearth20Regal.swatch(Hearth20Regal.GOLD) if pair[0]=="N" else Hearth20Regal.swatch(Hearth20Regal.MUTED))
		var tip:=Vector2.from_angle(deg_to_rad(north-90))
		draw_colored_polygon(PackedVector2Array([center+tip*(r-31),center+tip.orthogonal()*8,center-tip*15,center-tip.orthogonal()*8]),Color("#dbba80"))
		draw_circle(center,3,Color("#0b111b"))
		var sky_dir:=Vector2.from_angle(deg_to_rad(sky_azimuth+north-90))
		draw_circle(center+sky_dir*(r+9),6,Color("#ffdb87") if daylight else Color("#a7cdf4"))
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			dragging=event.pressed
			if dragging: grab_focus(); _point(event.position)
			accept_event()
		elif event is InputEventMouseMotion and dragging: _point(event.position); accept_event()
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT,KEY_RIGHT]:
			north=fposmod(north+(5 if event.keycode==KEY_RIGHT else -5),360); direction_changed.emit(north); queue_redraw(); accept_event()
	func _point(point: Vector2) -> void:
		north=fposmod(rad_to_deg((point-size*0.5).angle())+90.0,360.0)
		direction_changed.emit(north); queue_redraw()

static func build(toolbox: Node) -> void:
	toolbox.section("NATURAL LIGHT")
	var values:=Hearth20NaturalLight.settings(toolbox.board.current_scene())
	var container: Control=toolbox._target()
	var debounce:=Timer.new()
	debounce.one_shot=true; debounce.wait_time=0.2
	container.add_child(debounce)
	debounce.timeout.connect(func(): toolbox._report(toolbox.session.set_natural_lighting(values)))
	var compass:=Compass.new()
	compass.north=float(values.north_degrees)
	container.add_child(compass)
	var orientation: Label=toolbox.label("",12,Hearth20Design.GOLD)
	orientation.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(orientation)
	var clock: Label=toolbox.label("",23,Hearth20Design.INK)
	clock.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(clock)
	var slider:=HSlider.new()
	slider.min_value=0; slider.max_value=24; slider.step=1.0/12.0; slider.value=float(values.time_hours)
	slider.custom_minimum_size.y=30
	slider.tooltip_text="Time of day: midnight to midnight, in five-minute steps."
	container.add_child(slider)
	var ticks: Label=toolbox.label("00:00       06:00       12:00       18:00       24:00",10,Hearth20Design.MUTED)
	ticks.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(ticks)
	var description: Label=toolbox.label("",12,Hearth20Design.MUTED)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	container.add_child(description)
	var refresh:=func():
		var state:=Hearth20NaturalLight.sky({"natural_light":values})
		clock.text=Hearth20NaturalLight.time_label(float(values.time_hours))
		orientation.text="Board north · %.0f°"%float(values.north_degrees)
		compass.sky_azimuth=float(state.azimuth); compass.daylight=bool(state.daylight); compass.queue_redraw()
		description.text="%s · azimuth %.0f° · elevation %.0f°\nWindow facing and sill height determine the cast."%["Warm sunlight" if state.daylight else "Soft blue moonlight",float(state.azimuth),rad_to_deg(float(state.altitude))]
	slider.value_changed.connect(func(v): values.time_hours=v; refresh.call(); debounce.start())
	compass.direction_changed.connect(func(v): values.north_degrees=v; refresh.call(); debounce.start())
	var intensity_controls: Dictionary={}
	for spec in [["Sun intensity","sun_intensity",200.0],["Moon intensity","moon_intensity",200.0],["Atmosphere","haze",100.0]]:
		var field:=str(spec[1])
		var row:=HBoxContainer.new()
		row.add_child(toolbox.label(str(spec[0]),12,Hearth20Design.MUTED))
		var number:=Label.new(); number.size_flags_horizontal=Control.SIZE_EXPAND_FILL; number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		number.text="%.0f%%"%(float(values[field])*100); row.add_child(number); container.add_child(row)
		var control:=HSlider.new()
		control.max_value=float(spec[2]); control.step=1; control.value=float(values[field])*100; control.custom_minimum_size.y=25
		control.value_changed.connect(func(v): values[field]=v/100.0; number.text="%.0f%%"%v; debounce.start())
		container.add_child(control)
		intensity_controls[field]=[control,number]
	var sync:=func(_state: Dictionary):
		if not debounce.is_stopped(): return
		var latest:=Hearth20NaturalLight.settings(toolbox.board.current_scene())
		if latest==values: return
		values.clear(); values.merge(latest,true)
		slider.set_value_no_signal(float(values.time_hours))
		compass.north=float(values.north_degrees)
		for field in intensity_controls:
			intensity_controls[field][0].set_value_no_signal(float(values[field])*100)
			intensity_controls[field][1].text="%.0f%%"%(float(values[field])*100)
		refresh.call()
	toolbox.session.state_changed.connect(sync)
	container.tree_exiting.connect(func():
		if toolbox.session.state_changed.is_connected(sync): toolbox.session.state_changed.disconnect(sync))
	refresh.call()
