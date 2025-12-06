extends Node

signal foe_added(foe: Node)
signal foe_removed(foe: Node)

var foes: Array = []
var screen_size: Vector2i

func initialize(screen_size: Vector2i):
	self.screen_size = screen_size

func reset():
	clear_all_foes()

func clear_all_foes():
	for foe in foes:
		if is_instance_valid(foe):
			foe.queue_free()
	foes.clear()

func add_foe(foe: Node):
	add_child(foe)
	foes.append(foe)
	foe_added.emit(foe)

func remove_foe(foe: Node):
	if foes.has(foe):
		foes.erase(foe)
		if is_instance_valid(foe):
			foe.queue_free()
		foe_removed.emit(foe)

func cleanup_off_screen_foes(camera_x: float):
	var cleanup_threshold = camera_x - screen_size.x * 2
	for foe in foes.duplicate():
		if not is_instance_valid(foe):
			foes.erase(foe)
			continue
		if foe.position.x < cleanup_threshold:
			remove_foe(foe)
