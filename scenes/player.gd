extends CharacterBody2D


const GRAVITY : int = 4200
const GLIDE_GRAVITY : int = 1200
const JUMP_VELOCITY = -1800
const DOUBLE_JUMP_VELOCITY = -1000

var is_sliding: bool = false
var sliding_timer: float = 0.0
var has_double_jumped: bool = false


func _physics_process(delta: float) -> void:
	# Use glide gravity if double jump has been used, otherwise use normal gravity
	var current_gravity = GLIDE_GRAVITY if has_double_jumped else GRAVITY
	velocity.y += current_gravity * delta

	# Update sliding timer
	if is_sliding:
		sliding_timer += delta
		# Calculate animation duration: 4 frames / 3.0 speed = ~1.33 seconds
		var animation_duration = 4.0 / 3.0
		if sliding_timer >= animation_duration:
			is_sliding = false
			sliding_timer = 0.0
			$RunCollisionShape.disabled = false

	if is_on_floor():
		# Reset double jump when touching the ground
		has_double_jumped = false
		if not get_parent().game_running:
			$AnimatedSprite2D.play("idle")
		else:
			if Input.is_action_pressed("ui_accept"):
				velocity.y = JUMP_VELOCITY
			elif Input.is_action_just_pressed("ui_down") and not is_sliding:
				is_sliding = true
				sliding_timer = 0.0
				$AnimatedSprite2D.play("sliding")
				$RunCollisionShape.disabled = true
			elif is_sliding:
				# Keep sliding animation playing and collision disabled
				$AnimatedSprite2D.play("sliding")
			else:
				$AnimatedSprite2D.play("running")
				$RunCollisionShape.disabled = false
	else:
		# Allow double jump while in the air
		if Input.is_action_just_pressed("ui_accept") and not has_double_jumped:
			velocity.y = DOUBLE_JUMP_VELOCITY
			has_double_jumped = true
		$AnimatedSprite2D.play("jumping")

	move_and_slide()
