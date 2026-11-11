extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func png(color: Color) -> PackedByteArray:
	var image=Image.create(48,48,false,Image.FORMAT_RGBA8);image.fill(color);return image.save_png_to_buffer()
func run() -> void:
	var server=Hearth20SteamImages.new();var client=Hearth20SteamImages.new();var campaign=Hearth20Identity.new_campaign("Image reference fixture")
	var a=Hearth20Assets.store_asset(campaign,Hearth20Assets.inspect_token_png_bytes(png(Color.RED)),"token")
	var b=Hearth20Assets.store_asset(campaign,Hearth20Assets.inspect_token_png_bytes(png(Color.BLUE)),"token")
	var image=png(Color.GOLD)
	var view={"revision":1,"map_png":image,"map_sha256":Hearth20Contracts.sha256(image),"assets":campaign.assets.duplicate(true),"actors":[{"id":"a","asset_id":a},{"id":"b","asset_id":b}]}
	var first=server.encode(view);expect(first.map_png==image and first.assets.size()==2,"initial view includes its authorized images")
	var decoded=client.decode(first);expect(decoded.ok and decoded.snapshot.assets==view.assets and decoded.snapshot.map_png==image,"initial image references reconstruct exactly")
	server.remember(view,true);client.remember(decoded.snapshot)
	var cover=view.duplicate(true);cover.revision=2;cover.map_png=PackedByteArray();cover.map_sha256=Hearth20Contracts.sha256(cover.map_png);cover.assets={};cover.actors=[]
	var concealed=client.decode(server.encode(cover));expect(concealed.ok and concealed.snapshot.map_png.is_empty() and concealed.snapshot.assets.is_empty() and concealed.snapshot.actors.is_empty(),"covered live view contains no image or token")
	server.remember(cover,true);client.remember(concealed.snapshot)
	var reveal=server.encode(view)
	expect(reveal.get("map_cached",false) and reveal.map_png.is_empty() and reveal.assets.is_empty(),"unchanged reveal sends zero map/PNG payload bytes")
	var restored=client.decode(reveal);expect(restored.ok and restored.snapshot.map_png==image and restored.snapshot.assets==view.assets,"authorized previous images restore without retransmission")
	var stowed=view.duplicate(true);stowed.assets.erase(a);stowed.actors.remove_at(0)
	var delta=server.encode(stowed);expect(delta.assets.is_empty() and delta.asset_ids==[b],"stowing a pawn does not resend other players' PNGs")
	var removed=client.decode(delta);expect(removed.ok and removed.snapshot.assets.keys()==[b] and removed.snapshot.actors.size()==1,"active view removes the stowed pawn and its image reference")
	var masked=view.duplicate(true);masked.map_png=png(Color.BLACK);masked.map_sha256=Hearth20Contracts.sha256(masked.map_png)
	var changed=server.encode(masked);expect(not changed.get("map_cached",false) and changed.map_png==masked.map_png,"a newly redacted map cannot reuse the previous map")
	server.remember(masked,true);client.remember(masked)
	expect(server.encode(view).get("map_cached",false),"returning to a recently authorized map reuses its exact image")
	var legacy=Hearth20SteamImages.new();legacy.protocol_version=1;legacy.remember(view,true);legacy.remember(masked,true)
	expect(not legacy.encode(view).get("map_cached",false),"legacy cache-v1 peers keep their original single-map behavior")
	var lit=view.duplicate(true);lit.scene={"id":"page-a","light_field":{"width":64,"height":64,"codec":"rgb8-deflate-v1","data":PackedByteArray([1,2,3,4])}}
	server.remember(lit,true);client.remember(lit)
	var dark=lit.duplicate(true);dark.scene={"id":"blackout"};dark.map_png=PackedByteArray();dark.map_sha256=Hearth20Contracts.sha256(dark.map_png);dark.assets={};dark.actors=[]
	server.remember(dark,true);client.remember(dark)
	var compact_lit=server.encode(lit)
	expect(compact_lit.get("light_cached",false) and compact_lit.scene.light_field.is_empty(),"reveal omits previously delivered lighting as well as the map")
	var decoded_lit=client.decode(compact_lit)
	expect(decoded_lit.ok and decoded_lit.snapshot.scene.light_field==lit.scene.light_field,"the exact retained authorized lighting is restored")
	var missing_light=compact_lit.duplicate(true);missing_light.light_field_digest="0".repeat(64)
	expect(not client.decode(missing_light).ok,"unknown lighting references fail closed")
	for n in 7:
		var map=png(Color(float(n)/7.,.4,.6));server.remember({"map_png":map,"map_sha256":Hearth20Contracts.sha256(map)},true)
	expect(server.maps.size()==Hearth20SteamImages.MAP_COUNT and server.maps_bytes<=Hearth20SteamImages.MAP_LIMIT,"retained map references have explicit count and byte budgets")
	server.remember(masked,true)
	var missing=delta.duplicate(true);missing.asset_ids=["sha256-"+"f".repeat(64)]
	expect(not client.decode(missing).ok,"unknown references cannot manufacture unseen assets")
	missing=delta.duplicate(true);missing.asset_ids=[b,b];expect(not client.decode(missing).ok,"duplicate references are rejected")
	missing=server.encode(masked);missing.map_sha256="0".repeat(64);expect(not client.decode(missing).ok,"map reuse requires the exact authorized digest")
	var large={"map_png":PackedByteArray(),"assets":{}}
	for n in 3:
		var digest=(str(n)+"a".repeat(63));large.assets["sha256-"+digest]={"sha256":digest,"byte_length":8388608}
	server.clear();server.remember(large,true);expect(server.asset_bytes<=Hearth20SteamImages.ASSET_LIMIT and server.assets.size()==2,"historical token references are bounded by bytes")
	server.clear()
	for n in 70:
		var digest=Hearth20Contracts.sha256(str(n).to_utf8_buffer());server.remember({"assets":{"sha256-"+digest:{"sha256":digest,"byte_length":10}}},true)
	expect(server.assets.size()==64,"historical references are bounded by count")
	server.clear();client.clear();expect(server.assets.is_empty() and client.assets.is_empty() and client.map_bytes.is_empty(),"disconnect can clear every retained image")
	var chunks=Hearth20SteamChunks.new();var job=Hearth20SteamChunks.make_job("x".repeat(70000),"snapshot");var frame=Hearth20SteamChunks.frame(job)
	expect(chunks.accept(1,frame,"snapshot").ok and chunks.reserved>0,"large in-flight transfer begins")
	expect(chunks.cancel(1,job.id) and chunks.reserved==0,"superseding a transfer releases its buffered bytes")
	expect(chunks.accept(1,frame,"snapshot").get("replayed",false),"cancelled late frames cannot resurrect old board state")
	expect(not chunks.cancel(1,"invalid"),"cancellation accepts only bounded transfer IDs")
	var session=Hearth20Session.new();root.add_child(session);session.configure(Hearth20Identity.new_campaign("Real inn image reuse"))
	expect(session.load_sample_map("lantern-larch-inn",false).ok,"real sample inn loads into the data-only fixture")
	var original=session._project_for("image-reuse-player");var known=Hearth20SteamImages.new();known.remember(original,true)
	session.set_blackout(true);known.remember(session._project_for("image-reuse-player"),true)
	var began=Time.get_ticks_usec();session.set_blackout(false);var unmasked=session._project_for("image-reuse-player");var elapsed=Time.get_ticks_usec()-began
	var compact=known.encode(unmasked)
	expect(compact.get("map_cached",false) and compact.map_png.is_empty() and compact.assets.is_empty(),"real lit inn reveal uses references instead of map/token payloads")
	expect(var_to_bytes(compact).size()<var_to_bytes(original).size()/4,"real sample's reveal payload shrinks by more than fourfold")
	print("INN REVEAL initial_bytes=",var_to_bytes(original).size()," reference_bytes=",var_to_bytes(compact).size()," prepare_usec=",elapsed)
	session.queue_free();await process_frame
	print("Steam image references: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
