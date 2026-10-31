extends "res://scripts/commute_day.gd"
## DAY 3(수) — 옥상 주차장, 엘리베이터 앞 딱 한 칸.
## 앞차는 차량용 엘리베이터를 타고 천천히 올라간다. 내리면 바로 앞 칸이다.
## 나는 길에서 리프트(Space)로 9m 옥상까지 솟구쳐, 메인(Shift)을 짧게 뿜어 난간을 넘고 그 칸에 먼저 내려앉는다.

const ROOF_Y := 9.0
const BLD := Rect2(-18, 16, 14, 30) ## x, z, 폭, 길이 (x -18..-4, z 16..46)
const SPOT := Vector3(-7.8, ROOF_Y, 31.0)
const LIFT := Rect2(-3.8, 29.0, 3.0, 4.0) ## 엘리베이터 바닥(x -3.8..-0.8, z 29..33)
const STAIR_DOOR := Vector3(-12.0, ROOF_Y, 18.6)

var _platform: AnimatableBody3D


func _configure() -> void:
	use_models = true
	day_index = 2
	day_name = "수 · 옥상 주차장"
	intro_text = "수요일\n옥상 주차장 딱 한 칸!"
	start_clock = 8 * 3600 + 59 * 60 + 35.0
	start_xform = Transform3D(Basis.IDENTITY, Vector3(2.2, 0, 0))
	spot_center = SPOT
	spot_yaw_deg = 90.0
	cut_cam_pos = Vector3(4.0, 15.0, 42.0)
	cut_cam_target = Vector3(-5.6, 9.6, 30.5)
	win_lines = ["엘리베이터\n기다렸잖아요!!", "…저게 날아?"]
	lose_line = "줄 서세요~"
	rival_color = Color(0.25, 0.3, 0.7)
	rival_paint = Color(0.4, 0.55, 0.85)


func _setup_rival(r: RivalCar) -> void:
	var lx := LIFT.position.x + LIFT.size.x * 0.5
	var lz := LIFT.position.y + LIFT.size.y * 0.5
	r.setup_path([Vector3(lx, 0, 20), Vector3(lx, 0, lz), Vector3(lx, ROOF_Y, lz), Vector3(-4.6, ROOF_Y, lz), SPOT], false)
	# 길이: 11 + 9 + 2.3 + 3.2 = 25.5m. 엘리베이터 문 앞에서 잠깐 서고(0.40~0.43), 수직 구간(0.43~0.78)은 천천히.
	# 내가 리프트로 솟구칠 때 엘리베이터가 오르기 시작해, 내가 칸에 댈 무렵 옥상에 올라와 칸으로 온다(약 15초 도착).
	# 예전(2.6, 엘리베이터 0.45배)은 18초 넘어 도착해 쫓기는 맛이 없었다(10/24 사용자: 적이 너무 늦게 온다)
	r.speed = 2.8
	r.slow_zones = [[0.40, 0.431, 0.12], [0.431, 0.784, 0.6]]


func _walk_points(from: Vector3) -> Array[Vector3]:
	return [Vector3(-12.0, ROOF_Y, from.z), STAIR_DOOR]


func _day_process(_delta: float) -> void:
	# 엘리베이터 바닥은 앞차가 타고 있는 동안 같이 오르내린다
	var rp := rival.global_position
	if LIFT.has_point(Vector2(rp.x, rp.z)):
		_platform.global_position.y = rp.y - 0.1


func _build_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	_block(Vector3(-150, -1, -80), Vector3(150, 0, 200), _material("asphalt"))
	var white := _plain(Color(0.9, 0.9, 0.86), true)
	_block(Vector3(-0.6, 0, -20), Vector3(-0.5, 0.02, 90), white, false)
	_block(Vector3(5.5, 0, -20), Vector3(6.0, 0.7, 90), _material("concrete"))

	# 건물과 옥상 난간(엘리베이터 쪽은 터 있음)
	var x0 := BLD.position.x
	var x1 := BLD.position.x + BLD.size.x
	var z0 := BLD.position.y
	var z1 := BLD.position.y + BLD.size.y
	_building(Vector3(x0, 0, z0), Vector3(x1, ROOF_Y, z1), "concrete", false) # 10/24: 격자 상자 → 창 있는 건물(옥상은 주차장이라 기계실 없음)
	var rail := _material("concrete")
	_block(Vector3(x1 - 0.3, ROOF_Y, z0), Vector3(x1, ROOF_Y + 0.6, LIFT.position.y), rail)
	_block(Vector3(x1 - 0.3, ROOF_Y, LIFT.position.y + LIFT.size.y), Vector3(x1, ROOF_Y + 0.6, z1), rail)
	_block(Vector3(x0, ROOF_Y, z0), Vector3(x0 + 0.3, ROOF_Y + 0.6, z1), rail)
	_block(Vector3(x0, ROOF_Y, z0), Vector3(x1, ROOF_Y + 0.6, z0 + 0.3), rail)
	_block(Vector3(x0, ROOF_Y, z1 - 0.3), Vector3(x1, ROOF_Y + 0.6, z1), rail)
	_sign("옥상 주차", Vector3(x1 + 0.05, 6.4, 23.0), 90.0, 120)

	# 옥상 칸 두 줄: 엘리베이터 쪽 줄 가운데가 빈칸
	_parking_row(Vector3(SPOT.x, ROOF_Y, SPOT.z), 5, 5, true, rng)
	_parking_row(Vector3(-15.8, ROOF_Y, SPOT.z), 5, 5, false, rng)
	# 계단실
	_block(Vector3(-13.2, ROOF_Y, 16.3), Vector3(-10.8, ROOF_Y + 2.4, 18.3), _plain(Color(0.62, 0.62, 0.6)))
	_block(Vector3(-12.6, ROOF_Y, 18.28), Vector3(-11.4, ROOF_Y + 1.9, 18.36), _plain(Color(0.08, 0.1, 0.14)), false)

	# 차량용 엘리베이터: 네 기둥(위는 열려 있음)과 오르내리는 바닥
	var lx0 := LIFT.position.x
	var lx1 := LIFT.position.x + LIFT.size.x
	var lz0 := LIFT.position.y
	var lz1 := LIFT.position.y + LIFT.size.y
	for x: float in [lx0, lx1]:
		for z: float in [lz0, lz1]:
			_block(Vector3(x - 0.15, 0, z - 0.15), Vector3(x + 0.15, ROOF_Y + 0.6, z + 0.15), _plain(Color(0.95, 0.75, 0.1)))
	_sign("차량 엘리베이터", Vector3(lx1 + 0.2, 3.2, (lz0 + lz1) * 0.5), 90.0, 70)
	_platform = AnimatableBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LIFT.size.x - 0.2, 0.2, LIFT.size.y - 0.2)
	shape.shape = box
	_platform.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mi.mesh = bm
	mi.material_override = _plain(Color(0.35, 0.36, 0.4))
	_platform.add_child(mi)
	add_child(_platform)
	_platform.global_position = Vector3((lx0 + lx1) * 0.5, -0.1, (lz0 + lz1) * 0.5)

	_build_props()

	# 배경
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 41
	_skyline(rng2, 12.0, -30.0, 130.0)
	_skyline(rng2, -45.0, -30.0, 130.0)


## Tripo 소품(모델 버전에서만 보인다, 10/24). 중앙 분리대 가로등, 건물 앞 나무·쓰레기통. 내 차·앞차 길(x -4..2.5, z 15..34)은 비운다
func _build_props() -> void:
	if not use_models:
		return
	# 가로등: 분리대(x 5.75, 높이 0.7) 위, 팔은 -X로 차선 위. 돌렸으니 기둥은 모델 원점의 +X 1.66m
	for z: float in [6.0, 46.0]:
		_prop("streetlight", Vector3(5.75 - 1.66, 0.7, z), 180.0, Vector3(-1.66, 2.25, 0), Vector3(0.3, 4.5, 0.3)) # 돌렸으니 기둥 충돌은 모델 -X 쪽
	for z: float in [38.5, 44.0]:
		_prop("tree", Vector3(-3.2, 0, z), 0.0, Vector3(-0.09, 0.3, 0.05), Vector3(0.95, 0.6, 0.95))
	_prop("trash_bin", Vector3(-3.4, 0, 41.2), 90.0, Vector3(0, 0.4, 0), Vector3(0.55, 0.8, 0.55))
	for z: float in [27.4, 34.6]:
		_prop("cone", Vector3(-0.3, 0, z), 0.0)

