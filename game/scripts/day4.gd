extends "res://scripts/commute_day.gd"
## DAY 4(목) — 길 건너 옥상 주차장, 딱 한 칸.
## 앞차는 건물을 돌아 경사로로 옥상에 올라간다. 나는 길 오른쪽 높은 건물 밑동의 곡면으로 비스듬히 들어가
## 흡착 팬(E)으로 벽을 타고 오르다가, 리프트(Space)로 벽을 차고 길 건너 옥상으로 날아가 그 칸에 먼저 댄다.
## 리프트는 차 바닥 쪽으로 뿜으므로, 벽에 붙어 있을 때 누르면 벽 반대쪽(길 건너)으로 밀려 나간다.
## 좌표: 진행 방향 +Z. 오른쪽(-X)에 벽 타는 건물 A, 왼쪽(+X)에 옥상 주차장 건물 B.

const WALL_X := -5.0 ## 건물 A의 길 쪽 벽
const WALL_TOP := 22.0
const PIPE_R := 3.0 ## 벽 밑동 곡면 반지름
const PIPE_Z := Vector2(6.0, 52.0) ## 곡면이 깔린 구간
const ROOF_Y := 8.0
const BLD := Rect2(5, 24, 16, 38) ## 건물 B: x 5..21, z 24..62
const SPOT := Vector3(14.0, ROOF_Y, 44.0)
const STAIR_DOOR := Vector3(6.4, ROOF_Y, 57.0)


func _configure() -> void:
	use_models = true
	day_index = 3
	day_name = "목 · 길 건너 옥상"
	intro_text = "목요일\n길 건너 옥상 한 칸!"
	start_clock = 8 * 3600 + 59 * 60 + 36.0
	start_xform = Transform3D(Basis.IDENTITY, Vector3(1.0, 0, 0))
	spot_center = SPOT
	spot_yaw_deg = 90.0
	cut_cam_pos = Vector3(2.0, 15.0, 36.0)
	cut_cam_target = Vector3(12.5, 8.6, 44.5)
	win_lines = ["벽을 타고\n왔다고요?!", "…이건 반칙이지"]
	lose_line = "경사로가\n정석이죠~"
	rival_color = Color(0.2, 0.5, 0.32)
	rival_paint = Color(0.92, 0.48, 0.2)


func _setup_rival(r: RivalCar) -> void:
	# 길 → 건물 B 남쪽 경사로 → 옥상 남쪽 통로 → 서쪽 통로로 북쪽 → 동쪽으로 칸에 들어간다
	r.setup_path([Vector3(2.8, 0, 8), Vector3(2.8, 0, 17), Vector3(6.0, 0, 21.2), Vector3(18.5, ROOF_Y, 21.2),
		Vector3(18.4, ROOF_Y, 24.6), Vector3(16.0, ROOF_Y, 26.0), Vector3(9.0, ROOF_Y, 26.2), Vector3(8.8, ROOF_Y, 41.0), Vector3(10.4, ROOF_Y, 44.0), SPOT], true)
	r.speed = 7.0
	r.slow_zones = [[0.12, 0.17, 0.4], [0.88, 1.01, 0.35]] # 경사로 앞에서 한 번 멈칫, 칸 앞에서 천천히


func _walk_points(from: Vector3) -> Array[Vector3]:
	return [Vector3(STAIR_DOOR.x + 1.2, ROOF_Y, from.z), Vector3(STAIR_DOOR.x + 1.2, ROOF_Y, STAIR_DOOR.z - 1.0), STAIR_DOOR]


func _build_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	_block(Vector3(-150, -1, -80), Vector3(150, 0, 200), _material("asphalt"))
	var white := _plain(Color(0.9, 0.9, 0.86), true)
	_block(Vector3(1.95, 0, -20), Vector3(2.05, 0.02, 90), white, false)

	# 건물 A(벽 타는 쪽)와 밑동 곡면
	_building(Vector3(-22, 0, -10), Vector3(WALL_X, WALL_TOP, 72), "concrete") # 10/24: 격자 상자 → 창 있는 건물(창 줄이 벽 타는 속도를 보여 준다)
	_arc_x(Vector2(WALL_X + PIPE_R, PIPE_R), PIPE_R, 0.0, 90.0, 24, PIPE_Z.x, PIPE_Z.y, _material("curl"), -1.0)
	_sign("외벽 주행 금지", Vector3(WALL_X + 0.06, 12.0, 30.0), 90.0, 100, Color(1, 0.35, 0.3))

	# 건물 B(옥상 주차장). 길 쪽 가장자리는 낮은 턱 없이 열려 있다
	var x0 := BLD.position.x
	var x1 := BLD.position.x + BLD.size.x
	var z0 := BLD.position.y
	var z1 := BLD.position.y + BLD.size.y
	_building(Vector3(x0, 0, z0), Vector3(x1, ROOF_Y, z1), "brick", false)
	var rail := _material("concrete")
	_block(Vector3(x1 - 0.3, ROOF_Y, z0), Vector3(x1, ROOF_Y + 0.6, z1), rail)
	_block(Vector3(x0, ROOF_Y, z1 - 0.3), Vector3(x1, ROOF_Y + 0.6, z1), rail)
	_sign("옥상 주차", Vector3(x0 - 0.05, 5.2, 40.0), -90.0, 120)

	# 옥상 칸: 서쪽 줄 가운데가 빈칸, 동쪽 줄은 꽉 찼다
	_parking_row(Vector3(SPOT.x, ROOF_Y, SPOT.z), 5, 5, true, rng)
	_parking_row(Vector3(19.0, ROOF_Y, SPOT.z), 5, 5, false, rng, false)
	# 계단실
	_block(Vector3(5.2, ROOF_Y, 57.6), Vector3(7.6, ROOF_Y + 2.4, 60.0), _plain(Color(0.62, 0.62, 0.6)))
	_block(Vector3(5.8, ROOF_Y, 57.52), Vector3(7.0, ROOF_Y + 1.9, 57.6), _plain(Color(0.08, 0.1, 0.14)), false)

	# 건물 B 남쪽 경사로(앞차 길): 길에서 옥상 남동쪽 모서리까지
	_ramp_x(Vector3(6.0, 0, 21.2), Vector3(18.5, ROOF_Y, 21.2), 2.8, _material("concrete"))
	_block(Vector3(18.5, ROOF_Y - 0.4, 19.6), Vector3(21.0, ROOF_Y, 24.0), _material("deck"))

	# 배경
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 43
	_skyline(rng2, 26.0, -30.0, 130.0)
	for x in [-40.0, -20.0, 0.0, 20.0]:
		_building(Vector3(x, 0, 100), Vector3(x + 16, rng2.randf_range(15.0, 40.0), 114))
	_build_props()


## Tripo 소품(모델 버전에서만, 10/24). 건물 B 앞 보도 쪽(x 3.6~4.6)에 가로등·버스 정류장·쓰레기통. 앞차 길(z 8~22)과 착지 구간은 비운다
func _build_props() -> void:
	if not use_models:
		return
	for z: float in [2.0, 64.0]:
		_prop("streetlight", Vector3(4.6 - 1.66, 0, z), 180.0, Vector3(-1.66, 2.25, 0), Vector3(0.3, 4.5, 0.3)) # 돌렸으니 기둥 충돌은 모델 -X 쪽
	_prop("bus_stop", Vector3(4.2, 0, 52.0), -90.0)
	_prop("trash_bin", Vector3(4.4, 0, 48.6), 90.0, Vector3(0, 0.4, 0), Vector3(0.55, 0.8, 0.55))
	for z: float in [26.0, 34.0]:
		_prop("bollard", Vector3(4.4, 0, z), 0.0)


## x 방향 경사로: 윗면이 from에서 to까지(폭 width, z 중심 from.z)
func _ramp_x(from: Vector3, to: Vector3, width: float, mat: Material) -> void:
	var d := to - from
	var angle := atan2(d.y, d.x)
	var b := Basis(Vector3.BACK, angle)
	var center := (from + to) * 0.5 - b.y * 0.2
	_box(Transform3D(b, center), Vector3(d.length() + 0.1, 0.4, width), mat).set_meta("ramp", true)
