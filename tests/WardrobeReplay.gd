extends "res://tests/HallInteriorReplay.gd"

func _open_rack() -> Control:
	await _walk_in_room(Vector2(0, 33))
	await _walk_in_room(Vector2(-52, 33))
	await tree.physics_frame
	await tree.process_frame
	var rack := room.get_node("ClothesRack")
	if not _expect(player.interaction_target == rack and rack.get_node("Hint").visible,
		"Walk up to the clothes rack from the middle of the hall. At %s, focus %s." % [
			room.to_local(player.global_position), player.interaction_target]):
		return null
	await _key(KEY_E)
	var panel := ui.get_node("Control/WardrobePanel") as Control
	if not _expect(panel.modal.visible and tree.paused, "E at the rack opens the paused wardrobe."):
		return null
	return panel

func _check_outfit(id: String) -> bool:
	var data: Dictionary = PlayerAttire.CATALOG[id]
	var atlas := player.sprite.texture as AtlasTexture
	var sheet_matches := player.sprite.texture.resource_path == PlayerAttire.ORIGINAL_PATH if id == PlayerAttire.DEFAULT else (
		atlas != null and atlas.region == Rect2(0, data.sheet * 96, 96, 96))
	return _expect(state.attire_id == id and sheet_matches and player.tool_gesture.sleeve == data.sleeve,
		"The actor and its tool sleeve wear " + id)

func _wear(panel: Control, id: String) -> bool:
	await _press(panel.rows[id])
	if not _expect(not panel.apply_button.disabled, "The unlocked garment can be worn."):
		return false
	await _press(panel.apply_button)
	return _expect(not panel.modal.visible and not tree.paused, "Applying the outfit returns to the room.") and _check_outfit(id)

func _promote_at_dawn() -> bool:
	# Supply the first promotion's reputation so this scenario can focus on the outfit.
	state.reputation = state.promotion_reputation()
	var plan := await _bed_plan()
	if plan == null:
		return false
	await _press(plan.get_node("%Sleep"))
	await tree.create_timer(1.20).timeout
	return _expect(state.current_day == 2 and state.current_rank == state.Rank.ZHONG_SHI
		and state.can_wear_attire("hemp") and not state.can_wear_attire("silk"),
		"A real dawn promotion unlocks hemp and keeps the higher silk locked.")

func _resume_outfit() -> bool:
	await _press(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _press(button)
			break
	if not _expect(settings.save_status.text == "游戏已保存", "Save the outfit from the settings menu."):
		return false
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _press(tree.current_scene.continue_button)
	return await _estate() and _expect(state.estate_room == state.EstateRoom.HALL, "Continue inside the same hall.") and _check_outfit("hemp")

func _west_road() -> bool:
	for point in [Vector2(-181, 54), Vector2(-181, 0), Vector2(-270, -21)]:
		await Campaign.walk_to(tree, player, point)
	if not _expect(await Campaign.walk_through_gates(tree, &"ui_left", state.WEST_MARKET_SCENE), "Walk across the real west road gate."):
		return false
	player = tree.current_scene.get_node("Player")
	return _check_outfit("hemp")

func _play() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _press(tree.current_scene.new_button)
	if not await _estate() or not _check_outfit(PlayerAttire.DEFAULT) or not await _enter():
		return
	var panel := await _open_rack()
	if panel == null:
		return
	await _press(panel.rows["brocade"])
	var west_view: TextureRect = panel.views.get_node("Side/Sprite")
	_expect(panel.apply_button.disabled and panel.apply_button.text.contains("大夫") and west_view.texture.region.position.y == 448,
		"The locked court outfit can be inspected from the side without equipping it.")
	await _snapshot("01-brocade-preview")
	await _key(KEY_ESCAPE)
	if not _expect(not tree.paused and state.attire_id == PlayerAttire.DEFAULT, "Esc leaves the preview without committing it."):
		return
	panel = await _open_rack()
	if panel == null or not await _wear(panel, "rust"):
		return
	await _snapshot("02-rust-in-hall")
	if not await _promote_at_dawn():
		return
	panel = await _open_rack()
	if panel == null:
		return
	await _press(panel.rows["hemp"])
	await _snapshot("03-hemp-after-promotion")
	if not await _wear(panel, "hemp") or not await _resume_outfit() or not await _leave():
		return
	await _snapshot("04-hemp-at-door")
	if not await _west_road():
		return
	await _snapshot("05-hemp-at-market")
	# Use the real nightly rank check after staging the existing threshold for overdue tribute.
	state.days_without_contribution = state.balance.no_contribution_threshold - 1
	state.reputation = state.balance.rank_strip_threshold
	state.restore_stamina()
	_expect(state.current_rank == state.Rank.XIA_SHI, "The usual lack of tribute can lower the rank.")
	_check_outfit(PlayerAttire.DEFAULT)
	print("WARDROBE_ROUND_TRIP day=", state.current_day, " west_market=true demoted_attire=", state.attire_id)
