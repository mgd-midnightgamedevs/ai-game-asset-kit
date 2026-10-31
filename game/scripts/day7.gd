extends "res://scripts/commute_day.gd"
## DAY 7(일) — 고가도로 건너 브런치 맛집, 마지막 한 자리.
## 길이 9m 높이 고가도로(흙을 채운 옹벽 구간)에 막혔다. 앞차는 멀리 있는 굴다리로 돌아간다.
## 나는 리프트(Space)를 길게 눌러 고가도로 위로 올라가고, 차들이 달리는 차로를 건너, 반대편 난간을 넘어 내려와 칸에 댄다.
## 좌표: 진행 방향 +Z. 고가도로는 x 방향(z 24~40), 굴다리는 x 44~56.

const DECK_Y := 9.0
const DECK_Z := Vector2(24.0, 40.0)
const RAIL_H := 1.2
const UNDERPASS_X := Vector2(44.0, 56.0)
const LANE_X := -1.8
const SPOT := Vector3(-1.8, 0, 57.0) ## 고가도로를 넘는 차선과 같은 줄
const DOOR := Vector3(0.0, 0.15, 66.0)
## 고가도로 차로: [z, 방향(+1 = +X), 속도, 첫 차 x, 간격]
const LANES := [
	[26.6, -1.0, 13.0, 30.0, 42.0],
	[30.4, -1.0, 15.0, 8.0, 46.0],
	[33.6, 1.0, 14.0, -36.0, 44.0],
	[37.4, 1.0, 12.0, -10.0, 40.0],
]
const TRAFFIC_SPAN := 132.0 ## x -132..132에서 돈다

var _traffic: Array[AnimatableBody3D] = []
var _traffic_lane: Array[int] = []


func _configure() -> void:
	use_models = true
	day_index = 6
	day_name = "일 · 브런치 맛집"
	intro_text = "일요일\n고가도로 건너 브런치 마지막 한 자리!"
	play_hint = "굴다리로 돌면 늦는다"
	start_clock = 10 * 3600 + 59 * 60 + 36.0
	deadline_label = "11시 예약"
	clear_line = "%s 도착 · 예약 세이프"
	start_xform = Transform3D(Basis.IDENTITY, Vector3(LANE_X, 0, 0))
	spot_center = SPOT
	spot_yaw_deg = 0.0
	cut_cam_pos = Vector3(7.0, 5.5, 48.0)
	cut_cam_target = Vector3(0.0, 0.8, 56.0)
	win_lines = ["줄 서서\n기다렸는데!!", "…고가도로를 넘어?"]
	lose_line = "웨이팅은\n기본이죠~"
	rival_color = Color(0.7, 0.4, 0.75)
	rival_paint = Color(0.92, 0.92, 0.95)


func _setup_rival(r: RivalCar) -> void:
	# 남쪽 옆길 → 굴다리 → 북쪽 옆길 → 맛집 주차장
	var ux := (UNDERPASS_X.x + UNDERPASS_X.y) * 0.5
	r.setup_path([Vector3(1.8, 0, 6.0), Vector3(1.8, 0, 15.0), Vector3(6.0, 0, 20.0), Vector3(ux - 2.0, 0, 20.0),
		Vector3(ux, 0, 24.0), Vector3(ux, 0, 40.0), Vector3(ux - 4.0, 0, 44.0), Vector3(4.0, 0, 44.0),
		Vector3(0.8, 0, 50.0), SPOT], true)
	r.speed = 11.0
	r.slow_zones = [[0.93, 1.01, 0.35]]


func _walk_points(from: Vector3) -> Array[Vector3]:
	return [Vector3(from.x, 0.15, DOOR.z - 1.2), DOOR]


func _day_process(delta: float) -> void:
	for i in _traffic.size():
		var lane: Array = LANES[_traffic_lane[i]]
		var c := _traffic[i]
		var x: float = c.global_position.x + lane[1] * lane[2] * delta
		if x > TRAFFIC_SPAN:
			x -= TRAFFIC_SPAN * 2.0
		elif x < -TRAFFIC_SPAN:
			x += TRAFFIC_SPAN * 2.0
		c.global_position = Vector3(x, DECK_Y, lane[0])


func _build_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	_block(Vector3(-150, -1, -80), Vector3(150, 0, 200), _material("asphalt"))
	var white := _plain(Color(0.9, 0.9, 0.86), true)
	var yellow := _plain(Color(1.0, 0.82, 0.2), true)
	_block(Vector3(-0.05, 0, -20), Vector3(0.05, 0.02, 14.0), yellow, false)

	# 고가도로: 옹벽(흙 채움) 구간 + 굴다리 위 다리
	var z0 := DECK_Z.x
	var z1 := DECK_Z.y
	_block(Vector3(-150, 0, z0), Vector3(UNDERPASS_X.x, DECK_Y, z1), _material("concrete"))
	_block(Vector3(UNDERPASS_X.y, 0, z0), Vector3(150, DECK_Y, z1), _material("concrete"))
	_block(Vector3(UNDERPASS_X.x, DECK_Y - 1.2, z0), Vector3(UNDERPASS_X.y, DECK_Y, z1), _material("concrete"))
	_block(Vector3(-150, DECK_Y, z0 + 0.3), Vector3(150, DECK_Y + 0.02, z1 - 0.3), _material("asphalt"), false)
	var rail := _material("deck")
	_block(Vector3(-150, DECK_Y, z0), Vector3(150, DECK_Y + RAIL_H, z0 + 0.3), rail)
	_block(Vector3(-150, DECK_Y, z1 - 0.3), Vector3(150, DECK_Y + RAIL_H, z1), rail)
	for lz: float in [28.5, 35.5]:
		var x := -150.0
		while x < 150.0:
			_block(Vector3(x, DECK_Y + 0.02, lz - 0.06), Vector3(x + 3.0, DECK_Y + 0.04, lz + 0.06), white, false)
			x += 7.0
	_block(Vector3(-150, DECK_Y + 0.02, 31.95), Vector3(150, DECK_Y + 0.04, 32.05), yellow, false)
	_sign("고가도로", Vector3(-8.0, 6.0, z0 - 0.05), 180.0, 140)
	_sign("굴다리 →", Vector3(16.0, 4.5, z0 - 0.05), 180.0, 110, Color(1, 0.9, 0.3))

	# 고가도로 위 차들(부딪히면 사고)
	var cols := [Color(0.85, 0.85, 0.87), Color(0.15, 0.16, 0.2), Color(0.62, 0.1, 0.12), Color(0.2, 0.32, 0.55), Color(0.9, 0.75, 0.2)]
	for li in LANES.size():
		var lane: Array = LANES[li]
		var x: float = lane[3]
		var k := 0
		while k < 7:
			var c := _traffic_car(cols[rng.randi() % cols.size()], lane[1] > 0.0, Vector3(x, DECK_Y, lane[0]))
			_traffic.append(c)
			_traffic_lane.append(li)
			x -= lane[1] * lane[4]
			if x > TRAFFIC_SPAN:
				x -= TRAFFIC_SPAN * 2.0
			elif x < -TRAFFIC_SPAN:
				x += TRAFFIC_SPAN * 2.0
			k += 1

	# 옆길(앞차가 도는 길)
	_block(Vector3(4.0, 0, 18.0), Vector3(60.0, 0.02, 22.0), _material("deck"), false)
	_block(Vector3(4.0, 0, 42.0), Vector3(60.0, 0.02, 46.0), _material("deck"), false)

	# 브런치 맛집 주차장과 가게
	_block(Vector3(-12, 0, 49.5), Vector3(12, 0.02, 63), _material("sidewalk"), false)
	_parking_row_x(SPOT, 3, 3, true, rng)
	_block(Vector3(-12, 0, 66), Vector3(12, 7, 76), _material("building"))
	_block(Vector3(-1.0, 0, 65.94), Vector3(1.0, 2.0, 66.0), _plain(Color(0.08, 0.1, 0.14)), false)
	_sign("브런치", Vector3(0, 3.6, 65.9), 180.0, 130, Color(1, 0.85, 0.6))
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 59
	_skyline(rng2, 14.0, -30.0, 18.0)
	_skyline(rng2, -32.0, -30.0, 18.0)
	_skyline(rng2, 16.0, 48.0, 130.0)
	_skyline(rng2, -34.0, 48.0, 130.0)


## 원점에서 만든 뒤 옮기면 그 사이에 있는 내 차를 쓸고 지나가므로, 자리를 먼저 정하고 넣는다.
func _traffic_car(col: Color, east: bool, at: Vector3) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.2, 1.2, 1.8)
	shape.shape = box
	shape.position = Vector3(0, 0.8, 0)
	body.add_child(shape)
	for part in [[Vector3(4.2, 0.7, 1.8), Vector3(0, 0.55, 0), col], [Vector3(2.0, 0.5, 1.6), Vector3(-0.3 if east else 0.3, 1.15, 0), Color(0.08, 0.1, 0.14)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		mi.position = part[1]
		mi.material_override = _plain(part[2])
		body.add_child(mi)
	add_child(body)
	return body
