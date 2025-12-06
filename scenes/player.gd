extends CharacterBody2D


const GRAVITY : int = 4200
const JUMP_VELOCITY = -1800

var is_sliding: bool = false
var sliding_timer: float = 0.0


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta

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
		$AnimatedSprite2D.play("jumping")

	move_and_slide()
