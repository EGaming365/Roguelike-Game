extends Control

@export var columns: int = 4
@export var collapsed_slots: int = 12
@export var slot_size: Vector2 = Vector2(84, 100)
@export var slot_gap: int = 12
@export var edge_margin: float = 37.0
@export_enum("top_left", "top_right", "bottom_left", "bottom_right") var anchor_corner: String = "top_right"
@export var hide_when_empty: bool = true
@export var show_stack_counts: bool = true
@export var expand_duration: float = 0.45
@export var resize_duration: float = 0.25
@export var upgrade_ids: Array[String] = ["kinetic_ram", "arc_conduit", "tesla_tower", "overclocked_servos"]
@export var upgrade_names: Array[String] = ["Kinetic Ram", "Arc Conduit", "Tesla Tower", "Overclocked Servos"]
@export var upgrade_icons: Array[Texture2D] = []
@export var fallback_icon: Texture2D
@export var slot_color: Color = Color(0.12, 0.12, 0.14, 0.9)
@export var slot_hover_color: Color = Color(0.25, 0.25, 0.3, 0.95)
@export var icon_padding: float = 4.0
@export var stack_font_size: int = 24
@export var stack_color: Color = Color(1.0, 1.0, 1.0)
@export var stack_outline_size: int = 4
@export var initials_font_size: int = 14
@export var arrow_size: Vector2 = Vector2(14.0, 7.0)
@export var arrow_width: float = 2.0
@export var arrow_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var arrow_button_height: float = 22.0
@export var upgrade_source_group: StringName = &"player"
@export var ui_blocker_group: StringName = &"ui_blocker"

@onready var panel: PanelContainer = find_child("Panel", true, false) as PanelContainer
@onready var grid: GridContainer = find_child("GridContainer", true, false) as GridContainer
@onready var clip: Control = find_child("Clip", true, false) as Control
@onready var arrow_button: Button = find_child("ArrowButton", true, false) as Button

var upgrades_source: Node = null
var last_hash: int = -1
var has_synced: bool = false
var expanded: bool = false
var slot_count: int = 0
var clip_height: float = 0.0
var arrow_rotation: float = 0.0
var height_tween: Tween
var arrow_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(ui_blocker_group)

	if panel == null or grid == null:
		push_warning("UpgradeHUD needs a PanelContainer named Panel that contains a GridContainer")
		set_process(false)
		return

	grid.columns = columns
	grid.add_theme_constant_override("h_separation", slot_gap)
	grid.add_theme_constant_override("v_separation", slot_gap)

	if clip == null:
		push_warning("UpgradeHUD is missing a Control named Clip around the GridContainer, so expanding cannot animate")
	else:
		clip.clip_contents = true
		clip.custom_minimum_size = Vector2(grid_width(), 0.0)

	if arrow_button != null:
		arrow_button.flat = true
		arrow_button.text = ""
		arrow_button.focus_mode = Control.FOCUS_NONE
		arrow_button.custom_minimum_size = Vector2(0.0, arrow_button_height)
		arrow_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		arrow_button.draw.connect(draw_arrow)
		arrow_button.pressed.connect(toggle_expanded)
		arrow_button.visible = false
	else:
		push_warning("UpgradeHUD is missing a Button named ArrowButton")

	panel.minimum_size_changed.connect(fit_panel)
	panel.resized.connect(_position_panel)
	get_viewport().size_changed.connect(_position_panel)

	panel.visible = not hide_when_empty
	fit_panel()


func _process(_delta: float) -> void:
	if upgrades_source == null or not is_instance_valid(upgrades_source):
		find_upgrades_source()
		if upgrades_source == null:
			return

	var stacks: Variant = upgrades_source.get("upgrade_stacks")
	if typeof(stacks) != TYPE_DICTIONARY:
		return

	var stack_data: Dictionary = stacks
	var current_hash: int = stack_data.hash()
	if has_synced and current_hash == last_hash:
		return

	last_hash = current_hash
	refresh(stack_data, has_synced)
	has_synced = true


func find_upgrades_source() -> void:
	var holder: Node = get_tree().get_first_node_in_group(upgrade_source_group)
	if holder == null:
		return
	var source: Variant = holder.get("upgrades")
	if source is Node:
		upgrades_source = source as Node


func refresh(stacks: Dictionary, animate: bool) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	slot_count = 0
	for id in stacks.keys():
		var amount: int = int(stacks[id])
		if amount <= 0:
			continue
		grid.add_child(build_slot(str(id), amount))
		slot_count += 1

	panel.visible = slot_count > 0 or not hide_when_empty

	if slot_count <= collapsed_slots:
		expanded = false

	if arrow_button != null:
		arrow_button.visible = slot_count > collapsed_slots

	animate_height(resize_duration if animate else 0.0)
	animate_arrow(resize_duration if animate else 0.0)


func build_slot(id: String, amount: int) -> Control:
	var display_name: String = display_name_for(id)

	var slot: Control = Control.new()
	slot.custom_minimum_size = slot_size
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.tooltip_text = display_name if amount <= 1 else "%s (x%d)" % [display_name, amount]

	var background: ColorRect = ColorRect.new()
	background.color = slot_color
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_parent(background)
	slot.add_child(background)

	var icon: Texture2D = icon_for(id)
	if icon != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill_parent(icon_rect)
		icon_rect.offset_left = icon_padding
		icon_rect.offset_top = icon_padding
		icon_rect.offset_right = -icon_padding
		icon_rect.offset_bottom = -icon_padding
		slot.add_child(icon_rect)
	else:
		var initials: Label = Label.new()
		initials.text = initials_for(display_name)
		initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initials.mouse_filter = Control.MOUSE_FILTER_IGNORE
		initials.add_theme_font_size_override("font_size", initials_font_size)
		fill_parent(initials)
		slot.add_child(initials)

	if show_stack_counts and amount > 1:
		var count: Label = Label.new()
		count.text = "x" + str(amount)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", stack_font_size)
		count.add_theme_color_override("font_color", stack_color)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", stack_outline_size)
		fill_parent(count)
		count.offset_right = -3.0
		count.offset_bottom = -1.0
		slot.add_child(count)

	slot.mouse_entered.connect(on_slot_hover.bind(background, true))
	slot.mouse_exited.connect(on_slot_hover.bind(background, false))

	return slot


func fill_parent(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func on_slot_hover(background: ColorRect, hovering: bool) -> void:
	if is_instance_valid(background):
		background.color = slot_hover_color if hovering else slot_color


func display_name_for(id: String) -> String:
	var index: int = upgrade_ids.find(id)
	if index >= 0 and index < upgrade_names.size():
		return upgrade_names[index]
	return id.capitalize()


func icon_for(id: String) -> Texture2D:
	var index: int = upgrade_ids.find(id)
	if index >= 0 and index < upgrade_icons.size() and upgrade_icons[index] != null:
		return upgrade_icons[index]
	return fallback_icon


func initials_for(display_name: String) -> String:
	var result: String = ""
	for word in display_name.split(" ", false):
		result += word.substr(0, 1).to_upper()
		if result.length() >= 2:
			break
	return result


func grid_width() -> float:
	var column_count: int = maxi(columns, 1)
	return float(column_count) * slot_size.x + float(column_count - 1) * float(slot_gap)


func rows_for(count: int) -> int:
	return ceili(float(count) / float(maxi(columns, 1)))


func height_for_rows(rows: int) -> float:
	if rows <= 0:
		return 0.0
	return float(rows) * slot_size.y + float(rows - 1) * float(slot_gap)


func target_clip_height() -> float:
	var visible_slots: int = slot_count if expanded else mini(slot_count, collapsed_slots)
	return height_for_rows(rows_for(visible_slots))


func toggle_expanded() -> void:
	if slot_count <= collapsed_slots:
		return
	expanded = not expanded
	animate_height(expand_duration)
	animate_arrow(expand_duration)


func animate_height(duration: float) -> void:
	if clip == null:
		return

	var target: float = target_clip_height()

	if height_tween != null and height_tween.is_valid():
		height_tween.kill()

	if duration <= 0.0:
		set_clip_height(target)
		return

	height_tween = create_tween()
	height_tween.set_trans(Tween.TRANS_CUBIC)
	height_tween.set_ease(Tween.EASE_IN_OUT)
	height_tween.tween_method(set_clip_height, clip_height, target, duration)


func set_clip_height(value: float) -> void:
	clip_height = value
	clip.custom_minimum_size = Vector2(grid_width(), value)
	fit_panel()


func animate_arrow(duration: float) -> void:
	var target: float = PI if expanded else 0.0

	if arrow_tween != null and arrow_tween.is_valid():
		arrow_tween.kill()

	if duration <= 0.0:
		set_arrow_rotation(target)
		return

	arrow_tween = create_tween()
	arrow_tween.set_trans(Tween.TRANS_CUBIC)
	arrow_tween.set_ease(Tween.EASE_IN_OUT)
	arrow_tween.tween_method(set_arrow_rotation, arrow_rotation, target, duration)


func set_arrow_rotation(value: float) -> void:
	arrow_rotation = value
	if arrow_button != null:
		arrow_button.queue_redraw()


func draw_arrow() -> void:
	var center: Vector2 = arrow_button.size * 0.5
	var half_width: float = arrow_size.x * 0.5
	var half_height: float = arrow_size.y * 0.5
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(0.0, half_height),
		Vector2(half_width, -half_height)
	])
	arrow_button.draw_set_transform(center, arrow_rotation, Vector2.ONE)
	arrow_button.draw_polyline(points, arrow_color, arrow_width, true)
	arrow_button.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func fit_panel() -> void:
	panel.size = panel.get_combined_minimum_size()
	_position_panel()


func _position_panel() -> void:
	if panel == null:
		return

	var area: Vector2 = get_viewport_rect().size
	var x: float = edge_margin
	var y: float = edge_margin

	if anchor_corner == "top_right" or anchor_corner == "bottom_right":
		x = area.x - panel.size.x - edge_margin
	if anchor_corner == "bottom_left" or anchor_corner == "bottom_right":
		y = area.y - panel.size.y - edge_margin

	panel.position = Vector2(x, y)


func is_mouse_over() -> bool:
	if panel == null or not panel.visible:
		return false
	return panel.get_global_rect().has_point(panel.get_global_mouse_position())
