extends RefCounted
class_name Hearth20SteamRate
## Steam's token-bucket rate is explicitly chosen. A high maximum alone does
## not guarantee that its initial RTT-based estimate will ever ramp up.
const START=4*1024*1024
const MINIMUM=64*1024
const MAXIMUM=64*1024*1024
const BUFFER=16*1024*1024
var target=START
var applied=0
var config_ok=false
var sample_msec=-1
var baseline_ping=-1.
var clean_samples=0
var last={}
var handle=-1
var apply_msec=-1000
func sample(status: Dictionary,busy: bool,connections: int,now: int) -> bool:
	var ceiling=maxi(MINIMUM,MAXIMUM/maxi(1,connections))
	if applied==0:target=maxi(MINIMUM,START/maxi(1,connections))
	target=mini(target,ceiling);last=status.duplicate()
	if sample_msec<0:sample_msec=now;return applied!=target
	if now-sample_msec<1000:return applied!=target
	sample_msec=now
	var ping=maxf(0.,float(status.get("ping",0)))
	if ping>0 and (baseline_ping<0 or ping<baseline_ping):baseline_ping=ping
	var quality=1.;var measured=false
	for key in ["local_quality","remote_quality"]:
		var value=float(status.get(key,-1.))
		if value>=0 and value<=1:quality=minf(quality,value);measured=true
	var rate=maxf(0.,float(status.get("bytes_out_per_second",0)))
	var inflated=baseline_ping>0 and ping>maxf(baseline_ping*1.8,baseline_ping+100.)
	if busy and ((measured and quality<.97) or inflated):
		target=maxi(MINIMUM,roundi(float(target)*.6));clean_samples=0
	elif busy and rate>=float(target)*.7 and (not measured or quality>=.99):
		clean_samples+=1
		if clean_samples>=1:target=mini(ceiling,maxi(target+65536,roundi(float(target)*1.5)));clean_samples=0
	else:clean_samples=0
	return applied!=target
func window_bytes() -> int:
	var rtt=maxf(0.,float(last.get("ping",50)))/1000.
	return clampi(roundi(float(target)*maxf(.1,rtt*2.))+524288,1024*1024,16*1024*1024)
func report() -> Dictionary:
	return {"requested_bps":target,"effective_bps":int(last.get("send_rate",0)),"out_bps":float(last.get("bytes_out_per_second",0)),"in_bps":float(last.get("bytes_in_per_second",0)),"pending_bytes":int(last.get("pending_reliable",0)),"unacknowledged_bytes":int(last.get("sent_unacknowledged_reliable",0)),"ping_ms":int(last.get("ping",0)),"local_quality":float(last.get("local_quality",-1)),"remote_quality":float(last.get("remote_quality",-1)),"config_ok":config_ok,"window_bytes":window_bytes()}
