extends RefCounted
class_name Hearth20MaskedImageCache
## Exact source + mask matches only. Never reuses an image for a different entitlement.
const BUDGET=96*1024*1024
static var entries={}
static var used=0
static var mutex=Mutex.new()
static func lookup(key: String,source: PackedByteArray) -> PackedByteArray:
	mutex.lock();var result=_lookup(key,source);mutex.unlock();return result
static func _lookup(key: String,source: PackedByteArray) -> PackedByteArray:
	var value=entries.get(key,{})
	if value.is_empty() or value.source!=source:return PackedByteArray()
	entries.erase(key);entries[key]=value;return value.result.duplicate()
static func put(key: String,source: PackedByteArray,result: PackedByteArray) -> void:
	mutex.lock();_put(key,source,result);mutex.unlock()
static func _put(key: String,source: PackedByteArray,result: PackedByteArray) -> void:
	var amount=source.size()+result.size()
	if amount>BUDGET or result.is_empty():return
	if entries.has(key):used-=int(entries[key].bytes);entries.erase(key)
	while not entries.is_empty() and (entries.size()>=4 or used+amount>BUDGET):
		var oldest=entries.keys()[0];used-=int(entries[oldest].bytes);entries.erase(oldest)
	entries[key]={"source":source.duplicate(),"result":result.duplicate(),"bytes":amount};used+=amount
