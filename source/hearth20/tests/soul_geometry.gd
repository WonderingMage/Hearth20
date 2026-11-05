extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	for sides in [4,6,8]:
		var motion=Hearth20SoulMotion.new();var faces=Hearth20DiceModel.shape(sides);motion.setup(faces,0)
		var contacts=0;var free=0;var hidden=0;var emerged=0;var visited={};var previous=motion.state(0.,0).position
		for sample in 600:
			var time=sample*.1;var frame=motion.frame(time)
			expect(frame.tails.size()==40 and frame.heads.size()==5,"five souls each retain a complete independent trail")
			for index in 5:
				var state=frame.states[index];visited[state.face]=true
				if state.emergence<.01:hidden+=1
				if state.emergence>.99:emerged+=1
				expect(state.emergence>=0. and state.emergence<=1.,"liquid emergence stays smoothly bounded")
				if state.pressure>.99:
					contacts+=1;var plane=faces[state.face];expect(absf(state.position.dot(plane.normal)-(float(plane.distance)-Hearth20SoulMotion.GLASS_INSET-.026))<.001,"pressed spirit touches correct inner pane")
				elif state.seeking<.01:free+=1
				for face in faces:expect(state.position.dot(face.normal)<=face.distance-Hearth20SoulMotion.GLASS_INSET+.001,"head stays inside thick-glass hull")
			expect(previous.distance_to(frame.states[0].position)<.10,"no jump on wall-target changes");previous=frame.states[0].position
		expect(contacts>30 and free>30 and visited.size()>=sides-1,"wander/contact/recoil cycle covers die faces")
		expect(hidden>30 and emerged>30,"souls repeatedly emerge from and disappear into the abyss")
		for value in range(1,sides+1):
			var die=Hearth20CasinoDie.new();root.add_child(die);die.setup(sides,value);var ink=die.number.mesh.get_aabb()
			expect(ink.get_center().length()<.0001,"visible glyph is centered on all casino results")
			expect(die.number.position.is_equal_approx(faces[value-1].center+faces[value-1].normal*.028),"number anchor matches face centroid")
			var gathering=die.soul_motion.frame(1.,.85)
			expect(gathering.states.size()==5 and gathering.states.all(func(s):return s.emergence>.99 and s.forward.dot(faces[value-1].normal)>.99),"all five spirits gather at the camera-facing result pane")
			var formed=die.soul_motion.frame(2.3,2.3)
			expect(formed.states.all(func(s):return s.emergence<.001),"the gathered spirits are consumed as the glyph forms")
			for moment in [.0,.425,.85,1.2,1.6,2.1,3.4,4.4]:
				for state in die.soul_motion.frame(moment,moment).states:
					expect(state.forward.is_finite() and state.forward.length()>.99,"gathering cannot create a degenerate direction")
					for face in faces:expect(state.position.dot(face.normal)<=face.distance-Hearth20SoulMotion.GLASS_INSET+.001,"reveal migration remains inside the thick inner hull")
			expect(die.body.has_node("FreezingCrystalSpears"),"real branching ice geometry above the glazing")
			die.queue_free()
	var before=Hearth20SoulReveal.envelope(.6);var flare=Hearth20SoulReveal.envelope(1.25);var settled=Hearth20SoulReveal.envelope(2.35)
	expect(before.formation==0. and flare.flash>.99 and flare.formation==0.,"the full white aura precedes the visible number")
	expect(settled.flash==0. and settled.formation==1. and settled.rays==1.,"white light subsides into a complete number with soft rays")
	for text in ["0","1","5","8","10","12","20","00","100"]:
		var number=Hearth20DiceNumeral.new();number.setup(text,.6,.7);expect(number.mesh.get_aabb().get_center().length()<.0001,"single and multiple digit ink center");number.free()
	await process_frame;print("Soul geometry: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
