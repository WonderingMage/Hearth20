extends SubViewportContainer
class_name Hearth20CasinoTable
## Self-contained first-person scene. No map nodes or map assets live in this viewport.
signal card_selected(id: String)
signal card_hovered(id: String)
signal peek_changed(peeking: bool)
signal book_opened_changed(opened: bool)
signal game_loading_changed(loading: bool)
signal game_motion_finished
signal wager_picked(wager: Dictionary)
var camera_override=false
var casino_active=true
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var card_surface: SubViewportContainer
var card_viewport: SubViewport
var card_camera: Camera3D
var soul_viewport: SubViewport
var soul_world: Node3D
var soul_camera: Camera3D
var presentation_world: Node3D
var presentation_content: Node3D
var card_root: Node3D
var candles: Array=[]
var pieces: Dictionary={}
var hand_hits: Array=[]
var public_hits: Array=[]
var materials: Texture2D
var art: Texture2D
var salon: Texture2D
var elapsed=0.0
var looking=false
var look_offset=Vector2.ZERO
var lean=0.0
var selected=""
var hovered=""
var current: Dictionary={}
var seat=0
var quality=0.72
var peeking=false
var peek_blend=0.0
var book_blend=0.0
var book: Hearth20CasinoBook
var peek_before_book=false
var hand_shift=Vector3.ZERO
var bronze: Material
var wood: Material
var felt: Material
var card_style: Hearth20CasinoCard
var game_view: Hearth20CasinoGameView
var center_props: Node3D
var stock_deck: Node3D
var room: Hearth20TavernRoom
func setup(textures: Dictionary) -> void:
	stretch=true;mouse_filter=Control.MOUSE_FILTER_STOP;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	materials=textures.materials;art=textures.art;salon=textures.salon
	card_style=Hearth20CasinoCard.new();card_style.setup(art,materials)
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.transparent_bg=false;viewport.msaa_3d=Viewport.MSAA_2X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	world=Node3D.new();viewport.add_child(world);card_root=Node3D.new();world.add_child(card_root)
	camera=Camera3D.new();camera.current=true;camera.fov=64;camera.near=.04;world.add_child(camera);_camera()
	var env_node=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("#100c09");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#b69b75");env.ambient_light_energy=.28;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env_node.environment=env;world.add_child(env_node)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-58,-24,0);key.light_color=Color("#ffd298");key.light_energy=.75;key.shadow_enabled=true;key.directional_shadow_max_distance=15;world.add_child(key)
	bronze=_surface(2,.72,.38);wood=_surface(0,.04,.83);felt=_surface(1,0,.97)
	room=Hearth20TavernRoom.new();world.add_child(room);room.setup(self)
	var crafted_table=Hearth20GeneratedModels.make("table",Vector3(4.84,.84,3.06))
	if crafted_table!=null:world.add_child(crafted_table)
	else:
		_lathe(world,Vector3.ZERO,[[.0,.65],[1.0,.65],[1.0,.75],[.98,.8],[.94,.83],[0.,.83]],2.42,1.53,wood,64)
		_lathe(world,Vector3.ZERO,[[1.,.838],[.0,.838]],2.17,1.29,felt,64)
		for band in [[2.38,1.49,.77],[2.20,1.32,.835]]:_ring(Vector3(0,band[2],0),band[0],band[1],.012,bronze)
	for x in [-1.87,1.87]:_candle(Vector3(x,.84,-.1))
	_goblet(Vector3(-1.65,.84,.78));_pouch(Vector3(1.7,.84,.62))
	book=Hearth20CasinoBook.new();world.add_child(book);book.setup(self,textures);book.opened_changed.connect(_book_state)
	center_props=Node3D.new();world.add_child(center_props);stock_deck=Node3D.new();world.add_child(stock_deck)
	# Raised, individually turned brass coins and grooved stacks.
	for i in 12:
		var angle=i*2.399;var radius=.08*sqrt(float(i));var at=Vector3(sin(angle)*radius,.85+.011*(i%5),cos(angle)*radius-.1)
		_coin(at,.052,center_props)
	for i in 8:
		var deck=_bevel(Vector3(.47,.012,.71),.013,_card_material("",true));deck.position=Vector3(-.74,.86+i*.012,-.15);deck.rotation.y=-.15;stock_deck.add_child(deck)
	_card_layer();game_view=Hearth20CasinoGameView.new();add_child(game_view);game_view.setup(self);_dust();material=_post();gui_input.connect(_input_table);mouse_exited.connect(func():hovered="";card_hovered.emit(""));resized.connect(_resolution);_resolution()
func _card_layer() -> void:
	# The presentation world has no table, props or environment depth buffer.
	card_surface=SubViewportContainer.new();card_surface.name="CameraCardLayer";card_surface.stretch=true;card_surface.z_index=5;card_surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;card_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(card_surface)
	card_viewport=SubViewport.new();card_viewport.own_world_3d=true;card_viewport.transparent_bg=true;card_viewport.handle_input_locally=false;card_viewport.msaa_3d=Viewport.MSAA_4X;card_surface.add_child(card_viewport)
	presentation_world=Node3D.new();card_viewport.add_child(presentation_world);presentation_content=Node3D.new();presentation_world.add_child(presentation_content);card_root.reparent(presentation_content,false)
	stock_deck.reparent(presentation_content,false)
	card_camera=Camera3D.new();card_camera.current=true;card_camera.near=.015;card_camera.far=64;presentation_world.add_child(card_camera)
	var environment=WorldEnvironment.new();var settings=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(0,0,0,0);settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("#b69b75");settings.ambient_light_energy=.28;settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=settings;presentation_world.add_child(environment)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-58,-24,0);key.light_color=Color("#ffd298");key.light_energy=.75;presentation_world.add_child(key);_camera()
	var sky_material=ProceduralSkyMaterial.new();sky_material.sky_top_color=Color("#5a667e");sky_material.sky_horizon_color=Color("#f1d3a3");sky_material.ground_bottom_color=Color("#211a16");sky_material.ground_horizon_color=Color("#a76f38");sky_material.sky_energy_multiplier=.7
	var reflections=Sky.new();reflections.sky_material=sky_material;reflections.radiance_size=Sky.RADIANCE_SIZE_128;settings.sky=reflections;settings.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var soul_holder=Node.new();soul_holder.name="UndisplayedSoulBuffer";add_child(soul_holder)
	soul_viewport=SubViewport.new();soul_viewport.name="SoulTransmissionBuffer";soul_viewport.own_world_3d=true;soul_viewport.transparent_bg=true;soul_viewport.handle_input_locally=false;soul_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;soul_holder.add_child(soul_viewport)
	soul_world=Node3D.new();soul_viewport.add_child(soul_world);soul_camera=Camera3D.new();soul_camera.near=.015;soul_camera.far=64;soul_camera.current=true;soul_world.add_child(soul_camera)
	var soul_environment=WorldEnvironment.new();soul_environment.environment=settings.duplicate(true);soul_world.add_child(soul_environment);soul_world.add_child(key.duplicate())
func _resolution() -> void:
	if viewport!=null:stretch_shrink=maxi(1,ceili(maxf(size.x/1920.,size.y/1080.)))
	if card_surface!=null:card_surface.stretch_shrink=stretch_shrink
func _surface(tile: int, metallic: float, rough: float) -> ShaderMaterial:
	var shader=Shader.new();shader.code="""shader_type spatial;render_mode cull_disabled;uniform sampler2D atlas:source_color,filter_linear_mipmap;uniform vec2 tile;uniform float metal=0.;uniform float rough=.8;void fragment(){vec2 p=fract(UV*vec2(2.,2.));vec3 color=texture(atlas,tile+p*.498).rgb;ALBEDO=color;METALLIC=metal;ROUGHNESS=rough;}"""
	var mat=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("atlas",materials);mat.set_shader_parameter("tile",Vector2(tile%2,tile/2)*.5);mat.set_shader_parameter("metal",metallic);mat.set_shader_parameter("rough",rough);return mat
func _card_material(id: String, back: bool=false) -> ShaderMaterial:
	return card_style.face(id,back)
func _lathe(parent: Node3D, at: Vector3, profile: Array, rx: float, rz: float, mat: Material, segments: int=32) -> MeshInstance3D:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size()-1):
		for j in segments:
			for spec in [[row,j],[row+1,j],[row+1,j+1],[row,j],[row+1,j+1],[row,j+1]]:
				var p=profile[spec[0]];var a=float(spec[1])*TAU/segments;st.set_uv(Vector2(float(spec[1])/segments,float(spec[0])/maxi(1,profile.size()-1)));st.add_vertex(Vector3(cos(a)*float(p[0])*rx,float(p[1]),sin(a)*float(p[0])*rz))
	st.generate_normals();var node=MeshInstance3D.new();node.mesh=st.commit();node.material_override=mat;node.position=at;parent.add_child(node);return node
func _ring(at: Vector3, rx: float, rz: float, width: float, mat: Material) -> void:
	_lathe(world,at,[[.99,-width],[1.,-width],[1.,width],[.99,width]],rx,rz,mat,64)
func _bevel(dim: Vector3, bevel: float, mat: Material) -> MeshInstance3D:
	# An eight-sided chamfered slab, with explicit side faces and UVs.
	var x=dim.x*.5;var z=dim.z*.5;var y=dim.y*.5;var b=minf(bevel,minf(x,z)*.6)
	var points=[Vector2(-x+b,-z),Vector2(x-b,-z),Vector2(x,-z+b),Vector2(x,z-b),Vector2(x-b,z),Vector2(-x+b,z),Vector2(-x,z-b),Vector2(-x,-z+b)]
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 8:
		var p=points[j];var q=points[(j+1)%8]
		for v in [Vector3(0,y,0),Vector3(q.x,y,q.y),Vector3(p.x,y,p.y),Vector3(0,-y,0),Vector3(p.x,-y,p.y),Vector3(q.x,-y,q.y),Vector3(p.x,-y,p.y),Vector3(p.x,y,p.y),Vector3(q.x,y,q.y),Vector3(p.x,-y,p.y),Vector3(q.x,y,q.y),Vector3(q.x,-y,q.y)]:
			st.set_uv(Vector2(v.x/dim.x+.5,v.z/dim.z+.5));st.add_vertex(v)
	st.generate_normals();var node=MeshInstance3D.new();node.mesh=st.commit();node.material_override=mat;return node
func _coin(at: Vector3, radius: float, parent: Node3D=null) -> void:
	var owner_node=parent if parent!=null else world
	var crafted=Hearth20GeneratedModels.make("dragon_coin",Vector3(radius*2,.014,radius*2))
	if crafted!=null:crafted.position=at;owner_node.add_child(crafted);return
	_lathe(owner_node,at,[[0.,0],[radius,0],[radius,.009],[radius*.94,.014],[0.,.014]],1,1,bronze,16)
	var text=_letters("✧",.07,.001,Color("#d7b45c"));text.position=at+Vector3(0,.016,0);text.rotation.x=-PI/2;owner_node.add_child(text)
func _letters(text: String, height: float, depth: float, color: Color) -> MeshInstance3D:
	var mesh=TextMesh.new();mesh.font=Hearth20Design.font(true);mesh.font_size=40;mesh.pixel_size=height/40.;mesh.depth=depth;mesh.text=text
	var node=MeshInstance3D.new();node.mesh=mesh;var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.64;mat.metallic=.24;node.material_override=mat;return node
func _candle(at: Vector3) -> void:
	var crafted=Hearth20GeneratedModels.make("candle",Vector3(.22,.53,.22))
	if crafted!=null:crafted.position=at;world.add_child(crafted)
	else:
		_lathe(world,at,[[0.,0],[.16,0],[.17,.025],[.11,.05],[.055,.10],[.035,.22],[.065,.26],[.10,.28],[.10,.3],[0.,.3]],1,1,bronze,24)
		var wax=StandardMaterial3D.new();wax.albedo_color=Color("#ccaf7b");wax.roughness=.94
		_lathe(world,at,[[.055,.3],[.06,.32],[.052,.5],[.048,.53],[.04,.52],[0.,.52]],1,1,wax,16)
	var flame=MeshInstance3D.new();var mesh=QuadMesh.new();mesh.size=Vector2(.10,.20);flame.mesh=mesh;flame.position=at+Vector3(0,.62,0)
	var shader=Shader.new();shader.code="""shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;void vertex(){VERTEX.x+=sin(TIME*9.+UV.y*7.)*.01*UV.y;}void fragment(){vec2 p=(UV-.5)*vec2(2.,1.3);float a=pow(max(0.,1.-length(p*vec2(1.+UV.y,1.))),2.);ALBEDO=mix(vec3(1.,.20,.01),vec3(1.,.9,.50),a);EMISSION=ALBEDO*2.;ALPHA=a;}"""
	var mat=ShaderMaterial.new();mat.shader=shader;flame.material_override=mat;flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(flame)
	var light=OmniLight3D.new();light.position=at+Vector3(0,.65,0);light.light_color=Color("#ffc277");light.light_energy=2.;light.omni_range=4.5;light.shadow_enabled=true;world.add_child(light);candles.append(light)
func _goblet(at: Vector3) -> void:
	var crafted=Hearth20GeneratedModels.make("goblet",Vector3(.32,.40,.32))
	if crafted!=null:crafted.position=at;world.add_child(crafted);return
	_lathe(world,at,[[0.,0],[.15,.0],[.15,.025],[.055,.05],[.025,.17],[.035,.23],[.13,.27],[.18,.4],[.18,.43],[.16,.43],[.15,.4],[.12,.3],[0.,.28]],1,1,bronze,24)
	var wine=StandardMaterial3D.new();wine.albedo_color=Color("#270b12");wine.roughness=.12;wine.metallic=.3;_lathe(world,at,[[.155,.38],[0.,.38]],1,1,wine,24)
func _pouch(at: Vector3) -> void:
	var crafted=Hearth20GeneratedModels.make("purse_bag",Vector3(.35,.31,.30))
	if crafted!=null:crafted.position=at;world.add_child(crafted);return
	var leather=StandardMaterial3D.new();leather.albedo_color=Color("#33251b");leather.roughness=.92;_lathe(world,at,[[0.,0],[.17,0],[.20,.06],[.19,.19],[.11,.25],[.07,.28],[.09,.31],[.04,.31]],1,1,leather,18)
func _dust() -> void:
	var node=GPUParticles3D.new();node.amount=64;node.lifetime=12;node.position=Vector3(0,2,-3.5);node.visibility_aabb=AABB(Vector3(-5,-2,-5),Vector3(10,5,10))
	var p=ParticleProcessMaterial.new();p.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;p.emission_box_extents=Vector3(4,1.5,1.5);p.gravity=Vector3(0,-.02,0);p.initial_velocity_min=.015;p.initial_velocity_max=.045;p.scale_min=.006;p.scale_max=.018;node.process_material=p
	var quad=QuadMesh.new();quad.size=Vector2.ONE;var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(.7,.5,.25,.18);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	var gradient=Gradient.new();gradient.colors=PackedColorArray([Color(1,1,1,.4),Color(1,1,1,0)]);var texture=GradientTexture2D.new();texture.gradient=gradient;texture.width=32;texture.height=32;texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(.0,.0);mat.albedo_texture=texture;quad.material=mat;node.draw_pass_1=quad;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;world.add_child(node)
func _post() -> ShaderMaterial:
	var shader=Shader.new();shader.code="""shader_type canvas_item;uniform float grain_strength=.035;void fragment(){vec2 dimensions=vec2(textureSize(TEXTURE,0));vec2 uv=(floor(UV*dimensions)+.5)/dimensions;vec3 c=texture(TEXTURE,uv).rgb;float n=fract(sin(dot(floor(UV*dimensions)+floor(TIME*17.),vec2(12.9898,78.233)))*43758.5453);float vignette=1.-.34*pow(length(UV-.5)*1.4,1.8);c=floor((c+(n-.5)*grain_strength)*40.)/40.;COLOR=vec4(c*vignette,1.);}"""
	var mat=ShaderMaterial.new();mat.shader=shader;return mat
func present(game: Dictionary, seat_index: int, chosen: String="") -> void:
	current=game;seat=seat_index;selected=chosen;hand_hits.clear();public_hits.clear();var wanted={};var seats=game.get("seats",[]);var count=maxi(2,seats.size())
	game_view.present(game,seat_index)
	center_props.visible=game.get("game","")=="three_dragon_ante";stock_deck.visible=center_props.visible and game.get("phase","") in ["ante","play","between"]
	book.closed_position=Vector3(-1.55,.85,.85) if game.get("game","") in Hearth20CasinoGames.TYPES else Vector3(-1.39,.85,.70)
	if not book.opened and not book.busy:book.position=book.closed_position
	for j in seats.size():
		var angle=float(j-maxi(0,seat))*TAU/count;var s=seats[j];var own=j==seat;var hand=s.get("hand",[]) if own else []
		for k in int(s.get("hand_count",0)):
			var id=str(hand[k]) if k<hand.size() else "";var key="hand:"+str(j)+":"+(id if own else str(k));var fraction=(float(k)-(int(s.hand_count)-1)*.5);var spacing=minf(.28,1.4/maxi(1,int(s.hand_count)-1))
			var local=Vector3(fraction*spacing,1.02+fraction*.015,1.12+fraction*.035);var at=local.rotated(Vector3.UP,angle);var rot=Vector3(1.05,angle,-fraction*.020 if own else 0)
			var node=_piece(key,id,not own,at,rot,wanted)
			if own and not id.is_empty():hand_hits.append({"id":id,"node":node,"base_y":at.y,"base_z":at.z,"base_x":at.x})
		for k in s.flight.size():
			var id=str(s.flight[k]);var key="flight:"+id;var at=Vector3((k-(s.flight.size()-1)*.5)*.29,.865+j*.016+k*.005,.80).rotated(Vector3.UP,angle);var played=_piece(key,id,false,at,Vector3(0,angle,0),wanted,"hand:"+str(j)+":");played.scale=Vector3.ONE*.72;public_hits.append({"id":id,"node":played})
		if game.get("phase","")=="ante" and s.get("ante_chosen",false):
			var back_node=_piece("pending-ante:"+str(j),"",true,Vector3(sin(angle)*.25,.87+j*.008,cos(angle)*.25),Vector3(0,angle,0),wanted,"hand:"+str(j)+":");back_node.get_meta("aura").visible=true
	for k in game.get("ante",[]).size():
		var id=str(game.ante[k]);var shown=_piece("ante:"+id,id,false,Vector3((k-(game.ante.size()-1)*.5)*.28,.86+k*.008,-.05),Vector3(0,.10*k,0),wanted);shown.scale=Vector3.ONE*.72;public_hits.append({"id":id,"node":shown})
	for key in pieces.keys():
		if not wanted.has(key):pieces[key].queue_free();pieces.erase(key)
func _piece(key: String, id: String, back: bool, at: Vector3, rot: Vector3, wanted: Dictionary, from_prefix: String="") -> Node3D:
	wanted[key]=true
	if pieces.has(key):
		var node=pieces[key];var tween=create_tween().set_parallel(true);tween.tween_property(node,"position",at,.24).set_trans(Tween.TRANS_CUBIC);tween.tween_property(node,"rotation",rot,.24);return node
	var root_node=Node3D.new();card_root.add_child(root_node);pieces[key]=root_node
	var node=_bevel(Vector3(.45,.003,.68),.012,card_style.face(id,back));root_node.add_child(node)
	var aura=_halo();root_node.add_child(aura);root_node.set_meta("aura",aura)
	if not back:
		var c=Hearth20TavernGames.card(id)
		card_style.decorate(root_node,c)
	root_node.position=Vector3(-.74,1.05,-.15);root_node.rotation=rot+Vector3(0,.3,0)
	if not from_prefix.is_empty():
		for prior in pieces:
			if str(prior).begins_with(from_prefix) and (str(prior).ends_with(":"+id) or not wanted.has(prior)):
				root_node.position=pieces[prior].position;root_node.rotation=pieces[prior].rotation;break
	var tween=create_tween().set_parallel(true);tween.tween_property(root_node,"position",at,.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT);tween.tween_property(root_node,"rotation",rot,.55);return root_node
func _camera() -> void:
	if camera_override:return
	if camera==null:return
	var normal_position=Vector3(look_offset.x*.10,1.96-lean*.12,2.45-lean*.35).lerp(Vector3(0,2.10,2.20),peek_blend)
	var normal_target=Vector3(look_offset.x*.6,.85+look_offset.y*.35,-.25).lerp(Vector3(0,.87,.0),peek_blend)
	camera.position=normal_position.lerp(Vector3(0,2.52,1.62),book_blend);camera.look_at(normal_target.lerp(Vector3(0,1.25,.65),book_blend));camera.rotation.z=sin(elapsed*.35)*.0009
	if card_camera!=null:card_camera.transform=camera.transform;card_camera.fov=camera.fov
func _input_table(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:looking=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:lean=clampf(lean+(0.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -.2),0.,1.);_camera()
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var view_point=event.position*Vector2(viewport.size)/size;var origin=camera.project_ray_origin(view_point);var direction=camera.project_ray_normal(view_point)
			if book.opened:book.hit(origin,direction);return
			if current.get("game","") in Hearth20CasinoGames.TYPES:
				if game_view.pointer(origin,direction,true):return
				book.hit(origin,direction);return
			var chosen=_hit_card(event.position);var own=hand_hits.any(func(h):return h.id==chosen)
			# The book occupies its own left corner; card backs beyond it must not
			# make its visible cover impossible to click.
			if book.hit(origin,direction):return
			if own:
				if peeking:toggle_peek()
				else:card_selected.emit(chosen)
			else:
				var point=Plane(Vector3.UP,.84).intersects_ray(origin,direction)
				if point!=null and absf(point.x)<.9 and absf(point.z)<.55:toggle_peek()
				elif not chosen.is_empty():card_selected.emit(chosen)
	if event is InputEventMouseMotion:
		if current.get("game","") in Hearth20CasinoGames.TYPES and not book.opened:
			var view_point=event.position*Vector2(viewport.size)/size;game_view.pointer(camera.project_ray_origin(view_point),camera.project_ray_normal(view_point),false)
		var next=_hit_card(event.position) if not book.opened else ""
		if peeking and not public_hits.any(func(h):return h.id==next):next=""
		if next!=hovered:hovered=next;card_hovered.emit(hovered)
	if event is InputEventMouseMotion and looking:look_offset=(look_offset+event.relative*Vector2(-.004,.004)).clamp(Vector2(-1,-1),Vector2(1,1));_camera()
func _hit_card(position_value: Vector2) -> String:
	var point_on_view=position_value*Vector2(viewport.size)/size
	var origin=camera.project_ray_origin(point_on_view);var direction=camera.project_ray_normal(point_on_view);var best=INF;var chosen=""
	for hit in hand_hits+public_hits:
		var node=hit.node;var plane=Plane(node.global_transform.basis.y.normalized(),node.global_position);var point=plane.intersects_ray(origin,direction)
		if point==null:continue
		var local=node.to_local(point)
		if absf(local.x)<.225 and absf(local.z)<.34 and origin.distance_to(point)<best:chosen=hit.id;best=origin.distance_to(point)
	return chosen
func _halo() -> MeshInstance3D:
	var mesh=PlaneMesh.new();mesh.size=Vector2(.55,.81);var node=MeshInstance3D.new();node.mesh=mesh;node.position.y=-.006
	var shader=Shader.new();shader.code="""shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;void fragment(){vec2 p=abs(UV-.5)*2.;float d=max(p.x,p.y);float edge=exp(-pow((d-.82)*9.,2.));float sparks=pow(max(0.,sin(atan(UV.y-.5,UV.x-.5)*17.+TIME*4.)),18.)*edge;ALBEDO=vec3(1.,.64,.16);EMISSION=ALBEDO*(1.+sparks);ALPHA=edge*(.34+.13*sin(TIME*3.))+sparks*.6;}"""
	var mat=ShaderMaterial.new();mat.shader=shader;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visible=false;return node
func toggle_peek() -> void:
	if book.opened:return
	peeking=not peeking;selected="";hovered="";peek_changed.emit(peeking)
func _book_state(opened: bool) -> void:
	if opened:peek_before_book=peeking;peeking=true;selected="";hovered="";stretch_shrink=1
	else:peeking=peek_before_book;_resolution()
	card_surface.visible=not opened
	card_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if opened else SubViewport.UPDATE_ALWAYS
	if opened and soul_viewport!=null:soul_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	book_opened_changed.emit(opened)
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;card_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;soul_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	if game_view!=null:
		for content in [game_view.world_root,game_view.overlay_root]:
			if is_instance_valid(content):content.visible=not book.opened
	if card_viewport!=null:
		var has_visible_overlay=false
		if casino_active and not book.opened:
			for hit in hand_hits+public_hits:
				if Hearth20RenderVisibility.sphere(card_camera,hit.node.global_position,.75):has_visible_overlay=true;break
			if stock_deck.visible and Hearth20RenderVisibility.sphere(card_camera,Vector3(-.74,.94,-.15),.65):has_visible_overlay=true
			if game_view!=null:
				for die in game_view.dice.values():
					if Hearth20RenderVisibility.sphere(card_camera,die.global_position,.60):has_visible_overlay=true;break
		var draw_cards=casino_active and has_visible_overlay and not current.is_empty() and current.get("phase","")!="lobby" and not book.opened
		card_surface.visible=draw_cards;card_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if draw_cards else SubViewport.UPDATE_DISABLED
	elapsed+=delta;peek_blend=move_toward(peek_blend,1. if peeking else 0.,delta*3.5);book_blend=move_toward(book_blend,1. if book.opened else 0.,delta*2.5);_camera()
	if soul_viewport!=null:
		soul_viewport.size=card_viewport.size;soul_camera.global_transform=card_camera.global_transform;soul_camera.fov=card_camera.fov
		var draw_souls=casino_active and card_surface.visible and game_view!=null and game_view.kind=="gambit_of_ord" and not game_view.dice.is_empty()
		soul_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if draw_souls else SubViewport.UPDATE_DISABLED
	if peeking and not hand_hits.is_empty():
		# Move the whole fan together. Independent camera depths can make adjacent
		# slabs cross during the return from a peek or the rules book.
		var reference=hand_hits[hand_hits.size()/2];var base=Vector3(reference.base_x,reference.base_y,reference.base_z)+hand_shift;var top=INF;var bottom=-INF
		for x in [-.225,.225]:
			for z in [-.34,.34]:
				var point=camera.unproject_position(base+reference.node.global_basis*Vector3(x,0,z));top=minf(top,point.y);bottom=maxf(bottom,point.y)
		var center=camera.unproject_position(base);center.y+=float(viewport.size.y)-(bottom-top)*.2-top
		var depth=-camera.to_local(base).z;var target=hand_shift+camera.project_position(center,depth)-base;hand_shift=hand_shift.lerp(target,minf(1.,delta*10.))
	else:hand_shift=hand_shift.lerp(Vector3.ZERO,minf(1.,delta*12.))
	for hit in hand_hits:
		var active=(hit.id==hovered or hit.id==selected) and not peeking;hit.node.get_meta("aura").visible=active
		var target=Vector3(float(hit.base_x),float(hit.base_y)+(.30 if active else 0.),float(hit.base_z)+(.28 if active else 0.))+hand_shift
		hit.node.position=target if peeking else hit.node.position.lerp(target,minf(1.,delta*12.))
	for hit in public_hits:hit.node.get_meta("aura").visible=hit.id==hovered
	for i in candles.size():candles[i].light_energy=1.7+sin(elapsed*7.3+i)*.12+sin(elapsed*11.7+i*3)*.10

