extends RefCounted
class_name Hearth20PdfReader
## Read PDF field dictionaries, including orphaned D&D Beyond widgets.
## No PDF actions, scripts, links, attachments or appearance programs execute.
const MAX_FILE=24000000
const MAX_STREAM=12000000
var bytes=PackedByteArray()
var pos=0
var objects={}
var budget=0
var decoded_total:=0
var began:=0
const TOTAL_DECODED=96000000

func matches(pattern: String,text: String) -> Array:
	var regex=RegEx.new();regex.compile(pattern);return regex.search_all(text)

func read(path: String) -> Dictionary:
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:return {"ok":false,"error":"Could not open that PDF."}
	if file.get_length()>MAX_FILE:return {"ok":false,"error":"Use a character-sheet PDF smaller than 24 MB."}
	var raw=file.get_buffer(file.get_length());file.close()
	if raw.slice(0,5).get_string_from_ascii()!="%PDF-":return {"ok":false,"error":"That file is not a PDF character sheet."}
	# A one-byte-per-character index keeps regex offsets aligned with file bytes.
	var safe=raw.duplicate();var zero=safe.find(0)
	while zero>=0:safe[zero]=1;zero=safe.find(0,zero+1)
	var index=safe.get_string_from_ascii()
	if not matches("/Encrypt\\b",index).is_empty():return {"ok":false,"error":"This PDF is encrypted. Export an unprotected character sheet from Beyond."}
	objects={};budget=0;decoded_total=0;began=Time.get_ticks_msec()
	for match_obj in matches("(?m)([0-9]+)\\s+[0-9]+\\s+obj\\b",index):
		if objects.size()>24000 or Time.get_ticks_msec()-began>8000:return {"ok":false,"error":"This PDF is too complex. Use the original Beyond PDF export."}
		bytes=raw;pos=match_obj.get_end();var value=parse_value()
		var record={"value":value,"stream":PackedByteArray()}
		skip_space()
		if value is Dictionary and raw.slice(pos,pos+6).get_string_from_ascii()=="stream":
			pos+=6
			if pos<raw.size() and raw[pos]==13:pos+=1
			if pos<raw.size() and raw[pos]==10:pos+=1
			var length=value.get("Length",0)
			if length is float or length is int:
				if length>0 and length<=MAX_FILE and pos+int(length)<=raw.size():record.stream=raw.slice(pos,pos+int(length))
			else:
				var end=index.find("endstream",pos)
				if end>pos and end-pos<=MAX_FILE:record.stream=raw.slice(pos,end)
		objects[int(match_obj.get_string(1))]=record
	# PDF 1.5+ may place field dictionaries in compressed object streams.
	for id in objects.keys():
		var obj=objects[id].value
		if not obj is Dictionary or obj.get("Type","")!="ObjStm":continue
		var unpacked=decode_stream(objects[id]);var first=int(obj.get("First",0));var count=int(obj.get("N",0))
		if first<=0 or first>=unpacked.size() or count>24000:continue
		var header=unpacked.slice(0,first).get_string_from_ascii();var numbers=matches("[0-9]+",header)
		for i in mini(count,int(numbers.size()/2)):
			bytes=unpacked;pos=first+int(numbers[i*2+1].get_string())
			objects[int(numbers[i*2].get_string())]={"value":parse_value(),"stream":PackedByteArray()}
	if budget>2000000:return {"ok":false,"error":"The PDF object data exceeds the supported complexity limit."}
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(raw);var source_sha:=digest.finish().hex_encode()
	var fields={};var conflicts=[];var positions: Dictionary={};var total_text:=0
	for id in objects:
		var obj=objects[id].value
		if not obj is Dictionary:continue
		var parent=resolve(obj.get("Parent",{})); var name=resolve(obj.get("T",parent.get("T","") if parent is Dictionary else ""));var value=resolve(obj.get("V",null))
		if value==null and parent is Dictionary:value=resolve(parent.get("V",null))
		if not name is String or name.is_empty():continue
		if obj.get("Rect") is Array and obj.Rect.size()==4:
			positions[name]={"rect":obj.Rect,"page":int(obj.get("P",{}).get("ref",0)) if obj.get("P",{}) is Dictionary else 0}
		if value is Array and value.all(func(item):return item is String):value="\n".join(value)
		if value is String or value is int or value is float or value is bool:
			var clean=str(value).strip_edges()
			if clean.is_empty():continue
			if fields.has(name) and fields[name]!=clean:conflicts.append(name)
			elif not fields.has(name):
				if fields.size()>=4096 or clean.length()>32000 or total_text+clean.length()>750000:return {"ok":false,"error":"The sheet contains too much field text. Use a smaller original PDF export."}
				fields[name]=clean;total_text+=clean.length()

	if fields.is_empty():return {"ok":false,"error":"No readable character fields found. Use Beyond’s Export to PDF file. Scanned pages and flattened Print to PDF copies are not supported."}
	return {"ok":true,"fields":fields,"field_count":fields.size(),"conflicts":conflicts,"positions":positions,"portraits":portraits(),"sha256":source_sha}

func decode_stream(record: Dictionary) -> PackedByteArray:
	var filters: Variant=record.value.get("Filter",[])
	if filters is String: filters=[filters]
	if not filters is Array:return PackedByteArray()
	var data: PackedByteArray=record.stream
	for filter in filters:
		if decoded_total>TOTAL_DECODED:return PackedByteArray()
		if filter in ["FlateDecode","Fl"]:data=data.decompress_dynamic(MAX_STREAM,FileAccess.COMPRESSION_DEFLATE)
		elif filter in ["ASCII85Decode","A85"]:data=ascii85(data)
		else:return PackedByteArray()
		decoded_total+=data.size()
		if data.is_empty() or data.size()>MAX_STREAM:return PackedByteArray()
	return data
func ascii85(data: PackedByteArray) -> PackedByteArray:
	var result:=PackedByteArray();var group:=0;var count:=0;var offset:=2 if data.size()>1 and data[0]==60 and data[1]==126 else 0
	for i in range(offset,data.size()):
		var c:=int(data[i])
		if c in [0,9,10,12,13,32]:continue
		if c==126:break
		if c==122 and count==0:result.append_array(PackedByteArray([0,0,0,0]));continue
		if c<33 or c>117:return PackedByteArray()
		group=group*85+c-33;count+=1
		if count==5:
			if group>4294967295:return PackedByteArray()
			for shift in [24,16,8,0]:result.append((group>>shift)&255)
			group=0;count=0
		if result.size()>MAX_STREAM:return PackedByteArray()
	if count==1:return PackedByteArray()
	if count>1:
		var size:=count
		while count<5:group=group*85+84;count+=1
		for j in size-1:result.append((group>>(24-j*8))&255)
	return result
func portraits() -> Array:
	var output: Array=[];var hashes: Dictionary={}
	for record in objects.values():
		var info: Variant=record.value
		if not info is Dictionary or info.get("Subtype","")!="Image" or (not info.get("ColorSpace","") is String or info.get("ColorSpace","")!="DeviceRGB") or int(info.get("BitsPerComponent",0))!=8:continue
		var w:=int(info.get("Width",0));var h:=int(info.get("Height",0))
		if w<96 or h<96 or w>2048 or h>2048 or float(w)/h<.6 or float(w)/h>1.6:continue
		var image: Image
		if info.get("Filter","") is String and info.get("Filter","")=="DCTDecode":
			image=Image.new()
			if image.load_jpg_from_buffer(record.stream)!=OK:continue
		else:
			var pixels:=decode_stream(record)
			if pixels.size()!=w*h*3:continue
			image=Image.create_from_data(w,h,false,Image.FORMAT_RGB8,pixels)
		if image==null or image.get_width()!=w or image.get_height()!=h:continue
		image.convert(Image.FORMAT_RGBA8)
		if info.has("SMask"):
			var mask_ref: Variant=info.SMask
			if mask_ref is Dictionary and mask_ref.has("ref") and objects.has(int(mask_ref.ref)):
				var mask:=decode_stream(objects[int(mask_ref.ref)])
				if mask.size()==w*h:
					var rgba:=image.get_data()
					for i in mask.size():rgba[i*4+3]=mask[i]
					image=Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,rgba)
		if maxi(w,h)>512:image.resize(roundi(w*512.0/maxi(w,h)),roundi(h*512.0/maxi(w,h)),Image.INTERPOLATE_LANCZOS)
		var png:=image.save_png_to_buffer();var key:=png.hex_encode().sha256_text()
		if not hashes.has(key):output.append(png);hashes[key]=true
		if output.size()>=4:break
	return output

func resolve(value,depth: int=0):
	if depth>12:return null
	if value is Dictionary and value.has("ref"):
		return resolve(objects.get(int(value.ref),{}).get("value",null),depth+1)
	return value

func skip_space():
	while pos<bytes.size():
		if bytes[pos] in [0,9,10,12,13,32]:pos+=1
		elif bytes[pos]==37:
			while pos<bytes.size() and bytes[pos] not in [10,13]:pos+=1
		else:break

func delimiter(value: int) -> bool:
	return value in [0,9,10,12,13,32,40,41,60,62,91,93,123,125,47,37]

func word() -> String:
	var start=pos
	while pos<bytes.size() and not delimiter(bytes[pos]):pos+=1
	return bytes.slice(start,pos).get_string_from_ascii()

func parse_value(depth: int=0):
	budget+=1
	if depth>32 or budget>2000000:return null
	skip_space()
	if pos>=bytes.size():return null
	var c=bytes[pos];pos+=1
	if c==40:
		var result=PackedByteArray();var nesting=1
		while pos<bytes.size() and nesting>0 and result.size()<MAX_STREAM:
			var b=bytes[pos];pos+=1
			if b==92:
				if pos>=bytes.size():break
				b=bytes[pos];pos+=1
				if b in [10,13]:
					if b==13 and pos<bytes.size() and bytes[pos]==10:pos+=1
					continue
				if b>=48 and b<=55:
					var octal=b-48;var n=1
					while n<3 and pos<bytes.size() and bytes[pos]>=48 and bytes[pos]<=55:octal=octal*8+bytes[pos]-48;pos+=1;n+=1
					result.append(octal%256);continue
				result.append({110:10,114:13,116:9,98:8,102:12}.get(b,b));continue
			if b==40:nesting+=1
			if b==41:nesting-=1
			if nesting>0:result.append(b)
		return decode_text(result)
	if c==60:
		if pos<bytes.size() and bytes[pos]==60:
			pos+=1;var result={}
			while pos<bytes.size() and result.size()<10000:
				skip_space()
				if pos+1<bytes.size() and bytes[pos]==62 and bytes[pos+1]==62:pos+=2;break
				var start=pos;var k=parse_value(depth+1)
				if not k is String or pos==start:break
				result[k]=parse_value(depth+1)
			return result
		var hex=""
		while pos<bytes.size() and bytes[pos]!=62:
			if bytes[pos] not in [9,10,12,13,32]:hex+=String.chr(bytes[pos])
			pos+=1
		pos+=1
		if hex.length()%2:hex+="0"
		return decode_text(hex.hex_decode())
	if c==91:
		var result=[]
		while pos<bytes.size() and result.size()<12000:
			skip_space()
			if pos>=bytes.size():break
			if bytes[pos]==93:pos+=1;break
			var start=pos;result.append(parse_value(depth+1))
			if pos==start:break
		return result
	if c==47:
		var name=word()
		for escape in matches("#[0-9A-Fa-f]{2}",name):name=name.replace(escape.get_string(),String.chr(escape.get_string().substr(1).hex_to_int()))
		return name
	pos-=1;var token=word()
	if token.is_empty():pos+=1;return null
	if token=="true":return true
	if token=="false":return false
	if token=="null":return null
	if token.is_valid_int():
		var saved=pos;skip_space();var generation=word();skip_space()
		if generation.is_valid_int() and pos<bytes.size() and bytes[pos]==82:pos+=1;return {"ref":int(token)}
		pos=saved;return int(token)
	if token.is_valid_float():return float(token)
	return token

func decode_text(data: PackedByteArray) -> String:
	if data.size()>=3 and data[0]==239 and data[1]==187 and data[2]==191:return data.slice(3).get_string_from_utf8()
	if data.size()>=2 and data[0]==254 and data[1]==255:
		var result="";var i=2
		while i+1<data.size():
			var code=int(data[i])*256+data[i+1];i+=2
			if code>=0xD800 and code<=0xDBFF and i+1<data.size():
				var low=int(data[i])*256+data[i+1]
				if low>=0xDC00 and low<=0xDFFF:code=0x10000+(code-0xD800)*1024+low-0xDC00;i+=2
			if code!=0:result+=String.chr(code)
		return result
	if data.size()>=2 and data[0]==255 and data[1]==254:return data.get_string_from_utf16()
	# PDFDocEncoding differs from Latin-1 in this punctuation range.
	var text=data.get_string_from_ascii()
	var specials={128:"•",129:"†",130:"‡",131:"…",132:"—",133:"–",134:"ƒ",135:"⁄",136:"‹",137:"›",138:"−",139:"‰",140:"„",141:"“",142:"”",143:"‘",144:"’",145:"‚",146:"™",147:"ﬁ",148:"ﬂ",149:"Ł",150:"Œ",151:"Š",152:"Ÿ",153:"Ž",154:"ı",155:"ł",156:"œ",157:"š",158:"ž",160:"€"}
	for value in specials:text=text.replace(String.chr(value),specials[value])
	return text
