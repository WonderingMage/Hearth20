extends RefCounted
class_name Hearth20SteamChunks
## Only data is decoded. Object deserialization and arbitrary remote calls are never allowed.
const CHUNK=32768
const LIMIT=64*1024*1024
const MEMORY_LIMIT=128*1024*1024
const IDLE_MSEC=45000
var incoming={}
var completed={}
var reserved=0
static func make_job(value: Variant,kind: String,limit=LIMIT) -> Dictionary:
	var data=var_to_bytes(value)
	if kind not in ["snapshot","character"] or data.is_empty() or data.size()>limit:return {}
	return {"id":"transfer-"+Crypto.new().generate_random_bytes(12).hex_encode(),"kind":kind,"size":data.size(),"sha256":Hearth20Contracts.sha256(data),"count":ceili(float(data.size())/CHUNK),"next":0,"data":data,"started":Time.get_ticks_msec()}
static func frame(job: Dictionary) -> Dictionary:
	var meta={}
	for field in ["id","kind","size","sha256","count"]:meta[field]=job[field]
	meta.index=job.next
	return {"_h20_transfer":meta,"bytes":job.data.slice(int(job.next)*CHUNK,mini(int(job.size),(int(job.next)+1)*CHUNK))}
func accept(peer: int,packet: Dictionary,kind: String,limit=LIMIT,now=-1) -> Dictionary:
	if now<0:now=Time.get_ticks_msec()
	var meta=packet.get("_h20_transfer");var bytes=packet.get("bytes")
	if not meta is Dictionary or not bytes is PackedByteArray:return _bad("Invalid transfer frame.")
	for field in ["index","size","count"]:
		if not meta.get(field) is int:return _bad("Invalid transfer counters.")
	if not Hearth20Contracts.valid_identifier(meta.get("id")) or meta.get("kind")!=kind:return _bad("Invalid transfer identity.")
	if not meta.id.begins_with("transfer-") or meta.id.length()!=33 or not meta.id.substr(9).is_valid_hex_number(false):return _bad("Invalid transfer identifier.")
	if not meta.get("sha256") is String or meta.sha256.length()!=64 or not meta.sha256.is_valid_hex_number(false):return _bad("Invalid transfer checksum.")
	if meta.size<1 or meta.size>limit or meta.count!=ceili(float(meta.size)/CHUNK) or meta.index<0 or meta.index>=meta.count:return _bad("Transfer exceeds its bounds.")
	var expected=mini(CHUNK,meta.size-meta.index*CHUNK)
	if bytes.size()!=expected:return _bad("Transfer chunk has the wrong length.")
	var key=str(peer)+":"+str(meta.id)
	if completed.has(key):return {"ok":true,"complete":false,"replayed":true}
	if not incoming.has(key):
		if incoming.values().any(func(value):return value.peer==peer):return _bad("Another transfer is already in progress.")
		if meta.index!=0 or incoming.size()>=10 or reserved+meta.size>MEMORY_LIMIT:return _bad("Transfer could not begin.")
		incoming[key]={"peer":peer,"meta":meta.duplicate(),"data":PackedByteArray(),"next":0,"updated":now};reserved+=meta.size
	var stream: Dictionary=incoming[key]
	for field in ["id","kind","size","sha256","count"]:
		if stream.meta[field]!=meta[field]:_discard(key);return _bad("Transfer information changed.")
	if meta.index!=stream.next:_discard(key);return _bad("Transfer chunks arrived out of order.")
	stream.data.append_array(bytes);stream.next+=1;stream.updated=now
	var progress=float(stream.data.size())/float(meta.size)
	if stream.next<int(meta.count):return {"ok":true,"complete":false,"progress":progress}
	var data: PackedByteArray=stream.data;_discard(key);completed[key]=now
	while completed.size()>128:completed.erase(completed.keys()[0])
	if Hearth20Contracts.sha256(data)!=meta.sha256:return _bad("Transfer checksum did not match.")
	var value=bytes_to_var(data)
	if value==null:return _bad("Transfer did not contain campaign data.")
	return {"ok":true,"complete":true,"progress":1.,"value":value}
func expire(now=-1) -> Array:
	if now<0:now=Time.get_ticks_msec()
	var peers=[]
	for key in incoming.keys():
		if now-int(incoming[key].updated)>IDLE_MSEC:peers.append(incoming[key].peer);_discard(key)
	for key in completed.keys():
		if now-int(completed[key])>IDLE_MSEC:completed.erase(key)
	return peers
func clear_peer(peer: int) -> void:
	for key in incoming.keys():
		if incoming[key].peer==peer:_discard(key)
	for key in completed.keys():
		if key.begins_with(str(peer)+":"):completed.erase(key)
func cancel(peer: int,id: String) -> bool:
	if not id.begins_with("transfer-") or id.length()!=33 or not id.substr(9).is_valid_hex_number(false):return false
	var key=str(peer)+":"+id;_discard(key);completed[key]=Time.get_ticks_msec()
	while completed.size()>128:completed.erase(completed.keys()[0])
	return true
func clear() -> void:incoming.clear();completed.clear();reserved=0
func _discard(key: String) -> void:
	if incoming.has(key):reserved-=int(incoming[key].meta.size);incoming.erase(key)
func _bad(message: String) -> Dictionary:return {"ok":false,"complete":false,"error":message}
