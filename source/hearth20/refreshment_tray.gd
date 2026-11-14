extends Node
class_name Hearth20RefreshmentTray
## Personal models only; the server relays sounds and owns serving/time state.
var shell: Hearth20SeatedShell
var session: Hearth20Session
var table: Hearth20CasinoTable
var stool: Node3D
var menu_model: Node3D
var serving: Node3D
var food_model: Node3D
var drink_model: Node3D
var plate: Node3D
var menu: Hearth20RefreshmentMenu
var note: Label
var effect: ColorRect
var veil: Control
var blackout_label: Label
var food_at=Vector3(0,1.006,-.14)
var drink_at=Vector3(0,1.006,.15)
var value={}
var order_id=""
var generation=0
var offset=0.
var server_stamp=-1.
var seen={}
var played_pending=""
var clock=0.
var was_blackout=false
var blackout_flash=0.
var swallow_piece: Node3D
var spectate_requested=false
var saved_look=Vector2.ZERO
var saved_look_up=false
var wake_ack=0.
var wake_profile=""
var wake_player: AudioStreamPlayer
func setup(owner_shell: Hearth20SeatedShell) -> void:
	shell=owner_shell;table=shell.table;session=shell.app.session
	stool=Node3D.new();stool.name="PersonalRefreshmentTable";stool.position=Vector3(1.20,0,2.39);table.world.add_child(stool)
	var crafted=Hearth20GeneratedModels.make("side_table",Vector3(.76,1.006,.76))
	if crafted!=null:stool.add_child(crafted)
	else:
		table._lathe(stool,Vector3.ZERO,[[0.,.965],[1.,.965],[1.,.995],[.98,1.006],[0.,1.006]],.38,.38,table.wood,48)
		table._lathe(stool,Vector3.ZERO,[[.75,.03],[.9,.06],[.8,.1],[.32,.15],[.22,.23],[.24,.48],[.20,.70],[.30,.89],[.82,.95]],.23,.23,table.wood,32)
		table._lathe(stool,Vector3.ZERO,[[.99,.978],[1.01,.978],[1.01,.986],[.99,.986]],.38,.38,table.bronze,48)
	serving=Node3D.new();stool.add_child(serving);_physical_menu();_screen_ui()
	session.refreshment_event.connect(_event);session.refreshment_action_result.connect(_result)
func _physical_menu() -> void:
	menu_model=Node3D.new();menu_model.name="PhysicalRefreshmentMenu";menu_model.position=Vector3(0,1.16,0);menu_model.basis=Basis.looking_at(Vector3(-.9,.4,0),Vector3.UP,true);stool.add_child(menu_model)
	var crafted=Hearth20GeneratedModels.make("menu",Vector3(.31,.43,.045),true)
	if crafted!=null:menu_model.add_child(crafted);return
	var leather=StandardMaterial3D.new();leather.albedo_color=Color("#301812");leather.roughness=.9
	var board=table._bevel(Vector3(.31,.025,.43),.025,leather);board.rotation.x=PI/2;menu_model.add_child(board)
	for side in [-1.,1.]:
		var rail=table._bevel(Vector3(.012,.012,.405),.004,table.bronze);rail.position=Vector3(side*.14,0,.017);rail.rotation.x=PI/2;menu_model.add_child(rail)
	for spec in [["✦",.08,.115],["MENU",.065,.025],["FOOD & DRINK",.024,-.058],["THE HEARTH",.023,-.12]]:
		var letters=table._letters(spec[0],spec[1],.001,Color("#e7c27b"));letters.position=Vector3(0,spec[2],.026);menu_model.add_child(letters)
func _screen_ui() -> void:
	menu=Hearth20RefreshmentMenu.new();shell.add_child(menu);menu.ordered.connect(func(food,drink):_request({"action":"order","food":food,"drink":drink}))
	note=Label.new();note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;note.anchor_left=.2;note.anchor_right=.8;note.anchor_top=.15;note.offset_bottom=50;note.z_index=1450;note.add_theme_font_size_override("font_size",20);note.add_theme_color_override("font_color",Color("#ffe0a0"));note.mouse_filter=Control.MOUSE_FILTER_IGNORE;shell.add_child(note)
	effect=ColorRect.new();effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);effect.mouse_filter=Control.MOUSE_FILTER_IGNORE;effect.z_index=1700;shell.add_child(effect)
	var shader=Shader.new();shader.code="""shader_type canvas_item;
uniform sampler2D scene:hint_screen_texture,repeat_disable,filter_linear;
uniform float beers=0.;uniform float blackout=0.;
void fragment(){vec2 uv=SCREEN_UV;float strength=max(0.,beers-2.)/3.;float mild=min(beers,2.)*.00035;float a=sin(TIME*.43)*(.012*strength+mild);mat2 rot=mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)));uv=rot*(uv-.5)*(.996-.035*strength)+.5;uv+=vec2(sin(TIME*.6+uv.y*4.),cos(TIME*.47+uv.x*5.))*.0018*strength;vec2 d=SCREEN_PIXEL_SIZE*(strength*3.8+mild);vec3 c=texture(scene,uv).rgb*.24;c+=(texture(scene,uv+d).rgb+texture(scene,uv-d).rgb+texture(scene,uv+vec2(d.x,-d.y)).rgb+texture(scene,uv+vec2(-d.x,d.y)).rgb)*.12;c+=(texture(scene,uv+vec2(d.x*2.,0)).rgb+texture(scene,uv-vec2(d.x*2.,0)).rgb+texture(scene,uv+vec2(0,d.y*2.)).rgb+texture(scene,uv-vec2(0,d.y*2.)).rgb)*.07;COLOR=vec4(c*(1.-blackout),1.);}"""
	var mat=ShaderMaterial.new();mat.shader=shader;effect.material=mat;effect.hide()
	veil=Control.new();veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.z_index=1800;shell.add_child(veil);veil.hide()
	var panel=PanelContainer.new();panel.anchor_left=.24;panel.anchor_right=.76;panel.offset_top=12;panel.offset_bottom=100;panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Color(.03,.02,.015,.95),2,12,Color("#b48c49")));veil.add_child(panel)
	var col=VBoxContainer.new();panel.add_child(col);blackout_label=Label.new();blackout_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;blackout_label.add_theme_font_size_override("font_size",20);col.add_child(blackout_label)
	var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;col.add_child(row)
	for title in ["Watch battlemap","Look at the table"]:
		var button=Button.new();button.text=title;row.add_child(button);button.pressed.connect(func():
			spectate_requested=true;blackout_flash=0.
			shell.leave_focus()
			if title=="Watch battlemap" and shell.current_mode=="map":shell.focus_map())
func _request(command: Dictionary) -> void:
	_result(session.refreshments_action(command))
func _result(result: Dictionary) -> void:
	if not result.get("ok",false):note.text=str(result.get("error","Could not complete that serving."));menu.confirm.disabled=false
func now() -> float:return Time.get_unix_time_from_system()+offset
func _process(delta: float) -> void:
	if shell==null:return
	clock+=delta
	blackout_flash=move_toward(blackout_flash,1. if was_blackout and not spectate_requested else 0.,delta*.42);effect.material.set_shader_parameter("blackout",blackout_flash)
	effect.visible=blackout_flash>0. or Hearth20Refreshments.active_beers(value,now()).size()>0
	if clock>.15:
		clock=0.;value=session.refreshment_view()
		if value.has("server_now") and float(value.server_now)!=server_stamp:
			server_stamp=float(value.server_now);offset=server_stamp-Time.get_unix_time_from_system()
		_sync()
	_animate()
func _sync() -> void:
	var next_id=str(value.get("order",{}).get("id",""));var available=Hearth20Refreshments.menu_available(value)
	menu_model.visible=available and not session.is_spectating()
	if next_id!=order_id:
		order_id=next_id;generation+=1;_clear_serving()
		if not next_id.is_empty() and not available:_load_serving(value.order.duplicate(true),generation)
	if not value.get("order",{}).is_empty():
		if int(value.get("food_bites",0))>=2 and is_instance_valid(food_model):food_model.queue_free();food_model=null
		if int(value.get("drink_sips",0))>=3 and is_instance_valid(drink_model):drink_model.queue_free();drink_model=null
	if available and is_instance_valid(plate):plate.queue_free();plate=null
	if not available and menu.visible:menu.hide()
	var toward=atan2(stool.position.x,2.45-stool.position.z)
	if absf(wrapf(shell.look.x-toward,-PI,PI))<.45 and shell.focus_state=="table" and not menu.visible:
		note.text="Click the menu to choose provisions" if available else "Click your dish · %d bites left     /     Click your drink · %d sips left"%[2-int(value.get("food_bites",0)),3-int(value.get("drink_sips",0))]
	else:note.text=""
	var count=Hearth20Refreshments.active_beers(value,now()).size();effect.visible=count>0 or blackout_flash>0.
	effect.material.set_shader_parameter("beers",float(mini(count,5)))
	var blackout=session.is_spectating();veil.visible=blackout
	if blackout:
		var seconds=maxi(0,ceili(float(value.get("wake_at",now()))-now()));blackout_label.text="BLACKOUT · WAKING IN %dm %02ds"%[seconds/60,seconds%60]
		if not was_blackout:
			saved_look=shell.look;saved_look_up=shell.look_up;spectate_requested=false;blackout_flash=1.;menu.hide();shell.app.beyond_sheet.suspend_native();shell.leave_focus();shell.held_pull=""
		if is_instance_valid(shell.app.casino_portal.hud):shell.app.casino_portal.hud.hide()
		shell.look_button.hide();shell.map_viewport.gui_disable_input=true
	else:shell.map_viewport.gui_disable_input=false
	var profile=str(value.get("scope",""))+":"+session.local_player_id
	if not str(value.get("scope","")).is_empty() and profile!=wake_profile:
		wake_profile=profile;wake_ack=0.;var path=_wake_path()
		if FileAccess.file_exists(path):wake_ack=float(FileAccess.get_file_as_string(path))
	var woke=float(value.get("woke_at",0.))
	if not blackout and woke>wake_ack and not wake_profile.is_empty():_wake(woke)
	was_blackout=blackout
	var pending=value.get("pending",{});var key=str(value.get("order",{}).get("id",""))+str(pending.get("started_at",""))
	if not pending.is_empty() and key!=played_pending:
		played_pending=key
		if pending.action=="bite" and value.order.food in ["chips","fries","icecream_jar","chilli"]:_make_piece(value.order.food)
func _clear_serving() -> void:
	for child in serving.get_children():child.queue_free()
	food_model=null;drink_model=null;plate=null;swallow_piece=null
func _load_serving(order: Dictionary,token: int) -> void:
	var food_pack=await Hearth20RefreshmentModels.prepare(order.food,get_tree())
	var drink_pack=await Hearth20RefreshmentModels.prepare(order.drink,get_tree())
	if not is_inside_tree() or token!=generation:return
	if food_pack==null or drink_pack==null:note.text="A serving model could not be loaded.";return
	if int(value.get("food_bites",0))<2:
		food_model=Hearth20RefreshmentModels.make(order.food,food_pack);serving.add_child(food_model);food_model.position=food_at
		if Hearth20RefreshmentCatalog.FOODS[order.food].plate:
			var porcelain=StandardMaterial3D.new();porcelain.albedo_color=Color("#e5d8b8");porcelain.roughness=.24
			plate=Hearth20GeneratedModels.make("plate",Vector3(.34,.018,.34))
			if plate!=null:plate.position=food_at-Vector3(0,.005,0);serving.add_child(plate)
			else:plate=table._lathe(serving,food_at-Vector3(0,.005,0),[[0.,0],[.75,0],[.95,.006],[1.,.014],[.97,.018],[.80,.008],[0.,.008]],.17,.17,porcelain,40)
	if int(value.get("drink_sips",0))<3:drink_model=Hearth20RefreshmentModels.make(order.drink,drink_pack);serving.add_child(drink_model);drink_model.position=drink_at
	if now()-float(order.arrived_at)<15.:_smoke()
func _smoke() -> void:
	var smoke=CPUParticles3D.new();smoke.name="ServingSmokeBomb";smoke.position=Vector3(0,1.08,0);smoke.amount=42;smoke.lifetime=.9;smoke.one_shot=true;smoke.explosiveness=.95;smoke.direction=Vector3.UP;smoke.spread=85.;smoke.initial_velocity_min=.10;smoke.initial_velocity_max=.48;smoke.gravity=Vector3(0,.15,0);smoke.scale_amount_min=.11;smoke.scale_amount_max=.28;stool.add_child(smoke)
	var gradient=Gradient.new();gradient.colors=PackedColorArray([Color(.88,.71,.36,0),Color(.72,.65,.52,.55),Color(.18,.15,.12,0)]);gradient.offsets=PackedFloat32Array([0,.16,1]);smoke.color_ramp=gradient
	var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}void fragment(){float a=1.-smoothstep(.08,.5,length(UV-.5));float n=sin(UV.x*24.+TIME*3.)*sin(UV.y*19.-TIME*2.);ALBEDO=COLOR.rgb;ALPHA=COLOR.a*a*(.65+n*.20);}"
	var mat=ShaderMaterial.new();mat.shader=shader;var quad=QuadMesh.new();quad.size=Vector2.ONE;quad.material=mat;smoke.mesh=quad;smoke.finished.connect(smoke.queue_free);smoke.emitting=true
func _make_piece(food: String) -> void:
	if is_instance_valid(swallow_piece):swallow_piece.queue_free()
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("#e6b85e") if food in ["chips","fries"] else Color("#e5bb89") if food=="icecream_jar" else Color("#7c3521");mat.roughness=.83
	swallow_piece=Node3D.new();serving.add_child(swallow_piece)
	for i in (3 if food=="chips" else 1):
		var dimensions=Vector3(.035,.005,.045) if food=="chips" else Vector3(.013,.012,.07) if food=="fries" else Vector3(.026,.023,.034)
		var mesh=Hearth20GeneratedModels.make("potato_chip" if food=="chips" else "potato_fry" if food=="fries" else "food",dimensions,true)
		if mesh==null:mesh=table._bevel(dimensions,.006,mat)
		mesh.position=Vector3(i*.017,0,0);mesh.rotation=Vector3(.3*i,.8*i,.2);swallow_piece.add_child(mesh)
func _animate() -> void:
	if value.is_empty():return
	var pending=value.get("pending",{})
	for spec in [[food_model,food_at],[drink_model,drink_at]]:
		if is_instance_valid(spec[0]):spec[0].position=spec[1];spec[0].rotation=Vector3(0,-PI/2,0);spec[0].scale=Vector3.ONE
	if pending.is_empty():
		if is_instance_valid(swallow_piece):swallow_piece.queue_free();swallow_piece=null
		return
	var duration=maxf(.01,float(pending.ends_at)-float(pending.started_at));var t=clampf((now()-float(pending.started_at))/duration,0.,1.);var lift=smoothstep(0.,.19,t)*(1.-smoothstep(.82,1.,t))
	var node=drink_model if pending.action=="sip" else swallow_piece if is_instance_valid(swallow_piece) else food_model
	if not is_instance_valid(node):return
	if pending.action=="sip":
		_drink_pose(node,t)
		return
	var start=drink_at if pending.action=="sip" else food_at
	var mouth=serving.to_local(table.camera.to_global(Vector3(.11,-.19,-.32)))
	node.position=start.lerp(mouth,lift);node.rotation=Vector3(-.9*lift if pending.action=="sip" else .2*lift,-PI/2,.12*sin(t*TAU)*lift)
	if pending.action=="bite" and t>.25 and t<.82:
		node.position.y-=.25*smoothstep(.25,.4,t)
		if is_instance_valid(swallow_piece):node.scale=Vector3.ONE*(1.-smoothstep(.25,.40,t))
		elif int(value.get("food_bites",0))==1:node.scale=Vector3.ONE*(1.-smoothstep(.25,.4,t))
	if pending.action=="bite" and node==food_model and int(value.get("food_bites",0))==1 and t>=.4:node.scale=Vector3.ZERO
	if pending.action=="bite" and value.order.food=="chips" and is_instance_valid(food_model):
		var rustle=sin(clampf(t/.25,0.,1.)*PI);food_model.position.y+=rustle*.07;food_model.rotation.z=sin(t*75.)*.03*rustle
func _drink_pose(node: Node3D,t: float) -> void:
	var reach=smoothstep(0.,.24,t)*(1.-smoothstep(.78,1.,t))
	var tip=smoothstep(.24,.43,t)*(1.-smoothstep(.64,.80,t))
	var rest=Basis(Vector3.UP,-PI/2.)
	var camera_basis=serving.global_basis.inverse()*table.camera.global_basis
	# Tip the base AWAY from the face around the camera's right axis. The old
	# negative world-X rotation pushed the mug through the camera when looking right.
	var drinking=camera_basis*Basis(Vector3.RIGHT,1.15*tip)*rest
	var rotation_value=Quaternion(rest).slerp(Quaternion(drinking.orthonormalized()),reach)
	var lip: Vector3=node.get_meta("drink_lip",Vector3(0,.23,0))
	var mouth=serving.to_local(table.camera.to_global(Vector3(.08,-.15,-.28)))
	var start_lip=drink_at+rest*lip
	var path=start_lip.lerp(mouth,reach)
	path.y+=sin(reach*PI)*.035
	node.quaternion=rotation_value;node.position=path-node.basis*lip
func hit(screen: Vector2) -> bool:
	if menu.visible or session.is_spectating():return false
	var origin=table.camera.project_ray_origin(screen);var ray=table.camera.project_ray_normal(screen);var inverse=stool.global_transform.affine_inverse();var a=inverse*origin;var b=inverse*(origin+ray*8.)
	if menu_model.visible:
		var box=AABB(Vector3(-.23,1.0,-.23),Vector3(.46,.48,.46))
		if box.intersects_segment(a,b):menu.open();return true
	if not value.get("pending",{}).is_empty():return false
	for spec in [[food_model,"bite",food_at],[drink_model,"sip",drink_at]]:
		if not is_instance_valid(spec[0]):continue
		var box=AABB(spec[2]-Vector3(.16,0,.14),Vector3(.32,.34,.28))
		if box.intersects_segment(a,b):_request({"action":spec[1],"order_id":order_id});return true
	return false
func _event(event: Dictionary) -> void:
	var id=str(event.get("id",""))
	if seen.has(id):return
	seen[id]=true
	while seen.size()>128:seen.erase(seen.keys()[0])
	if event.get("player_id","")==session.local_player_id and event.kind=="order":menu.hide()
	if event.kind=="sip":_play("drink",.20)
	elif event.kind=="bite":
		if event.food=="chips":_play("bag",0.)
		_play(Hearth20RefreshmentCatalog.sound(event.food,int(event.get("number",0))),.58)
func _play(kind: String,delay: float) -> void:
	var player=AudioStreamPlayer.new();player.bus="Tavern & Party";player.stream=load(Hearth20RefreshmentCatalog.BASE+"audio/"+kind+".ogg");player.volume_db=-14.;add_child(player);player.finished.connect(player.queue_free)
	if delay<=0.:player.play()
	else:
		var tween=create_tween();tween.tween_interval(delay);tween.tween_callback(player.play)
func _wake_path() -> String:return "user://hearth20/refreshment-wakes/"+wake_profile.sha256_text()+".txt"
func _wake(stamp: float) -> void:
	wake_ack=stamp;DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://hearth20/refreshment-wakes"))
	var file=FileAccess.open(_wake_path(),FileAccess.WRITE)
	if file!=null:file.store_string(str(stamp));file.close()
	shell.leave_focus();shell.look=saved_look;shell.look_up=saved_look_up;shell.look_blend=Vector2(saved_look.x,saved_look.y+(.88 if saved_look_up else -.05));blackout_flash=1.;effect.show();spectate_requested=false
	if is_instance_valid(wake_player):wake_player.queue_free()
	wake_player=AudioStreamPlayer.new();wake_player.bus="Wake Voice";wake_player.name="FinallyAwake";wake_player.stream=load(Hearth20RefreshmentCatalog.BASE+"audio/wake.mp3");wake_player.volume_db=-8.;add_child(wake_player);wake_player.finished.connect(wake_player.queue_free);wake_player.play()
func glance() -> void:
	if shell.focus_state!="table":shell.leave_focus()
	var relative=stool.global_position+Vector3(0,1.13,0)-Vector3(0,1.96,2.45);shell.look_up=false;shell.look.x=atan2(relative.x,-relative.z)
	var gaze=smoothstep(.45,1.15,absf(shell.look.x))*1.265
	var target_y=1.96+relative.y*2.7/Vector2(relative.x,relative.z).length();shell.look.y=(target_y-.85-gaze)/3.1+.05
