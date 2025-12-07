extends CanvasLayer

var event_label: Label
var label_settings: LabelSettings
var timer: float = 0.0
var showing_event: bool = false
var showing_outcome: bool = false
const EVENT_DISPLAY_DURATION: float = 2.0

func _ready():
	event_label = $EventLabel
	event_label.visible = false
	
	# Create LabelSettings for text outline
	# Get the font and font size from the theme overrides
	var font = event_label.get_theme_font("font")
	var font_size = event_label.get_theme_font_size("font_size")
	
	label_settings = LabelSettings.new()
	label_settings.font = font
	label_settings.font_size = font_size
	label_settings.outline_size = 8
	label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
	event_label.label_settings = label_settings

func _process(delta: float):
	if showing_event:
		timer -= delta
		if timer <= 0.0:
			hide_event()
			showing_event = false
	
	if showing_outcome:
		timer -= delta
		if timer <= 0.0:
			hide_outcome()
			showing_outcome = false

func show_special_event():
	# Show "Special Event!" for 2 seconds
	event_label.text = "SPECIAL EVENT"
	event_label.modulate = Color.WHITE
	label_settings.outline_size = 8
	label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
	event_label.visible = true
	showing_event = true
	timer = EVENT_DISPLAY_DURATION

func hide_event():
	event_label.visible = false
	showing_event = false

func show_outcome(outcome_type: String):
	# Stop showing event message if it's still active
	if showing_event:
		showing_event = false
	
	# Show outcome message
	match outcome_type:
		"miss":
			event_label.text = "Miss"
			event_label.modulate = Color(0.3, 0.3, 0.3)  # Dark grey
			label_settings.outline_size = 8
			label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
		"nice":
			event_label.text = "Nice!"
			event_label.modulate = Color.GREEN
			label_settings.outline_size = 8
			label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
		"oops":
			event_label.text = "Oops!"
			event_label.modulate = Color.RED
			label_settings.outline_size = 8
			label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
		"too_early":
			event_label.text = "Too Early!"
			event_label.modulate = Color.ORANGE
			label_settings.outline_size = 8
			label_settings.outline_color = Color(0, 0, 0, 1)  # Black outline
	
	event_label.visible = true
	showing_outcome = true
	timer = EVENT_DISPLAY_DURATION  # Show for 2 seconds

func hide_outcome():
	event_label.visible = false
	showing_outcome = false
