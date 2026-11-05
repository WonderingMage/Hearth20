extends Node
class_name Hearth20CasinoGameView
## Three lean game presentations share the tavern, camera, book and local overlay.
var table: Hearth20CasinoTable
var world_root: Node3D
var overlay_root: Node3D
var dynamic_root: Node3D
var wheel: Node3D
var ball: MeshInstance3D
var wheel_tween: Tween
var kind=""
var game: Dictionary={}
var seat=-1
var dice: Dictionary={}
var racers: Array=[]
var packed: PackedScene
var preparing=false
var prepare_started=0
var warm=0
var normalize_pending=0
var last_round=-1
var last_stage=-1
var last_result=0
var visual_scores=[0,0,0,0,0]
var race_queue: Array=[]
var animating=false
var motion_left=0.
var error=""
var soul_batch: Hearth20SoulBatch
var soul_elapsed=0.
const MODEL="res://hearth20/casino/lizard.scn"
const RACER_COLORS=[Color("#b83c37"),Color("#4c9b61"),Color("#d6a144"),Color("#6669b6"),Color("#ddd1ae")]
func setup(owner_table: Hearth20CasinoTable) -> void:table=owner_table;set_process(false)
func clear() -> void:
	if soul_batch!=null:soul_batch.finish();soul_batch=null
	# Every threaded request must be collected, including a lobby changed before warm-up.
	if kind=="run_of_luck" and packed==null:
		var status=ResourceLoader.load_threaded_get_status(MODEL)
		if status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,ResourceLoader.THREAD_LOAD_LOADED]:ResourceLoader.load_threaded_get(MODEL)
	if wheel_tween!=null and wheel_tween.is_valid():wheel_tween.kill()
	if is_instance_valid(world_root):world_root.queue_free()
	if is_instance_valid(overlay_root):overlay_root.queue_free()
	dice.clear();racers.clear();race_queue.clear();packed=null;kind="";last_round=-1;last_stage=-1;last_result=0;preparing=false;animating=false;set_process(false);table.card_surface.material=null
func present(state: Dictionary, perspective: int) -> void:
	var next=str(state.get("game",""))
	if next not in Hearth20CasinoGames.TYPES:
		if not kind.is_empty():clear();table.game_loading_changed.emit(false)
		return
	var changed=next!=kind
	if changed:
		clear();kind=next;world_root=Node3D.new();table.world.add_child(world_root);overlay_root=Node3D.new();table.presentation_content.add_child(overlay_root);dynamic_root=Node3D.new();world_root.add_child(dynamic_root)
		preparing=true;prepare_started=Time.get_ticks_msec();warm=0;table.game_loading_changed.emit(true);set_process(true)
		if kind=="run_of_luck":
			ResourceLoader.load_threaded_request(MODEL,"PackedScene");_race_board()
		elif kind=="tymoras_spinner":_wheel_board()
		else:table.card_surface.material=Hearth20FxPost.material()
	game=state;seat=perspective
	if kind=="gambit_of_ord":_ord()
	elif kind=="tymoras_spinner":_spinner()
	elif not preparing:_race()
func release_pending() -> void:
	clear()
func _color(color: Color, metal=.0, rough=.8) -> StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=rough;return m
func _velvet(red: bool) -> ShaderMaterial:
	var shader=Shader.new();shader.code="""shader_type spatial;render_mode cull_disabled;varying vec3 p;uniform vec3 velvet:source_color;void vertex(){p=VERTEX;}void fragment(){float nap=fract(sin(dot(floor(p.xz*2300.),vec2(12.9898,78.233)))*43758.5453);ALBEDO=velvet*(.90+nap*.08);ROUGHNESS=.97;SPECULAR=.12;METALLIC=0.;}""";var m=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("velvet",Color("#8a1428") if red else Color("#111019"));return m
func _word(text: String, at: Vector3, height=.055, color=Color("#ecd29b"), billboard=true, parent: Node3D=null) -> Node3D:
	var label=Label3D.new();label.text=text;label.font=Hearth20Design.font(true);label.font_size=64;label.pixel_size=height/64.;label.modulate=color;label.outline_size=3;label.outline_modulate=Color("#211509");label.position=at
	if billboard:label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	else:label.rotation.x=-PI/2
	(parent if parent!=null else world_root).add_child(label);return label
func _clear_dynamic() -> void:
	for child in dynamic_root.get_children():child.queue_free()
func _die(key: String, sides: int, value: int, at: Vector3, size_value: float, style: String, roll: bool) -> void:
	var actor=dice.get(key)
	if actor!=null and (actor.value!=value or actor.sides!=sides):actor.queue_free();dice.erase(key);actor=null
	if actor==null:
		actor=Hearth20CasinoDie.new();overlay_root.add_child(actor);actor.target_scale=size_value;actor.setup(sides,value,style);actor.place(at,table.card_camera,roll);dice[key]=actor
		if style=="soul":actor.attach_scene_buffers(table.viewport.get_texture(),table.soul_viewport.get_texture(),table.soul_world)
	else:
		actor.resting=at
		if roll:actor.place(at,table.card_camera,true)
func _retain_dice(wanted: Array) -> void:
	for key in dice.keys():
		if key not in wanted:dice[key].queue_free();dice.erase(key)
func _ord() -> void:
	_clear_dynamic();var count=maxi(1,game.seats.size());var wanted=[];var fresh=last_round>=0 and (last_round!=game.round or last_stage!=game.stage)
	for j in game.seats.size():
		var s=game.seats[j];var angle=float(j-maxi(0,seat))*TAU/count;var own=j==seat;var open=s.has("dice") and (own or (game.revealed and not s.folded))
		if open:
			for k in s.dice.size():
				var key="ord:"+str(j)+":"+str(k);wanted.append(key);var offset=(float(k)-(s.dice.size()-1)*.5)
				var at=Vector3(offset*.56,1.08,1.13) if own else Vector3(offset*.28,.99,.80).rotated(Vector3.UP,angle)
				_die(key,[8,6,4][k],int(s.dice[k]),at,.23 if own else .12,"soul",fresh and k==s.dice.size()-1)
		else:
			for k in int(s.dice_count):
				var at=Vector3((k-(int(s.dice_count)-1)*.5)*.19,.85,.80).rotated(Vector3.UP,angle)
				table._lathe(dynamic_root,at,[[0.,0],[.085,0],[.085,.015],[.065,.025],[.075,.14],[.055,.18],[0.,.18]],1,1,_color(Color("#151219"),.25,.4),24)
				table._lathe(dynamic_root,at,[[.085,.012],[.085,.023],[.075,.023],[.075,.012]],1,1,table.bronze,24)
		if not own:_word(s.name+"\n"+("Folded" if s.folded else str(s.dice_count)+(" hidden die" if int(s.dice_count)==1 else " hidden dice") if not open else str(Hearth20CasinoGamesUI._sum(s.get("dice",[])))),Vector3(sin(angle)*1.12,1.15,cos(angle)*.80-.12),.062,Color("#e2c58c"),true,dynamic_root)
	_retain_dice(wanted);_chip_pot()
	if fresh:animating=true;motion_left=Hearth20SoulReveal.ROLL_SECONDS+Hearth20SoulReveal.DURATION
	last_round=game.round;last_stage=game.stage
func _chip_pot() -> void:
	var stacks=mini(7,maxi(0,ceili(float(game.pot)/10.)))
	for i in stacks:
		for k in mini(5,maxi(1,int(game.pot)/maxi(1,stacks))):
			table._lathe(dynamic_root,Vector3((i%3-1)*.115,.852+k*.015,-.12+(i/3)*.12),[[0.,0],[.047,0],[.047,.012],[0.,.012]],1,1,table.bronze,20)
func _race_board() -> void:
	var base=table._bevel(Vector3(2.62,.045,1.26),.035,table.wood);base.position=Vector3(0,.861,-.38);world_root.add_child(base)
	var gold=table.bronze
	for i in 6:
		var rail=table._bevel(Vector3(2.51,.012,.009),.003,gold);rail.position=Vector3(0,.89,-.98+i*.24);world_root.add_child(rail)
	for i in range(13):
		var x=-1.12+float(i)/12.*2.24;var line=table._bevel(Vector3(.005,.006,1.19),.001,gold);line.position=Vector3(x,.889,-.38);world_root.add_child(line)
		if i%2==0:_word(str(i),Vector3(x,.90,.27),.036,Color("#c9ac6a"),false)
	for i in 5:_word(str(i+1),Vector3(-1.23,.92,-.86+i*.24),.05,RACER_COLORS[i],false)
	_word("QUON A DRENSAL · THREE STAGES",Vector3(0,1.02,-1.07),.065)
func _build_lizards() -> void:
	for i in 5:
		var racer=Hearth20CasinoLizard.new();world_root.add_child(racer);racer.setup(packed);racers.append(racer)
	normalize_pending=2
func _race_position(i: int, score: float) -> Vector3:return Vector3(-1.12+score/12.*2.24,.894,-.86+i*.24)
func _race() -> void:
	if racers.size()!=5:return
	if last_round!=game.round:
		race_queue.clear();motion_left=0.;animating=false;visual_scores=game.positions.duplicate()
		for i in 5:racers[i].snap_to(_race_position(i,float(visual_scores[i])))
		last_stage=game.stage;last_round=game.round
	elif game.stage>last_stage:
		for stage in range(last_stage,int(game.stage)):race_queue.append(game.race_rolls[stage].duplicate())
		last_stage=game.stage
	if not animating and not race_queue.is_empty():_race_motion()
	_clear_dynamic()
	for i in 5:
		_word(Hearth20CasinoGamesUI.RACERS[i]+" · "+str(game.positions[i]),Vector3(1.31,1.02,-.86+i*.24),.045,RACER_COLORS[i],true,dynamic_root)
	if game.phase=="between":
		var best=0
		for score in game.positions:best=maxi(best,int(score))
		for i in 5:
			if game.positions[i]==best:_word("✧",_race_position(i,float(best))+Vector3(0,.25,0),.12,Color("#ffe596"),true,dynamic_root)
func _race_motion() -> void:
	var moves=race_queue.pop_front();var wanted=[];var maximum=1
	for i in 5:
		visual_scores[i]+=int(moves[i]);maximum=maxi(maximum,int(moves[i]));racers[i].walk_paces(int(moves[i]),_race_position(i,float(visual_scores[i])),.75)
		var key="race:"+str(i);wanted.append(key);_die(key,4,int(moves[i]),Vector3((i-2)*.32,1.10,1.15),.135,"green",true)
	_retain_dice(wanted);animating=true;motion_left=.80+maximum*.40
func _wheel_board() -> void:
	wheel=Node3D.new();wheel.position=Vector3(0,.88,-.13);world_root.add_child(wheel)
	table._lathe(world_root,Vector3(0,.85,-.13),[[0.,0],[.83,0],[.87,.035],[.87,.07],[.82,.10],[.75,.11],[.75,.07]],1,1,table.bronze,96)
	for red in [true,false]:
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for n in range(1,21):
			if (n in Hearth20CasinoGames.RED)!=red:continue
			var angle=float(n-1)*TAU/20.
			for k in 6:
				var a=angle-PI/20.+.014+float(k)*(TAU/20.-.028)/6.;var b=angle-PI/20.+.014+float(k+1)*(TAU/20.-.028)/6.
				for p in [Vector2(.27,a),Vector2(.73,a),Vector2(.73,b),Vector2(.27,a),Vector2(.73,b),Vector2(.27,b)]:st.set_uv(Vector2(p.x,p.y));st.add_vertex(Vector3(sin(p.y)*p.x,.065,cos(p.y)*p.x))
		st.generate_normals();var sector=MeshInstance3D.new();sector.mesh=st.commit();sector.material_override=_velvet(red);wheel.add_child(sector)
	for n in range(1,21):
		var a=float(n-1)*TAU/20.;var rib=table._bevel(Vector3(.012,.022,.49),.003,table.bronze);rib.position=Vector3(sin(a-PI/20.)*.50,.075,cos(a-PI/20.)*.50);rib.rotation.y=a-PI/20.;wheel.add_child(rib)
		var label=_word(str(n),Vector3(sin(a)*.57,.079,cos(a)*.57),.059,Color("#eee0bd"),false,wheel);label.rotation.y=a
	table._lathe(wheel,Vector3.ZERO,[[0.,.03],[.25,.03],[.25,.065],[.12,.11],[.07,.19],[.10,.22],[.025,.26],[0.,.30]],1,1,table.bronze,48)
	var pointer=table._bevel(Vector3(.045,.04,.11),.014,table.bronze);pointer.position=Vector3(0,.99,.65);world_root.add_child(pointer)
	ball=MeshInstance3D.new();var pearl=SphereMesh.new();pearl.radius=.023;pearl.height=.046;pearl.radial_segments=16;pearl.rings=8;ball.mesh=pearl;ball.material_override=_color(Color("#f3e8c8"),.23,.14);ball.position=Vector3(0,.97,.60);world_root.add_child(ball)
	var felt=table._bevel(Vector3(1.08,.012,.59),.018,_velvet(false));felt.position=Vector3(0,.86,1.07);world_root.add_child(felt)
	for n in range(1,21):
		var cell=table._bevel(Vector3(.185,.008,.095),.008,_velvet(n in Hearth20CasinoGames.RED));cell.position=_bet_cell(n);world_root.add_child(cell);_word(str(n),cell.position+Vector3(0,.006,0),.042,Color("#ead5a1"),false)
func _bet_cell(number: int) -> Vector3:return Vector3(((number-1)%5-2)*.207,.873,.855+((number-1)/5)*.137)
func _spinner() -> void:
	_clear_dynamic()
	for i in game.seats.size():
		for bet in game.seats[i].bets:
			if bet.kind=="number":
				var at=_bet_cell(int(bet.number))+Vector3(.035*float(i%2),.012+.012*i,0);var chip=table._bevel(Vector3(.055,.012,.055),.022,_color(RACER_COLORS[i%5],.4,.35));chip.position=at;dynamic_root.add_child(chip)
	if wheel==null:return
	if game.round!=last_round:
		last_result=0;last_round=game.round
	if game.result>0 and game.result!=last_result:
		var first=last_result==0 and last_stage>=0;last_result=game.result
		var target=ceilf(wheel.rotation.y/TAU)*TAU+TAU*4.-float(int(game.result)-1)*TAU/20.
		if first:
			animating=true;motion_left=3.1
			if wheel_tween!=null and wheel_tween.is_valid():wheel_tween.kill()
			wheel_tween=create_tween();wheel_tween.tween_property(wheel,"rotation:y",target,3.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		else:wheel.rotation.y=target
	last_stage=game.stage
func pointer(origin: Vector3, direction: Vector3, click: bool) -> bool:
	var hit=false
	for actor in dice.values():
		var along=direction.dot(actor.global_position-origin);actor.hovered=along>0 and (origin+direction*along).distance_to(actor.global_position)<actor.target_scale*.9
		if actor.hovered:hit=true
	if hit:return true
	if not click or game.get("phase","")!="betting":return false
	var point=Plane(Vector3.UP,.88).intersects_ray(origin,direction)
	if point==null:return false
	if kind=="tymoras_spinner":
		for n in range(1,21):
			var delta=point-_bet_cell(n)
			if absf(delta.x)<.1 and absf(delta.z)<.066:table.wager_picked.emit({"kind":"number","number":n});return true
	elif kind=="run_of_luck" and absf(point.x)<1.25:
		for i in 5:
			if absf(point.z-(-.86+i*.24))<.11:table.wager_picked.emit({"kind":"racer","number":i});return true
	return false
func _process(delta: float) -> void:
	if preparing:
		if kind=="run_of_luck" and packed==null:
			var status=ResourceLoader.load_threaded_get_status(MODEL)
			if status==ResourceLoader.THREAD_LOAD_LOADED:packed=ResourceLoader.load_threaded_get(MODEL);_build_lizards()
			elif status==ResourceLoader.THREAD_LOAD_FAILED:error="The lizard model could not load."
			return
		if normalize_pending>0:
			normalize_pending-=1
			if normalize_pending==0:
				for racer in racers:racer.normalize_model(.27);racer.rotation.y-=PI/2
				_race()
			return
		warm+=1
		if warm>=12 and Time.get_ticks_msec()-prepare_started>450:preparing=false;if_ready()
	if animating:
		motion_left-=delta
		if kind=="tymoras_spinner" and ball!=null:
			var t=clampf(1.-motion_left/3.1,0,1);var angle=(1.-pow(t,.42))*TAU*6.;var radius=lerpf(.765,.60,smoothstep(.65,1.,t));ball.position=Vector3(sin(angle)*radius,.97+absf(sin(t*PI*12.))*pow(1.-t,2.)*.06,cos(angle)*radius-.13)
		if motion_left<=0:
			animating=false
			if kind=="run_of_luck" and not race_queue.is_empty():_race_motion()
			else:table.game_motion_finished.emit()
	for actor in dice.values():
		actor.render_active=table.casino_active and table.is_visible_in_tree() and table.card_surface.visible and not table.book.opened and Hearth20RenderVisibility.sphere(table.card_camera,actor.global_position,.60)
		var basis: Basis=actor.body.get_meta("result_basis");actor.final_rotation=Quaternion(table.card_camera.global_basis*basis.inverse())
		if not actor.rolling:actor.body.quaternion=actor.final_rotation
	_update_spirits(delta)
func _update_spirits(delta: float) -> void:
	if soul_batch!=null and soul_batch.ready():
		soul_batch.finish()
		for i in soul_batch.jobs.size():
			var actor=soul_batch.jobs[i].actor.get_ref()
			if is_instance_valid(actor) and actor.render_active:actor.apply_soul_frame(soul_batch.frames[i],soul_batch.jobs[i].age)
		soul_batch=null
	var active=dice.values().filter(func(actor):return actor.theme=="soul" and actor.render_active)
	for actor in dice.values():actor.threaded_motion=active.size()>=2 and actor in active
	soul_elapsed+=delta
	if active.size()<2 or soul_elapsed<1./30. or soul_batch!=null:return
	soul_elapsed=0.;var jobs=[]
	for actor in active:jobs.append({"motion":actor.soul_motion,"age":actor.age,"reveal":actor.reveal_elapsed,"actor":weakref(actor)})
	soul_batch=Hearth20SoulBatch.new();soul_batch.start(jobs)
func if_ready() -> void:
	if kind=="run_of_luck":_race()
	table.game_loading_changed.emit(false)
func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and soul_batch!=null:soul_batch.finish();soul_batch=null
	if what==NOTIFICATION_PREDELETE and wheel_tween!=null and wheel_tween.is_valid():wheel_tween.kill()
