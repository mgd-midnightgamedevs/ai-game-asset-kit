extends "res://scripts/commute_day.gd"
## DAY 6(토) — 주말 배달 알바: 계단식 고층 빌딩 세 곳에 9시까지 배달.
## 1) 6m 테라스: 길에서 리프트(Space)로 뛰어올라 배달 칸에 멈춘다.
## 2) 12m 테라스: 1번에서 조금 달려 다시 리프트 + 메인(Shift)으로 한 층 위로.
## 3) 30m 옥상: 타워 밑동 곡면으로 들어가 흡착 팬(E)으로 벽을 타고, 둥근 옥상 모서리를 그대로 넘어 옥상 칸에 멈춘다.
## 배달할 때마다 공기가 가득 찬다. 앞차는 없고 마감 시각과 싸운다.
## 좌표: 진행 방향 +Z. 건물은 z 16부터 계단처럼 높아진다.

const T1_Y := 6.0 ## 1층 테라스
const T1_Z := 16.0
const T2_Y := 12.0
const T2_Z := 28.0
const TOWER_Z := 40.0 ## 타워 벽(남쪽 면)
const TOWER_X := 6.0 ## 타워 반폭
const ROOF_Y := 30.0
const EDGE_R := 6.0 ## 옥상 모서리 둥근 반지름(이보다 작으면 최고 속도에서 팬이 못 붙잡고 튕겨 나간다)
const PIPE_R := 4.5 ## 타워 밑동 곡면
const STOPS := [
	[Vector3(0, T1_Y, 21.0), "1층 테라스 카페"],
	[Vector3(0, T2_Y, 33.0), "12m 테라스"],
	[Vector3(0, ROOF_Y, 52.0), "30m 옥상"],
]

var stops: Array[ParkingPad] = []
var delivered := 0


func _configure() -> void:
	use_models = true
	day_index = 5
	day_name = "토 · 주말 배달 알바"
	intro_text = "토요일\n9시까지 고층 빌딩 세 곳 배달!"
	play_hint = "배달 칸에 멈추면 배달 완료"
	rival_role = "none"
	start_clock = 8 * 3600 + 59 * 60 + 15.0 # 45초 안에 세 곳
	deadline = 9 * 3600.0
	deadline_label = "9시 배달 마감"
	deadline_lose = "9시 넘었다… 배달 지연"
	win_toast = "배달 완료!"
	clear_line = "%s 배달 완료 · 별점 5점"
	start_xform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	spot_center = STOPS[0][0]
	spot_yaw_deg = 0.0
	spot_size = Vector2(3.4, 4.4)
	them_pos = Vector3(2.6, ROOF_Y + 0.15, 53.5)
	cut_cam_pos = Vector3(9.0, ROOF_Y + 4.5, 44.0)
	cut_cam_target = Vector3(0.6, ROOF_Y + 0.6, 52.5)
	win_lines = ["벌써요?!\n엘리베이터 고장인데…", "…벽으로 왔어요?"]
	rival_color = Color(0.85, 0.5, 0.6)


func _setup_goal() -> void:
	spot.title = STOPS[0][1]
	stops.append(spot)
	for i in range(1, STOPS.size()):
		var p := ParkingPad.new()
		p.title = STOPS[i][1]
		p.size = spot_size
		p.transform = Transform3D(Basis.IDENTITY, STOPS[i][0])
		add_child(p)
		p.set_state(ParkingPad.State.IDLE)
		stops.append(p)


func _on_spot_done() -> void:
	_drop_parcel(spot.global_position)
	delivered += 1
	if delivered >= stops.size():
		_win()
		return
	car.refill_air()
	spot.set_state(ParkingPad.State.CHARGED)
	spot.update_fill()
	spot = stops[delivered]
	spot.set_state(ParkingPad.State.NEXT)
	hud.toast("배달 %d/%d 완료! 공기 충전\n다음: %s" % [delivered, stops.size(), spot.title], 1.8)


func _walk_points(from: Vector3) -> Array[Vector3]:
	return [from + Vector3(1.0, 0, 1.5)]


func _drop_parcel(at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.45, 0.5)
	mi.mesh = bm
	mi.material_override = _plain(Color(0.72, 0.52, 0.3))
	mi.position = at + Vector3(-1.4, 0.25, 1.6)
	add_child(mi)


func _build_world() -> void:
	_block(Vector3(-150, -1, -80), Vector3(150, 0, 200), _material("asphalt"))
	var white := _plain(Color(0.9, 0.9, 0.86), true)
	_block(Vector3(-0.05, 0, -20), Vector3(0.05, 0.02, T1_Z - 1.0), white, false)

	# 계단식 빌딩: 1층 테라스(6m) → 2층 테라스(12m) → 타워(30m)
	_block(Vector3(-10, 0, T1_Z), Vector3(10, T1_Y, 64), _material("building"))
	_block(Vector3(-10, T1_Y, T2_Z), Vector3(10, T2_Y, 64), _material("building"))
	_block(Vector3(-TOWER_X, T2_Y, TOWER_Z), Vector3(TOWER_X, ROOF_Y - EDGE_R, 64), _material("office"))
	_block(Vector3(-TOWER_X, ROOF_Y - EDGE_R, TOWER_Z + EDGE_R), Vector3(TOWER_X, ROOF_Y, 64), _material("office"))
	_block(Vector3(-TOWER_X, ROOF_Y - EDGE_R, TOWER_Z + 2.0), Vector3(TOWER_X, ROOF_Y - 2.0, TOWER_Z + EDGE_R), _material("office")) # 둥근 모서리 속 채움(보이는 구멍 막기)
	# 타워 밑동 곡면(2층 테라스 바닥 → 벽)과 둥근 옥상 모서리(벽 → 옥상)
	_arc(Vector2(TOWER_Z - PIPE_R, T2_Y + PIPE_R), PIPE_R, 0.0, 90.0, 24, TOWER_X * 2.0, 0.0, _material("curl"))
	_arc_convex(Vector2(TOWER_Z + EDGE_R, ROOF_Y - EDGE_R), EDGE_R, 0.0, 90.0, 36, TOWER_X * 2.0, 0.0, _material("curl"))
	# 테라스 난간(옆·뒤만. 앞은 뛰어 들어와야 하므로 열려 있다)
	var rail := _material("concrete")
	_block(Vector3(9.7, T1_Y, T1_Z), Vector3(10, T1_Y + 0.6, T2_Z), rail)
	_block(Vector3(-10, T1_Y, T1_Z), Vector3(-9.7, T1_Y + 0.6, T2_Z), rail)
	_block(Vector3(9.7, T2_Y, T2_Z), Vector3(10, T2_Y + 0.6, TOWER_Z), rail)
	_block(Vector3(-10, T2_Y, T2_Z), Vector3(-9.7, T2_Y + 0.6, TOWER_Z), rail)
	_sign("테라스 카페", Vector3(0, 3.6, T1_Z - 0.05), 180.0, 110)
	_sign("배달은 9시까지", Vector3(0, T2_Y - 2.4, T2_Z - 0.05), 180.0, 90, Color(1, 0.9, 0.3))
	_sign("스카이 타워", Vector3(0, ROOF_Y - EDGE_R - 3.0, TOWER_Z - 0.05), 180.0, 130)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 47
	_skyline(rng2, 16.0, -30.0, 120.0)
	_skyline(rng2, -32.0, -30.0, 120.0)
