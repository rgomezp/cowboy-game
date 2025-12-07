extends Node

signal special_event_started()
signal special_event_ended()

var special_scenes: Array[PackedScene] = []
var screen_size: Vector2i
var ground_sprite: Sprite2D

# Timing variables
var time_since_last_event: float = 0.0
var next_event_interval: float = 0.0
var is_event_active: bool = false
var event_phase: String = "waiting"  # "waiting", "preparing", "spawning", "active"

# Event phases
var prepare_timer: float = 0.0
const PREPARE_DURATION: float = 5.0  # 5 seconds with only coins

var current_special: Node2D = null

func initialize(special_scenes: Array[PackedScene], screen_size: Vector2i, ground_sprite: Sprite2D):
	self.special_scenes = special_scenes
	self.screen_size = screen_size
	self.ground_sprite = ground_sprite
	schedule_next_event()

func reset():
	time_since_last_event = 0.0
	is_event_active = false
	event_phase = "waiting"
	prepare_timer = 0.0
	if current_special and is_instance_valid(current_special):
		current_special.queue_free()
		current_special = null
	schedule_next_event()

func schedule_next_event():
	# Schedule next event in 0-5 seconds (for testing - normally 60-120 seconds / 1-2 minutes)
	next_event_interval = randf_range(0.0, 5.0)
	time_since_last_event = 0.0
	print("[SpecialEvent] Scheduled next event in %.1f seconds" % next_event_interval)

func update(delta: float, current_speed: float, camera_x: float) -> void:
	if is_event_active:
		handle_active_event(delta, current_speed, camera_x)
	else:
		# Check if it's time for a new event
		time_since_last_event += delta
		if time_since_last_event >= next_event_interval:
			print("[SpecialEvent] Time reached! Starting special event (waited %.1f seconds)" % time_since_last_event)
			start_special_event()

func start_special_event():
	is_event_active = true
	event_phase = "preparing"
	prepare_timer = 0.0
	print("[SpecialEvent] Event started - Phase: %s (preparing for %.1f seconds)" % [event_phase, PREPARE_DURATION])
	special_event_started.emit()

func handle_active_event(delta: float, current_speed: float, camera_x: float):
	match event_phase:
		"preparing":
			# Wait 5 seconds with only coins
			prepare_timer += delta
			if prepare_timer >= PREPARE_DURATION:
				print("[SpecialEvent] Preparation complete (%.1f seconds). Spawning special..." % prepare_timer)
				spawn_special(current_speed, camera_x)
				event_phase = "active"
				print("[SpecialEvent] Phase changed to: %s" % event_phase)

		"active":
			# Check if special has moved off screen
			# The special flag script handles its own cleanup, so we just check if it's still valid
			if not current_special or not is_instance_valid(current_special):
				# Special was removed, end event
				print("[SpecialEvent] Special object removed/cleaned up. Ending event.")
				end_special_event()

func spawn_special(current_speed: float, camera_x: float):
	if special_scenes.is_empty():
		print("[SpecialEvent] ERROR: No special scenes available!")
		end_special_event()
		return

	# Pick a random special
	var special_scene = special_scenes[randi() % special_scenes.size()]
	current_special = special_scene.instantiate()
	var special_name = current_special.name
	print("[SpecialEvent] Spawning special: %s" % special_name)

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
	# Set z_index lower than ground so flags appear behind it
	current_special.z_index = -1
	print("[SpecialEvent] Special positioned at: (%.1f, %.1f), camera_x: %.1f, sprite_height: %.1f, scale: %s" % [spawn_x, spawn_y, camera_x, sprite_height, sprite_scale])

	# Add to scene tree first so get_tree() works
	add_child(current_special)

	# Initialize the special flag script if it exists (after adding to tree)
	if current_special.has_method("initialize"):
		current_special.initialize(current_speed, screen_size, camera_x)
		print("[SpecialEvent] Special initialized with speed: %.1f (30%% parallax)" % current_speed)

func end_special_event():
	print("[SpecialEvent] Ending special event. Phase: %s" % event_phase)
	is_event_active = false
	event_phase = "waiting"
	prepare_timer = 0.0

	if current_special and is_instance_valid(current_special):
		print("[SpecialEvent] Cleaning up special object: %s" % current_special.name)
		current_special.queue_free()
	current_special = null

	schedule_next_event()
	print("[SpecialEvent] Event ended. Spawners re-enabled.")
	special_event_ended.emit()

func get_event_active() -> bool:
	return is_event_active
