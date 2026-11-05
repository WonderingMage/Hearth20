extends Control
class_name Hearth20DiceStage
## Receives only a fresh, host-authorized roll; history never triggers an animation.
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var pieces: Array=[]
var queue: Array=[]
var seen: Dictionary={}
var age:=0.0
var active_entry: Dictionary={}
var caption: Label
var result_label: Label
var session: Hearth20Session
var last_role:=""
var suspended:=false
var preparing:=false
var preparation_age:=0.0
func setup(owner_session: Hearth20Session) -> void:
	session=owner_session; last_role=session.local_role; mouse_filter=Control.MOUSE_FILTER_IGNORE; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var surface:=SubViewportContainer.new(); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); surface.stretch=true; surface.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(surface)
	viewport=SubViewport.new(); viewport.transparent_bg=true; viewport.own_world_3d=true; viewport.handle_input_locally=false; viewport.msaa_3d=Viewport.MSAA_4X; surface.add_child(viewport)
	world=Node3D.new(); viewport.add_child(world)
	camera=Camera3D.new(); camera.current=true; camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=9; camera.position=Vector3(0,12,13); world.add_child(camera); camera.look_at(Vector3.ZERO)
	var environment:=WorldEnvironment.new(); var env:=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=Color(0,0,0,0); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("#e3d9c8"); env.ambient_light_energy=.4; environment.environment=env; world.add_child(environment)
	for spec in [[Vector3(-45,-30,0),1.5,Color("#ffe4b2")],[Vector3(-15,140,0),.9,Color("#9fbbd2")]]:
		var light:=DirectionalLight3D.new(); light.rotation_degrees=spec[0]; light.light_energy=spec[1]; light.light_color=spec[2]; world.add_child(light)
	caption=Label.new(); caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; caption.add_theme_font_size_override("font_size",14); caption.add_theme_color_override("font_color",Color("#f3d995")); caption.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(caption)
	result_label=Label.new(); result_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; result_label.add_theme_font_override("font",Hearth20Design.font(true)); result_label.add_theme_font_size_override("font_size",25); result_label.add_theme_color_override("font_color",Color("#fff0c2")); result_label.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(result_label)
	session.dice_rolled.connect(enqueue); session.snapshot_received.connect(func(snapshot):
		if snapshot.get("connection_closed",false): clear_rolls())
	hide()
static func valid_entry(entry: Dictionary) -> bool:
	if entry.get("type","")!="roll" or not Hearth20Contracts.valid_identifier(entry.get("id")) or not entry.get("dice") is Array or entry.dice.is_empty() or entry.dice.size()>50: return false
	if not entry.get("formula") is String or entry.formula.length()>64 or not Hearth20DiceSets.valid(entry.get("dice_set","set-1")): return false
	if entry.get("mode","normal") not in ["normal","advantage","disadvantage"] or entry.get("visibility","public") not in ["public","self","gm","secret"]: return false
	for field in ["kept","modifier","total"]:
		if not Hearth20Contracts._integer_number(entry.get(field)): return false
	var pattern:=RegEx.new(); pattern.compile("^([0-9]{1,2})d([0-9]{1,4})([+-][0-9]{1,4})?$"); var parsed:=pattern.search(entry.formula)
	if parsed==null: return false
	var count:=int(parsed.get_string(1)); var sides:=int(parsed.get_string(2)); var bonus:=int(parsed.get_string(3)); var mode: String=entry.get("mode","normal"); var sum_value:=0
	if count<1 or count>50 or sides<2 or sides>1000 or absi(bonus)>1000 or bonus!=int(entry.modifier): return false
	if mode!="normal" and (count!=1 or sides!=20): return false
	if entry.dice.size()!=(count if mode=="normal" else 2): return false
	for value in entry.dice:
		if not Hearth20Contracts._integer_number(value) or int(value)<1 or int(value)>sides: return false
		sum_value+=int(value)
	var kept: int=sum_value if mode=="normal" else maxi(int(entry.dice[0]),int(entry.dice[1])) if mode=="advantage" else mini(int(entry.dice[0]),int(entry.dice[1]))
	return int(entry.kept)==kept and int(entry.total)==kept+bonus

func enqueue(entry: Dictionary) -> void:
	if suspended:return
	if not valid_entry(entry) or seen.has(entry.id): return
	seen[entry.id]=true
	while seen.size()>256: seen.erase(seen.keys()[0])
	queue.append(entry.duplicate(true))
	while queue.size()>12: queue.pop_front()
	if active_entry.is_empty(): _next()
func clear_rolls() -> void:
	queue.clear(); active_entry.clear(); seen.clear(); preparing=false
	for piece in pieces: piece.node.queue_free(); piece.shadow.queue_free()
	pieces.clear(); hide()
func _next() -> void:
	for piece in pieces: piece.node.queue_free(); piece.shadow.queue_free()
	pieces.clear()
	if queue.is_empty(): active_entry={}; hide(); return
	active_entry=queue.pop_front(); age=0; preparation_age=0; preparing=true; show()
	caption.text="Preparing "+Hearth20DiceSets.NAMES[str(active_entry.get("dice_set","set-1"))]+"…"; result_label.text=""
	Hearth20DiceSets.request(str(active_entry.get("dice_set","set-1")))
func _build() -> void:
	preparing=false; age=0
	var expression: String=active_entry.formula; var sides:=int(expression.get_slice("d",1).get_slice("+",0).get_slice("-",0)); var mode: String=active_entry.get("mode","normal")
	var rng:=RandomNumberGenerator.new(); rng.seed=hash(active_entry.id)
	var dice: Array=active_entry.dice; var specs: Array=[]
	for i in dice.size():
		var value:=int(dice[i]); var secondary:=mode!="normal" and value!=int(active_entry.get("kept",value))
		if sides==100: specs.append({"sides":10,"value":0 if value==100 else value/10*10,"secondary":secondary,"tens":true}); specs.append({"sides":10,"value":value%10,"secondary":secondary,"tens":false})
		else: specs.append({"sides":sides,"value":value,"secondary":secondary,"tens":false})
	var columns:=mini(10,specs.size()); var rows:=ceili(specs.size()/float(columns)); var spacing:=2.25 if specs.size()<9 else 1.5
	camera.size=maxf(7,maxf(rows*spacing+3,(columns*spacing+2)/maxf(.5,size.x/maxf(1,size.y))))
	for i in specs.size():
		var spec: Dictionary=specs[i]; var model:=Hearth20DiceSets.make(str(active_entry.get("dice_set","set-1")),spec.sides,spec.value,spec.secondary,spec.tens); world.add_child(model)
		var target:=Vector3((float(i%columns)-(columns-1)*.5)*spacing,0,(float(i/columns)-(rows-1)*.5)*spacing)
		# Calibration includes the printed glyph's up axis as well as its face normal.
		# Map both to the viewing camera so the settled result is upright and frontal.
		var local_basis: Basis=model.get_meta("result_basis"); var final_rotation:=Quaternion(camera.global_basis*local_basis.inverse())
		var shadow:=MeshInstance3D.new(); var disk:=PlaneMesh.new(); disk.size=Vector2(2.5,2.5); shadow.mesh=disk
		var shader:=Shader.new(); shader.code="shader_type spatial; render_mode unshaded,blend_mix,depth_draw_never; void fragment(){float r=length(UV-.5)*2.; ALBEDO=vec3(.015,.009,.005); ALPHA=pow(max(0.,1.-r),1.8)*.48;}"
		var material:=ShaderMaterial.new(); material.shader=shader; shadow.material_override=material; shadow.position=target; shadow.position.y=-1.05; world.add_child(shadow)
		pieces.append({"node":model,"shadow":shadow,"target":target,"initial":Vector3(target.x+rng.randf_range(-4,4),5+rng.randf()*4,target.z-5),"spin":Vector3(rng.randf_range(8,16),rng.randf_range(10,20),rng.randf_range(9,18)),"rotation":final_rotation,"delay":float(i)*.025})
	caption.text=str(active_entry.get("sender","Player"))+"  ·  "+str(active_entry.get("visibility","public")).to_upper()+"  ·  "+expression+ ("  ·  "+mode.to_upper() if mode!="normal" else "")
	if sides==100: caption.text+="  ·  percentile · tens then ones"
	result_label.text=""
func _process(delta: float) -> void:
	if viewport==null: return
	if session.local_role!=last_role: clear_rolls(); last_role=session.local_role
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	Hearth20DiceSets.poll()
	if active_entry.is_empty(): return
	caption.position=Vector2(0,size.y*.70); caption.size.x=size.x; result_label.position=Vector2(0,size.y*.75); result_label.size.x=size.x
	if preparing:
		preparation_age+=delta
		if Hearth20DiceSets.ready(str(active_entry.get("dice_set","set-1"))) or preparation_age>15: _build()
		return
	age+=delta
	caption.position=Vector2(0,size.y*.70); caption.size.x=size.x; result_label.position=Vector2(0,size.y*.75); result_label.size.x=size.x
	for piece in pieces:
		var time:=maxf(0,age-float(piece.delay)); var t:=clampf(time/2.25,0,1); var travel:=1.0-pow(1.0-t,3)
		var bounce:=absf(sin(t*PI*3.0))*pow(1.0-t,1.5)*3.8
		piece.node.position=piece.initial.lerp(piece.target,travel); piece.node.position.y=lerpf(float(piece.initial.y),0,travel)+bounce
		var rolling:=Quaternion.from_euler(piece.spin*time)
		piece.node.quaternion=rolling.slerp(piece.rotation,smoothstep(.50,1.0,t)); piece.shadow.scale=Vector3.ONE*(1.0+piece.node.position.y*.09)
	if age>2.4: result_label.text="%s   %s   %s"%[str(active_entry.kept),("+ "+str(active_entry.modifier)) if int(active_entry.get("modifier",0))>=0 else str(active_entry.modifier),"= "+str(active_entry.total)]
	if age>5.5+pieces.size()*.025: _next()
