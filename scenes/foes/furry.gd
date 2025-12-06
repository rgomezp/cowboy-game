extends Area2D

var is_destroyed: bool = false

func _ready() -> void:
	# Connect to animation finished signal to remove after destroy animation
	var animated_sprite = $AnimatedSprite2D
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

func destroy():
	if is_destroyed:
		return
	
	is_destroyed = true
	var animated_sprite = $AnimatedSprite2D
	if animated_sprite:
		animated_sprite.play("destroy")
		# Disable collisions
		if has_node("CollisionBox"):
			$CollisionBox.disabled = true
		if has_node("CollisionBoxTop"):
			var top_collision = get_node("CollisionBoxTop")
			if top_collision is Area2D:
				top_collision.monitoring = false
				top_collision.monitorable = false
			elif top_collision is CollisionShape2D:
				top_collision.disabled = true
		# Disable main Area2D monitoring
		monitoring = false
		monitorable = false

func _on_animation_finished():
	# When destroy animation finishes, remove the foe
	if is_destroyed:
		# Signal to parent to remove this foe
		queue_free()
