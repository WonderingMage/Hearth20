extends RefCounted
class_name Hearth20PlayerProfile
## Local signing identity. Only the public key is stored in a campaign or sent.
const ROOT := "user://hearth20/profile"
const KEY_PATH := ROOT+"/player.key"
const SETTINGS_PATH := ROOT+"/display.cfg"
static var cached_key: CryptoKey

static func key() -> CryptoKey:
	if cached_key!=null: return cached_key
	var loaded:=CryptoKey.new()
	if FileAccess.file_exists(KEY_PATH):
		if loaded.load(KEY_PATH)!=OK or loaded.is_public_only(): return null
		cached_key=loaded; return loaded
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	loaded=Crypto.new().generate_rsa(2048)
	if loaded==null or loaded.save(KEY_PATH)!=OK: return null
	cached_key=loaded
	return loaded

static func public_key() -> String:
	var identity:=key()
	return identity.save_to_string(true) if identity!=null else ""

static func principal(public_pem: String) -> String:
	return "player-"+public_pem.sha256_text().left(24)

static func challenge_hash(nonce: PackedByteArray, public_pem: String) -> PackedByteArray:
	var digest:=HashingContext.new(); digest.start(HashingContext.HASH_SHA256)
	digest.update("HEARTH20-PLAYER-PROOF-v1\n".to_utf8_buffer())
	digest.update(nonce); digest.update(public_pem.to_utf8_buffer())
	return digest.finish()

static func sign(nonce: PackedByteArray) -> PackedByteArray:
	var identity:=key()
	return Crypto.new().sign(HashingContext.HASH_SHA256,challenge_hash(nonce,identity.save_to_string(true)),identity) if identity!=null else PackedByteArray()

static func valid_public(public_pem: String) -> bool:
	if public_pem.length()<100 or public_pem.length()>1024 or not public_pem.begins_with("-----BEGIN PUBLIC KEY-----"): return false
	var parsed:=CryptoKey.new()
	return parsed.load_from_string(public_pem,true)==OK and parsed.is_public_only() and parsed.save_to_string(true)==public_pem

static func verify(nonce: PackedByteArray, public_pem: String, signature: PackedByteArray) -> bool:
	if nonce.size()!=32 or signature.size()!=256 or not valid_public(public_pem): return false
	var parsed:=CryptoKey.new(); parsed.load_from_string(public_pem,true)
	return Crypto.new().verify(HashingContext.HASH_SHA256,challenge_hash(nonce,public_pem),signature,parsed)

static func preferences() -> Dictionary:
	var config:=ConfigFile.new(); config.load(SETTINGS_PATH)
	return {"display_name":str(config.get_value("player","display_name","")).left(40),"address":str(config.get_value("player","address","")).left(255),"port":int(config.get_value("player","port",28930))}

static func remember(display_name: String, address: String, port: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var config:=ConfigFile.new(); config.load(SETTINGS_PATH)
	config.set_value("player","display_name",display_name.strip_edges().left(40))
	config.set_value("player","address",address.strip_edges().left(255))
	config.set_value("player","port",port)
	config.save(SETTINGS_PATH)

static func valid_participants(value: Variant) -> bool:
	if not value is Dictionary or value.size()>256: return false
	for id in value:
		var entry: Variant=value[id]
		if not entry is Dictionary or not entry.get("public_key") is String or not valid_public(entry.public_key): return false
		if id!=principal(entry.public_key) or not entry.get("display_name") is String or entry.display_name.strip_edges().is_empty() or entry.display_name.length()>40: return false
	return true

static func dice_set() -> String:
	var config:=ConfigFile.new(); config.load(SETTINGS_PATH)
	var id: Variant=config.get_value("player","dice_set","set-1")
	return str(id) if Hearth20DiceSets.valid(id,true) else "set-1"
static func remember_dice_set(id: String) -> void:
	if not Hearth20DiceSets.valid(id,true): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var config:=ConfigFile.new(); config.load(SETTINGS_PATH); config.set_value("player","dice_set",id); config.save(SETTINGS_PATH)
