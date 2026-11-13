extends RefCounted

enum Section { ESTATE, BRIDGE, MARKET }

const WEST_ROAD := preload("res://scripts/WestRoadLayout.gd")
const WEST_MARKET := preload("res://scripts/WestMarketLayout.gd")

static var estate_departure := _estate_departure()
static var bridge := _bridge_lane()
static var market := _curve(Array(WEST_MARKET.silk_guest_path()))
static var roads: Array[Curve2D] = [estate_departure, bridge, market]

static func _estate_departure() -> Curve2D:
	var court := EstateLayout.WEST_COURT_PATH.slice(0, EstateLayout.WEST_COURT_PATH.find(EstateLayout.WEST_COURT) + 1)
	court.reverse()
	var lane := EstateLayout.WEST_LANE.slice(0, EstateLayout.WEST_LANE.find(EstateLayout.WEST_COURT_TURN))
	lane.reverse()
	return _curve([EstateLayout.SILK_SAMPLE_STOP] + court + lane + [EstateLayout.WEST_GATE])

static func _bridge_lane() -> Curve2D:
	var path: Array = WEST_ROAD.ROAD.slice(1, -1)
	for index in range(1, path.size() - 1):
		path[index] += Vector2(0, -9)
	return _curve(path)

static func _curve(points: Array) -> Curve2D:
	var path := Curve2D.new()
	for foot: Vector2 in points:
		path.add_point(foot)
	return path

static func road_offset(section: Section, trip: VisitorData.SilkTrip) -> float:
	var bridge_length := bridge.get_baked_length()
	match trip:
		VisitorData.SilkTrip.WEST_ROAD:
			var first_leg := estate_departure.get_baked_length()
			var elapsed := inverse_lerp(VisitorData.SILK_MARKET_DEPART, VisitorData.SILK_MARKET_ARRIVE, Global.day_progress)
			var distance := elapsed * (first_leg + bridge_length)
			if section == Section.ESTATE and distance < first_leg:
				return distance
			if section == Section.BRIDGE and distance >= first_leg:
				return first_leg + bridge_length - distance
		VisitorData.SilkTrip.RETURN_ROAD:
			var first_leg := market.get_baked_length()
			var elapsed := inverse_lerp(VisitorData.SILK_MARKET_LEAVE, VisitorData.SILK_MARKET_RETURN, Global.day_progress)
			var distance := elapsed * (first_leg + bridge_length)
			if section == Section.MARKET and distance < first_leg:
				return first_leg - distance
			if section == Section.BRIDGE and distance >= first_leg:
				return distance - first_leg
	return -1.0

static func position_on(section: Section, offset: float) -> Vector2:
	return roads[section].sample_baked(offset)

static func walk(visitor: Visitor, activity: VisitorData.VisitActivity, section: Section, offset: float) -> void:
	var path := roads[section]
	var heading := path.sample_baked(offset + 3.0) - path.sample_baked(offset - 3.0)
	if section == Section.MARKET or (section == Section.BRIDGE and visitor.data.silk_trip() == VisitorData.SilkTrip.WEST_ROAD):
		heading = -heading
	visitor.follow_travel_clock(activity, path.sample_baked(offset), heading)
