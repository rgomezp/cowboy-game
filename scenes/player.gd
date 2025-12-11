extends CharacterBody2D


const GRAVITY : int = 4200
const GLIDE_GRAVITY : int = 1200
const JUMP_VELOCITY = -1800
const DOUBLE_JUMP_VELOCITY = -1000
const DOUBLE_JUMP_PEAK_TOLERANCE = 300  # Distance from peak where double jump is still allowed (increased for later timing)

var is_sliding: bool = false
var sliding_timer: float = 0.0
var has_double_jumped: bool = false
var jump_peak_y: float = 0.0
var is_tracking_peak: bool = false

# Blinking/immunity state
var is_blinking: bool = false
var blink_timer: float = 0.0
var blink_count: int = 0
var total_blinks: int = 0
const BLINK_DURATION: float = 0.2  # Time for each blink (on/off cycle)

# Mobile touch input state
var touch_start_position: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_touching: bool = false
var touch_index: int = -1
const SWIPE_THRESHOLD: float = 100.0  # Minimum distance for swipe detection
const TAP_MAX_DURATION: float = 0.2  # Maximum time for a tap (seconds)
const TAP_MAX_DISTANCE: float = 50.0  # Maximum distance for a tap (pixels)
var touch_jump_pressed: bool = false
var touch_jump_just_pressed: bool = false
var touch_slide_pressed: bool = false

# Jump buffering - remembers jump input slightly before landing
var jump_buffer_time: float = 0.0
const JUMP_BUFFER_DURATION: float = 0.15  # 150ms window to buffer jump input

# Slide buffering - remembers slide input slightly before landing
var slide_buffer_time: float = 0.0
const SLIDE_BUFFER_DURATION: float = 0.5  # 500ms window to buffer slide input


func _is_shotgun_active() -> bool:
	# Check if shotgun power up is active
	var main_node = get_parent()
	if not main_node or not "powerup_manager" in main_node:
		return false

	var powerup_manager = main_node.powerup_manager
	if not powerup_manager:
		return false

	var active_powerup = powerup_manager.get_active_powerup()
	return active_powerup != null and active_powerup.name == "shotgun" and active_powerup.is_active

func _is_gokart_active() -> bool:
	# Check if gokart power up is active
	var main_node = get_parent()
	if not main_node or not "powerup_manager" in main_node:
		return false

	var powerup_manager = main_node.powerup_manager
	if not powerup_manager:
		return false

	var active_powerup = powerup_manager.get_active_powerup()
	return active_powerup != null and active_powerup.name == "gokart" and active_powerup.is_active

func _get_animation_name(base_name: String) -> String:
	# Prioritize gokart animation if active (single animation for all states)
	if _is_gokart_active():
		if $AnimatedSprite2D.sprite_frames.has_animation("kart"):
			return "kart"
		# Fallback to "gokart" if "kart" doesn't exist
		if $AnimatedSprite2D.sprite_frames.has_animation("gokart"):
			return "gokart"

	# Return the shotgun version of the animation if shotgun is active, otherwise return base name
	if _is_shotgun_active():
		var shotgun_name = base_name + "_shotgun"
		# Check if the animation exists before using it
		if $AnimatedSprite2D.sprite_frames.has_animation(shotgun_name):
			return shotgun_name
	return base_name

func _unhandled_input(event: InputEvent) -> void:
	# Handle mobile touch input (only process if not handled by UI buttons)
	# Using _unhandled_input ensures button presses don't trigger player actions
	if event is InputEventScreenTouch:
		var touch_event = event as InputEventScreenTouch
		if touch_event.pressed:
			# Touch started - trigger jump immediately on touch down
			# This allows tap-and-hold: tap triggers jump, keep holding to glide
			if touch_index == -1:  # Only track first touch
				touch_index = touch_event.index
				touch_start_position = touch_event.position
				touch_start_time = Time.get_ticks_msec() / 1000.0
				is_touching = true
				# Trigger jump immediately on touch down (not on release)
				touch_jump_just_pressed = true
		else:
			# Touch ended
			if touch_event.index == touch_index:
				var touch_end_position = touch_event.position
				var touch_delta = touch_end_position - touch_start_position

				# Detect swipe down (only on release, jump is handled on touch start)
				if touch_delta.y > SWIPE_THRESHOLD and abs(touch_delta.x) < abs(touch_delta.y):
					# Swipe down detected
					touch_slide_pressed = true

				# Reset touch state
				is_touching = false
				touch_index = -1
				touch_start_position = Vector2.ZERO
				touch_start_time = 0.0

	elif event is InputEventScreenDrag:
		var drag_event = event as InputEventScreenDrag
		if drag_event.index == touch_index:
			# Track drag for swipe detection
			var drag_delta = drag_event.position - touch_start_position
			# If dragging down significantly, it's a swipe down
			if drag_delta.y > SWIPE_THRESHOLD and abs(drag_delta.x) < abs(drag_delta.y):
				# Swipe down detected during drag
				touch_slide_pressed = true
				is_touching = false
				touch_index = -1

func _physics_process(delta: float) -> void:
	# Update collision shapes based on gokart power-up state
	var gokart_active = _is_gokart_active()

	# Update jump buffer timer
	if jump_buffer_time > 0:
		jump_buffer_time -= delta

	# Check for jump input and buffer it
	var jump_input_this_frame = Input.is_action_just_pressed("ui_accept") or touch_jump_just_pressed
	if jump_input_this_frame:
		jump_buffer_time = JUMP_BUFFER_DURATION

	# Update slide buffer timer
	if slide_buffer_time > 0:
		slide_buffer_time -= delta

	# Check for slide input and buffer it
	var slide_input_this_frame = Input.is_action_just_pressed("ui_down") or touch_slide_pressed
	if slide_input_this_frame:
		slide_buffer_time = SLIDE_BUFFER_DURATION

	# Use glide gravity only if double jump has been used, input is held, and gokart is not active
	# If input is released while gliding, return to normal gravity for better maneuverability
	# Check both keyboard and touch input for jump
	# For touch: if holding longer than tap duration, it counts as a hold for gliding
	# This allows tap-and-hold gesture: tap for double jump, then hold to glide
	var touch_hold_duration = 0.0
	if is_touching and touch_start_time > 0.0:
		touch_hold_duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time
	var is_touching_and_holding = is_touching and touch_hold_duration > TAP_MAX_DURATION
	var is_holding_jump = Input.is_action_pressed("ui_accept") or is_touching_and_holding
	var current_gravity = GLIDE_GRAVITY if (has_double_jumped and is_holding_jump and not gokart_active) else GRAVITY
	velocity.y += current_gravity * delta

	# Update collision shapes - do this before move_and_slide to ensure proper collision detection
	if gokart_active:
		# When gokart is active, use kart collision shape
		$KartCollisionShape.disabled = false
		$RunCollisionShape.disabled = true
		$SlideCollisionShape.disabled = true
		# If on ground, ensure velocity.y is not positive to prevent falling through
		if is_on_floor() and velocity.y > 0:
			velocity.y = 0
	else:
		# When gokart is not active, use normal collision shapes
		$KartCollisionShape.disabled = true
		# Ensure at least one collision shape is enabled
		if not is_sliding:
			$RunCollisionShape.disabled = false
			$SlideCollisionShape.disabled = true
		else:
			$RunCollisionShape.disabled = true
			$SlideCollisionShape.disabled = false

	# Update sliding timer
	if is_sliding:
		sliding_timer += delta
		# Calculate animation duration: 4 frames / 3.0 speed = ~1.33 seconds
		var animation_duration = 4.0 / 3.0
		if sliding_timer >= animation_duration:
			is_sliding = false
			sliding_timer = 0.0
			if not gokart_active:
				$RunCollisionShape.disabled = false

	if is_on_floor():
		# Reset double jump when touching the ground
		has_double_jumped = false
		is_tracking_peak = false
		jump_peak_y = 0.0
		if not get_parent().game_running:
			$AnimatedSprite2D.play(_get_animation_name("idle"))
		else:
			# Check for buffered jump input (includes current frame input)
			if jump_buffer_time > 0:
				velocity.y = JUMP_VELOCITY
				jump_buffer_time = 0  # Clear the buffer
				# Start tracking peak when jumping
				is_tracking_peak = true
				jump_peak_y = global_position.y
			# Check for buffered slide input (includes current frame input)
			elif slide_buffer_time > 0 and not is_sliding and not gokart_active:
				is_sliding = true
				sliding_timer = 0.0
				slide_buffer_time = 0  # Clear the buffer
				$AnimatedSprite2D.play(_get_animation_name("sliding"))
				$RunCollisionShape.disabled = true
			elif is_sliding and not gokart_active:
				# Keep sliding animation playing and collision disabled
				$AnimatedSprite2D.play(_get_animation_name("sliding"))
			else:
				$AnimatedSprite2D.play(_get_animation_name("running"))
				if not gokart_active:
					$RunCollisionShape.disabled = false
	else:
		# Track the peak height while rising
		if is_tracking_peak:
			if velocity.y < 0:  # Still rising
				jump_peak_y = min(jump_peak_y, global_position.y)
			else:  # Started falling, stop tracking
				is_tracking_peak = false

		# Allow double jump only near the peak of the first jump (disabled when gokart is active)
		# Check both keyboard and touch input for double jump
		var double_jump_input = Input.is_action_just_pressed("ui_accept") or touch_jump_just_pressed
		var distance_from_peak = abs(global_position.y - jump_peak_y)
		if double_jump_input and not has_double_jumped and not gokart_active and distance_from_peak <= DOUBLE_JUMP_PEAK_TOLERANCE:
			velocity.y = DOUBLE_JUMP_VELOCITY
			has_double_jumped = true
			is_tracking_peak = false
			jump_buffer_time = 0  # Clear any buffer when double jumping

		# Play gliding animation only if double jumped AND holding jump input
		# If input is released while gliding, switch to jumping animation
		if has_double_jumped and is_holding_jump and not gokart_active:
			$AnimatedSprite2D.play(_get_animation_name("gliding"))
		else:
			$AnimatedSprite2D.play(_get_animation_name("jumping"))

	move_and_slide()

	# Reset touch input flags at end of frame if they weren't used
	# This ensures they don't persist to the next frame
	touch_jump_just_pressed = false
	touch_slide_pressed = false

	# Handle blinking
	if is_blinking:
		blink_timer += delta
		if blink_timer >= BLINK_DURATION:
			blink_timer = 0.0
			blink_count += 1
			# Toggle visibility
			$AnimatedSprite2D.visible = (blink_count % 2 == 0)

			# Check if we've completed all blinks (3 blinks = 6 toggles)
			if blink_count >= total_blinks * 2:
				stop_blinking()

func start_blinking(blink_times: int):
	is_blinking = true
	blink_timer = 0.0
	blink_count = 0
	total_blinks = blink_times
	$AnimatedSprite2D.visible = true  # Start visible

func stop_blinking():
	is_blinking = false
	blink_timer = 0.0
	blink_count = 0
	$AnimatedSprite2D.visible = true  # Ensure visible when done
	# Notify main that immunity period is over
	var main_node = get_parent()
	if main_node and main_node.has_method("end_player_immunity"):
		main_node.end_player_immunity()
