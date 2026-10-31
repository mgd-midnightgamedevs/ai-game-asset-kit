extends "res://scripts/commute_day.gd"
## DAY 8(다음 주 월) — 경찰차 따돌리기.
## 지난주 내내 날아다녔더니 경찰차가 사이렌을 켜고 뒤에서 따라온다. 길에서는 경찰차가 더 빠르다.
## 회사 정면 밑동 곡면으로 들어가 흡착 팬(E)으로 벽을 타고, 둥근 옥상 모서리를 넘어 옥상 주차장 칸에 대면 성공.
## 경찰차는 벽을 못 탄다. 같은 높이에서 따라붙히면(2.6m) 잡힌다.
## 좌표: 진행 방향 +Z. 회사 건물 정면은 z = FRONT_Z.

const FRONT_Z := 70.0
const ROOF_Y := 14.0
const EDGE_R := 6.0 ## 둥근 옥상 모서리(최고 속도에서도 팬이 붙잡는 반지름)
const PIPE_R := 4.5 ## 정면 밑동 곡면
const RAMP_X := 6.0 ## 곡면·둥근 모서리가 있는 정면 가운데 반폭
const SPOT := Vector3(0.0, ROOF_Y, 84.0)
const STAIR_DOOR := Vector3(-9.0, ROOF_Y, 90.0)
const POLICE_START_Z := -12.0
const POLICE_ACCEL := 4.0 ## m/s², 경찰차가 출발해 속도를 올리는 정도
const POLICE_MAX := 12.2 ## 내 차 최고 속도(약 10.3)보다 빠르다


func _configure() -> void:
	use_models = true
	day_index = 7
	day_name = "월 · 경찰차 따돌리기"
	intro_text = "다음 주 월요일\n경찰차가 따라온다!"
	play_hint = "경찰보다 먼저 회사 옥상으로"
	rival_role = "police"
	start_clock = 8 * 3600 + 59 * 60 + 36.0
	clear_line = "%s 출근 · 경찰 따돌림"
	start_xform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	spot_center = SPOT
	spot_yaw_deg = 0.0
	cut_cam_pos = Vector3(9.0, ROOF_Y + 6.0, FRONT_Z - 10.0)
	cut_cam_target = Vector3(0.0, 2.0, FRONT_Z - 6.0)
	win_lines = ["거기 서!!", "…차가 벽을 타네"]
	lose_line = "면허증\n주세요~"
	rival_color = Color(0.12, 0.17, 0.35) # 경찰 제복
	rival_paint = Color(0.95, 0.95, 0.96)


func _setup_rival(r: RivalCar) -> void:
	r.setup_path([Vector3(0, 0, POLICE_START_Z), Vector3(0, 0, FRONT_Z - PIPE_R - 1.8)], false)
	r.speed = 0.0


func _day_process(delta: float) -> void:
	if phase == Phase.PLAY and rival.started:
		rival.speed = minf(rival.speed + POLICE_ACCEL * delta, POLICE_MAX)
	# 추적 카메라는 앞을 보므로 경찰차가 얼마나 붙었는지 HUD 오른쪽 위에 보여 준다
	if phase == Phase.PLAY:
		var gap := maxf(car.get_vehicle_position().distance_to(rival.global_position) - RivalCar.LENGTH * 0.5, 0.0)
		day_name = "경찰차 %dm 뒤" % roundi(gap)


func _walk_points(from: Vector3) -> Array[Vector3]:
	return [Vector3(STAIR_DOOR.x + 1.5, ROOF_Y, from.z), STAIR_DOOR]


func _build_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	_block(Vector3(-150, -1, -80), Vector3(150, 0, 200), _material("asphalt"))
	var white := _plain(Color(0.9, 0.9, 0.86), true)
	var yellow := _plain(Color(1.0, 0.82, 0.2), true)
	# 길: 중앙선, 양쪽 인도와 길가에 세운 차들
	_block(Vector3(-0.05, 0, -30), Vector3(0.05, 0.02, FRONT_Z - PIPE_R - 3.0), yellow, false)
	for side: float in [-1.0, 1.0]:
		_block(Vector3(side * 7.0 - 0.05, 0, -30), Vector3(side * 7.0 + 0.05, 0.02, FRONT_Z - 2.0), white, false)
		var a := Vector3(side * 8.0 if side > 0 else -14.0, 0, -30)
		var b := Vector3(14.0 if side > 0 else side * 8.0, 0.15, FRONT_Z)
		_block(a, b, _material("sidewalk"))
		var z := -20.0
		while z < FRONT_Z - 12.0:
			if rng.randf() < 0.7:
				var col: Color = PARKED_COLORS[rng.randi() % PARKED_COLORS.size()]
				_parked_car(Vector3(side * 6.2, 0, z), 0.0, col, rng.randf_range(0.85, 1.15), int(z) + (302 if side > 0 else 200))
			z += 5.0

	# 회사 건물: 정면 가운데는 밑동 곡면 → 벽 → 둥근 옥상 모서리, 양옆은 그냥 벽
	_block(Vector3(-14, 0, FRONT_Z + EDGE_R), Vector3(14, ROOF_Y, 94), _material("office"))
	_block(Vector3(-14, 0, FRONT_Z), Vector3(-RAMP_X, ROOF_Y, FRONT_Z + EDGE_R), _material("office"))
	_block(Vector3(RAMP_X, 0, FRONT_Z), Vector3(14, ROOF_Y, FRONT_Z + EDGE_R), _material("office"))
	_block(Vector3(-RAMP_X, 0, FRONT_Z), Vector3(RAMP_X, ROOF_Y - EDGE_R, FRONT_Z + EDGE_R), _material("office"))
	_block(Vector3(-RAMP_X, ROOF_Y - EDGE_R, FRONT_Z + 2.0), Vector3(RAMP_X, ROOF_Y - 2.0, FRONT_Z + EDGE_R), _material("office")) # 둥근 모서리 속 채움
	_arc(Vector2(FRONT_Z - PIPE_R, PIPE_R), PIPE_R, 0.0, 90.0, 30, RAMP_X * 2.0, 0.0, _material("curl"))
	_arc_convex(Vector2(FRONT_Z + EDGE_R, ROOF_Y - EDGE_R), EDGE_R, 0.0, 90.0, 36, RAMP_X * 2.0, 0.0, _material("curl"))
	_sign("본사", Vector3(-10.0, ROOF_Y - 3.5, FRONT_Z - 0.05), 180.0, 150)
	_sign("옥상 주차장", Vector3(10.0, ROOF_Y - 3.5, FRONT_Z - 0.05), 180.0, 90)

	# 옥상 주차장
	var rail := _material("concrete")
	_block(Vector3(-14, ROOF_Y, 93.7), Vector3(14, ROOF_Y + 0.6, 94), rail)
	_block(Vector3(-14, ROOF_Y, FRONT_Z), Vector3(-13.7, ROOF_Y + 0.6, 94), rail)
	_block(Vector3(13.7, ROOF_Y, FRONT_Z), Vector3(14, ROOF_Y + 0.6, 94), rail)
	_parking_row_x(SPOT, 4, 4, true, rng)
	_block(Vector3(-10.4, ROOF_Y, 90.6), Vector3(-7.6, ROOF_Y + 2.4, 93.6), _material("building"))
	_block(Vector3(-9.6, ROOF_Y, 90.52), Vector3(-8.4, ROOF_Y + 1.9, 90.6), _plain(Color(0.08, 0.1, 0.14)), false)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 67
	_skyline(rng2, 15.0, -40.0, 66.0)
	_skyline(rng2, -31.0, -40.0, 66.0)
