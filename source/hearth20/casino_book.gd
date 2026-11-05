extends Node3D
class_name Hearth20CasinoBook
## Personal reading scene; action loops stop and page viewports free when closed.
signal opened_changed(opened: bool)
signal chapter_changed(index: int)
signal closed
const TITLES=["Three-Dragon Ante","Gambit of Ord","Run of Luck","Tymora's Spinner"]
const ANTE_SPREADS=[
["I · THE GAMBIT","Each player begins with six private cards. Choose one as your hidden ante.\n\nAll antes reveal together. Everyone pays coins equal to the highest value into the stakes.\n\nThe strongest untied ante leads the first round.","CHOOSE · COMMIT · REVEAL","Hover to inspect a card. Click it, then commit the face-down ante.\n\nYour choice stays hidden until everyone commits.","ante"],
["I · PLAY YOUR FLIGHT","Play clockwise, one card each turn. Your face-up cards form your flight.\n\nThe first card triggers its power. Later cards trigger when their value is no higher than the previous play.\n\nResolve any prompted choice before the next player acts.","A WEAKER PLAY CAN HELP","Read the selected card's power in the side panel.\n\nChoose the highlighted legal action. Other players see the played card, not your remaining hand.","play"],
["I · WINNING & GOLD","After three rounds, the strongest flight takes the stakes. Tied flights continue.\n\nMatching colors or strengths can earn special-flight bonuses.\n\nA player running out of coins ends the game.","DECLARE YOUR COINS","Declare the gold, silver and copper on your D&D Beyond sheet before you ready. Buy-ins stay in table escrow.\n\nThe CM cashes out or refunds. Enter your final balance notice on D&D Beyond, then confirm the update.","gold"],
["I · AT YOUR SEAT","Hover to lift a card and inspect it. Click to select it.\n\nClick an empty area in the middle of the table to peek over your hand. Only the card tops remain visible.\n\nClick again, the hand edge, or Escape to return.","PEEK AT THE TABLE","The camera centers the public cards while your hand lowers.\n\nReading this book and peeking change only your own view.","peek"]]
const GAME_SPREADS={
1:[
["II · THE HIDDEN GAMBIT","The CM deals a private d8. Check, call, raise, go all in or fold when your turn comes.\n\nAfter bets match, the CM adds a hidden d6. Bet again. A final d4 reveals the surviving totals.\n\nHighest total wins. Folded dice stay private.","CALL · RAISE · REVEAL","Your soul-glass dice belong to your view. Other seats show covered dice until showdown.\n\nHover a die to inspect it.","dice"],
["II · CHIPS & RULINGS","Buy-ins move from your declared balance to a table hoard. The minimum is the opening ante.\n\nAll-in players remain eligible for the pots they funded. Uncalled chips return in full.\n\nThe casino keeps 20% of matched pots, rounded down to whole chips. Tied remainders pass clockwise.","THE CASINO MASTER","The CM may grant a private reroll or resolve a forced fold after a character-ability ruling.\n\nCash out between gambits; cancellation refunds original buy-ins. Players enter the final balance notice in D&D Beyond.","gold"]],
2:[
["III · FIVE LIVING RACERS","Back one of five lizards before betting locks. Click a lane or choose its name, then place your wager.\n\nThe CM releases three stages. Each racer walks the paces rolled on its gilded green d4.\n\nThe greatest total after three stages wins.","BACK · LOCK · RELEASE","Your wager is shown beside your character. Remove it before locking to choose another racer.\n\nThe CM releases each stage.","race"],
["III · THE FINISH LINE","A first-place wager returns twice its stake. Every tied winner pays in full.\n\nBehind one clear winner, second-place wagers return half, rounded down to whole chips. Tied seconds all qualify.\n\nThe house must back every possible payout before releasing the racers.","A LITTLE LIFE AT THE TABLE","Lizard by Froggreen.\nSketchfab · CC BY 4.0.\n\nOriginal rig, colors and gait; miniature scale and materials adjusted. Full links ship with the model.","race"]],
3:[
["IV · TYMORA'S WHEEL","Choose odd, even, red, black, the ends (1 or 20), or an exact number. Click a numbered cell to select it.\n\nSet your stake, then place the wager. Different bets may share a spin.\n\nOnly the CM locks betting and spins the D20 wheel.","PLACE · LOCK · SPIN","The wheel reveals one number from 1 to 20.\n\nRed and black each cover ten numbers; color and odd/even are separate bets.","spinner"],
["IV · HOUSE TERMS","Payout ratios are profit: a winning stake also returns.\n\nDefault profits are 1:1 for odd, even, red and black; 8:1 for the ends; 18:1 for an exact number.\n\nThe CM can set other terms before opening. The displayed terms remain fixed for that table.","GOLD THAT STAYS GOLD","Every payout is backed by the casino reserve.\n\nCash out between spins, or cancel to refund original buy-ins. Enter the final balance notice on D&D Beyond and confirm the update.","gold"]]}
var table: Hearth20CasinoTable
var atlas: Texture2D
var cover: Texture2D
var hinge: Node3D
var straps: Array=[]
var pages: Array=[]
var leaves: Array=[]
var guides: Array=[]
var riffles: Array=[]
var retired_pages: Array=[]
var left_page: MeshInstance3D
var right_page: MeshInstance3D
var opened=false
var busy=false
var chapter=-1
var spread=0
var open_tween: Tween
var flip_tween: Tween
var strap_progress=0.
var page_clock=0.
var closed_position=Vector3(-1.39,.85,.70)
var right_stack: MeshInstance3D
var left_stack: MeshInstance3D
func setup(owner_table: Hearth20CasinoTable, textures: Dictionary) -> void:
	table=owner_table;atlas=textures.book;cover=textures.cover;position=closed_position;rotation.y=.2
	var leather=_mat(1,.1,.8);var strap_mat=_mat(3,0.,.92);var front=_cover_mat();var paper=_paper_edges()
	var back=table._bevel(Vector3(.68,.035,.94),.025,leather);back.position=Vector3(.33,.015,0);add_child(back)
	right_stack=table._bevel(Vector3(.61,.12,.86),.012,paper);right_stack.name="PermanentRightPages";right_stack.position=Vector3(.33,.092,0);add_child(right_stack)
	left_stack=table._bevel(Vector3(.61,.12,.86),.012,paper);left_stack.name="PermanentLeftPages";add_child(left_stack);_stack_pose(0.)
	var spine=table._bevel(Vector3(.065,.18,.95),.025,leather);spine.position=Vector3(.01,.09,0);add_child(spine)
	hinge=Node3D.new();hinge.position=Vector3(0,.17,0);add_child(hinge)
	var lid=table._bevel(Vector3(.68,.035,.94),.025,front);lid.position=Vector3(.33,0,0);hinge.add_child(lid)
	for z in [-.36,.36]:
		var belt=MeshInstance3D.new();belt.material_override=strap_mat;add_child(belt)
		var binding=Node3D.new();binding.position=Vector3(.64,.20,z);add_child(binding)
		for part in [[Vector3(.075,.022,.009),Vector3(-.025,.014,-.038)],[Vector3(.075,.022,.009),Vector3(-.025,.014,.038)],[Vector3(.009,.022,.08),Vector3(-.062,.014,0)],[Vector3(.009,.022,.08),Vector3(.012,.014,0)]]:
			var buckle=table._bevel(part[0],.002,table.bronze);buckle.position=part[1];binding.add_child(buckle)
		straps.append({"mesh":belt,"buckle":binding,"z":z})
	var cord=table._bevel(Vector3(.03,.008,.22),.005,table.bronze);cord.position=Vector3(.45,.014,.48);add_child(cord)
	_set_straps(0.);set_process(false)
func _mat(tile: int, metal: float, rough: float) -> ShaderMaterial:
	var shader=Shader.new();shader.code="""shader_type spatial;render_mode cull_disabled;uniform sampler2D atlas:source_color;uniform vec2 tile;uniform float metal;uniform float rough;void fragment(){ALBEDO=texture(atlas,tile+UV*.498).rgb;METALLIC=metal;ROUGHNESS=rough;}"""
	var m=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("atlas",atlas);m.set_shader_parameter("tile",Vector2(tile%2,tile/2)*.5);m.set_shader_parameter("metal",metal);m.set_shader_parameter("rough",rough);return m
func _cover_mat() -> StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_texture=cover;m.roughness=.77;m.metallic=.13;return m
func _paper_edges() -> ShaderMaterial:
	var shader=Shader.new();shader.code="""shader_type spatial;render_mode unshaded,cull_disabled;uniform sampler2D atlas:source_color;varying vec3 point;void vertex(){point=VERTEX;}void fragment(){vec3 paper=texture(atlas,vec2(.001,.501)+UV*.498).rgb;float lines=.86+.14*smoothstep(.2,.8,fract(point.y*1800.+sin(point.x*17.)*.08));ALBEDO=mix(vec3(.74,.675,.51),paper,.18)*lines;ROUGHNESS=1.;}"""
	var mat=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("atlas",atlas);return mat

func hit(origin: Vector3, direction: Vector3) -> bool:
	var plane=Plane(global_transform.basis.y.normalized(),to_global(Vector3(0,.18,0)));var point=plane.intersects_ray(origin,direction)
	if point==null:return false
	var at=to_local(point)
	if absf(at.z)>.49 or at.x<(-.69 if opened else -.03) or at.x>.70:return false
	if not opened:open_book();return true
	if chapter==-1 and at.x<0:
		var v=(at.z+.43)/.86;var index=floori((v-.3125)/.127)
		if index>=0 and index<4:select_chapter(index)
	elif chapter>=0 and at.z>.26:turn_spread(1 if at.x>0 else -1)
	return true
func open_book() -> void:
	if busy or opened:return
	opened=true;busy=true;chapter=-1;spread=0;_pages();set_process(true);opened_changed.emit(true)
	open_tween=create_tween().set_parallel(true)
	open_tween.tween_property(self,"position",Vector3(0,1.03,.65),.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	open_tween.tween_property(self,"rotation:y",0.,.65);open_tween.tween_property(self,"scale",Vector3.ONE*1.5,.65)
	open_tween.tween_method(_set_straps,0.,1.,.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	open_tween.tween_property(hinge,"rotation:z",PI,.60).set_delay(.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	open_tween.tween_property(hinge,"position:y",.015,.60).set_delay(.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	open_tween.tween_method(_stack_pose,0.,1.,.60).set_delay(.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	open_tween.finished.connect(_opened,CONNECT_ONE_SHOT)
func close_book() -> void:
	if busy or not opened:return
	busy=true;open_tween=create_tween().set_parallel(true)
	open_tween.tween_property(hinge,"rotation:z",0.,.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	open_tween.tween_property(hinge,"position:y",.17,.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	open_tween.tween_method(_stack_pose,1.,0.,.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	open_tween.tween_property(self,"position",closed_position,.8);open_tween.tween_property(self,"rotation:y",.2,.8);open_tween.tween_property(self,"scale",Vector3.ONE,.8)
	open_tween.tween_method(_set_straps,1.,0.,.28).set_delay(.49).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	open_tween.finished.connect(_closed,CONNECT_ONE_SHOT)
func _opened() -> void:busy=false
func _closed() -> void:
	for leaf_value in leaves:leaf_value.queue_free()
	for page in pages:page.queue_free()
	leaves.clear();pages.clear();guides.clear();opened=false;busy=false;set_process(false);opened_changed.emit(false);closed.emit()
func _stack_pose(amount: float) -> void:
	# These opaque volumes are part of the binding, never transient page viewports.
	right_stack.scale.y=lerpf(1.,.75,amount);right_stack.position.y=lerpf(.092,.079,amount)
	left_stack.visible=amount>.005;left_stack.scale=Vector3(maxf(.001,amount),maxf(.001,amount*.75),1);left_stack.position=Vector3(-.33*amount,.034+.045*amount,0)
func _set_straps(value: float) -> void:
	strap_progress=value
	for strap in straps:
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 20:
			var a=_strap_point(float(i)/20.,value);var b=_strap_point(float(i+1)/20.,value)
			for v in [[a,-.036],[b,.036],[b,-.036],[a,-.036],[a,.036],[b,.036]]:
				st.set_uv(Vector2(float(i)/20.,(v[1]+.036)/.072));st.add_vertex(Vector3(v[0].x,v[0].y,strap.z+v[1]))
		st.generate_normals();strap.mesh.mesh=st.commit();strap.buckle.position=Vector3(.64+value*.03,.20-value*.01,strap.z);strap.buckle.rotation.z=sin(value*PI)*-.16
func _strap_point(t: float, amount: float) -> Vector2:
	var p0=Vector2(.64,.20).lerp(Vector2(.67,.19),amount);var p1=Vector2(.41,.20).lerp(Vector2(1.05,.28),amount)
	var p2=Vector2(.18,.20).lerp(Vector2(1.12,-.04),amount);var p3=Vector2(-.04,.20).lerp(Vector2(.76,-.055),amount)
	return p0*(1-t)*(1-t)*(1-t)+p1*3*(1-t)*(1-t)*t+p2*3*(1-t)*t*t+p3*t*t*t
func _pages() -> void:
	for page in pages:page.queue_free()
	for leaf_value in leaves:leaf_value.queue_free()
	pages.clear();leaves.clear();guides.clear()
	left_page=_leaf(Vector3.ZERO);remove_child(left_page);hinge.add_child(left_page);left_page.position=Vector3(.33,-.11,0);left_page.rotation.z=PI
	right_page=_leaf(Vector3(.33,.125,0));_write_pages()
func _leaf(at: Vector3) -> MeshInstance3D:
	var node=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(.61,.86);node.mesh=plane;node.position=at;add_child(node);leaves.append(node);return node

func _render_page(title_value: String, body: String, index_page=false, guide="") -> Texture2D:
	var viewport=SubViewport.new();viewport.size=Vector2i(768,1024);viewport.transparent_bg=false;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport);pages.append(viewport)
	var base=TextureRect.new();base.size=Vector2(768,1024);var texture=AtlasTexture.new();texture.atlas=atlas;texture.region=Rect2(Vector2(0,atlas.get_height()*.5),Vector2(atlas.get_width()*.5,atlas.get_height()*.5));base.texture=texture;base.stretch_mode=TextureRect.STRETCH_SCALE;viewport.add_child(base)
	var title_label=_ink(title_value,46);title_label.position=Vector2(72,65);title_label.size=Vector2(624,125);viewport.add_child(title_label)
	if index_page:
		for i in TITLES.size():
			var row=_ink(["I","II","III","IV"][i]+"   "+TITLES[i],42);row.position=Vector2(84,320+i*130);row.size=Vector2(600,100);viewport.add_child(row)
	else:
		var label=_ink(body,40);label.set_meta("book_body",true);label.position=Vector2(76,210);label.size=Vector2(616,390 if not guide.is_empty() else 690);viewport.add_child(label)
	if not guide.is_empty():
		var demo=Hearth20CasinoGuide.new();demo.kind=guide;demo.position=Vector2(74,635);demo.size=Vector2(620,275);viewport.add_child(demo);guides.append({"node":demo,"viewport":viewport})
	var count=spread_count();var folio=_ink("DA ROLLS  ·  "+("CONTENTS" if chapter<0 else str(spread+1)+" / "+str(count)+"    ·    TURN PAGE →"),24);folio.position=Vector2(72,950);folio.size=Vector2(624,48);folio.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;viewport.add_child(folio)
	return viewport.get_texture()
func _ink(text_value: String, points: int) -> Label:
	var label=Label.new();label.text=text_value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_override("font",Hearth20Design.font(true));label.add_theme_font_size_override("font_size",points);label.add_theme_color_override("font_color",Color("#28190d"));return label
func spread_count() -> int:return 4 if chapter==0 else GAME_SPREADS[chapter].size() if chapter>0 else 1
func _write_pages() -> void:
	var left: Texture2D;var right: Texture2D
	if chapter<0:
		left=_render_page("DA ROLLS\nFour games · one table","",true)
		right=_render_page("A GAMBLER'S COMPANION","Welcome to the Gilded Table.\n\nChoose a chapter on the left or use a bookmark. Turn the lower page corners to read onward.\n\nAll four games are playable. The CM chooses the table and announces its stakes.\n\nYour reading and animations stay in your own view.")
	elif chapter==0:
		var data=ANTE_SPREADS[spread];left=_render_page(data[0],data[1]);right=_render_page(data[2],data[3],false,data[4])
	else:
		var data=GAME_SPREADS[chapter][spread];left=_render_page(data[0],data[1]);right=_render_page(data[2],data[3],false,data[4])
	for spec in [[left_page,left],[right_page,right]]:
		var mat=StandardMaterial3D.new();mat.albedo_texture=spec[1];mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=.92;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR;spec[0].material_override=mat
func select_chapter(index: int) -> void:
	if not opened or busy or index< -1 or index>=4:return
	_turn_to(index,0)
func turn_spread(direction: int) -> void:
	if not opened or busy or chapter<0:return
	var target=clampi(spread+direction,0,spread_count()-1)
	if target!=spread:_turn_to(chapter,target)
func _turn_to(index: int, target_spread: int) -> void:
	busy=true;var forward=index>chapter or (index==chapter and target_spread>=spread);var old_material=right_page.material_override if forward else left_page.material_override
	var count=clampi(8+absi(index-chapter)*3,8,17) if index!=chapter else 6
	chapter=index;spread=target_spread
	retired_pages.append_array(pages)
	pages.clear();guides.clear();_write_pages();flip_tween=create_tween().set_parallel(true)
	for i in count:
		var pivot=Node3D.new();pivot.position.y=.128+float(i)*.0012;add_child(pivot);riffles.append(pivot)
		var sheet=MeshInstance3D.new();sheet.material_override=old_material;pivot.add_child(sheet)
		var from=0. if forward else PI;var to=PI if forward else 0.
		_turn_leaf(from,pivot,sheet);flip_tween.tween_method(_turn_leaf.bind(pivot,sheet),from,to,.25).set_delay(i*.028).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flip_tween.finished.connect(_chapter_done,CONNECT_ONE_SHOT)
func _turn_leaf(angle: float, pivot: Node3D, sheet: MeshInstance3D) -> void:
	pivot.rotation.z=angle;var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		for p in [Vector2(float(i)/12.,0),Vector2(float(i+1)/12.,1),Vector2(float(i+1)/12.,0),Vector2(float(i)/12.,0),Vector2(float(i)/12.,1),Vector2(float(i+1)/12.,1)]:
			st.set_uv(p);st.add_vertex(Vector3(p.x*.61,sin(p.x*PI)*sin(angle)*.075,(p.y-.5)*.86))
	st.generate_normals();sheet.mesh=st.commit()
func _chapter_done() -> void:
	for pivot in riffles:pivot.queue_free()
	for page in retired_pages:page.queue_free()
	riffles.clear();retired_pages.clear();busy=false;chapter_changed.emit(chapter)
func _process(delta: float) -> void:
	if not opened or busy or guides.is_empty():return
	page_clock+=delta
	if page_clock<.05:return
	var step=page_clock;page_clock=0.
	for guide in guides:
		guide.node.age+=step;guide.node.queue_redraw();guide.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		if open_tween!=null and open_tween.is_valid():open_tween.kill()
		if flip_tween!=null and flip_tween.is_valid():flip_tween.kill()
