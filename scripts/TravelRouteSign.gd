extends PanelContainer
class_name TravelRouteSign

@onready var direction_label: Label = %Direction
@onready var destination_label: Label = %Destination
@onready var step_label: Label = %NextStep
@onready var cancel_button: Button = %CancelDirections

var traveler: Player
var campaign_hud: CanvasLayer

func _ready() -> void:
	set_process(false)
	for control: Control in [destination_label, step_label, cancel_button]:
		InterfaceFont.scale_reading_text(control)

func setup(walker: Player, hud: CanvasLayer, cancel: Callable, map_button: Button) -> void:
	traveler = walker
	campaign_hud = hud
	cancel_button.pressed.connect(func():
		var restore_focus := cancel_button.has_focus()
		cancel.call()
		if restore_focus and map_button.is_visible_in_tree():
			map_button.grab_focus()
			GamepadInput.snap_pointer_to_focus.call_deferred()
	)

func set_route(destination: String, next_step: String = "", direction: String = "◆") -> void:
	if destination_label.text != destination:
		destination_label.text = destination
		cancel_button.accessibility_description = "停止前往" + destination
	direction_label.text = direction
	step_label.text = next_step
	step_label.visible = not next_step.is_empty()
	set_process(not destination.is_empty())
	_refresh_visibility()

func _process(_delta: float) -> void:
	_refresh_visibility()

func _refresh_visibility() -> void:
	visible = (not destination_label.text.is_empty() and Global.outcome == Global.Outcome.RUNNING
		and not traveler.world_controls_blocked() and not campaign_hud.modal_open and not campaign_hud.settings_open)
