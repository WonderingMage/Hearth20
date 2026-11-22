extends RefCounted
class_name Hearth20TokenGif
## Bounded GIF89a decoding for transparent, looping token art.

const MAX_SIDE := 512
const MAX_FRAMES := 120
const MAX_FRAME_PIXELS := 8 * 1024 * 1024
const MAX_BYTES := 8 * 1024 * 1024
const INVALID := "GIF token is malformed or exceeds 512 pixels per side, 120 frames, or 8 MiB. Try a smaller animation."

var data: PackedByteArray
var offset := 0

static func is_gif(bytes: PackedByteArray) -> bool:
	return bytes.size()>=6 and bytes.slice(0,6).get_string_from_ascii() in ["GIF87a","GIF89a"]

static func inspect(bytes: PackedByteArray, keep_images := false) -> Dictionary:
	if not is_gif(bytes) or bytes.size()<14 or bytes.size()>MAX_BYTES:return {"ok":false,"error":INVALID}
	var decoder:=Hearth20TokenGif.new()
	decoder.data=bytes
	var clip:=decoder._read(keep_images)
	return {"ok":false,"error":INVALID} if clip.is_empty() else clip

func _read(keep_images: bool) -> Dictionary:
	var width := _word(6)
	var height := _word(8)
	if width<1 or height<1 or width>MAX_SIDE or height>MAX_SIDE:return {}
	var flags: int=data[10]
	var background_index: int=data[11]
	offset=13
	var global_colors := _palette(flags)
	if (flags & 128)!=0 and global_colors.is_empty():return {}
	var canvas: Image
	var transparent_pixel := Color(0,0,0,0)
	var background := transparent_pixel
	var frames: Array[Image]=[]
	var delays:=PackedInt32Array()
	var transparent: int=-1
	var disposal: int=0
	var delay: int=100
	var extensions:=0
	while offset<data.size():
		var section: int=data[offset]
		offset+=1
		if section==0x3b:
			if delays.is_empty() or offset!=data.size():return {}
			return {"ok":true,"width":width,"height":height,"frames":frames,"delays":delays}
		if section==0x21:
			if offset>=data.size() or extensions>=1024:return {}
			extensions+=1
			var label: int=data[offset]
			offset+=1
			if label==0xf9:
				if offset+6>data.size() or data[offset]!=4 or data[offset+5]!=0:return {}
				var control: int=data[offset+1]
				var hundredths:=_word(offset+2)
				delay=clampi(hundredths*10,20,60000) if hundredths>0 else 100
				transparent=int(data[offset+4]) if (control&1)!=0 else -1
				disposal=(control>>2)&7
				offset+=6
			elif not _sub_blocks(false).ok:return {}
			continue
		if section!=0x2c or offset+9>data.size() or delays.size()>=MAX_FRAMES:return {}
		if (delays.size()+1)*width*height>MAX_FRAME_PIXELS:return {}
		var area:=Rect2i(_word(offset),_word(offset+2),_word(offset+4),_word(offset+6))
		flags=data[offset+8]
		offset+=9
		if area.size.x<1 or area.size.y<1 or area.end.x>width or area.end.y>height:return {}
		var colors:=_palette(flags) if (flags&128)!=0 else global_colors
		if colors.is_empty() or offset>=data.size() or transparent*3>=colors.size():return {}
		var minimum: int=data[offset]
		offset+=1
		var blocks:=_sub_blocks(true)
		if not blocks.ok:return {}
		@warning_ignore("integer_division")
		var indices:=_indices(blocks.bytes,minimum,area.size.x*area.size.y,colors.size()/3)
		if indices.is_empty():return {}
		if keep_images:
			if canvas==null:
				canvas=Image.create_empty(width,height,false,Image.FORMAT_RGBA8)
				if transparent<0 and background_index*3+2<global_colors.size():
					var start:=background_index*3
					background=Color8(global_colors[start],global_colors[start+1],global_colors[start+2])
				canvas.fill(background)
			var previous:=canvas.duplicate() as Image if disposal==3 else null
			var patch:=_patch_image(indices,colors,area.size,transparent,(flags&64)!=0)
			canvas.blit_rect_mask(patch,patch,Rect2i(Vector2i.ZERO,area.size),area.position)
			frames.append(canvas.duplicate() as Image)
			if disposal==2:canvas.fill_rect(area,transparent_pixel if transparent>=0 else background)
			elif disposal==3:canvas=previous
		delays.append(delay)
		transparent=-1;disposal=0;delay=100
	return {}

func _word(at: int) -> int:
	return int(data[at]) | (int(data[at+1])<<8)

func _palette(flags: int) -> PackedByteArray:
	if (flags&128)==0:return PackedByteArray()
	var end:=offset+(2<<(flags&7))*3
	if end>data.size():return PackedByteArray()
	var palette:=data.slice(offset,end)
	offset=end
	return palette

func _sub_blocks(collect: bool) -> Dictionary:
	var bytes:=PackedByteArray()
	while offset<data.size():
		var count: int=data[offset]
		offset+=1
		if count==0:return {"ok":true,"bytes":bytes}
		if offset+count>data.size():break
		if collect:bytes.append_array(data.slice(offset,offset+count))
		offset+=count
	return {"ok":false}

static func _indices(bytes: PackedByteArray, minimum: int, pixels: int, colors: int) -> PackedByteArray:
	if minimum<2 or minimum>8:return PackedByteArray()
	var clear:=1<<minimum
	var end:=clear+1
	var next:=end+1
	var width:=minimum+1
	var bit:=0
	var written:=0
	var previous: int=-1
	var first: int=0
	var result:=PackedByteArray()
	var stack:=PackedByteArray()
	var suffix:=PackedByteArray()
	var prefix:=PackedInt32Array()
	result.resize(pixels)
	stack.resize(4096);suffix.resize(4096);prefix.resize(4096)
	while bit+width<=bytes.size()*8:
		var at:=bit>>3
		var word: int=bytes[at]
		if at+1<bytes.size():word|=int(bytes[at+1])<<8
		if at+2<bytes.size():word|=int(bytes[at+2])<<16
		var code: int=(word>>(bit&7))&((1<<width)-1)
		bit+=width
		if code==clear:
			previous=-1;next=end+1;width=minimum+1
			continue
		if code==end:
			return result if written==pixels else PackedByteArray()
		var original:=code
		var depth:=0
		if code>=next:
			if code!=next or previous<0:return PackedByteArray()
			stack[depth]=first
			depth+=1
			code=previous
		while code>=clear:
			if code<=end or code>=next or depth>=4095:return PackedByteArray()
			stack[depth]=suffix[code]
			depth+=1
			code=prefix[code]
		if code>=colors or written+depth+1>pixels:return PackedByteArray()
		first=code
		result[written]=first
		written+=1
		for i in range(depth-1,-1,-1):
			result[written]=stack[i]
			written+=1
		if previous>=0 and next<4096:
			prefix[next]=previous
			suffix[next]=first
			next+=1
			if next==(1<<width) and width<12:width+=1
		previous=original
	return PackedByteArray()

static func _patch_image(indices: PackedByteArray, palette: PackedByteArray, size: Vector2i, transparent: int, interlaced: bool) -> Image:
	var rows:=PackedInt32Array()
	if interlaced:
		for pass_index in 4:
			for y in range([0,4,2,1][pass_index],size.y,[8,8,4,2][pass_index]):rows.append(y)
	else:
		rows=PackedInt32Array(range(size.y))
	var rgba:=PackedByteArray()
	rgba.resize(indices.size()*4)
	for row in size.y:
		var out:=rows[row]*size.x*4
		var start:=row*size.x
		for column in size.x:
			var index: int=indices[start+column]
			if index!=transparent:
				var rgb:=index*3
				rgba[out]=palette[rgb];rgba[out+1]=palette[rgb+1];rgba[out+2]=palette[rgb+2];rgba[out+3]=255
			out+=4
	return Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBA8,rgba)
