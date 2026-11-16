extends RefCounted
class_name Hearth20DrawingSelection
const KINDS=["freehand","line","rectangle","ellipse","text"]
static func editable(object: Dictionary,role: String,layer: String,player: String) -> bool:
	return object.get("kind","") in KINDS and object.get("layer","tokens")==layer and (role=="dm" or (layer=="tokens" and (object.get("mine",false) or (not player.is_empty() and object.get("owner","")==player))))
static func touches(object: Dictionary,rectangle: Rect2) -> bool:
	var area=rectangle.abs().grow(.025)
	if object.kind not in ["freehand","line"]:return area.intersects(Hearth20BoardTools.bounds(object),true)
	var edges=[area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]
	for point in object.points:
		if area.has_point(point):return true
	for i in range(1,object.points.size()):
		for edge in 4:
			if Geometry2D.segment_intersects_segment(object.points[i-1],object.points[i],edges[edge],edges[(edge+1)%4])!=null:return true
	return false
