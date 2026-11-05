extends RefCounted
class_name Hearth20DiceModel
static var shapes: Dictionary={}
static func hull(points: Array) -> Array:
	var faces: Array=[]; var planes: Dictionary={}
	for a in points.size():
		for b in range(a+1,points.size()):
			for c in range(b+1,points.size()):
				var normal: Vector3=(points[b]-points[a]).cross(points[c]-points[a]).normalized()
				if normal.length_squared()<.1: continue
				if normal.dot(points[a])<0: normal=-normal
				var distance: float=normal.dot(points[a]); var outside:=false; var indices: Array=[]
				for i in points.size():
					var delta: float=normal.dot(points[i])-distance
					if delta>.0001: outside=true; break
					if absf(delta)<.0001: indices.append(i)
				if outside or indices.size()<3: continue
				var key:=str(indices)
				if planes.has(key): continue
				planes[key]=true
				var center:=Vector3.ZERO
				for i in indices: center+=points[i]
				center/=indices.size()
				var u: Vector3=(points[indices[0]]-center).normalized(); var v:=normal.cross(u)
				indices.sort_custom(func(i,j): return atan2((points[i]-center).dot(v),(points[i]-center).dot(u))<atan2((points[j]-center).dot(v),(points[j]-center).dot(u)))
				var vertices: Array=[]
				for i in indices: vertices.append(points[i])
				faces.append({"vertices":vertices,"normal":normal,"center":center,"distance":distance})
	return faces
static func shape(sides: int) -> Array:
	if shapes.has(sides): return shapes[sides]
	var points: Array=[]; var phi:=(1.0+sqrt(5.0))*.5
	match sides:
		4: points=[Vector3(1,1,1),Vector3(-1,-1,1),Vector3(-1,1,-1),Vector3(1,-1,-1)]
		6:
			for x in [-1,1]:
				for y in [-1,1]:
					for z in [-1,1]: points.append(Vector3(x,y,z))
		8: points=[Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]
		10:
			var antiprism: Array=[]
			for i in 5:
				antiprism.append(Vector3(cos(i*TAU/5),.55,sin(i*TAU/5))); antiprism.append(Vector3(cos((i+.5)*TAU/5),-.55,sin((i+.5)*TAU/5)))
			for face in hull(antiprism): points.append(face.normal/face.distance)
		12:
			for face in shape(20): points.append(face.normal/face.distance)
		_:
			for a in [-1,1]:
				for b in [-1,1]: points.append(Vector3(0,a,b*phi)); points.append(Vector3(a,b*phi,0)); points.append(Vector3(a*phi,0,b))
	var radius:=0.0
	for point in points: radius=maxf(radius,point.length())
	for i in points.size(): points[i]/=radius
	shapes[sides]=hull(points); return shapes[sides]
static func make(sides: int, value: int, secondary: bool=false, percentile_tens: bool=false) -> Node3D:
	var body:=Node3D.new(); var faces:=shape(sides); var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normals: Array=[]; var edge_keys: Dictionary={}; var edges: Array=[]
	for i in faces.size():
		var face: Dictionary=faces[i]; normals.append(face.normal)
		var tint:=Color("#4b4650") if secondary else Color("#192b30").lerp(Color("#263c3b"),float(i%3)*.16)
		var vertices: Array=face.vertices
		for j in range(1,vertices.size()-1):
			for index in [0,j+1,j]:
				surface.set_normal(face.normal); surface.set_color(tint); surface.add_vertex(face.center+(vertices[index]-face.center)*.95)
		for j in vertices.size():
			var a: Vector3=vertices[j]; var b: Vector3=vertices[(j+1)%vertices.size()]
			var key:=str(a)+str(b) if str(a)<str(b) else str(b)+str(a)
			if not edge_keys.has(key): edge_keys[key]=true; edges.append([a,b])
		var text=("%02d"%(i*10) if percentile_tens else str(i if sides==10 and value==0 else i+1))
		if sides not in [4,6,8,10,12,20]:text=str(value) if i==0 else "✦"
		var label=Hearth20DiceNumeral.new();label.setup(text,.34 if sides in [4,6,8] else .23,.43 if sides in [4,6,8] else .34,Color("#ac9cae") if secondary else Color("#f4d994"),.2)
		label.position=face.center+face.normal*.009;label.basis=Basis.looking_at(face.normal,Vector3.RIGHT if absf(face.normal.dot(Vector3.UP))>.98 else Vector3.UP,true);body.add_child(label)

	var material:=StandardMaterial3D.new(); material.vertex_color_use_as_albedo=true; material.metallic=.48; material.roughness=.3; surface.set_material(material)
	var mesh:=MeshInstance3D.new(); mesh.mesh=surface.commit(); body.add_child(mesh)
	var gold:=StandardMaterial3D.new(); gold.albedo_color=Color("#827287") if secondary else Color("#c5a258"); gold.metallic=.78; gold.roughness=.24
	var edge_instance:=MultiMeshInstance3D.new(); var multi:=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D
	var cylinder:=CylinderMesh.new(); cylinder.top_radius=.014; cylinder.bottom_radius=.014; cylinder.height=1; cylinder.radial_segments=6; cylinder.rings=1; multi.mesh=cylinder; multi.instance_count=edges.size(); edge_instance.multimesh=multi; edge_instance.material_override=gold; body.add_child(edge_instance)
	for i in edges.size():
		var edge: Array=edges[i]; var axis: Vector3=(edge[1]-edge[0]).normalized()
		multi.set_instance_transform(i,Transform3D(Basis(Quaternion(Vector3.UP,axis)).scaled(Vector3(1,edge[0].distance_to(edge[1]),1)),(edge[0]+edge[1])*.5))
	var target:=clampi(value-1,0,faces.size()-1)
	if percentile_tens: target=clampi(value/10,0,9)
	elif sides==10 and value==0: target=0
	elif sides not in [4,6,8,10,12,20]: target=0
	var normal: Vector3=normals[target]
	body.set_meta("result_basis",Basis.looking_at(normal,Vector3.RIGHT if absf(normal.dot(Vector3.UP))>.98 else Vector3.UP,true))
	body.set_meta("result_normal",normal); body.set_meta("result_value",value); body.set_meta("sides",sides); body.set_meta("face_count",faces.size())
	return body
