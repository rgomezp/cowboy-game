extends AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var main_scene = get_tree().current_scene
	if main_scene and "speed" in main_scene:
		position.x -= main_scene.speed / 10
