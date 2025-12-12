extends Node

signal special_event_started()
signal special_event_ended()

var special_scenes: Array[PackedScene] = []
var screen_size: Vector2i
var ground_sprite: Sprite2D
var special_ground: Node  # Reference to the special ground node
var powerup_manager: Node = null  # Reference to the powerup manager

# Timing variables
var time_since_last_event: float = 0.0
var next_event_interval: float = 0.0
var is_event_active: bool = false
var event_phase: String = "waiting"  # "waiting", "preparing", "spawning", "active"

# Event phases
var prepare_timer: float = 0.0
const PREPARE_DURATION: float = 3.0  # 5 seconds with only coins
var button_delay_timer: float = 0.0
const BUTTON_DELAY: float = 3.0  # 3 seconds delay before showing buttons

# Scheduling range variables
var min_event_interval: float = 10.0
var max_event_interval: float = 30.0

var is_debugging: bool = false

var current_special: Node2D = null
var current_special_scene_path: String = ""  # Track which scene was spawned
var buttons_ui: CanvasLayer = null  # Reference to buttons UI
var buttons_shown: bool = false  # Track if buttons have been shown for this event
var button_pressed: bool = false  # Track if a button was pressed (don't end event until special leaves screen)
var pending_cleanup: bool = false  # Track if we're waiting for special to leave screen before cleanup
var shown_specials: Array[int] = []  # Track which special indices have been shown in this cycle

func initialize(special_scenes_param: Array[PackedScene], screen_size_param: Vector2i, ground_sprite_param: Sprite2D, special_ground_param: Node, buttons_ui_param: CanvasLayer, powerup_manager_param: Node = null):
	special_scenes = special_scenes_param
	screen_size = screen_size_param
	ground_sprite = ground_sprite_param
	special_ground = special_ground_param
	buttons_ui = buttons_ui_param
	powerup_manager = powerup_manager_param
	shown_specials.clear()  # Initialize shown specials tracking
	schedule_next_event()

func debug():
	is_debugging = true

func reset():
	time_since_last_event = 0.0
	is_event_active = false
	event_phase = "waiting"
	prepare_timer = 0.0
	button_delay_timer = 0.0
	pending_cleanup = false
	shown_specials.clear()  # Reset shown specials tracking
	if current_special and is_instance_valid(current_special):
		current_special.queue_free()
		current_special = null
	schedule_next_event()

func schedule_next_event():
	# Schedule next event in 10-30 seconds (10-30 seconds)
	if is_debugging:
		next_event_interval = 1.0
	else:
		next_event_interval = randf_range(min_event_interval, max_event_interval)
	time_since_last_event = 0.0

func update(delta: float, current_speed: float, camera_x: float) -> void:
	if is_event_active:
		handle_active_event(delta, current_speed, camera_x)
	else:
		# Check if powerup UI is active - if so, don't increment timer or start events
		var powerup_ui_active = false
		if powerup_manager and powerup_manager.has_method("is_powerup_ui_active"):
			powerup_ui_active = powerup_manager.is_powerup_ui_active()

		# Only increment timer if powerup UI is not active
		if not powerup_ui_active:
			time_since_last_event += delta

		# Check if it's time for a new event (only if powerup UI is not active)
		if time_since_last_event >= next_event_interval and not powerup_ui_active:
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
			# Wait 3 seconds with only coins
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

	# Get available specials (not yet shown in this cycle)
	var available_specials: Array[PackedScene] = []
	var available_indices: Array[int] = []

	for i in range(special_scenes.size()):
		if i not in shown_specials:
			available_specials.append(special_scenes[i])
			available_indices.append(i)

	# If all specials have been shown, reset and use all specials
	if available_specials.is_empty():
		shown_specials.clear()
		available_specials = special_scenes.duplicate()
		available_indices.clear()
		for i in range(special_scenes.size()):
			available_indices.append(i)

	# Pick a random special from available ones
	var random_index = randi() % available_specials.size()
	var special_scene = available_specials[random_index]
	var selected_index = available_indices[random_index]

	current_special = special_scene.instantiate()

	# Store the scene path for determining if it's good/bad
	# We need to get the path from the PackedScene
	current_special_scene_path = special_scenes[selected_index].resource_path

	# Mark this special as shown by its index
	if selected_index not in shown_specials:
		shown_specials.append(selected_index)

	# Connect to the special's signals
	if current_special.has_signal("entered_camera_view"):
		current_special.entered_camera_view.connect(_on_special_entered_camera_view)
	if current_special.has_signal("left_camera_view"):
		current_special.left_camera_view.connect(_on_special_left_camera_view)

	# Position flag so bottom touches ground level (y=1280)
	# Handle both Sprite2D and AnimatedSprite2D
	var sprite = null
	var sprite_height = 0.0
	var sprite_scale = Vector2(1, 1)

	# Try to get Sprite2D first
	if current_special.has_node("Sprite2D"):
		sprite = current_special.get_node("Sprite2D")
		if sprite and sprite.texture:
			sprite_height = sprite.texture.get_height()
			sprite_scale = sprite.scale
	# If not found, try AnimatedSprite2D
	elif current_special.has_node("AnimatedSprite2D"):
		sprite = current_special.get_node("AnimatedSprite2D")
		if sprite and sprite.sprite_frames:
			# Get the first frame's texture to determine height
			var first_frame = sprite.sprite_frames.get_frame_texture("default", 0)
			if first_frame:
				sprite_height = first_frame.get_height()
			sprite_scale = sprite.scale

	# If we still don't have a valid sprite, use a default height
	if sprite_height == 0.0:
		sprite_height = 50.0  # Default fallback height

	# Ground level is at y=1280
	# Sprite2D origin is at center by default, so we need to position center at (ground_y - half_height)
	const GROUND_LEVEL_Y: float = 1280.0
	var sprite_half_height = (sprite_height * sprite_scale.y) / 2.0
	var spawn_y = GROUND_LEVEL_Y - sprite_half_height

	# Calculate sprite width for proper off-screen positioning
	var sprite_width = 0.0
	if sprite and sprite is Sprite2D and sprite.texture:
		sprite_width = sprite.texture.get_width() * sprite_scale.x
	elif sprite and sprite is AnimatedSprite2D and sprite.sprite_frames:
		var first_frame = sprite.sprite_frames.get_frame_texture("default", 0)
		if first_frame:
			sprite_width = first_frame.get_width() * sprite_scale.x

	# If we still don't have a valid width, use a default
	if sprite_width == 0.0:
		sprite_width = 100.0  # Default fallback width

	# Sprite origin is at center, so add half width to ensure left edge is off-screen
	var sprite_half_width = sprite_width / 2.0

	# Position so the LEFT edge of the sprite is past the right edge of the screen
	var spawn_x = camera_x + screen_size.x + sprite_half_width + GameConstants.SPAWN_OFFSET

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

func _on_special_left_camera_view():
	# Special object has left camera view - cleanup if pending, otherwise end event
	print("[SpecialEventManager] DEBUG: Special left camera view (pending_cleanup=%s, is_event_active=%s, event_phase=%s)" % [pending_cleanup, is_event_active, event_phase])
	if pending_cleanup:
		# We were waiting for the special to leave before cleanup
		# Event has already been ended, just clean up the special object
		print("[SpecialEventManager] DEBUG: Pending cleanup detected - cleaning up special now")
		cleanup_special()
	else:
		# Normal flow - special left screen, end event
		if is_event_active and event_phase == "active":
			print("[SpecialEventManager] DEBUG: Normal flow - ending event because special left screen")
			end_special_event()

func mark_button_pressed():
	# Called when a button is pressed - mark that button was pressed
	# End the event immediately, but wait for special to leave screen before cleanup
	print("[SpecialEventManager] DEBUG: Button pressed - ending event, will cleanup when special leaves screen")
	button_pressed = true
	# End the event immediately - this will set pending_cleanup if special is still visible
	if is_event_active:
		end_special_event()

func end_special_event():
	print("[SpecialEventManager] DEBUG: end_special_event() called (button_pressed=%s)" % button_pressed)
	is_event_active = false
	event_phase = "waiting"
	prepare_timer = 0.0
	current_special_scene_path = ""
	buttons_shown = false  # Reset for next event

	button_pressed = false  # Reset button press flag

	# Don't hide buttons here - let them hide after their 1 second timer completes
	# The buttons will hide themselves after 1 second or when pressed

	# Check if special is still on screen before freeing
	if current_special and is_instance_valid(current_special):
		# Check if special has already left the screen
		# The special object tracks this with has_left_view property
		var special_has_left_view = false
		if "has_left_view" in current_special:
			special_has_left_view = current_special.has_left_view

		print("[SpecialEventManager] DEBUG: Special exists, has_left_view=%s" % special_has_left_view)

		# If special is still visible, wait for it to leave before cleanup
		if not special_has_left_view:
			pending_cleanup = true
			print("[SpecialEventManager] DEBUG: Special still visible - setting pending_cleanup=true, waiting for special to leave")
			# Don't free yet - wait for _on_special_left_camera_view() to be called
			# Schedule and emit now since event is ending
			schedule_next_event()
			special_event_ended.emit()
			print("[SpecialEventManager] DEBUG: Event ended signal emitted, waiting for special to leave before cleanup")
			return
		else:
			# Special has already left, safe to free immediately
			print("[SpecialEventManager] DEBUG: Special already left view - cleaning up immediately")
			cleanup_special()
			# Schedule and emit after cleanup
			schedule_next_event()
			special_event_ended.emit()
			return
	else:
		# Special doesn't exist or is invalid, just clean up
		print("[SpecialEventManager] DEBUG: Special doesn't exist or is invalid")
		current_special = null

	# If we reach here, cleanup is complete - schedule next event and emit signal
	schedule_next_event()
	special_event_ended.emit()
	print("[SpecialEventManager] DEBUG: Event ended (no special to clean up)")

func cleanup_special():
	# Actually free the special object and reset state
	print("[SpecialEventManager] DEBUG: cleanup_special() called - freeing special from memory")
	if current_special and is_instance_valid(current_special):
		print("[SpecialEventManager] DEBUG: Calling queue_free() on special object")
		current_special.queue_free()
	else:
		print("[SpecialEventManager] DEBUG: Special is null or invalid, nothing to free")
	current_special = null
	pending_cleanup = false
	print("[SpecialEventManager] DEBUG: Cleanup complete, pending_cleanup=%s" % pending_cleanup)

func get_event_active() -> bool:
	return is_event_active

func get_current_special_scene_path() -> String:
	return current_special_scene_path
