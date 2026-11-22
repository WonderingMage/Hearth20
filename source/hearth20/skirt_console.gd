extends Node3D
class_name Hearth20SkirtConsole
## A local DM control panel on the near table apron; authority stays in Session.
var shell
var caps={}
var labels={}
var held=""
var hovered=""
var tooltip: Label3D
const KEYS=["fey_forest","blue_dungeon","gold_vault","infernal_wastes","jax","cisco","kal","arman"]
const ROW_GAP := .215
func setup(owner: Control) -> void:
	shell=owner;name="DMSkirtConsole";position=Vector3(0,.675,2.38);rotation=Vector3(-1.0,0,0)
	var wood=shell.table.room.materials.get("timber",shell.table.wood)
	for x in [-.52,.52]:
		var bracket=shell.table._bevel(Vector3(.07,.045,.18),.009,shell.table.bronze)
		bracket.position=Vector3(x,.10,-.083)
		bracket.rotation.x=1.0
		add_child(bracket)
	var back=shell.table._bevel(Vector3(1.34,.055,.30+ROW_GAP),.04,wood);back.rotation.x=PI/2;back.position.y=-ROW_GAP*.5;add_child(back)
	var border=shell.table._bevel(Vector3(1.28,.008,.25+ROW_GAP),.035,shell.table.bronze);border.rotation.x=PI/2;border.position=Vector3(0,-ROW_GAP*.5,.033);add_child(border)
	var recess=shell.table._bevel(Vector3(1.25,.008,.22+ROW_GAP),.03,wood);recess.rotation.x=PI/2;recess.position=Vector3(0,-ROW_GAP*.5,.039);add_child(recess)
	for i in KEYS.size():
		var id=KEYS[i];var cap=Node3D.new();cap.name="Push_"+id
		cap.position=Vector3((i-2)*.235,0,.05) if i<5 else Vector3((i-6)*.235,-ROW_GAP,.05)
		add_child(cap);caps[id]=cap
		var button=shell.table._bevel(Vector3(.205,.033,.174),.027,wood);button.rotation.x=PI/2;cap.add_child(button)
		var is_alert: bool=Hearth20JaxAlert.TARGETS.has(id)
		var text=Label3D.new();text.text=str(id).capitalize() if is_alert else str(Hearth20RoomWorlds.PRESETS[id].short);text.font=Hearth20Design.font(true);text.font_size=32;text.pixel_size=.00058;text.position=Vector3(0,-.045,.020);text.modulate=Color("#d6b777");text.outline_size=0;cap.add_child(text);labels[id]=text
		_icon(cap,"jax" if is_alert else id)
	for x in [-.59,.59]:
		var pin=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=.012;cylinder.bottom_radius=.012;cylinder.height=.006;cylinder.radial_segments=12;pin.mesh=cylinder;pin.rotation.x=PI/2;pin.position=Vector3(x,.113,.04);pin.material_override=shell.table.bronze;add_child(pin)
	tooltip=Label3D.new();tooltip.font=Hearth20Design.font(false);tooltip.font_size=34;tooltip.pixel_size=.00065;tooltip.position=Vector3(0,.22,.06);tooltip.modulate=Color("#ead8ac");tooltip.outline_size=7;add_child(tooltip)
	var lamp=OmniLight3D.new();lamp.position=Vector3(0,.14,.22);lamp.omni_range=1.2;lamp.light_color=Color("#ffdda0");lamp.light_energy=.38;lamp.shadow_enabled=false;add_child(lamp)
	Hearth20GeneratedModels.shadows(self,false)
func _icon(parent: Node3D,id: String) -> void:
	var paths=[]
	match id:
		"fey_forest":paths=[[Vector2(-.032,.005),Vector2(0,.061),Vector2(.032,.005),Vector2(-.032,.005)],[Vector2(0,.005),Vector2(0,-.008)]]
		"blue_dungeon":paths=[[Vector2(-.027,-.006),Vector2(-.027,.033),Vector2(-.018,.051),Vector2(0,.060),Vector2(.018,.051),Vector2(.027,.033),Vector2(.027,-.006)],[Vector2(-.032,-.006),Vector2(.032,-.006)]]
		"gold_vault":paths=[[Vector2(0,-.008),Vector2(-.032,.024),Vector2(0,.060),Vector2(.032,.024),Vector2(0,-.008)],[Vector2(-.014,.025),Vector2(.014,.025)]]
		"infernal_wastes":paths=[[Vector2(0,-.010),Vector2(-.030,.003),Vector2(-.026,.027),Vector2(-.007,.043),Vector2(-.003,.067),Vector2(.024,.034),Vector2(.031,.013),Vector2(.019,-.005),Vector2(0,-.010)]]
		"jax":paths=[[Vector2(-.022,-.012),Vector2(-.032,.002),Vector2(-.037,.020),Vector2(-.030,.029),Vector2(-.018,.016),Vector2(-.018,.037),Vector2(-.009,.041),Vector2(-.009,.074),Vector2(-.004,.080),Vector2(.004,.080),Vector2(.009,.074),Vector2(.009,.041),Vector2(.019,.039),Vector2(.020,.031),Vector2(.030,.028),Vector2(.033,.004),Vector2(.024,-.012),Vector2(-.022,-.012)],[Vector2(-.009,.041),Vector2(-.009,.022)],[Vector2(.009,.041),Vector2(.009,.020)],[Vector2(.020,.031),Vector2(.020,.014)]]
	for path in paths:
		for i in range(path.size()-1):
			var a=Vector3(path[i].x,path[i].y+.025,.021);var b=Vector3(path[i+1].x,path[i+1].y+.025,.021)
			var stroke=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.0018;mesh.bottom_radius=.0018;mesh.height=a.distance_to(b);mesh.radial_segments=6;stroke.mesh=mesh;stroke.material_override=shell.table.bronze;stroke.position=(a+b)*.5;stroke.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()));parent.add_child(stroke)
func _process(delta: float) -> void:
	visible=shell.app.session.local_role=="dm" and shell.focus_state=="table" and not shell.app.session.is_spectating()
	if not visible:held="";hovered="";tooltip.hide();return
	var selected=shell.app.session.room_environment()
	for id in caps:
		caps[id].position.z=lerpf(caps[id].position.z,.024 if held==id else .05,minf(1.,delta*18.))
		labels[id].modulate=Color("#fff0bf") if id==selected else Color("#d6b777")
	var view=shell.table.room.get_node_or_null("WindowWorld")
	tooltip.visible=not hovered.is_empty() or (view!=null and (view.loading or not view.load_error.is_empty()))
	tooltip.text="Preparing window view…" if view!=null and view.loading else view.load_error if view!=null and not view.load_error.is_empty() else hovered.capitalize()+" · five-second table alert" if Hearth20JaxAlert.TARGETS.has(hovered) else str(Hearth20RoomWorlds.PRESETS.get(hovered,{}).get("title",""))
func hit(camera: Camera3D,screen: Vector2) -> String:
	if not visible or shell.app.session.local_role!="dm":return ""
	var inverse=global_transform.affine_inverse();var origin=inverse*camera.project_ray_origin(screen);var direction=(inverse.basis*camera.project_ray_normal(screen)).normalized()
	if direction.z>=-.0001:return ""
	var point=Plane(Vector3.BACK,.07).intersects_ray(origin,direction)
	if not point is Vector3:return ""
	for id in caps:
		if absf(point.x-caps[id].position.x)<.108 and absf(point.y-caps[id].position.y)<.09:return id
	return ""
func activate(id: String) -> Dictionary:
	if shell.app.session.local_role!="dm":return {"ok":false,"error":"Only the DM controls the table console."}
	if Hearth20JaxAlert.TARGETS.has(id):return shell.app.session.send_table_alert(id)
	return shell.app.session.set_room_environment(id)
