extends RefCounted
class_name Hearth20RenderVisibility
## Conservative sphere/frustum checks for optional presentation work, never game rules.
static func sphere(camera: Camera3D,center: Vector3,radius: float) -> bool:
	var local=camera.to_local(center);var depth=-local.z
	if depth+radius<camera.near or depth-radius>camera.far:return false
	if depth<=radius:return true
	var dimensions=Vector2(camera.get_viewport().size);var half_height=depth*tan(deg_to_rad(camera.fov)*.5);var half_width=half_height*dimensions.x/maxf(1.,dimensions.y)
	return absf(local.x)<=half_width+radius*1.5 and absf(local.y)<=half_height+radius*1.5
