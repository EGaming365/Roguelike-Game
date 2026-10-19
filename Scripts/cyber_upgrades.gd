extends Node2D

const KINETIC_RAM: String = "kinetic_ram"
const ARC_CONDUIT: String = "arc_conduit"
const TESLA_TOWER: String = "tesla_tower"
const OVERCLOCKED_SERVOS: String = "overclocked_servos"

@export var starting_kinetic_ram_stacks: int = 0
@export var starting_arc_conduit_stacks: int = 0
@export var starting_tesla_tower_stacks: int = 0
@export var starting_overclocked_servos_stacks: int = 0
@export var print_upgrades: bool = false
@export_flags_2d_physics var target_collision_mask: int = 1
@export var show_hitboxes: bool = true
@export var hitbox_linger: float = 0.1
@export var kinetic_ram_base_damage: int = 20
@export var kinetic_ram_damage_per_stack: int = 10
@export var kinetic_ram_radius: float = 40.0
@export var kinetic_ram_origin_offset: Vector2 = Vector2(0.0, -8.0)
@export var kinetic_ram_knockback_speed: float = 500.0
@export var kinetic_ram_visual_push: float = 14.0
@export var kinetic_ram_hitbox_color: Color = Color(0.3, 0.8, 1.0, 0.9)
@export var arc_conduit_chance: float = 0.1
@export var arc_conduit_chance_per_stack: float = 0.0
@export var arc_conduit_damage: int = 12
@export var arc_conduit_damage_per_stack: int = 2
@export var arc_conduit_range: float = 300.0
@export var arc_conduit_max_chains: int = 3
@export var arc_conduit_base_bolts: int = 1
@export var arc_conduit_chains_per_upgrade: int = 1
@export var arc_conduit_bolts_per_upgrade: int = 1
@export var arc_conduit_bolt_first: bool = false
@export var arc_conduit_hop_delay: float = 0.06
@export var chain_point_offset: Vector2 = Vector2(0.0, -16.0)
@export var bolt_color: Color = Color(1.0, 0.95, 0.25)
@export var bolt_glow_color: Color = Color(1.0, 0.85, 0.1, 0.4)
@export var bolt_width: float = 2.0
@export var bolt_jitter: float = 10.0
@export var bolt_segment_length: float = 14.0
@export var bolt_lifetime: float = 0.18
@export var range_ring_color: Color = Color(1.0, 0.95, 0.25, 0.35)
@export var tesla_tower_action: StringName = &"right_ability"
@export var tesla_tower_scene: PackedScene
@export var tesla_throw_range: float = 420.0
@export var tesla_throw_speed: float = 700.0
@export var tesla_min_flight_time: float = 0.2
@export var tesla_arc_height: float = 70.0
@export var tesla_throw_origin_offset: Vector2 = Vector2(0.0, -16.0)
@export var tesla_cooldown: float = 6.0
@export var tesla_preview_points: int = 24
@export var tesla_preview_width: float = 2.0
@export var tesla_preview_circle_radius: float = 24.0
@export var tesla_preview_fill_alpha: float = 0.2
@export var tesla_preview_color: Color = Color(1.0, 0.95, 0.25, 0.9)
@export var tesla_preview_unready_color: Color = Color(0.6, 0.6, 0.6, 0.6)
@export var servo_bonus_per_dodge: float = 0.1
@export var servo_max_bonus: float = 0.5

var player: CharacterBody2D
var upgrade_stacks: Dictionary = {}
var ram_shape: CircleShape2D
var chain_shape: CircleShape2D
var ram_hit_targets: Array[Node] = []
var ram_visible_left: float = 0.0
var ram_center: Vector2 = Vector2.ZERO
var chains: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var drew_last_frame: bool = false
var tesla_cooldown_left: float = 0.0
var preview_active: bool = false
var throw_start: Vector2 = Vector2.ZERO
var throw_target: Vector2 = Vector2.ZERO
var servo_bonus: float = 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY
	z_as_relative = false
	z_index = 150

	player = get_parent() as CharacterBody2D
	if player == null:
		push_warning("The Upgrades node must be a direct child of the Player")

	ram_shape = CircleShape2D.new()
	ram_shape.radius = kinetic_ram_radius
	chain_shape = CircleShape2D.new()
	chain_shape.radius = arc_conduit_range + absf(chain_point_offset.y)

	if not InputMap.has_action(tesla_tower_action):
		push_warning("Input action " + String(tesla_tower_action) + " not found. Add it in Project Settings > Input Map")

	if starting_kinetic_ram_stacks > 0:
		upgrade_stacks[KINETIC_RAM] = starting_kinetic_ram_stacks
	if starting_arc_conduit_stacks > 0:
		upgrade_stacks[ARC_CONDUIT] = starting_arc_conduit_stacks
	if starting_tesla_tower_stacks > 0:
		upgrade_stacks[TESLA_TOWER] = starting_tesla_tower_stacks
	if starting_overclocked_servos_stacks > 0:
		upgrade_stacks[OVERCLOCKED_SERVOS] = starting_overclocked_servos_stacks


func _physics_process(delta: float) -> void:
	if player == null:
		return

	update_ram(delta)
	update_tesla(delta)
	process_chains(delta)
	update_bolts(delta)

	var drawing: bool = not bolts.is_empty() or ram_visible_left > 0.0 or preview_active
	if drawing or drew_last_frame:
		queue_redraw()
	drew_last_frame = drawing


func get_stacks(upgrade_id: String) -> int:
	return int(upgrade_stacks.get(upgrade_id, 0))


func add_upgrade(upgrade_id: String) -> void:
	var known: bool = upgrade_id == KINETIC_RAM or upgrade_id == ARC_CONDUIT or upgrade_id == TESLA_TOWER or upgrade_id == OVERCLOCKED_SERVOS
	if not known:
		push_warning("Unknown upgrade id: " + upgrade_id)
		return
	upgrade_stacks[upgrade_id] = get_stacks(upgrade_id) + 1
	if print_upgrades:
		print("Upgrade gained: ", upgrade_id, " | stacks ", get_stacks(upgrade_id))
		if upgrade_id == ARC_CONDUIT:
			print("Arc Conduit now: ", arc_conduit_stats(get_stacks(ARC_CONDUIT)))


func arc_conduit_stats(stacks: int) -> Dictionary:
	var extra: int = maxi(stacks - 1, 0)
	var first_upgrades: int = ceili(float(extra) / 2.0)
	var second_upgrades: int = floori(float(extra) / 2.0)
	var chain_upgrades: int = second_upgrades if arc_conduit_bolt_first else first_upgrades
	var bolt_upgrades: int = first_upgrades if arc_conduit_bolt_first else second_upgrades
	return {
		"damage": arc_conduit_damage + arc_conduit_damage_per_stack * extra,
		"chains": arc_conduit_max_chains + chain_upgrades * arc_conduit_chains_per_upgrade,
		"bolts": arc_conduit_base_bolts + bolt_upgrades * arc_conduit_bolts_per_upgrade,
		"chance": arc_conduit_chance + arc_conduit_chance_per_stack * float(extra)
	}


func get_attack_speed_multiplier() -> float:
	if get_stacks(OVERCLOCKED_SERVOS) <= 0:
		return 1.0
	return 1.0 + servo_bonus


func on_dodge() -> void:
	if get_stacks(OVERCLOCKED_SERVOS) <= 0:
		return
	servo_bonus = minf(servo_bonus + servo_bonus_per_dodge, servo_max_bonus)
	if print_upgrades:
		print("Overclocked Servos: attacks ", int(round(servo_bonus * 100.0)), "% faster")


func on_player_damaged() -> void:
	if servo_bonus <= 0.0:
		return
	servo_bonus = 0.0
	if print_upgrades:
		print("Overclocked Servos reset")


func on_dash_started() -> void:
	ram_hit_targets.clear()


func on_player_hit(target: Object, _from_position: Vector2) -> void:
	var stacks: int = get_stacks(ARC_CONDUIT)
	if stacks <= 0:
		return

	var stats: Dictionary = arc_conduit_stats(stacks)
	if randf() >= clampf(float(stats["chance"]), 0.0, 1.0):
		return

	var node: Node2D = target as Node2D
	if node == null:
		return

	var origin: Vector2 = node.global_position + chain_point_offset
	var branches: Array = []
	for index in range(int(stats["bolts"])):
		branches.append({"from": origin, "remaining": int(stats["chains"]), "delay_left": 0.0})

	chains.append({"hit": [node], "branches": branches, "damage": int(stats["damage"])})


func update_tesla(delta: float) -> void:
	tesla_cooldown_left = maxf(tesla_cooldown_left - delta, 0.0)

	if get_stacks(TESLA_TOWER) <= 0 or not InputMap.has_action(tesla_tower_action):
		preview_active = false
		return

	if Input.is_action_pressed(tesla_tower_action):
		preview_active = true
		update_throw_target()
	elif preview_active:
		preview_active = false
		update_throw_target()
		if tesla_cooldown_left <= 0.0:
			throw_tower()


func update_throw_target() -> void:
	var ground_origin: Vector2 = player.global_position
	var offset: Vector2 = player.get_global_mouse_position() - ground_origin
	if offset.length() > tesla_throw_range:
		offset = offset.normalized() * tesla_throw_range
	throw_target = ground_origin + offset
	throw_start = ground_origin + tesla_throw_origin_offset


func throw_tower() -> void:
	if tesla_tower_scene == null:
		push_warning("Upgrades node has no Tesla Tower Scene assigned in the Inspector")
		return
	var tower: Node2D = tesla_tower_scene.instantiate() as Node2D
	if tower == null:
		return
	get_tree().current_scene.add_child(tower)
	var distance: float = throw_start.distance_to(throw_target)
	var flight_time: float = maxf(distance / maxf(tesla_throw_speed, 1.0), tesla_min_flight_time)
	tower.call("launch", throw_start, throw_target, flight_time, tesla_arc_height)
	tesla_cooldown_left = tesla_cooldown


func update_ram(delta: float) -> void:
	var stacks: int = get_stacks(KINETIC_RAM)
	var dash_left: float = float(player.get("dash_time_left"))

	if stacks > 0 and dash_left > 0.0:
		ram_center = player.global_position + kinetic_ram_origin_offset
		ram_visible_left = hitbox_linger
		for result in query_ram_targets():
			apply_ram_hit(result["collider"], stacks)
	elif ram_visible_left > 0.0:
		ram_visible_left = maxf(ram_visible_left - delta, 0.0)


func query_ram_targets() -> Array[Dictionary]:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = ram_shape
	query.transform = Transform2D(0.0, ram_center)
	query.collision_mask = target_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 16)


func apply_ram_hit(target: Object, stacks: int) -> void:
	var node: Node2D = target as Node2D
	if node == null or node == player or ram_hit_targets.has(node):
		return
	if node.is_in_group("player") or not node.has_method("take_damage"):
		return
	if node.get("dead") == true:
		return

	ram_hit_targets.append(node)

	var push_direction: Vector2 = player.get("dash_direction")
	if push_direction == Vector2.ZERO:
		push_direction = (node.global_position - player.global_position).normalized()

	var damage: int = kinetic_ram_base_damage + kinetic_ram_damage_per_stack * (stacks - 1)
	node.take_damage(damage, player.global_position)

	if "knockback_velocity" in node:
		node.set("knockback_velocity", push_direction * kinetic_ram_knockback_speed)
	elif "push_offset" in node:
		node.set("push_offset", push_direction * kinetic_ram_visual_push)

	player.call("hit_stop")


func process_chains(delta: float) -> void:
	for chain_index in range(chains.size() - 1, -1, -1):
		var chain: Dictionary = chains[chain_index]
		var branches: Array = chain["branches"]
		var branch_index: int = 0

		while branch_index < branches.size():
			var branch: Dictionary = branches[branch_index]
			branch["delay_left"] -= delta
			if branch["delay_left"] > 0.0:
				branch_index += 1
				continue

			var from_point: Vector2 = branch["from"]
			var next_target: Node2D = find_chain_target(from_point, chain["hit"])
			if next_target == null:
				branches.remove_at(branch_index)
				continue

			var to_point: Vector2 = next_target.global_position + chain_point_offset
			add_bolt(from_point, to_point)
			deal_chain_damage(next_target, chain["damage"], from_point)
			chain["hit"].append(next_target)
			branch["from"] = to_point
			branch["remaining"] -= 1
			branch["delay_left"] = arc_conduit_hop_delay

			if branch["remaining"] <= 0:
				branches.remove_at(branch_index)
			else:
				branch_index += 1

		if branches.is_empty():
			chains.remove_at(chain_index)


func deal_chain_damage(target: Node, damage: int, from_point: Vector2) -> void:
	if target.has_method("on_chain_lightning"):
		target.on_chain_lightning(damage, from_point)
	elif target.has_method("take_damage"):
		target.take_damage(damage, from_point)


func find_chain_target(from_point: Vector2, hit_list: Array) -> Node2D:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = chain_shape
	query.transform = Transform2D(0.0, from_point)
	query.collision_mask = target_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]

	var best: Node2D = null
	var best_distance: float = INF

	for result in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var candidate: Node2D = result["collider"] as Node2D
		if candidate == null or hit_list.has(candidate):
			continue
		var conducts: bool = candidate.has_method("on_chain_lightning")
		if candidate.is_in_group("player") or not (conducts or candidate.has_method("take_damage")):
			continue
		if candidate.get("dead") == true:
			continue
		var candidate_distance: float = from_point.distance_to(candidate.global_position + chain_point_offset)
		if candidate_distance <= arc_conduit_range and candidate_distance < best_distance:
			best = candidate
			best_distance = candidate_distance

	return best


func add_bolt(from_point: Vector2, to_point: Vector2) -> void:
	var span: Vector2 = to_point - from_point
	var segments: int = maxi(int(span.length() / maxf(bolt_segment_length, 1.0)), 2)
	var normal: Vector2 = span.normalized().orthogonal()
	var points: PackedVector2Array = PackedVector2Array()
	points.append(from_point)
	for index in range(1, segments):
		var t: float = float(index) / float(segments)
		points.append(from_point + span * t + normal * randf_range(-bolt_jitter, bolt_jitter))
	points.append(to_point)
	bolts.append({"points": points, "time_left": bolt_lifetime, "ring": from_point})


func update_bolts(delta: float) -> void:
	for index in range(bolts.size() - 1, -1, -1):
		bolts[index]["time_left"] -= delta
		if bolts[index]["time_left"] <= 0.0:
			bolts.remove_at(index)


func _draw() -> void:
	for bolt in bolts:
		var fade: float = clampf(bolt["time_left"] / maxf(bolt_lifetime, 0.001), 0.0, 1.0)
		var points: PackedVector2Array = bolt["points"]
		var glow: Color = bolt_glow_color
		glow.a *= fade
		var core: Color = bolt_color
		core.a *= fade
		draw_polyline(points, glow, bolt_width * 3.0)
		draw_polyline(points, core, bolt_width)
		if show_hitboxes:
			var ring: Color = range_ring_color
			ring.a *= fade
			draw_arc(bolt["ring"], arc_conduit_range, 0.0, TAU, 48, ring, 1.0)

	if show_hitboxes and ram_visible_left > 0.0:
		draw_arc(ram_center, kinetic_ram_radius, 0.0, TAU, 32, kinetic_ram_hitbox_color, 1.0)

	if preview_active:
		draw_throw_preview()


func draw_throw_preview() -> void:
	var line_color: Color = tesla_preview_color if tesla_cooldown_left <= 0.0 else tesla_preview_unready_color
	var points: PackedVector2Array = PackedVector2Array()
	var point_count: int = maxi(tesla_preview_points, 2)
	for index in range(point_count + 1):
		var t: float = float(index) / float(point_count)
		points.append(throw_start.lerp(throw_target, t) + Vector2(0.0, -tesla_arc_height * 4.0 * t * (1.0 - t)))
	draw_polyline(points, line_color, tesla_preview_width)

	var fill: Color = line_color
	fill.a = tesla_preview_fill_alpha
	draw_circle(throw_target, tesla_preview_circle_radius, fill)
	draw_arc(throw_target, tesla_preview_circle_radius, 0.0, TAU, 32, line_color, tesla_preview_width)
