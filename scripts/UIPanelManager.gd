extends Node
class_name UIPanelManager

## UI面板管理器 - 负责管理所有UI面板的显示和隐藏
## 从UIManager中分离出来的面板管理逻辑

# 场景引用
var management_panel_scene = preload("res://scenes/ManagementPanel.tscn")
var settings_panel_script = load("res://scripts/SettingsPanel.gd")
var debug_panel_scene = preload("res://scenes/DebugPanel.tscn")

# 当前实例
var management_panel_instance: Control
var settings_panel_instance: Panel
var debug_panel_instance: Control

# 父节点
var parent_node: Node

func setup(p_parent: Node) -> void:
	parent_node = p_parent
	# Pre-create settings panel (it's a script, not a scene)
	_precreate_settings_panel()

func _precreate_settings_panel() -> void:
	if settings_panel_instance == null:
		settings_panel_instance = settings_panel_script.new()
		settings_panel_instance.visible = false
		parent_node.add_child(settings_panel_instance)

## 显示管理面板
func show_management_panel() -> void:
	if management_panel_instance == null:
		management_panel_instance = management_panel_scene.instantiate()
		parent_node.add_child(management_panel_instance)
		management_panel_instance.get_node("CloseButton").pressed.connect(hide_management_panel)
	else:
		management_panel_instance.refresh_retainers()
		management_panel_instance.refresh_well_fields()
	management_panel_instance.show()

## 隐藏管理面板
func hide_management_panel() -> void:
	if management_panel_instance != null:
		management_panel_instance.hide()

## 切换管理面板
func toggle_management_panel() -> void:
	if management_panel_instance == null or not management_panel_instance.visible:
		show_management_panel()
	else:
		hide_management_panel()

## 显示设置面板
func show_settings_panel() -> void:
	if settings_panel_instance != null:
		settings_panel_instance.visible = true
		settings_panel_instance.move_to_front()

## 隐藏设置面板
func hide_settings_panel() -> void:
	if settings_panel_instance != null:
		settings_panel_instance.visible = false

## 切换设置面板
func toggle_settings_panel() -> void:
	if settings_panel_instance != null:
		settings_panel_instance.visible = not settings_panel_instance.visible
		if settings_panel_instance.visible:
			settings_panel_instance.move_to_front()

## 显示调试面板
func show_debug_panel() -> void:
	if OS.is_debug_build():
		if debug_panel_instance == null:
			debug_panel_instance = debug_panel_scene.instantiate()
			parent_node.add_child(debug_panel_instance)
		debug_panel_instance.show()

## 隐藏调试面板
func hide_debug_panel() -> void:
	if debug_panel_instance != null:
		debug_panel_instance.hide()

## 切换调试面板
func toggle_debug_panel() -> void:
	if OS.is_debug_build():
		if debug_panel_instance == null or not debug_panel_instance.visible:
			show_debug_panel()
		else:
			hide_debug_panel()

## 清理所有面板
func cleanup() -> void:
	if management_panel_instance != null:
		management_panel_instance.queue_free()
		management_panel_instance = null

	if settings_panel_instance != null:
		settings_panel_instance.queue_free()
		settings_panel_instance = null

	if debug_panel_instance != null:
		debug_panel_instance.queue_free()
		debug_panel_instance = null
