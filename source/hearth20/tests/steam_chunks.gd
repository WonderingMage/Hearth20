extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	var receiver=Hearth20SteamChunks.new()
	var bytes=PackedByteArray();bytes.resize(1536*1024);bytes.fill(73)
	var value={"map_png":bytes,"secret_test":"only the intended recipient","position":Vector2(4.5,5.5)}
	var job=Hearth20SteamChunks.make_job(value,"snapshot")
	expect(job.count>32 and job.size>1024*1024,"real map-sized data needs multiple Steam messages")
	var received={}
	for index in job.count:
		job.next=index;var packet=Hearth20SteamChunks.frame(job)
		expect(var_to_bytes(packet).size()<40000,"each framed message stays well below Steam's native limit")
		received=receiver.accept(1,packet,"snapshot",Hearth20SteamChunks.LIMIT,1000+index)
		expect(received.ok and received.complete==(index==job.count-1),"chunks expose data only once fully verified")
	expect(received.value==value and receiver.reserved==0 and receiver.incoming.is_empty(),"the exact image and state reconstruct, and buffers release")
	expect(receiver.accept(1,Hearth20SteamChunks.frame(job),"snapshot").get("replayed",false),"completed transfers cannot replay a snapshot")
	receiver.clear();job.next=0;var first=Hearth20SteamChunks.frame(job)
	for field in ["id","kind","size","count","index","sha256"]:
		var bad=first.duplicate(true);bad._h20_transfer[field]=-1 if field in ["size","count","index"] else "bad"
		expect(not receiver.accept(1,bad,"snapshot").ok,"reject invalid "+field+" before allocating")
	expect(receiver.reserved==0,"invalid headers consume no transfer memory")
	var cut=first.duplicate(true);cut.bytes=cut.bytes.slice(0,100)
	expect(not receiver.accept(1,cut,"snapshot").ok,"reject truncated chunks")
	expect(receiver.accept(1,first,"snapshot",Hearth20SteamChunks.LIMIT,2000).ok,"first valid chunk begins a bounded stream")
	var another=Hearth20SteamChunks.make_job(value,"snapshot");expect(not receiver.accept(1,Hearth20SteamChunks.frame(another),"snapshot").ok,"one peer cannot reserve unlimited parallel buffers")
	expect(not receiver.accept(1,first,"snapshot").ok and receiver.reserved==0,"out-of-order replay aborts and releases the stream")
	receiver.clear();expect(receiver.accept(1,first,"snapshot",Hearth20SteamChunks.LIMIT,3000).ok,"restart after cleanup")
	expect(receiver.expire(3000+Hearth20SteamChunks.IDLE_MSEC+1)==[1] and receiver.reserved==0,"stalled transfers expire and release memory")
	receiver.clear();receiver.accept(1,first,"snapshot");receiver.clear_peer(1);expect(receiver.incoming.is_empty() and receiver.reserved==0,"disconnect clears a peer's partial image")
	receiver.clear();var tampered=Hearth20SteamChunks.make_job({"name":"Aurelia"},"character");var frame=Hearth20SteamChunks.frame(tampered);frame.bytes[0]=frame.bytes[0]^1
	expect(not receiver.accept(7,frame,"character").ok,"payload corruption fails its complete checksum")
	expect(receiver.reserved==0,"corrupt streams release memory")
	var small=Hearth20SteamChunks.make_job([{"name":"Aurelia"},bytes],"character",2*1024*1024);var avatar={};receiver.clear()
	for i in small.count:small.next=i;avatar=receiver.accept(7,Hearth20SteamChunks.frame(small),"character",2*1024*1024)
	expect(avatar.complete and avatar.value[1]==bytes,"large character PNG upload retains the exact bytes")
	expect(Hearth20SteamChunks.make_job(value,"snapshot",1024).is_empty(),"sender refuses data over its declared bound")
	expect(Hearth20SteamChunks.make_job(value,"arbitrary-call").is_empty(),"transfer kinds never select arbitrary remote functions")
	print("Steam chunks: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
