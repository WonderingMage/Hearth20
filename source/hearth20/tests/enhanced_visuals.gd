extends SceneTree
var checks:=0
var failures: Array[String]=[]
var app: Hearth20App
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error("FAIL: "+message)
func capture(window: Window, name_value: String) -> void:
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_png(OS.get_environment("H20_QA_EVIDENCE").path_join(name_value+".png"))
func click(control: Control) -> void:
	var event:=InputEventMouseButton.new(); event.position=control.get_global_rect().get_center(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	Input.parse_input_event(event); await process_frame
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await process_frame
func find_compass(node: Node) -> Control:
	if node is Hearth20LightingPanel.Compass: return node
	for child in node.get_children():
		var found:=find_compass(child)
		if found!=null: return found
	return null
func run() -> void:
	natural_checks()
	root.size=Vector2i(1440,900)
	app=load("res://hearth20_main.tscn").instantiate(); root.add_child(app)
	expect(app._load_sample_map("sunspire-sanctum",false).ok,"real app loads the generated temple")
	await create_timer(.35).timeout
	var medallion: Control=app.find_child("AppearanceMedallion",true,false)
	expect(medallion!=null and medallion.custom_minimum_size==Vector2(54,54),"ornate appearance control is accessible")
	await capture(root,"regal-black-temple")
	await click(medallion)
	expect(Hearth20Regal.light_mode,"native medallion click switches to light mode")
	await create_timer(.25).timeout
	var foreground:=app.get_theme_color("font_color","Label")
	expect(foreground.r<.4 and Hearth20Regal.swatch(Hearth20Regal.SURFACE).r>.8,"light palette uses dark text over warm beige")
	var config:=ConfigFile.new(); config.load("user://hearth20/interface.cfg")
	expect(config.get_value("appearance","light",false)==true,"theme preference is saved locally")
	await capture(root,"regal-parchment-temple")
	await click(medallion)
	expect(not Hearth20Regal.light_mode,"second click restores regal black without touching the table")
	app.toolbox.open("lighting")
	await create_timer(.25).timeout
	var compass:=find_compass(app.toolbox)
	expect(compass!=null,"Light panel exposes the interactive compass")
	var sliders:=app.toolbox.content.find_children("*","HSlider",true,false)
	expect(sliders.size()>=4,"time, sun, moon and atmosphere sliders are present")
	if not sliders.is_empty(): sliders[0].value=0.0
	await create_timer(.35).timeout
	var scene: Dictionary=app.board.current_scene()
	expect(is_zero_approx(float(scene.natural_light.time_hours)),"time slider commits midnight to the host's actual scene")
	var old_north:=float(scene.natural_light.north_degrees)
	compass.grab_focus()
	var key:=InputEventKey.new(); key.pressed=true; key.keycode=KEY_RIGHT
	Input.parse_input_event(key); await create_timer(.35).timeout
	expect(is_equal_approx(float(scene.natural_light.north_degrees),fposmod(old_north+5,360)),"native keyboard rotation updates the board's north")
	await capture(root,"regal-light-compass-midnight")
	var natural:=Hearth20NaturalLight.DEFAULTS.duplicate(); natural.time_hours=0; natural.north_degrees=90; natural.moon_intensity=.65
	expect(app.session.set_natural_lighting(natural).ok,"DM applies stronger blue moonlight")
	expect(is_equal_approx(compass.north,90),"open Light panel follows authoritative compass changes")
	await capture(root,"temple-blue-moonlight")
	natural.time_hours=17.0; natural.north_degrees=0; natural.sun_intensity=1.2
	app.session.set_natural_lighting(natural)
	expect(app.toolbox.content.find_children("*","Label",true,false).any(func(node): return node.text=="17:00"),"open Light panel follows authoritative clock changes")
	await capture(root,"temple-low-sun-window-casts")
	app.toolbox.open("fx")
	await capture(root,"regal-effects-live-preview")
	root.size=Vector2i(1000,650)
	await create_timer(.3).timeout
	expect(app.save_button.get_global_rect().end.x<=1000,"ornate theme control and header fit the compact window")
	await capture(root,"regal-compact-effects")
	await effects_gallery()
	print("Enhanced visuals: %d assertions, %d failures."%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func natural_checks() -> void:
	var sky_day:=Hearth20NaturalLight.sky({"natural_light":{"time_hours":12.0}})
	var sky_night:=Hearth20NaturalLight.sky({"natural_light":{"time_hours":0.0}})
	expect(sky_day.daylight and not sky_night.daylight,"24-hour clock chooses sun or moon")
	expect(Color(str(sky_day.color)).r>Color(str(sky_day.color)).b and Color(str(sky_night.color)).b>Color(str(sky_night.color)).r,"sunlight is warm and moonlight blue")
	var rotated:=Hearth20NaturalLight.sky({"natural_light":{"time_hours":12.0,"north_degrees":90.0}})
	expect(Vector2(sky_day.direction).rotated(PI*.5).is_equal_approx(rotated.direction),"board compass rotates the natural light direction")
	expect(Hearth20NaturalLight.sky({"natural_light":{"time_hours":24.0}}).direction.is_equal_approx(sky_night.direction),"both midnight endpoints agree")
	expect(not Hearth20NaturalLight.valid({"time_hours":25}) and not Hearth20NaturalLight.valid({"north_degrees":NAN}) and not Hearth20NaturalLight.valid({"moon_intensity":-1}),"natural controls reject invalid ranges and nonfinite values")
	expect(Hearth20Lighting._irradiance(12,1,40)<Hearth20Lighting._irradiance(6,1,40)*.4,"point irradiance attenuates with distance and incident angle")
	var c:=Hearth20Identity.new_campaign()
	var s: Dictionary=c.scenes[0]
	s.width_cells=20; s.height_cells=12; s.dynamic_lighting=true; s.ambient_light="dark"
	s.natural_light={"time_hours":17.0,"north_degrees":0.0,"sun_intensity":1.0}
	s.annotations=[{"id":"window-opening","owner":"dm-local","kind":"window","layer":"light","points":[Vector2(2,4),Vector2(2,6)]},{"id":"window-light","owner":"dm-local","kind":"light","layer":"light","source_type":"window","points":[Vector2(2.1,5)],"bright":20,"dim":20,"window_height":8,"sill_height":3}]
	c.actors=[{"id":"viewer","name":"Viewer","is_hero":true,"owner_player_id":"viewer","scene_id":s.id,"position":Vector2(3,5),"vision":{"enabled":true,"darkvision_feet":0,"bright_light_feet":0,"dim_light_feet":0}}]
	var view:=Hearth20Vision.build_view(c,"viewer",s)
	var portal: Dictionary=view.lights[0].portal
	expect(is_equal_approx(float(portal.width),2) and float(portal.far)>float(portal.near),"light aperture comes from the actual ten-foot window geometry")
	expect(Hearth20NaturalLight.window_meshes(view.lights[0],view).size()>0,"facing window casts a finite rectangular sunlight patch")
	var late_length: float=portal.far
	s.natural_light.time_hours=12.0; s.natural_light.north_degrees=90.0
	view=Hearth20Vision.build_view(c,"viewer",s)
	expect(float(view.lights[0].portal.far)<late_length,"higher midday sun shortens the floor cast")
	s.natural_light.north_degrees=270.0
	view=Hearth20Vision.build_view(c,"viewer",s)
	expect(Hearth20NaturalLight.window_meshes(view.lights[0],view).is_empty(),"window facing away receives no direct solar patch")
	s.natural_light.sun_intensity=0.0
	view=Hearth20Vision.build_view(c,"viewer",s)
	expect(Hearth20Vision.level_at(Vector2(3,5),view)==0,"zero sun intensity cannot illuminate an ordinary-sight player")
	var session:=Hearth20Session.new(); root.add_child(session); session.configure(c); session.local_role="player"
	expect(not session.set_natural_lighting({"time_hours":10}).ok,"players cannot alter the clock or compass")
	session.queue_free()
	for id in ["oak-canopy","brass-chandelier"]:
		var texture: Texture2D=load("res://hearth20/sample_maps/scenery-"+id+".png")
		var image:=texture.get_image()
		expect(image.get_pixel(0,0).a<.01 and image.get_pixel(image.get_width()/2,image.get_height()/2).a>.1,"generated foreground preserves transparency: "+id)

func effects_gallery() -> void:
	var window:=Window.new(); window.title="Hearth20 · The Arcane Atelier"; window.size=Vector2i(1440,900); window.theme=Hearth20Design.theme(); root.add_child(window)
	var background:=ColorRect.new(); background.color=Hearth20Regal.swatch(Hearth20Regal.BG); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.add_child(background)
	var margin:=MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	window.add_child(margin)
	var column:=VBoxContainer.new(); margin.add_child(column)
	var title:=Label.new(); title.text="THE ARCANE ATELIER  /  FIFTEEN LIVING EFFECTS"; title.add_theme_font_override("font",Hearth20Design.font(true)); title.add_theme_font_size_override("font_size",24); title.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD)); column.add_child(title)
	var grid:=GridContainer.new(); grid.columns=5; grid.size_flags_vertical=Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",10); grid.add_theme_constant_override("v_separation",10); column.add_child(grid)
	var renderers: Array=[]
	var index:=0
	for kind in Hearth20BoardTools.EFFECTS:
		var panel:=PanelContainer.new(); panel.custom_minimum_size=Vector2(272,260); panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL; panel.size_flags_vertical=Control.SIZE_EXPAND_FILL; grid.add_child(panel)
		var tile:=VBoxContainer.new(); panel.add_child(tile)
		var label:=Label.new(); label.text=str(kind).capitalize(); label.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD)); tile.add_child(label)
		var canvas:=Control.new(); canvas.clip_contents=true; canvas.custom_minimum_size=Vector2(230,205); canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL; tile.add_child(canvas)
		var fx:=Hearth20FxRenderer.new(); fx.world_scale=44; canvas.add_child(fx); renderers.append(fx)
		var colors: Array=["#92baff","#ff8136","#ff7825","#6ecbd3","#ff9638","#ffcc65","#ef5931","#b695ff","#b395ff","#c2a0ff","#72c5b6","#ffb04f","#ead193","#ffe0a0","#c74a4b"]
		var event:={"id":"gallery-"+str(kind),"preset":"tabletop-fx-v1","source":Vector2(.8,2),"destination":Vector2(4.5,2),"effect":kind,"color":colors[index],"size":1.0,"density":48,"seed":100+index,"started_usec":Time.get_ticks_usec(),"travel_usec":1000000 if kind in ["rocket","missile"] else 0,"impact_duration_usec":3000000}
		expect(fx.add_authorized_event(event),"native cinematic effect starts: "+str(kind)); index+=1
	window.popup_centered(); await create_timer(.5).timeout
	for fx in renderers:
		for event in fx.events: event.started_usec=Time.get_ticks_usec()-500000
	await capture(window,"regal-cinematic-fx-gallery")
	expect(renderers.all(func(fx): return fx.cinematic!=null and not fx.cinematic.actors.is_empty()),"all fifteen effects create their spatial GPU actors")
	var first:=Hearth20Contracts.sha256(window.get_texture().get_image().get_data())
	await create_timer(.3).timeout; await RenderingServer.frame_post_draw
	expect(first!=Hearth20Contracts.sha256(window.get_texture().get_image().get_data()),"native effects change visibly over time")
	for fx in renderers: fx.clear_all()
	await process_frame; await process_frame
	expect(renderers.all(func(fx): return fx.visuals.is_empty() and fx.cinematic.actors.is_empty()),"clearing effects also removes their spatial and fallback layers")
	window.queue_free()
