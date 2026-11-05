extends RefCounted
class_name Hearth20SoulMotion
## Each spirit drifts, seeks a real inner face, presses, then recoils into vapor.
const SOULS=5
const TRAIL_POINTS=8
const GLASS_INSET=.145
var faces: Array=[]
var seed=0
var glyph_anchors: Array=[]
func setup(polyhedron: Array, seed_value: int) -> void:
	faces=polyhedron;seed=seed_value
func contain(point: Vector3, margin: float) -> Vector3:
	for _pass in 3:
		for face in faces:
			var excess=point.dot(face.normal)-(float(face.distance)-margin)
			if excess>0:point-=face.normal*excess
	return point
func state(time: float, index: int) -> Dictionary:
	var period=10.8+float(index)*.91+float(seed%3)*.13
	var offset=[.50,.15,.83,.34,.68][index]*period
	var clock=time+offset;var cycle=floori(clock/period);var phase=fposmod(clock,period)/period
	var face_index=posmod(seed+cycle+index*2,faces.size());var face=faces[face_index];var normal: Vector3=face.normal
	var reference=Vector3.UP if absf(normal.y)<.9 else Vector3.RIGHT
	var across=reference.cross(normal).normalized();var up=normal.cross(across)
	var phase_seed=float(seed)*.417
	var wandering=Vector3(sin(time*.53+index*2.399+phase_seed)*.22,cos(time*.41+index*1.71+phase_seed)*.19,sin(time*.37+index*2.91+phase_seed)*.21)
	wandering=contain(wandering,GLASS_INSET+.10)
	var slide=across*sin(time*.46+index)*.075+up*cos(time*.39+index*1.73)*.070
	var contact: Vector3=face.center-normal*GLASS_INSET+slide
	var target=contact-normal*.026
	var seeking=smoothstep(.23,.43,phase)*(1.-smoothstep(.65,.85,phase))
	var pressure=smoothstep(.40,.46,phase)*(1.-smoothstep(.63,.72,phase))
	var emergence=smoothstep(.16,.39,phase)*(1.-smoothstep(.70,.93,phase))
	var position=wandering.lerp(target,seeking)
	var direction=Vector3(cos(time*.53+index*2.399+phase_seed),-sin(time*.41+index*1.71+phase_seed)*.7,cos(time*.37+index*2.91+phase_seed)*.65).normalized().lerp(normal,seeking).normalized()
	return {"position":position,"forward":direction,"pressure":pressure,"seeking":seeking,"emergence":emergence,"contact":contact,"face":face_index,"phase":phase,"cycle":cycle}
func display_state(time: float,index: int,reveal_elapsed: float=-1.) -> Dictionary:
	var now=state(time,index)
	if reveal_elapsed<0. or reveal_elapsed>=4.3:return now
	var effect=Hearth20SoulReveal.envelope(reveal_elapsed);var face=faces[seed];var normal: Vector3=face.normal
	var basis=Basis.looking_at(normal,Vector3.RIGHT if absf(normal.y)>.98 else Vector3.UP,true)
	var angle=float(index)*TAU/SOULS+PI/2;var lane=Vector3(cos(angle)*.18,sin(angle)*.18,0)
	var center: Vector3=face.center-normal*(GLASS_INSET+.026)
	var destination=contain(center+basis*lane,GLASS_INSET+.020)
	if glyph_anchors.size()==SOULS:destination=destination.lerp(contain(center+basis*glyph_anchors[index],GLASS_INSET+.020),effect.morph)
	now.position=now.position.lerp(destination,effect.gather);var forward: Vector3=now.forward.lerp(normal,effect.gather)
	now.forward=forward.normalized() if forward.length_squared()>.00001 else basis.x
	now.pressure=lerpf(now.pressure,.8,effect.gather);now.emergence=lerpf(now.emergence,1.,effect.gather)*(1.-effect.consume)
	now.contact=now.contact.lerp(now.position+normal*.026,effect.gather);now.face=seed if effect.gather>.99 else now.face
	return now
func frame(time: float,reveal_elapsed: float=-1.) -> Dictionary:
	var heads=PackedVector4Array();var directions=PackedVector4Array();var tails=PackedVector4Array();var contacts=PackedVector4Array();var appearances=PackedVector4Array();var states=[]
	for index in SOULS:
		var now=display_state(time,index,reveal_elapsed);states.append(now)
		heads.append(Vector4(now.position.x,now.position.y,now.position.z,now.pressure))
		directions.append(Vector4(now.forward.x,now.forward.y,now.forward.z,float(index)*2.399+float(seed)*.419))
		contacts.append(Vector4(now.contact.x,now.contact.y,now.contact.z,now.pressure))
		appearances.append(Vector4(now.emergence,now.pressure,now.phase,0))
		for k in TRAIL_POINTS:
			var delay=float(k)*.24;var past=display_state(time-delay,index,reveal_elapsed-delay if reveal_elapsed>=0. else -1.)
			var point=contain(past.position-Vector3(0,.095+delay*.085,0),GLASS_INSET+.023)
			tails.append(Vector4(point.x,point.y,point.z,(1.-float(k)/TRAIL_POINTS)*float(past.emergence)))
	return {"heads":heads,"directions":directions,"tails":tails,"contacts":contacts,"appearances":appearances,"states":states}
