extends RefCounted
class_name Hearth20RoomFlame
## Shared upright atlas: top UV is the tip; bright base is at v=.88.
const BASE_V=.88
static func material(phase=0.) -> ShaderMaterial:
	var result=ShaderMaterial.new();result.shader=load("res://hearth20/room_craft/flame.gdshader")
	result.set_shader_parameter("atlas",load("res://hearth20/room_craft/flame-atlas.png"))
	result.set_shader_parameter("phase",phase);return result
static func center_above_wick(height: float) -> float:return (BASE_V-.5)*height
