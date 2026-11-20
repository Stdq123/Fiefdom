extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	state.sheepfold.bought_day = 1
	state.sheepfold.fodder = 2
	state.sheepfold.wool_nights = 3
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var pen := current_scene.get_node("World/SheepfoldPen") as Node2D
	var animal: SheepMotion = pen.animal
	var day: int = state.current_day
	var clock: float = state.day_progress
	var before := _stock(state)
	state.day_progress = 0.081
	pen._update_sheep(0.0)
	var first := animal.position
	state.day_progress = 0.095
	pen._update_sheep(0.17)
	_expect(animal.full_fleece and animal.walking and animal.flip_h and animal.position.y > first.y,
		"The first pasture segment walks toward its actual slope.")
	_check_planting(animal)
	state.current_day = state.SOLAR_TERMS.find(state.balance.rain_solar_term) * state.balance.days_per_solar_term + 1
	state.day_progress = 0.29
	pen._refresh()
	var low := animal.nose_position()
	var feet := _feet(animal)
	_expect(animal.position == pen.FEEDING_SPOT and not animal.walking and not animal.flip_h and animal.head_drop > 0.5,
		"The rainy sample lowers the head beside the real trough.")
	pen._update_sheep(0.43)
	_expect(low.distance_to(animal.nose_position()) > 0.15 and feet == _feet(animal) and animal.rotation == 0.0,
		"Nibbles move the head and preserve the stance.")
	state.sheepfold.wool_nights = 0
	pen._refresh()
	_expect(not animal.full_fleece and animal.position == pen.FEEDING_SPOT, "The short coat has the same ground anchor.")
	pen._on_sheared()
	var clipping: Vector2 = pen.clipping.position
	_expect(pen.clipping.visible and clipping.is_equal_approx(animal.position + animal.fleece_contact()),
		"The wool leaves from the shoulder of the present pose.")
	state.sheepfold.wool_nights = 3
	state.current_day = day
	state.day_progress = 0.83
	pen._refresh()
	_expect(animal.position == pen.SHELTER and not animal.walking and animal.head_drop == 0.0,
		"The evening pose settles in the original shelter.")
	state.day_progress = clock
	_expect(before == _stock(state) and state.saved_games().is_empty(),
		"The pose fixture leaves the campaign and the save catalog fixed.")
	current_scene.queue_free()
	await process_frame
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_planting(animal: SheepMotion) -> void:
	animal.present(Vector2.ZERO, Vector2.RIGHT, 0.0, 0.0)
	animal.present(Vector2(0.8, 0), Vector2.RIGHT, 0.0, 0.10)
	var planted := animal.position + animal.hoof_position(0)
	animal.present(Vector2(2.0, 0), Vector2.RIGHT, 0.0, 0.59)
	_expect(planted.distance_to(animal.position + animal.hoof_position(0)) <= 0.5,
		"A planted hoof stays at the same place as the body advances.")
	animal.present(Vector2(6.4, 0), Vector2.RIGHT, 0.0, 0.10)
	_expect(animal.hoof_position(0).y < -1.0 and animal.hoof_position(1).y == 0.0,
		"The rear hoof lifts while the other near hoof supports the sheep.")
	animal.present(animal.position, Vector2.RIGHT, 0.0, 0.14)
	_expect(not animal.walking and animal.hoof_position(0).y == 0.0, "Waiting restores a planted hoof.")

func _feet(animal: SheepMotion) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for index in 4:
		points.append(animal.hoof_position(index))
	return points

func _stock(state: Node) -> Array:
	var flock = state.sheepfold
	return [state.current_day, state.day_progress, state.current_stamina, state.money,
		state.food_storage, flock.bought_day, flock.fodder, flock.wool_nights, flock.wool]

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
