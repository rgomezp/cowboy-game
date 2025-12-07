extends Node

signal special_event_started()
signal special_event_ended()

var special_scenes: Array[PackedScene] = []
var screen_size: Vector2i
var ground_sprite: Sprite2D
var special_ground: Node  # Reference to the special ground node

# Timing variables
var time_since_last_event: float = 0.0
var next_event_interval: float = 0.0
var is_event_active: bool = false
var event_phase: String = "waiting"  # "waiting", "preparing", "spawning", "active"

# Event phases
var prepare_timer: float = 0.0
const PREPARE_DURATION: float = 5.0  # 5 seconds with only coins
var button_delay_timer: float = 0.0
const BUTTON_DELAY: float = 3.0  # 3 seconds delay before showing buttons

var current_special: Node2D = null
var current_special_scene_path: String = ""  # Track which scene was spawned
var buttons_ui: CanvasLayer = null  # Reference to buttons UI
var buttons_shown: bool = false  # Track if buttons have been shown for this event

func initialize(special_scenes_param: Array[PackedScene], screen_size_param: Vector2i, ground_sprite_param: Sprite2D, special_ground_param: Node, buttons_ui_param: CanvasLayer):
	special_scenes = special_scenes_param
	screen_size = screen_size_param
	ground_sprite = ground_sprite_param
	special_ground = special_ground_param
	buttons_ui = buttons_ui_param
	schedule_next_event()

func reset():
	time_since_last_event = 0.0
	is_event_active = false
	event_phase = "waiting"
	prepare_timer = 0.0
	button_delay_timer = 0.0
	if current_special and is_instance_valid(current_special):
		current_special.queue_free()
		current_special = null
	schedule_next_event()

func schedule_next_event():
	# Schedule next event in 60-120 seconds (1-2 minutes)
	next_event_interval = randf_range(60.0, 120.0)
	time_since_last_event = 0.0

func update(delta: float, current_speed: float, camera_x: float) -> void:
	if is_event_active:
		handle_active_event(delta, current_speed, camera_x)
	else:
		# Check if it's time for a new event
		time_since_last_event += delta
		if time_since_last_event >= next_event_interval:
			start_special_event()

func start_special_event():
	is_event_active = true
	event_phase = "preparing"
	prepare_timer = 0.0
	button_delay_timer = 0.0  # Start delay timer for showing buttons
	# Reset buttons UI for new event
	if buttons_ui and buttons_ui.has_method("reset_for_new_event"):
		buttons_ui.reset_for_new_event()
	special_event_started.emit()

func handle_active_event(delta: float, current_speed: float, camera_x: float):
	match event_phase:
		"preparing":
			# Wait 5 seconds with only coins
			prepare_timer += delta

			# Show buttons after 3 second delay
			button_delay_timer += delta
			if button_delay_timer >= BUTTON_DELAY and buttons_ui and not buttons_ui.get_is_visible():
				buttons_ui.show_buttons()

			if prepare_timer >= PREPARE_DURATION:
				spawn_special(current_speed, camera_x)
				event_phase = "active"

		"active":
			# Check if special has moved off screen
			# The special flag script handles its own cleanup, so we just check if it's still valid
			if not current_special or not is_instance_valid(current_special):
				# Special was removed, end event
				end_special_event()

func spawn_special(current_speed: float, camera_x: float):
	if special_scenes.is_empty():
		end_special_event()
		return

	# Pick a random special
	var special_index = randi() % special_scenes.size()
	var special_scene = special_scenes[special_index]
	current_special = special_scene.instantiate()

	# Store the scene path for determining if it's good/bad
	# We need to get the path from the PackedScene
	current_special_scene_path = special_scene.resource_path

	# Connect to the special's entered_camera_view signal
	if current_special.has_signal("entered_camera_view"):
		current_special.entered_camera_view.connect(_on_special_entered_camera_view)

	# Position flag so bottom touches ground level (y=1280)
	var sprite = current_special.get_node("Sprite2D")
	var sprite_height = sprite.texture.get_height()
	var sprite_scale = Vector2(1, 1)
	if "scale" in sprite:
		sprite_scale = sprite.scale

	# Ground level is at y=1280
	# Sprite2D origin is at center by default, so we need to position center at (ground_y - half_height)
	const GROUND_LEVEL_Y: float = 1280.0
	var sprite_half_height = (sprite_height * sprite_scale.y) / 2.0
	var spawn_y = GROUND_LEVEL_Y - sprite_half_height

	# Position at right edge of screen (ahead of camera)
	var spawn_x = camera_x + screen_size.x + 100

	current_special.position = Vector2(spawn_x, spawn_y)

	# Add to special ground node (which is behind main ground in scene hierarchy)
	special_ground.add_child(current_special)

	# Initialize the special flag script if it exists (after adding to tree)
	if current_special.has_method("initialize"):
		current_special.initialize(current_speed, screen_size, camera_x)

func _on_special_entered_camera_view():
	# Notify buttons that sprite has entered view - starts 1 second timer
	if buttons_ui and not buttons_shown:
		buttons_ui.on_sprite_entered_view()
		buttons_shown = true

func end_special_event():
	is_event_active = false
	event_phase = "waiting"
	prepare_timer = 0.0
	current_special_scene_path = ""
	buttons_shown = false  # Reset for next event

	# Don't hide buttons here - let them hide after their 1 second timer completes
	# The buttons will hide themselves after 1 second or when pressed

	if current_special and is_instance_valid(current_special):
		current_special.queue_free()
	current_special = null

	schedule_next_event()
	special_event_ended.emit()

func get_event_active() -> bool:
	return is_event_active

func get_current_special_scene_path() -> String:
	return current_special_scene_path
