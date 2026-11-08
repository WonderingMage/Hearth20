extends SceneTree
## Hearth20 data, movement, image, privacy, recipe, and FX contract checks.

const Identity = preload("res://hearth20/identity.gd")
const Contracts = preload("res://hearth20/contracts.gd")
const Recipes = preload("res://hearth20/recipes.gd")
const Assets = preload("res://hearth20/assets.gd")
const FxRenderer = preload("res://hearth20/fx_renderer.gd")
const BoardCanvas = preload("res://hearth20/board_canvas.gd")

var assertion_count := 0
var assertion_failures: Array[String] = []

func _expect(condition: bool, message: String) -> void:
	assertion_count += 1
	if condition:
		return
	assertion_failures.append(message)
	push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(Identity.validate_project_dispatch("Hearth20", "hearth20-development-gate").ok, "Hearth20 development gate may dispatch only the isolated Hearth20 scene")
	_expect(Identity.validate_project_dispatch("Hearthtable Lite", "lite").ok == false, "Hearth20 dispatch rejects Lite project identity")
	_expect(not Identity.validate_project_dispatch("Hearth20", "lite").ok, "Hearth20 dispatch rejects a foreign edition marker")
	var update_identity := Identity.network_identity()
	update_identity.merge({"update_namespace": Identity.UPDATE_NAMESPACE, "version": Identity.VERSION}, true)
	_expect(Identity.validate_update_manifest(update_identity), "Hearth20 updater identity requires its own product, network, schema, and namespace markers")
	var lite_update := update_identity.duplicate(true)
	lite_update.product_id = "com.wonderingmage.hearthtable-lite"
	_expect(not Identity.validate_update_manifest(lite_update), "Lite update provenance is refused by Hearth20")
	var wrong_update_namespace := update_identity.duplicate(true)
	wrong_update_namespace.update_namespace = "lite-updates-v1"
	_expect(not Identity.validate_update_manifest(wrong_update_namespace), "Hearth20 refuses update manifests from another namespace")
	var wrong_protocol := Identity.network_identity()
	wrong_protocol.protocol += 1
	_expect(not Identity.validate_network_identity(wrong_protocol), "network identity rejects a mismatched protocol even when the product ID matches")
	var campaign := Identity.new_campaign("Disposable contract fixture")
	campaign.custom_data = {"$h20_vector2": [5, 7], "nested": {"$h20_rect2": [1, 2, 3, 4], "malformed": {"$h20_vector2": [5, "not-a-number"]}}}
	_expect(Contracts.validate_campaign(campaign).ok, "new Hearth20 campaign must validate")
	var lite_copy := campaign.duplicate(true)
	lite_copy.product_id = "com.wonderingmage.hearthtable-lite"
	_expect(not Identity.validate_campaign(lite_copy).ok, "Lite campaign identity must be rejected")
	_expect(not Identity.save_campaign(campaign, "user://campaigns/lite-save.h20campaign").ok, "save path must remain under isolated Hearth20 root")

	var hero := {"id":"hero-a","name":"Private Hero Name","is_hero":true,"scene_id":"scene-start","position":Vector2(1,1),"owner_player_id":"player-a","hidden":false,"token_size":0.8,"png_asset_id":"","movement_policy":Contracts.default_movement_policy("blocked", ["player-a"]),"hp":42,"armor_class":16,"private_notes":"not public"}
	var enemy := {"id":"enemy-secret","name":"Hidden Wraith","is_hero":false,"scene_id":"scene-start","position":Vector2(7,7),"owner_player_id":"","hidden":true,"token_size":1.0,"png_asset_id":"","movement_policy":Contracts.default_movement_policy("blocked", []),"hp":99,"armor_class":22,"private_notes":"secret"}
	campaign.actors = [hero, enemy]
	var hidden_png := Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png_to_buffer()
	var hidden_image := Assets.inspect_token_png_bytes(hidden_png, "hidden.png")
	_expect(hidden_image.ok, "bounded token PNG import accepts decoded valid bytes")
	enemy.png_asset_id = Assets.store_asset(campaign, hidden_image, "token")
	_expect(Assets.read_asset(campaign, enemy.png_asset_id, "token") == hidden_png, "stored PNG override must preserve exact source bytes")
	_expect(Assets.sha256(Assets.read_asset(campaign, enemy.png_asset_id, "token")) == hidden_image.sha256, "stored PNG bytes must match the imported SHA-256")
	var oversized_header := PackedByteArray([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,8,1,0,0,0,1])
	var oversized_result := Assets.inspect_token_png_bytes(oversized_header, "oversized.png")
	_expect(not oversized_result.ok and oversized_result.error.contains("2,048"), "PNG dimensions are rejected from the header before decoding")

	var blocked := Contracts.authorize_and_apply_move(campaign, "player-a", "player", "hero-a", Vector2(1,1), Vector2(2,1), 5.0)
	_expect(not blocked.ok and hero.position == Vector2(1,1), "blocked movement cannot change host position")
	_expect(Contracts.set_movement_policy(campaign, "hero-a", "grant", ["player-a"], 10.0, "grant-test", "campaign").ok, "DM can establish a distance grant")
	_expect(Contracts.authorize_and_apply_move(campaign, "player-a", "player", "hero-a", Vector2(1,1), Vector2(2,1), 5.0).ok, "first authorized move spends grant")
	var over_budget := Contracts.authorize_and_apply_move(campaign, "player-a", "player", "hero-a", Vector2(2,1), Vector2(4,1), 10.0)
	_expect(not over_budget.ok and hero.position == Vector2(2,1), "over-budget move is rejected without changing position")
	_expect(not Contracts.authorize_and_apply_move(campaign, "player-b", "player", "hero-a", Vector2(2,1), Vector2(3,1), 5.0).ok, "another player cannot move the assigned hero")
	_expect(Contracts.revoke_movement(campaign, "hero-a").ok, "DM can revoke movement")
	_expect(not Contracts.authorize_and_apply_move(campaign, "player-a", "player", "hero-a", Vector2(2,1), Vector2(3,1), 5.0).ok, "revoked movement is blocked")
	_expect(Contracts.set_movement_policy(campaign, "hero-a", "free_until_revoked", ["player-a"]).ok, "DM can enable explicit free-until-revoked movement")
	_expect(Contracts.authorize_and_apply_move(campaign, "player-a", "player", "hero-a", Vector2(2,1), Vector2(12,1), 50.0).ok, "free movement still accepts only the assigned hero")
	hero.position = Vector2(1,1)
	_expect(Contracts.set_movement_policy(campaign, "hero-a", "turn_allowance", ["player-a"], 10.0).ok, "DM can set a turn-scoped allowance")
	_expect(Contracts.authorize_and_apply_move(campaign, "player-a", "player", "hero-a", Vector2(1,1), Vector2(2,1), 5.0).ok, "first turn move spends the host-measured allowance")
	_expect(Contracts.authorize_and_apply_move(campaign, "player-a", "player", "hero-a", Vector2(2,1), Vector2(3,1), 5.0).ok, "second turn move spends the cumulative allowance")
	_expect(not Contracts.authorize_and_apply_move(campaign, "player-a", "player", "hero-a", Vector2(3,1), Vector2(4,1), 5.0).ok, "turn allowance cannot be exceeded across successive moves")
	hero.position = Vector2(1,2)
	campaign.scenes[0].walls = [{"a":{"x":2.0,"y":0.0},"b":{"x":2.0,"y":4.0}}]
	_expect(not Contracts.authorize_and_apply_move(campaign, "player-a", "player", "hero-a", Vector2(1,2), Vector2(3,2), 10.0).ok, "movement cannot cross an intersecting wall")
	_expect(Contracts.segment_intersects(Vector2(1,0), Vector2(3,0), Vector2(2,0), Vector2(4,0)), "collinear movement cannot bypass a wall intersection")
	_expect(Contracts.authorize_and_apply_move(campaign, "dm-local", "dm", "hero-a", Vector2(1,2), Vector2(3,2), 0.0).ok and hero.position == Vector2(3,2), "DM placement remains free through blocking geometry")

	var projected := Contracts.project_for_player(campaign, "player-a", PackedByteArray())
	_expect(Identity.validate_network_identity(projected), "recipient snapshot carries the complete Hearth20 product, protocol, and schema identity")
	_expect(projected.actors.size() == 1 and projected.actors[0].id == "hero-a", "hidden actor must be filtered before projection")
	_expect(not projected.actors[0].has("name") and not projected.actors[0].has("hp") and not projected.actors[0].has("private_notes"), "player projection must omit private actor fields")
	_expect(not JSON.stringify(projected).contains("Hidden Wraith"), "hidden identity must not enter player projection")
	_expect(not projected.assets.has(enemy.png_asset_id) and not JSON.stringify(projected).contains(Marshalls.raw_to_base64(hidden_png)), "hidden token image bytes must not enter the player projection")
	var other_player_projection := Contracts.project_for_player(campaign, "player-b", PackedByteArray())
	_expect(Identity.validate_network_identity(other_player_projection), "every player projection carries the Hearth20 handshake identity")
	_expect(other_player_projection.actors.size() == 1 and other_player_projection.actors[0].id != "hero-a", "another player's visible hero receives a recipient-specific neutral token identity")
	_expect(not other_player_projection.actors[0].has("movement"), "movement permission details are sent only to the assigned player")
	_expect(not JSON.stringify(other_player_projection).contains("hero-a") and not JSON.stringify(other_player_projection).contains("enemy-secret"), "internal actor identifiers are absent from other-player snapshots")

	var asset_campaign := Identity.new_campaign("Disposable PNG projection fixture")
	var public_token := {"id":"public-token","name":"Private source label","is_hero":false,"scene_id":"scene-start","position":Vector2(3,3),"owner_player_id":"","hidden":false,"token_size":1.0,"png_asset_id":"","movement_policy":Contracts.default_movement_policy("blocked",[])}
	asset_campaign.actors = [public_token]
	var visible_png := Image.create(3, 4, false, Image.FORMAT_RGBA8).save_png_to_buffer()
	var visible_image := Assets.inspect_token_png_bytes(visible_png, "visible.png")
	public_token.png_asset_id = Assets.store_asset(asset_campaign, visible_image, "token")
	asset_campaign.assets[public_token.png_asset_id].private_path = "C:/private/source.png"
	var visible_projection := Contracts.project_for_player(asset_campaign, "player-b", PackedByteArray())
	var visible_record: Dictionary = visible_projection.assets[public_token.png_asset_id]
	_expect(Marshalls.base64_to_raw(visible_record.base64) == visible_png and visible_record.sha256 == Assets.sha256(visible_png), "visible PNG projection preserves and verifies the imported bytes")
	_expect(visible_record.size() == 7 and not JSON.stringify(visible_projection).contains("private_path") and not JSON.stringify(visible_projection).contains("Private source label"), "outbound PNG metadata is rebuilt from an allowlist")
	var corrupt_id := "sha256-" + "0".repeat(64)
	asset_campaign.assets[corrupt_id] = {"kind":"token","mime_type":"image/png","width":1,"height":1,"sha256":"bad","base64":"QUJD","byte_length":3,"private_path":"C:/secret.png"}
	public_token.png_asset_id = corrupt_id
	var corrupt_projection := Contracts.project_for_player(asset_campaign, "player-b", PackedByteArray())
	_expect(corrupt_projection.assets.is_empty() and corrupt_projection.actors[0].asset_id.is_empty(), "corrupt asset bytes are withheld before transfer")

	var recipe_file := FileAccess.open("res://hearth20/tests/fixtures/forest-camp.json", FileAccess.READ)
	var recipe: Variant = JSON.parse_string(recipe_file.get_as_text())
	var recipe_validation := Recipes.validate(recipe)
	_expect(recipe_validation.ok, "bounded sample recipe must validate: %s" % str(recipe_validation.get("errors", [])))
	var fractional_schema_recipe: Dictionary = recipe.duplicate(true)
	fractional_schema_recipe["schema_version"] = 1.5
	_expect(not Recipes.validate(fractional_schema_recipe).ok, "recipe schema version rejects non-integral numeric values")
	var other_schema_recipe: Dictionary = recipe.duplicate(true)
	other_schema_recipe["schema_version"] = 2
	_expect(not Recipes.validate(other_schema_recipe).ok, "recipe schema version still requires exactly version 1")
	var parsed_bounded := Recipes.parse_bounded_json(JSON.stringify(recipe))
	_expect(parsed_bounded.ok and parsed_bounded.recipe == recipe, "raw recipe text passes bounded preflight and strict schema validation")
	var twenty_prop_recipe := Recipes.author("camp with 20 tents", 24)
	var parsed_twenty_props := Recipes.parse_bounded_json(JSON.stringify(twenty_prop_recipe.recipe))
	_expect(twenty_prop_recipe.ok and twenty_prop_recipe.recipe.props.size() == 20 and parsed_twenty_props.ok, "bounded preflight reprocesses closing delimiters in a recipe with 20 props")
	var oversized_raw := "\"" + "x".repeat(Recipes.MAX_JSON_BYTES) + "\""
	var oversized_raw_result := Recipes.parse_bounded_json(oversized_raw)
	_expect(not oversized_raw_result.ok and oversized_raw_result.errors[0].contains("byte"), "oversized raw JSON is rejected before parsing")
	var nested_raw := "[".repeat(Recipes.MAX_JSON_DEPTH + 1) + "0" + "]".repeat(Recipes.MAX_JSON_DEPTH + 1)
	var nested_raw_result := Recipes.parse_bounded_json(nested_raw)
	_expect(not nested_raw_result.ok and nested_raw_result.errors[0].contains("nesting depth"), "deep raw JSON is rejected during preflight before parsing")
	var malformed_prefix_raw := "]".repeat(20) + "[".repeat(Recipes.MAX_JSON_DEPTH + 1) + "0" + "]".repeat(Recipes.MAX_JSON_DEPTH + 1)
	var malformed_prefix_result := Recipes.parse_bounded_json(malformed_prefix_raw)
	_expect(not malformed_prefix_result.ok and malformed_prefix_result.errors[0].contains("unmatched closing delimiter"), "malformed closing prefixes cannot offset the raw nesting-depth guard")
	_expect(recipe.unresolved_requests == ["clockwork", "lighthouse"], "unknown narrative concepts remain visible to the DM")
	var native_map_rect := BoardCanvas.native_map_rect(Vector2i(500, 333))
	_expect(native_map_rect.position == Vector2.ZERO and native_map_rect.size == Vector2(500, 333), "imported map artwork keeps its native pixel rectangle after cell calibration")
	var counted_props := Recipes.author("A forest camp with two tents, 3 torches, and one fire", 18)
	_expect(counted_props.ok and counted_props.recipe.props.size() == 6, "recipe authoring honors word and numeric quantities for supported prop nouns")
	_expect(Recipes.validate(counted_props.recipe).ok, "quantity-expanded offline recipes satisfy the strict import schema")
	var adjective_quantity := Recipes.author("A ruined hall with two stone pillars", 21)
	_expect(adjective_quantity.ok and adjective_quantity.recipe.props.filter(func(prop): return prop.kind == "pillar").size() == 2 and adjective_quantity.unresolved_requests.has("stone"), "bounded quantity lookup crosses an adjective while retaining that unsupported adjective for DM review")
	var many_unknown_terms := "A camp with"
	for unknown_index in 70:
		many_unknown_terms += " unsupportedterm%d" % unknown_index
	var capped_unknowns := Recipes.author(many_unknown_terms, 22)
	_expect(capped_unknowns.ok and capped_unknowns.unresolved_requests.size() <= 64 and capped_unknowns.unresolved_requests.back().contains("shorten prompt"), "over 64 unsupported terms produce a bounded recipe with a visible omission summary")
	_expect(Recipes.validate(capped_unknowns.recipe).ok, "unsupported-term overflow summary remains within the recipe import schema")
	var counted_cells := {}
	var counted_props_inside_rooms := true
	for prop in counted_props.recipe.props:
		var cell_key := "%s:%s,%s" % [prop.room_id, str(prop.position.x), str(prop.position.y)]
		if counted_cells.has(cell_key):
			counted_props_inside_rooms = false
		counted_cells[cell_key] = true
		var prop_room: Dictionary = counted_props.recipe.rooms.filter(func(item): return item.id == prop.room_id)[0]
		var prop_bounds: Dictionary = prop_room.grid
		if prop.position.x < prop_bounds.x or prop.position.y < prop_bounds.y or prop.position.x >= prop_bounds.x + prop_bounds.width or prop.position.y >= prop_bounds.y + prop_bounds.height:
			counted_props_inside_rooms = false
	_expect(counted_props_inside_rooms, "generated prop placements are unique and inside their named rooms")
	var excessive_props := Recipes.author("A camp with 120 tents in two rooms", 19)
	_expect(excessive_props.ok and excessive_props.recipe.props.size() == 50 and excessive_props.unresolved_requests.any(func(item): return item.contains("unplaced tent count 70")), "out-of-range prop quantities are bounded and the unplaced amount is reported")
	var negative_props := Recipes.author("A camp with -2 tents", 20)
	_expect(negative_props.recipe.props.is_empty() and negative_props.unresolved_requests.any(func(item): return item.contains("out-of-range tent count -2")), "negative prop counts are explicitly reported instead of silently changed")
	var root_injection: Dictionary = recipe.duplicate(true)
	root_injection["resource_path"] = "res://untrusted.gd"
	_expect(not Recipes.validate(root_injection).ok, "recipe validator rejects unknown root fields and resource-shaped paths")
	var prop_injection: Dictionary = recipe.duplicate(true)
	prop_injection["props"][0]["script"] = "res://untrusted.gd"
	_expect(not Recipes.validate(prop_injection).ok, "recipe validator rejects unknown nested prop fields before apply")
	var point_injection: Dictionary = recipe.duplicate(true)
	point_injection["props"][0]["position"]["resource_path"] = "res://untrusted.gd"
	_expect(not Recipes.validate(point_injection).ok, "recipe validator rejects unknown nested coordinate fields")
	var object_payload: Dictionary = recipe.duplicate(true)
	object_payload["provenance"]["script_object"] = Image.new()
	_expect(not Recipes.validate(object_payload).ok, "recipe validator accepts only JSON value types")
	var deep_payload: Dictionary = recipe.duplicate(true)
	var depth_cursor: Dictionary = deep_payload
	for _depth in Recipes.MAX_JSON_DEPTH + 2:
		var nested: Dictionary = {}
		depth_cursor["nested"] = nested
		depth_cursor = nested
	_expect(not Recipes.validate(deep_payload).ok, "recipe validator enforces maximum JSON nesting depth")
	var node_payload: Dictionary = recipe.duplicate(true)
	node_payload["extra_nodes"] = []
	for _node in Recipes.MAX_JSON_NODES:
		node_payload["extra_nodes"].append(0)
	_expect(not Recipes.validate(node_payload).ok, "recipe validator enforces maximum JSON node count")
	var raw_scalar_nodes := "[" + "0,".repeat(Recipes.MAX_JSON_NODES) + "0]"
	var raw_scalar_node_result := Recipes.parse_bounded_json(raw_scalar_nodes)
	_expect(raw_scalar_nodes.to_utf8_buffer().size() < Recipes.MAX_JSON_BYTES and not raw_scalar_node_result.ok and raw_scalar_node_result.errors[0].contains("JSON nodes"), "raw bounded-size JSON arrays over the node limit are rejected during preflight")
	var oversized_payload: Dictionary = recipe.duplicate(true)
	oversized_payload["extra_text"] = []
	for _text in 100:
		oversized_payload["extra_text"].append("x".repeat(3000))
	var oversized_validation := Recipes.validate(oversized_payload)
	_expect(not oversized_validation.ok and oversized_validation.errors.any(func(item): return item.contains("encoded data limit")), "recipe validator enforces encoded payload byte bounds")
	var draft := Recipes.author("A dark ruined chapel with three connected rooms, two stone pillars, a hidden trap, and a clockwork dragon", 9)
	_expect(draft.ok and draft.unresolved_requests.has("clockwork") and draft.unresolved_requests.has("dragon"), "unsupported prompt concepts must be reported")
	var unsupported_draft := Recipes.author("A flooded crypt beside a river ford", 3)
	_expect(unsupported_draft.unresolved_requests.has("flooded") and unsupported_draft.unresolved_requests.has("crypt") and unsupported_draft.unresolved_requests.has("river") and unsupported_draft.unresolved_requests.has("ford"), "unsupported locations and modifiers remain visible to the DM")
	var unsupported_visibility := Recipes.author("A hidden room behind a secret door", 4)
	_expect(unsupported_visibility.unresolved_requests.has("hidden") and unsupported_visibility.unresolved_requests.has("secret"), "unsupported room and door visibility modifiers remain visible to the DM")
	var vague_quantities := Recipes.author("A camp with many tents, few torches, and some fires", 23)
	_expect(vague_quantities.unresolved_requests.has("many") and vague_quantities.unresolved_requests.has("few") and vague_quantities.unresolved_requests.has("some"), "vague supported-prop quantities remain visible for DM review instead of silently implying one")
	var implemented_visibility := Recipes.author("A hidden trap beside a secret cache", 5)
	_expect(not implemented_visibility.unresolved_requests.has("hidden") and not implemented_visibility.unresolved_requests.has("secret") and implemented_visibility.recipe.props.size() == 2, "implemented hidden prop modifiers are consumed only where they are applied")
	var mixed_visibility := Recipes.author("A hidden room beside a hidden trap and a secret door near a secret cache", 6)
	_expect(mixed_visibility.unresolved_requests.has("hidden") and mixed_visibility.unresolved_requests.has("secret") and mixed_visibility.recipe.props.size() == 2 and mixed_visibility.recipe.props.all(func(prop): return prop.visibility == "gm"), "modifiers apply to their nearby supported props while unsupported room and door requests stay visible")
	var separated_visibility := Recipes.author("A hidden trap by tent", 7)
	var separated_tent: Dictionary = separated_visibility.recipe.props.filter(func(prop): return prop.kind == "tent")[0]
	_expect(separated_tent.visibility == "public", "a modifier cannot cross an unrecognized separator and attach to a different prop")
	var unknown_modifier := Recipes.author("A hidden small tent", 8)
	_expect(unknown_modifier.recipe.unresolved_requests.has("small") and unknown_modifier.recipe.unresolved_requests.has("hidden") and unknown_modifier.recipe.props[0].visibility == "public", "unrecognized words cannot be skipped while applying modifiers")
	var bad_recipe: Dictionary = recipe.duplicate(true)
	bad_recipe["rooms"][0]["grid"]["x"] = -1
	_expect(not Recipes.validate(bad_recipe).ok, "out-of-bounds recipe geometry must be rejected")

	var fog_scene: Dictionary = campaign.scenes[0]
	fog_scene.title = "DM SECRET: hidden chamber"
	fog_scene.fog_rects = [{"x":0.0,"y":0.0,"width":1.0,"height":1.0}]
	fog_scene.walls = [{"a":{"x":0.0,"y":0.5},"b":{"x":4.0,"y":0.5},"hidden":false}]
	fog_scene.doors = [{"id":"secret-door","a":{"x":0.0,"y":0.5},"b":{"x":0.0,"y":1.5},"hidden":false,"open":false}]
	fog_scene.props = [{"id":"secret-prop","kind":"cache","label":"Hidden cache","position":Vector2(0.5,0.5),"public":true,"hidden":false,"gm_details":"private annotation"}]
	fog_scene.fx = [{"id":"concealed-fire","public":true,"target_actor_id":"enemy-secret","center":Vector2(7,7),"start":Vector2(0.5,0.5),"end":Vector2(7,7),"started_usec":Time.get_ticks_usec(),"travel_usec":5_000_000,"impact_duration_usec":950_000}]
	var map_image := Image.create(192, 128, false, Image.FORMAT_RGBA8)
	map_image.fill(Color("#abcdef"))
	var map_bytes := map_image.save_png_to_buffer()
	var fog_projection := Contracts.project_for_player(campaign, "player-a", map_bytes)
	var masked := Image.new()
	_expect(masked.load_png_from_buffer(fog_projection.map_png) == OK, "fog projection remains a valid PNG")
	_expect(masked.get_pixel(32, 32) == Color.BLACK and masked.get_pixel(160, 96) == Color("#abcdef"), "fog pixels are masked before transfer")
	_expect(Assets.sha256(map_bytes) != Assets.sha256(fog_projection.map_png), "fog projection has a distinct content hash")
	_expect(fog_projection.map_png != map_bytes, "original map PNG bytes are not sent through the fog projection")
	_expect(fog_projection.scene.title == "Battle map" and fog_projection.scene.walls.is_empty() and fog_projection.scene.doors.is_empty() and fog_projection.scene.props.is_empty(), "fog-crossing scene details and DM title are omitted")
	_expect(fog_projection.fx.is_empty() and fog_scene.fx[0].private_recipients.has("player-a"), "FX trajectory crossing fog is withheld and cannot replay after reveal")
	fog_scene.fog_rects = []
	fog_scene.walls = [{"a":{"x":3.0,"y":2.0,"private_notes":"SECRET WALL ANNOTATION"},"b":{"x":4.0,"y":2.0,"gm_details":"secret endpoint metadata"},"hidden":false}]
	var after_reveal := Contracts.project_for_player(campaign, "player-a", map_bytes)
	_expect(after_reveal.fx.is_empty(), "an FX event withheld during fog does not replay when the area is revealed")
	_expect(not JSON.stringify(after_reveal.scene).contains("SECRET WALL ANNOTATION") and not JSON.stringify(after_reveal.scene).contains("secret endpoint metadata"), "nested wall metadata is removed by player-scene projection")

	var fx := FxRenderer.new()
	var rules_before: Array = campaign.actors.duplicate(true)
	var rocket := fx.play_fire_rocket(Vector2(0,0), Vector2(10,4))
	_expect(rocket.ok and int(rocket.arrival_usec) > int(rocket.event.started_usec), "rocket impact starts after measured travel time")
	_expect(campaign.actors == rules_before, "cosmetic FX cannot alter actor rules state")
	fx.free()
	var saved := Identity.save_campaign(campaign, Identity.SAVE_ROOT + "/roundtrip.h20campaign")
	_expect(saved.ok, "validated Hearth20 campaign saves under its separate data root")
	var loaded := Identity.load_campaign(Identity.SAVE_ROOT + "/roundtrip.h20campaign")
	if not loaded.ok:
		var persisted: Variant = JSON.parse_string(FileAccess.get_file_as_string(Identity.SAVE_ROOT + "/roundtrip.h20campaign"))
		var decoded: Variant = Identity._decode_variant(persisted)
		print("Roundtrip diagnostic scene_valid=%s scene=%s" % [str(Contracts.valid_scene(decoded.scenes[0])), str(decoded.scenes[0])])
	_expect(loaded.ok and loaded.get("campaign", {}).get("actors", []).size() == campaign.actors.size(), "Hearth20 save can reopen after full schema and asset validation: %s" % str(loaded.get("errors", [])))
	var custom_roundtrip: Dictionary = loaded.get("campaign", {}).get("custom_data", {})
	_expect(custom_roundtrip.get("$h20_vector2", null) is Array and custom_roundtrip.nested.get("$h20_rect2", null) is Array and custom_roundtrip.nested.malformed.get("$h20_vector2", [])[1] == "not-a-number", "reserved serialization tags and malformed tag lookalikes remain ordinary campaign data")
	print("Hearth20 contract checks: %d assertions, %d failures." % [assertion_count, assertion_failures.size()])
	quit(1 if not assertion_failures.is_empty() else 0)
