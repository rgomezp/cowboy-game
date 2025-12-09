extends CanvasLayer

signal powerup_button_pressed(powerup_name: String)

# Powerup buttons
var buttons: Dictionary = {}  # Maps powerup_name -> TextureButton

func _ready():
	# Initialize buttons dictionary
	buttons["gokart"] = $GokartButton
	buttons["shotgun"] = $ShotgunButton

	# Hide all buttons initially
	hide_all_buttons()

func _on_gokart_button_pressed():
	powerup_button_pressed.emit("gokart")

func _on_shotgun_button_pressed():
	powerup_button_pressed.emit("shotgun")

func show_button(powerup_name: String):
	# Hide all buttons first
	hide_all_buttons()

	# Show the requested button
	if buttons.has(powerup_name):
		buttons[powerup_name].visible = true
		buttons[powerup_name].disabled = false

func hide_all_buttons():
	for button in buttons.values():
		button.visible = false
		button.disabled = true

func set_button_visible(powerup_name: String, should_show: bool):
	if buttons.has(powerup_name):
		buttons[powerup_name].visible = should_show
