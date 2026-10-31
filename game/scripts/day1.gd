extends "res://scripts/commute_day.gd"
## DAY 1(월) — 회사 앞 마지막 한 칸.
## 앞차가 깜빡이를 켜고 길가 칸에 앞머리부터 주춤주춤 들어가려 한다. 차선은 이중 주차한 택배 트럭과 앞차가 막고 있다.
## 리프트로 앞차를 넘고 → 공중에서 오른쪽으로 90도 돌고(D) → 메인 추진으로 칸 쪽으로 밀고 → 바퀴로 내려앉아 멈추면 성공.
## 좌표: 진행 방향 +Z, 주차칸은 화면 오른쪽(-X) 길가, 회사 건물은 그 너머.
## 크기: 내 차(Kenney 차체 0.96 x 1.8m)에 맞춘 '작은 도시' 축척. 다른 차는 길이 3m, 사람은 약 1.2m.
## 겉모습: 로드스터면 세워 둔 차·사람(me, karen)·소품이 Tripo 모델, M 키로 상자 차가 되면 처음 상자 버전(소품은 없음).

const LANE_X := -3.4 ## 앞차와 내 차가 달리는 줄
const CURB_X := -4.0 ## 길가 경계선(칸 입구)
const SPOT := Vector3(-5.8, 0, 28)
const SIDEWALK_X := -7.9
const OFFICE_X := -11.0
const DOOR := Vector3(-10.8, 0.15, 28)
const MEDIAN_X := 2.0
const TRUCK_AT := Vector3(-0.1, 0, 16.9) ## 택배 트럭 바닥 가운데(앞이 +Z)
## 녹화용 고정 카메라(Shot cam=spot:이름): [카메라 위치, 기준점, 차를 따라보는 비율]
## crash: 인도 위 높은 곳에서 앞차 뒤를 박는 순간을 옆으로(트럭·앞차에 가리지 않게). paint: 인도에서 칸에 댄 차의 앞모습을 가까이(앞차 경적 글씨가 차 뒤로 가게)
const SHOT_CAMS := {
	"crash": [Vector3(-9.6, 4.6, 14.8), Vector3(-3.3, 0.6, 18.4), 0.3],
	"paint": [Vector3(-8.7, 1.5, 31.0), Vector3(-5.6, 0.55, 28.0), 0.15],
}
const TRUCK_SCALE := 0.56 ## Tripo 트럭 모델(11.8 x 5.15 x 3.72m) 줄이는 비율
const TRUCK_SIZE := Vector3(2.08, 2.88, 6.6) ## 줄인 트럭의 폭·높이·길이(부딪히는 상자)


func _configure() -> void:
	day_index = 0
	day_name = "월 · 마지막 한 칸"
	intro_text = "월요일\n회사 앞 마지막 한 칸!"
	start_clock = 8 * 3600 + 59 * 60 + 38.0
	start_xform = Transform3D(Basis.IDENTITY, Vector3(LANE_X, 0, 0))
	spot_center = SPOT
	spot_yaw_deg = 90.0
	cut_cam_pos = Vector3(0.5, 6.0, 35.0)
	cut_cam_target = Vector3(-7.0, 0.8, 27.0)
	use_models = true
	win_lines = ["아니 깜빡이\n켰잖아요!!", "…부들부들"]
	lose_line = "먼저\n왔거든요~"


func _setup_rival(r: RivalCar) -> void:
	# 차선 가운데 쪽으로 붙어 와서 꺾는다: Tripo 차들이 상자 차보다 길어 예전 줄(x -3.4)로는 옆 차 범퍼를 스쳤다(10/23)
	r.setup_bezier(Vector3(-2.7, 0, 18.5), Vector3(-2.5, 0, 28), SPOT)
	r.speed = r.curve.get_baked_length() / 4.8
	r.slow_zones = [[0.28, 0.4, 0.176], [0.68, 0.78, 0.24]] # 들어가다 두 번 멈칫


func _walk_points(from: Vector3) -> Array[Vector3]:
	return [Vector3(SIDEWALK_X - 0.6, 0.15, from.z), Vector3(SIDEWALK_X - 0.6, 0.15, DOOR.z), DOOR]


func _build_world() -> void:
	# 바닥·중앙 분리대·인도·회사 건물
	_block(Vector3(-150, -1, -80), Vector3(150, 0, 200), _material("asphalt"))
	_block(Vector3(MEDIAN_X, 0, -20), Vector3(MEDIAN_X + 0.5, 0.7, 90), _material("concrete"))
	_block(Vector3(OFFICE_X, 0, -20), Vector3(SIDEWALK_X, 0.15, 90), _material("sidewalk"))
	_building(Vector3(-32, 0, 6), Vector3(OFFICE_X, 30, 52), "hq")
	_block(Vector3(OFFICE_X - 0.05, 0.15, DOOR.z - 1.0), Vector3(OFFICE_X + 0.06, 2.0, DOOR.z + 1.0), _plain(Color(0.08, 0.1, 0.14)), false)
	_sign("본사", Vector3(OFFICE_X + 0.1, 2.7, DOOR.z), 90.0)

	# 흰 차선과 주차된 차들: 가운데 한 칸만 비어 있다
	var white := _plain(Color(0.9, 0.9, 0.86), true)
	_block(Vector3(CURB_X - 0.08, 0, -20), Vector3(CURB_X + 0.04, 0.02, 90), white, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_parking_row(Vector3(SPOT.x, 0, SPOT.z), 10, 11, true, rng)

	# 이중 주차한 택배 트럭(차선 왼쪽을 막는다). Tripo 트럭(높이 5.15m로 나옴)을 TRUCK_SCALE로 줄여 쓰고,
	# 부딪히는 상자도 그 크기에 맞춘다(예전 상자 11.8x3.2x2.35m보다 짧고 좁다, 10/23). 상자 버전도 같은 크기
	var tl := TRUCK_AT - Vector3(TRUCK_SIZE.x * 0.5, 0, TRUCK_SIZE.z * 0.5)
	var cab_z := tl.z + TRUCK_SIZE.z * 0.78 # 앞(+Z) 22%가 운전석
	_solid(tl + Vector3(0, 0.3, 0), tl + Vector3(TRUCK_SIZE.x, TRUCK_SIZE.y, TRUCK_SIZE.z * 0.78))
	_solid(Vector3(tl.x + 0.1, 0.3, cab_z), Vector3(tl.x + TRUCK_SIZE.x - 0.1, TRUCK_SIZE.y * 0.8, tl.z + TRUCK_SIZE.z))
	var truck_box := not _has_model("semi_truck")
	for part: Array in [[tl + Vector3(0, 0.3, 0), tl + Vector3(TRUCK_SIZE.x, TRUCK_SIZE.y, TRUCK_SIZE.z * 0.78), _material("truck")],
			[Vector3(tl.x + 0.1, 0.3, cab_z), Vector3(tl.x + TRUCK_SIZE.x - 0.1, TRUCK_SIZE.y * 0.8, tl.z + TRUCK_SIZE.z), _plain(Color(0.2, 0.42, 0.75))],
			[tl + Vector3(0.2, 0, 0.4), tl + Vector3(TRUCK_SIZE.x - 0.2, 0.3, TRUCK_SIZE.z - 0.4), _plain(Color(0.08, 0.08, 0.1))]]:
		if truck_box:
			_block(part[0], part[1], part[2], false)
		else:
			_box_look(part[0], part[1], part[2])
	if not truck_box:
		_model("semi_truck", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * TRUCK_SCALE), TRUCK_AT))

	# 맞은편 건물들(배경)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 21
	_skyline(rng2, 12.0, -30.0, 120.0)
	for x in [-40.0, -20.0, 0.0, 20.0]:
		_building(Vector3(x, 0, 96), Vector3(x + 16, rng2.randf_range(15.0, 40.0), 110))

	_build_props()


## Tripo 소품(모델 버전에서만 보인다). 충돌 상자는 모델 원점 기준. 사람이 걷는 길(인도 x -8.5, z 26~30)과 내 차가 뛰는 길(z 17~29)은 비운다.
func _build_props() -> void:
	var curb := 0.15 # 인도 높이
	# 가로등: 기둥이 모델 원점의 -X 1.66m, 팔은 +X로 4m. 인도 바깥쪽에 세워 팔이 칸 위로 나온다
	for z: float in [6.0, 50.0]:
		_prop("streetlight", Vector3(SIDEWALK_X - 0.5 + 1.66, curb, z), 0.0, Vector3(-1.66, 2.25, 0), Vector3(0.3, 4.5, 0.3))
	# 신호등: 중앙 분리대 위, 오는 차(-Z 쪽)를 본다. 돌렸으니 기둥은 원점의 +X 1.73m, 팔은 -X로 차선 위
	_prop("traffic_light", Vector3(MEDIAN_X + 0.25 - 1.73, 0.7, 40.0 - 0.35), 180.0, Vector3(-1.73, 1.9, -0.35), Vector3(0.3, 3.8, 0.3))
	# 건물 쪽: 화분 나무 둘, 길을 보는 벤치
	for z: float in [18.0, 40.0]:
		_prop("tree", Vector3(-10.0, curb, z), 0.0, Vector3(-0.09, 0.3, 0.05), Vector3(0.95, 0.6, 0.95))
	_prop("bench", Vector3(-10.5, curb, 33.0), 90.0, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.7))
	_prop("hydrant", Vector3(SIDEWALK_X - 0.4, curb, 31.6), 90.0, Vector3(0, 0.4, 0), Vector3(0.37, 0.8, 0.38))
	# 10/23 추가: 버스 정류장·쓰레기통·볼라드(인도), 오가는 사람 둘. 내 차·앞차 길에서 떨어진 인도 안쪽에만 둔다
	if _has_model("bus_stop"):
		_prop("bus_stop", Vector3(-10.1, curb, 11.0), 90.0)
	if _has_model("trash_bin"):
		for z: float in [15.2, 36.6]:
			_prop("trash_bin", Vector3(SIDEWALK_X - 0.32, curb, z), 90.0)
	if _has_model("bollard"):
		for z: float in [DOOR.z - 2.2, DOOR.z + 2.2]:
			for x: float in [-10.5, -9.75]:
				_prop("bollard", Vector3(x, curb, z), 0.0)
	if _has_model("walker_a"):
		# 칸·회사 문 앞(z 20~36)은 비운다: 날아와 내려앉을 때 추적 카메라가 인도 위로 내려와 사람 머리가 화면을 가렸다
		_pedestrian("walker_a", [Vector3(-9.15, curb, 2.0), Vector3(-9.15, curb, 19.0)], 1.1, 0.3)
	if _has_model("walker_b"):
		_pedestrian("walker_b", [Vector3(-8.75, curb, 48.0), Vector3(-8.75, curb, 37.0)], 1.2, 0.5)
	# 택배 트럭 앞뒤 고깔(차선 밖이라 부딪히지 않게 두었다)
	var rear := TRUCK_AT.z - TRUCK_SIZE.z * 0.5
	for p: Vector3 in [Vector3(-1.2, 0, rear - 1.2), Vector3(0.1, 0, rear - 1.4), Vector3(1.2, 0, rear - 1.2),
			Vector3(-1.3, 0, TRUCK_AT.z + TRUCK_SIZE.z * 0.5 + 0.8)]:
		_prop("cone", p, 0.0)
