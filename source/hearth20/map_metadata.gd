extends RefCounted
class_name Hearth20MapMetadata
## A small, CRC-checked PNG text record carries authored grid scale with the image.
const KEY := "Hearth20.Map"
const MAX_TEXT_BYTES := 4096

static func read(bytes: PackedByteArray, dimensions: Vector2i) -> Dictionary:
	var grid := {}
	if bytes.size()<8 or bytes.slice(0,8)!=PackedByteArray(Hearth20Assets.PNG_SIGNATURE):
		return {"ok":true,"grid":grid}
	var offset := 8
	var count := 0
	while offset+12<=bytes.size():
		count+=1
		if count>8192:return _error("PNG has too many chunks.")
		var length := Hearth20Assets._u32_be(bytes,offset)
		if length>bytes.size()-offset-12:return _error("PNG chunk exceeds the file boundary.")
		var type := bytes.slice(offset+4,offset+8).get_string_from_ascii()
		if type=="tEXt" and length>=KEY.length()+1:
			var prefix := bytes.slice(offset+8,offset+8+KEY.length()+1)
			if prefix==KEY.to_ascii_buffer()+PackedByteArray([0]):
				if not grid.is_empty():return _error("PNG has duplicate Hearth20 grid records.")
				if length>MAX_TEXT_BYTES+KEY.length()+1:return _error("Embedded grid record exceeds 4096 bytes.")
				var payload := bytes.slice(offset+4,offset+8+length)
				if crc32(payload)!=Hearth20Assets._u32_be(bytes,offset+8+length):return _error("Embedded grid checksum is invalid.")
				var text := bytes.slice(offset+8+KEY.length()+1,offset+8+length).get_string_from_utf8()
				if not Hearth20Recipes._preflight_json_text(text).ok:return _error("Embedded grid JSON is too deeply nested or malformed.")
				var parser := JSON.new()
				if parser.parse(text)!=OK:return _error("Embedded grid JSON could not be read.")
				var checked := validate(parser.data,dimensions)
				if not checked.ok:return checked
				grid=checked.grid
		offset+=length+12
		if type=="IEND":break
	return {"ok":true,"grid":grid}

static func validate(value: Variant, dimensions: Vector2i) -> Dictionary:
	if not value is Dictionary or value.size()>7:return _error("Embedded grid must be a small object.")
	for key in value:
		if key not in ["schema","width_cells","height_cells","feet_per_cell","pixel_width","pixel_height"]:
			return _error("Embedded grid has an unsupported field: "+str(key))
	if not Hearth20Contracts._integer_number(value.get("schema")) or value.schema!=1:return _error("Unsupported embedded grid schema.")
	var width: Variant=value.get("width_cells")
	if not Hearth20Contracts._integer_number(width) or width<1 or width>256:return _error("Embedded map width must be 1 to 256 cells.")
	var feet: Variant=value.get("feet_per_cell",5.0)
	if not Hearth20Contracts._finite_number(feet) or feet<=0 or feet>1000:return _error("Embedded grid scale is invalid.")
	var cell_pixels := float(dimensions.x)/float(width)
	var height := ceili(float(dimensions.y)/cell_pixels)
	if height<1 or height>256:return _error("Embedded map height exceeds 256 cells at this scale.")
	if value.has("height_cells"):
		if not Hearth20Contracts._integer_number(value.height_cells) or value.height_cells!=height:
			return _error("Embedded cell counts do not match the image aspect ratio.")
	for pair in [["pixel_width",dimensions.x],["pixel_height",dimensions.y]]:
		if value.has(pair[0]) and (not Hearth20Contracts._integer_number(value[pair[0]]) or value[pair[0]]!=pair[1]):
			return _error("Embedded pixel dimensions are stale; stamp the resized image again.")
	return {"ok":true,"grid":{"width_cells":int(width),"height_cells":height,"feet_per_cell":float(feet),"source":"embedded-png"}}

static func crc32(bytes: PackedByteArray) -> int:
	var result := 0xffffffff
	for byte in bytes:
		result=result^int(byte)
		for bit in 8:result=(result>>1)^(0xedb88320 if (result&1)!=0 else 0)
	return (result^0xffffffff)&0xffffffff

static func _error(message: String) -> Dictionary:
	return {"ok":false,"error":"Map metadata: "+message+" Re-export the generated map or remove its Hearth20.Map text record to calibrate manually."}
