extends CharacterBody2D


const GRAVITY : int = 4200
const GLIDE_GRAVITY : int = 1200
const JUMP_VELOCITY = -1800
const DOUBLE_JUMP_VELOCITY = -1000
const DOUBLE_JUMP_PEAK_TOLERANCE = 150  # Distance from peak where double jump is still allowed

var is_sliding: bool = false
var sliding_timer: float = 0.0
var has_double_jumped: bool = false
var jump_peak_y: float = 0.0
var is_tracking_peak: bool = false


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

func _physics_process(delta: float) -> void:
	# Update collision shapes based on gokart power-up state
	var gokart_active = _is_gokart_active()
	
	# Use glide gravity if double jump has been used and gokart is not active, otherwise use normal gravity
	var current_gravity = GLIDE_GRAVITY if (has_double_jumped and not gokart_active) else GRAVITY
	velocity.y += current_gravity * delta

	if gokart_active:
		# When gokart is active, use kart collision shape
		$KartCollisionShape.disabled = false
		$RunCollisionShape.disabled = true
		$SlideCollisionShape.disabled = true
	else:
		# When gokart is not active, use normal collision shapes
		$KartCollisionShape.disabled = true

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
			if Input.is_action_pressed("ui_accept"):
				velocity.y = JUMP_VELOCITY
				# Start tracking peak when jumping
				is_tracking_peak = true
				jump_peak_y = global_position.y
			elif Input.is_action_just_pressed("ui_down") and not is_sliding and not gokart_active:
				is_sliding = true
				sliding_timer = 0.0
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
		var distance_from_peak = abs(global_position.y - jump_peak_y)
		if Input.is_action_just_pressed("ui_accept") and not has_double_jumped and not gokart_active and distance_from_peak <= DOUBLE_JUMP_PEAK_TOLERANCE:
			velocity.y = DOUBLE_JUMP_VELOCITY
			has_double_jumped = true
			is_tracking_peak = false

		# Play gliding animation if double jumped, otherwise play jumping
		if has_double_jumped:
			$AnimatedSprite2D.play(_get_animation_name("gliding"))
		else:
			$AnimatedSprite2D.play(_get_animation_name("jumping"))

	move_and_slide()
