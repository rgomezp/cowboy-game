extends CharacterBody2D


const GRAVITY : int = 4200
const JUMP_VELOCITY = -1800


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	if is_on_floor():
		if not get_parent().game_running:
			$AnimatedSprite2D.play("idle")
		else:
			$RunCollisionShape.disabled = false
			if Input.is_action_pressed("ui_accept"):
				velocity.y = JUMP_VELOCITY
			elif Input.is_action_pressed("ui_down"):
				$AnimatedSprite2D.play("sliding")
				$RunCollisionShape.disabled = true
			else:
				$AnimatedSprite2D.play("running")
	else:
		$AnimatedSprite2D.play("jumping")

	move_and_slide()
