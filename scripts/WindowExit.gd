extends Node

const EXIT_CONFIRMATION := preload("res://scripts/ReturnToTitleDialog.gd")
const PANEL_FOCUS := preload("res://scripts/PanelFocus.gd")

var _dialog: ConfirmationDialog
var _close_pending := false
var _was_paused := false
var _pointer_was_suspended := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tree := get_tree()
	tree.auto_accept_quit = false
	tree.root.close_requested.connect(_on_close_requested)
	_dialog = EXIT_CONFIRMATION.new()
	_dialog.name = "WindowExitConfirmation"
	_dialog.exits_game = true
	_dialog.save_progress = Global.save_game
	_dialog.return_requested.connect(tree.quit)
	_dialog.visibility_changed.connect(_on_dialog_visibility_changed)
	add_child(_dialog)

func _on_close_requested() -> void:
	if _close_pending or _dialog.visible:
		return
	_close_pending = true
	_offer_exit.call_deferred()

func _offer_exit() -> void:
	var tree := get_tree()
	while tree.current_scene == null or MapTravel.active or _sleep_transition_active(tree.current_scene):
		await tree.process_frame
	_close_pending = false
	if tree.current_scene.scene_file_path not in Global.SAVE_SCENES.values():
		tree.quit()
		return
	if PANEL_FOCUS.has_popup(tree.root):
		return

	_was_paused = tree.paused
	_pointer_was_suspended = GamepadInput.pointer_suspended
	tree.paused = true
	GamepadInput.suspend_pointer(false)
	match Global.outcome:
		Global.Outcome.RUNNING:
			_dialog.ask("保存会更新本局手动档。直接退出会放弃尚未保存的进度。")
		Global.Outcome.TRADITIONAL, Global.Outcome.REFORMED:
			_dialog.ask("保存会将本次结局写入手动档。直接退出会放弃尚未保存的结局。", "留在结算")
		_:
			_dialog.ask("可以留在结算，读取先前保存的进度。", "留在结算", false)

func _sleep_transition_active(scene: Node) -> bool:
	if scene.scene_file_path != Global.ESTATE_SCENE:
		return false
	var tween: Tween = scene.get_node("UI").sleep_tween
	return tween != null and tween.is_running()

func _on_dialog_visibility_changed() -> void:
	if _dialog.visible:
		return
	get_tree().paused = _was_paused
	GamepadInput.suspend_pointer(_pointer_was_suspended)
