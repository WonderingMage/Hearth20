extends RefCounted
class_name Hearth20SplatAssets
## Offline preparation: preserve the declared world origin, unlike the upstream
## generic object viewer which centers each cloud on its own mean.
const Builder=preload("res://addons/gdgs/importers/builders/gaussian_resource_builder.gd")
static func prepare(canonical: Dictionary) -> Dictionary:
	var count=int(canonical.get("count",0))
	if count<1 or count>250000:return {"ok":false,"message":"A window capture must contain 1–250,000 Gaussians."}
	var positions: PackedVector3Array=canonical.positions
	if positions.size()!=count:return {"ok":false,"message":"Invalid Gaussian positions."}
	var center=Vector3.ZERO
	for p in positions:
		if not p.is_finite() or maxf(absf(p.x),maxf(absf(p.y),absf(p.z)))>1000.:return {"ok":false,"message":"Invalid capture coordinates or meter scale."}
		center+=p
	center/=float(count)
	var built=Builder.build(canonical)
	if not built.ok:return built
	var resource: GaussianResource=built.resource
	var floats=resource.point_data_float
	for i in count:
		floats[i*60]+=center.x;floats[i*60+1]+=center.y;floats[i*60+2]+=center.z
		resource.xyz[i]+=center
	resource.point_data_byte=floats.to_byte_array()
	resource.point_data_float=PackedFloat32Array() # Raster consumes the byte buffer.
	resource.aabb.position+=center
	return {"ok":true,"resource":resource}
