extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func compare(c: Dictionary,label: String) -> void:
	var scene=c.scenes[0];var cached=Hearth20Vision.build_view(c,"player-one",scene);var raw=Hearth20Vision.build_view(c,"player-two",scene,false)
	expect(Hearth20Contracts.valid_scene(scene),label+" fixture is a valid scene")
	expect(cached.levels==raw.levels,label+" levels match uncached calculation")
	expect(var_to_bytes(Hearth20Lighting.meshes(cached))==var_to_bytes(Hearth20Lighting.meshes(raw)),label+" light geometry matches")
	raw.erase("environment_key");expect(Hearth20Lighting.project_field(cached)==Hearth20Lighting.project_field(raw),label+" encoded field matches uncached encoding")
func run() -> void:
	var c=Hearth20Identity.new_campaign("Cache boundaries");var s=c.scenes[0];s.width_cells=16;s.height_cells=12;s.dynamic_lighting=true;s.ambient_light="dark"
	s.annotations=[{"id":"lamp","kind":"light","layer":"light","points":[Vector2(4,4)],"bright":20.,"dim":20.,"enabled":true},{"id":"pane","kind":"window","layer":"light","points":[Vector2(0,3),Vector2(0,5)],"color":"#e6c482","open":false}]
	for item in s.annotations:item.owner="dm-local"
	s.doors=[{"a":Vector2(6,0),"b":Vector2(6,12),"open":false}]
	var actor=Hearth20TokenInventory.new_actor("Actor",true,s,Vector2(3.5,3.5));actor.id="cache-actor";actor.in_inventory=false;c.actors.append(actor)
	compare(c,"initial");var first=Hearth20Vision.signature(c,s)
	var temporary=Hearth20Vision.build_view(c,"player-one",s);temporary.levels.fill(99)
	expect(not Hearth20Vision.build_view(c,"player-two",s).levels.has(99),"callers cannot modify a cached visibility buffer")
	actor.position+=Vector2(1,0);c.revision+=1;expect(Hearth20Vision.signature(c,s)==first,"ordinary token movement reuses environmental sight");compare(c,"ordinary move")
	actor.vision={"bright_light_feet":10.,"dim_light_feet":10.};expect(Hearth20Vision.signature(c,s)!=first,"carried light changes signature");compare(c,"carried light")
	first=Hearth20Vision.signature(c,s);actor.position+=Vector2(1,0);expect(Hearth20Vision.signature(c,s)!=first,"carried light movement invalidates sight");compare(c,"light moves")
	s.doors[0].open=true;compare(c,"open door")
	s.natural_light={"time_hours":10.,"north_degrees":90.};compare(c,"sky direction and hour")
	s.natural_light.time_hours=23.;compare(c,"moonlight")
	s.fog_rects=[Rect2(5,2,4,5)];compare(c,"new mask")
	var sight=Hearth20Vision.build_view(c,"player-one",s).duplicate(true);var original=Hearth20Lighting.project_field(sight);sight.levels.fill(0)
	expect(Hearth20Lighting.project_field(sight)!=original,"encoded field cache is keyed by the actual mask")
	s.blackout=true;compare(c,"full cover");expect(Hearth20Lighting.project_field(Hearth20Vision.build_view(c,"player-one",s)).is_empty(),"full cover never reuses a revealed field")
	s.blackout=false;s.fog_rects=[];compare(c,"reveal again")
	actor.layer="gm";actor.name="PRIVATE SECRET";var projected=Hearth20Contracts.project_for_player(c,"player-one",PackedByteArray())
	expect(not projected.is_empty() and not JSON.stringify(projected).contains("PRIVATE SECRET"),"shared environment cache cannot expose GM actors")
	expect(Hearth20Vision.common_cache.size()<=4 and Hearth20Lighting.projected_field_cache.size()<=4,"both caches stay bounded")
	print("Lighting cache: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
