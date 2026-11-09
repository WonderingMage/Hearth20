extends RefCounted
class_name Hearth20Assets
## Bounded image import. Token overrides retain the original PNG bytes exactly.

const MAP_MAX_BYTES := 40 * 1024 * 1024
const MAP_MAX_SIDE := 16384
const MAP_MAX_PIXELS := 67_108_864
const TOKEN_MAX_BYTES := 8 * 1024 * 1024
const TOKEN_MAX_SIDE := 2048
const TOKEN_MAX_PIXELS := 4_194_304
const PNG_SIGNATURE := [137, 80, 78, 71, 13, 10, 26, 10]
static var validated_cache={}
static var validated_bytes=0
static var cache_mutex=Mutex.new()
const CACHE_BUDGET=64*1024*1024

static func inspect_map_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Map image does not exist."}
	var bytes := _read_image_file(path,MAP_MAX_BYTES)
	if bytes.is_empty() or bytes.size() > MAP_MAX_BYTES:
		return {"ok": false, "error": "Map image must be at most 40 MiB."}
	var header_dimensions := _map_dimensions_from_header(bytes)
	if header_dimensions == Vector2i.ZERO:
		return {"ok": false, "error": "Map image must have a readable PNG or JPEG header."}
	if not _dimensions_ok_values(header_dimensions.x, header_dimensions.y, MAP_MAX_SIDE, MAP_MAX_PIXELS):
		return {"ok": false, "error": "Map image dimensions exceed the declared 16,384-side or 67,108,864-pixel limit."}
	var image := Image.new()
	var error=image.load_png_from_buffer(bytes) if bytes.slice(0,8)==PackedByteArray(PNG_SIGNATURE) else image.load_jpg_from_buffer(bytes)
	if error != OK:
		return {"ok": false, "error": "Could not decode the selected map image."}
	if image.get_width() != header_dimensions.x or image.get_height() != header_dimensions.y or not _dimensions_ok(image, MAP_MAX_SIDE, MAP_MAX_PIXELS):
		return {"ok": false, "error": "Map image dimensions exceed the declared 16,384-side or 67,108,864-pixel limit."}
	var png := image.save_png_to_buffer()
	if png.is_empty() or png.size() > MAP_MAX_BYTES:
		return {"ok": false, "error": "Decoded map image could not be stored within the image limit."}
	return {"ok": true, "bytes": png, "sha256": sha256(png), "width": image.get_width(), "height": image.get_height(), "mime_type": "image/png", "original_name": path.get_file().left(128)}

static func inspect_token_png(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Token PNG does not exist."}
	return inspect_token_png_bytes(_read_image_file(path,TOKEN_MAX_BYTES), path.get_file())

static func _read_image_file(path: String,limit: int) -> PackedByteArray:
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:return PackedByteArray()
	var length=file.get_length()
	if length<1 or length>limit:return PackedByteArray()
	var bytes=file.get_buffer(length)
	return bytes if bytes.size()==length else PackedByteArray()

static func inspect_token_png_bytes(bytes: PackedByteArray, name: String = "token.png") -> Dictionary:
	if bytes.size() < PNG_SIGNATURE.size() or bytes.size() > TOKEN_MAX_BYTES or bytes.slice(0, PNG_SIGNATURE.size()) != PackedByteArray(PNG_SIGNATURE):
		return {"ok": false, "error": "Token override must be a valid PNG of at most 8 MiB."}
	var header_dimensions := _png_dimensions(bytes)
	if header_dimensions == Vector2i.ZERO:
		return {"ok": false, "error": "Token PNG header is incomplete or invalid."}
	if not _dimensions_ok_values(header_dimensions.x, header_dimensions.y, TOKEN_MAX_SIDE, TOKEN_MAX_PIXELS):
		return {"ok": false, "error": "Token PNG exceeds 2,048 pixels per side or 4,194,304 total pixels."}
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return {"ok": false, "error": "Token PNG is truncated or could not be decoded."}
	if image.get_width() != header_dimensions.x or image.get_height() != header_dimensions.y or not _dimensions_ok(image, TOKEN_MAX_SIDE, TOKEN_MAX_PIXELS):
		return {"ok": false, "error": "Token PNG exceeds 2,048 pixels per side or 4,194,304 total pixels."}
	var digest := sha256(bytes)
	return {"ok": true, "bytes": bytes, "sha256": digest, "width": image.get_width(), "height": image.get_height(), "mime_type": "image/png", "name": name.get_file().left(128), "asset_id": "sha256-" + digest, "image": image}

static func store_asset(campaign: Dictionary, inspected: Dictionary, kind: String) -> String:
	if not inspected.get("ok", false) or kind not in ["map", "token"]:
		return ""
	var bytes: PackedByteArray = inspected.bytes
	var digest := sha256(bytes)
	var asset_id := "sha256-" + digest
	campaign.assets[asset_id] = {
		"kind": kind,
		"mime_type": str(inspected.get("mime_type","image/png")),
		"width": int(inspected.width),
		"height": int(inspected.height),
		"sha256": digest,
		"base64": Marshalls.raw_to_base64(bytes),
		"byte_length": bytes.size(),
	}
	return asset_id

static func read_asset(campaign: Dictionary, asset_id: String, expected_kind: String = "") -> PackedByteArray:
	cache_mutex.lock()
	var bytes=_read_asset(campaign,asset_id,expected_kind)
	cache_mutex.unlock()
	return bytes

static func _read_asset(campaign: Dictionary, asset_id: String, expected_kind: String) -> PackedByteArray:
	var record: Variant = campaign.get("assets", {}).get(asset_id, null)
	if not record is Dictionary or record.get("kind", "") not in ["map", "token"] or (not expected_kind.is_empty() and record.get("kind", "") != expected_kind):
		return PackedByteArray()
	if validated_cache.has(asset_id) and validated_cache[asset_id].record==record:
		var cached=validated_cache[asset_id];validated_cache.erase(asset_id);validated_cache[asset_id]=cached
		return cached.bytes.duplicate()
	var kind := str(record.get("kind", ""))
	var byte_limit := TOKEN_MAX_BYTES if kind == "token" else MAP_MAX_BYTES
	var byte_length := int(record.get("byte_length", -1))
	var encoded := str(record.get("base64", ""))
	var mime:=str(record.get("mime_type",""))
	if (mime!="image/png" and (kind!="map" or mime!="image/webp")) or byte_length < 1 or byte_length > byte_limit or encoded.length() != ceili(float(byte_length) / 3.0) * 4:
		return PackedByteArray()
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.size() != int(record.byte_length) or sha256(bytes) != str(record.get("sha256", "")) or "sha256-" + sha256(bytes) != asset_id:
		return PackedByteArray()
	if kind == "token":
		var checked := inspect_token_png_bytes(bytes)
		if not checked.ok or int(record.get("width", -1)) != int(checked.width) or int(record.get("height", -1)) != int(checked.height):
			return PackedByteArray()
	else:
		var dimensions := _webp_dimensions(bytes) if mime=="image/webp" else _png_dimensions(bytes)
		if not _dimensions_ok_values(dimensions.x, dimensions.y, MAP_MAX_SIDE, MAP_MAX_PIXELS) or int(record.get("width", -1)) != dimensions.x or int(record.get("height", -1)) != dimensions.y:
			return PackedByteArray()
		var image := decode_map(bytes)
		if image==null or image.get_width() != dimensions.x or image.get_height() != dimensions.y:
			return PackedByteArray()
	if validated_cache.has(asset_id):validated_bytes-=validated_cache[asset_id].bytes.size();validated_cache.erase(asset_id)
	while not validated_cache.is_empty() and (validated_cache.size()>=32 or validated_bytes+bytes.size()>CACHE_BUDGET):
		var oldest=validated_cache.keys()[0];validated_bytes-=validated_cache[oldest].bytes.size();validated_cache.erase(oldest)
	if bytes.size()<=CACHE_BUDGET:
		validated_cache[asset_id]={"record":record.duplicate(true),"bytes":bytes.duplicate()};validated_bytes+=bytes.size()
	return bytes

static func decode_map(bytes: PackedByteArray) -> Image:
	var webp:=bytes.size()>20 and bytes.slice(8,12).get_string_from_ascii()=="WEBP"
	var dimensions:=_webp_dimensions(bytes) if webp else _png_dimensions(bytes)
	if not _dimensions_ok_values(dimensions.x,dimensions.y,MAP_MAX_SIDE,MAP_MAX_PIXELS): return null
	var image:=Image.new()
	var error:=image.load_webp_from_buffer(bytes) if webp else image.load_png_from_buffer(bytes)
	if error!=OK or image.get_size()!=dimensions: return null
	image.convert(Image.FORMAT_RGBA8)
	return image

static func _webp_dimensions(bytes: PackedByteArray) -> Vector2i:
	if bytes.size()<30 or bytes.slice(0,4).get_string_from_ascii()!="RIFF" or bytes.slice(8,12).get_string_from_ascii()!="WEBP" or bytes.decode_u32(4)+8!=bytes.size(): return Vector2i.ZERO
	var declared:=Vector2i.ZERO
	var frame:=Vector2i.ZERO
	var offset:=12
	while offset+8<=bytes.size():
		var kind:=bytes.slice(offset,offset+4).get_string_from_ascii()
		var length:=int(bytes.decode_u32(offset+4))
		var p:=offset+8
		if length<0 or p+length>bytes.size() or kind in ["ANIM","ANMF"]: return Vector2i.ZERO
		if kind=="VP8X":
			if length!=10 or (int(bytes[p])&2)!=0: return Vector2i.ZERO
			declared=Vector2i(1+int(bytes[p+4])+(int(bytes[p+5])<<8)+(int(bytes[p+6])<<16),1+int(bytes[p+7])+(int(bytes[p+8])<<8)+(int(bytes[p+9])<<16))
		if kind=="VP8 ":
			if frame!=Vector2i.ZERO or length<10 or bytes[p+3]!=0x9d or bytes[p+4]!=0x01 or bytes[p+5]!=0x2a: return Vector2i.ZERO
			frame=Vector2i((int(bytes[p+6])+(int(bytes[p+7])<<8))&0x3fff,(int(bytes[p+8])+(int(bytes[p+9])<<8))&0x3fff)
		if kind=="VP8L":
			if frame!=Vector2i.ZERO or length<5 or bytes[p]!=0x2f: return Vector2i.ZERO
			var bits:=int(bytes.decode_u32(p+1))
			frame=Vector2i(1+(bits&0x3fff),1+((bits>>14)&0x3fff))
		offset=p+length+(length%2)
	if offset!=bytes.size() or frame==Vector2i.ZERO or (declared!=Vector2i.ZERO and declared!=frame): return Vector2i.ZERO
	return frame

static func attach_token_override(campaign: Dictionary, actor_id: String, bytes: PackedByteArray, name: String = "token.png") -> Dictionary:
	var actor := Hearth20Contracts.find_actor(campaign, actor_id)
	if actor.is_empty():
		return {"ok": false, "error": "Select a campaign token first."}
	var checked := inspect_token_png_bytes(bytes, name)
	if not checked.ok:
		return checked
	var asset_id := store_asset(campaign, checked, "token")
	if asset_id.is_empty():
		return {"ok": false, "error": "Could not store the token image."}
	actor.png_asset_id = asset_id
	actor.png_sha256 = checked.sha256
	campaign.revision = int(campaign.get("revision", 0)) + 1
	return {"ok": true, "asset_id": asset_id, "sha256": checked.sha256, "width": checked.width, "height": checked.height, "byte_length": bytes.size()}

static func sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func _dimensions_ok(image: Image, max_side: int, max_pixels: int) -> bool:
	return image.get_width() > 0 and image.get_height() > 0 and image.get_width() <= max_side and image.get_height() <= max_side and image.get_width() * image.get_height() <= max_pixels

static func _dimensions_ok_values(width: int, height: int, max_side: int, max_pixels: int) -> bool:
	return width > 0 and height > 0 and width <= max_side and height <= max_side and width * height <= max_pixels

static func _map_dimensions_from_header(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray(PNG_SIGNATURE):
		return _png_dimensions(bytes)
	if bytes.size() >= 3 and bytes[0] == 255 and bytes[1] == 216 and bytes[2] == 255:
		return _jpeg_dimensions(bytes)
	return Vector2i.ZERO

static func _png_dimensions(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() < 24 or bytes.slice(0, 8) != PackedByteArray(PNG_SIGNATURE) or bytes.slice(12, 16).get_string_from_ascii() != "IHDR" or _u32_be(bytes, 8) != 13:
		return Vector2i.ZERO
	return Vector2i(_u32_be(bytes, 16), _u32_be(bytes, 20))

static func _jpeg_dimensions(bytes: PackedByteArray) -> Vector2i:
	var offset := 2
	while offset + 1 < bytes.size():
		if bytes[offset] != 255:
			offset += 1
			continue
		while offset < bytes.size() and bytes[offset] == 255:
			offset += 1
		if offset >= bytes.size():
			return Vector2i.ZERO
		var marker := int(bytes[offset])
		offset += 1
		if marker == 0xD9 or marker == 0xDA:
			return Vector2i.ZERO
		if marker == 0xD8 or marker == 0x01 or (marker >= 0xD0 and marker <= 0xD7):
			continue
		if offset + 2 > bytes.size():
			return Vector2i.ZERO
		var segment_length := (int(bytes[offset]) << 8) | int(bytes[offset + 1])
		if segment_length < 2 or offset + segment_length > bytes.size():
			return Vector2i.ZERO
		if marker in [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF]:
			if segment_length < 7:
				return Vector2i.ZERO
			var height := (int(bytes[offset + 3]) << 8) | int(bytes[offset + 4])
			var width := (int(bytes[offset + 5]) << 8) | int(bytes[offset + 6])
			return Vector2i(width, height)
		offset += segment_length
	return Vector2i.ZERO

static func _u32_be(bytes: PackedByteArray, offset: int) -> int:
	return (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) | (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3])
