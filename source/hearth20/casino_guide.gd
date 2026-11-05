extends Control
class_name Hearth20CasinoGuide
## A small looping, illustrated action guide rendered only inside an open local book.
var kind="ante"
var age=0.
var ink=Color("#35200e")
var gold=Color("#8a5e23")
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func _word(text: String, at: Vector2, points=30) -> void:draw_string(Hearth20Design.font(true),at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,points,ink)
func _card(at: Vector2, value: String, hidden=false) -> void:
	var r=Rect2(at,Vector2(88,118));draw_style_box(_box(Color("#211a12") if hidden else Color("#ddc58e")),r)
	if hidden:
		draw_circle(at+Vector2(44,58),23,gold);draw_circle(at+Vector2(44,58),19,Color("#211a12"));_word("✧",at+Vector2(27,69),36)
	else:
		draw_circle(at+Vector2(44,22),19,Color("#701b2d"));draw_string(Hearth20Design.font(true),at+Vector2(33,33),value,HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("#eee7d8"));draw_line(at+Vector2(17,57),at+Vector2(68,98),gold,3,true)
func _box(color: Color) -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.border_color=gold;s.set_border_width_all(3);s.set_corner_radius_all(5);return s
func _draw() -> void:
	draw_style_box(_box(Color(.49,.35,.15,.09)),Rect2(Vector2.ZERO,size))
	var t=fmod(age,6.);var move=smoothstep(1.,3.,t);var stage=0 if t<2 else 1 if t<4 else 2
	match kind:
		"peek":
			_word(["Click the empty table","Your hand lowers","Click again to return"][stage],Vector2(28,40),29)
			draw_ellipse(Vector2(310,130),Vector2(210,52))
			for i in 4:_card(Vector2(160+i*68,130+(.0 if t<1 else sin(clampf((t-1)/4.,0,1)*PI)*83)),str(i+3))
			draw_line(Vector2(28,245),Vector2(592,245),ink,2,true)
		"gold":
			_word(["Your declared balance","Buy-in held at the table","CM settles or refunds"][stage],Vector2(24,40),28)
			for i in 5:
				var p=Vector2(110+i*14,140+i*5).lerp(Vector2(400+i*14,140+i*5),move);draw_circle(p,17,gold);draw_circle(p,12,Color("#d0ad55"))
			_word("PURSE",Vector2(65,224),26);_word("TABLE",Vector2(414,224),26)
		"race":
			_word("Five racers · three d4 stages",Vector2(24,40),29)
			for i in 5:
				var y=78+i*31;draw_line(Vector2(38,y+11),Vector2(580,y+11),Color(.3,.2,.1,.25),1,true)
				var x=60+fmod(age*(55+i*7),465);draw_circle(Vector2(x,y),9,Color("#678349"));draw_line(Vector2(x-13,y+4),Vector2(x+14,y-3),ink,4,true)
		"spinner":
			_word(["Choose your wager","All bets lock","The CM reveals the spin"][stage],Vector2(24,40),29)
			draw_arc(Vector2(310,153),79,0,TAU,64,gold,5,true)
			for i in 20:
				var p=Vector2(310,153)+Vector2.from_angle(float(i)*TAU/20)*68;draw_circle(p,3,gold)
			var angle=age*4.;draw_line(Vector2(310,153),Vector2(310,153)+Vector2.from_angle(angle)*67,ink,5,true)
		"dice":
			_word(["Private d8 · bet","Add d6 · bet again","Add d4 · reveal totals"][stage],Vector2(24,40),29)
			for i in 3:
				var r=Rect2(84+i*162,85,100,100);draw_style_box(_box(Color("#dfc996")),r);_word(["d8","d6","d4"][i],r.position+Vector2(21,61),39)
		_:
			var ante=kind=="ante";_word((["Choose your ante","Commit it face down","Reveal together"] if ante else ["Hover to inspect","Commit one legal card","A weaker play triggers"])[stage],Vector2(24,40),29)
			for i in 3:
				var start=Vector2(75+i*165,112);var end=Vector2(235+(i-1)*103,84);_card(start.lerp(end,move),str([8,3,6][i]),ante and stage==1)
			var cursor=Vector2(110,240).lerp(Vector2(300,154),smoothstep(0.,2.,t));draw_colored_polygon(PackedVector2Array([cursor,cursor+Vector2(0,25),cursor+Vector2(9,18),cursor+Vector2(20,17)]),Color("#f4ead3"));draw_polyline(PackedVector2Array([cursor,cursor+Vector2(0,25),cursor+Vector2(9,18),cursor+Vector2(20,17),cursor]),ink,2,true)
func draw_ellipse(center: Vector2, radius: Vector2) -> void:
	var points=PackedVector2Array()
	for i in 65:points.append(center+Vector2(cos(float(i)*TAU/64),sin(float(i)*TAU/64))*radius)
	draw_colored_polygon(points,Color(.3,.17,.07,.2));draw_polyline(points,gold,3,true)
