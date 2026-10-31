extends "res://scripts/commute_day.gd"
## DAY 2(화) — 주차 타워 만차, 옥상에 딱 한 칸.
## 3층(1층·2층·옥상)짜리 콘크리트 주차 타워. 1·2층은 꽉 찼고 옥상 왼쪽 줄에 한 칸이 비었다.
## 앞차는 옆 바깥 경사로로 천천히 올라가 옥상 칸을 노린다(올라와서 두리번거린다).
## 나는 1층 통로를 지나 뒤쪽 '진입금지' 곡면 옹벽을 흡착 팬(E 길게)으로 오르고, 거꾸로 튀어 나가
## 손을 떼면 추진기가 뒤집어 옥상에 내려준다 → 왼쪽 줄의 빈칸에 댄다.
## (10/23 사용자: 너무 비현실적인 주차장 → 기둥·천장 조명·주차 소품차·표지판을 갖춘 주차 타워로. 램프·날기 위치는 그대로)

const DECK_Y := 6.0
const DECK_Z0 := 40.0
const DECK_Z1 := 66.0
const SPOT := Vector3(-5.8, DECK_Y, 56.0)
const CURL_Z := 68.5
const CURL_R := 4.0
const STAIR_DOOR := Vector3(-8.0, DECK_Y, 47.6)
const LEVEL2_Y := 3.0 ## 2층 바닥
const COLS_X := [-7.8, -3.4, 3.4, 7.8]
const COLS_Z := [40.3, 48.7, 57.3, 65.7]
## 녹화용 고정 카메라(Shot cam=spot:curl): 건물 오른쪽 뒤 바깥 높은 곳에서 곡면 옹벽 옆모습과 옥상을 한 화면에
const SHOT_CAMS := {
	"curl": [Vector3(14.0, 10.0, 69.0), Vector3(0.0, 5.5, 66.0), 0.5],
}

var _mats2 := {}


func _configure() -> void:
	use_models = true
	day_index = 1
	day_name = "화 · 주차 타워"
	intro_text = "화요일\n주차 타워 만차… 옥상에 한 칸!"
	start_clock = 8 * 3600 + 59 * 60 + 30.0
	start_xform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	spot_center = SPOT
	spot_yaw_deg = 90.0
	cut_cam_pos = Vector3(1.0, 9.0, 64.0)
	cut_cam_target = Vector3(-1.2, 6.6, 54.5)
	win_lines = ["아니 경사로로\n올라와야죠!!", "…날아서 왔다고?"]
	lose_line = "경사로가\n정석이죠~"
	rival_color = Color(0.2, 0.45, 0.3)
	rival_paint = Color(0.35, 0.62, 0.42)


func _setup_rival(r: RivalCar) -> void:
	# 옥상에 올라와서는 앞 난간과 오른쪽 줄 첫 차 사이(z 40.3~43)로 꺾어 통로에 들어간다(그 차를 타고 넘지 않게, 10/23)
	r.setup_path([Vector3(9.5, 0, 1), Vector3(9.5, 0, 8), Vector3(9.5, DECK_Y, 36), Vector3(9.4, DECK_Y, 39.6),
		Vector3(7.6, DECK_Y, 41.5), Vector3(4.2, DECK_Y, 41.7), Vector3(1.6, DECK_Y, 43.2), Vector3(0.7, DECK_Y, 47.0),
		Vector3(0.4, DECK_Y, 53.0), Vector3(-2.4, DECK_Y, 56.0), SPOT], true)
	# 경사로는 빨리 올라와서(내가 1층을 달릴 때 왼쪽 경사로에 보인다) 옥상 통로에서 칸을 찾아 두리번거리며 천천히 다가온다.
	# 내가 옥상에 내릴 때 앞차는 통로 건너편에서 같은 칸으로 오는 중이다(10/23 사용자: 앞차가 너무 늦게 온다)
	# 10/24: 더 일찍 칸에 닿게(약 16.5초, 예전 19.7초). 내가 대고 나서 1~2초 안에 칸 앞까지 와 경적을 울린다
	r.speed = 5.6
	r.slow_zones = [[0.74, 0.86, 0.35]]


func _walk_points(from: Vector3) -> Array[Vector3]:
	return [Vector3(-3.0, DECK_Y, from.z), Vector3(-3.0, DECK_Y, STAIR_DOOR.z), STAIR_DOOR]


func _build_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	_block(Vector3(-150, -1, -80), Vector3(150, 0, 200), _material("asphalt"))
	var white := _plain(Color(0.9, 0.9, 0.86), true)
	_block(Vector3(-4.1, 0, -20), Vector3(-4.0, 0.02, 39), white, false)
	_block(Vector3(4.0, 0, -20), Vector3(4.1, 0.02, 39), white, false)
	var wall := _conc("wall")
	var slab := _conc("slab")

	# 바닥판: 1층(바닥에 칠만), 2층, 옥상
	_block(Vector3(-8, 0, DECK_Z0), Vector3(8, 0.015, DECK_Z1), slab, false)
	_block(Vector3(-8, LEVEL2_Y - 0.3, DECK_Z0), Vector3(8, LEVEL2_Y, DECK_Z1), slab)
	_block(Vector3(-8, DECK_Y - 0.6, DECK_Z0), Vector3(8, DECK_Y, DECK_Z1), slab)
	# 기둥(8m 간격). 1층 기둥 밑동에 노랑·검정 띠
	for x: float in COLS_X:
		for z: float in COLS_Z:
			_block(Vector3(x - 0.25, 0, z - 0.25), Vector3(x + 0.25, LEVEL2_Y - 0.3, z + 0.25), wall)
			_block(Vector3(x - 0.25, LEVEL2_Y, z - 0.25), Vector3(x + 0.25, DECK_Y - 0.6, z + 0.25), wall)
			for band in 3:
				var y0 := band * 0.25
				_block(Vector3(x - 0.27, y0, z - 0.27), Vector3(x + 0.27, y0 + 0.25, z + 0.27), _stripe(band % 2 == 0), false)
	# 1·2층 주차 줄(만차, 가운데 통로는 비움)
	# 1·2층 줄에는 픽업트럭도 섞는다(자동 주행이 스치는 옥상 줄은 예전 모델 그대로)
	var more: Array = ["hatchback", "sedan", "suv", "pickup", "sedan", "van"] if _has_model("pickup") else []
	_parking_row(Vector3(-5.8, 0, 52), 4, 5, false, rng, true, more)
	_parking_row(Vector3(5.8, 0, 52), 4, 5, false, rng, true, more)
	# 2층 줄은 따로 뽑는다: 1층·옥상 줄이 예전과 같은 순서로 뽑혀야 옥상 빈칸 옆 차들이 자동 주행을 맞춰 둔 그대로 선다
	var rng_2f := RandomNumberGenerator.new()
	rng_2f.seed = 19
	_parking_row(Vector3(-5.8, LEVEL2_Y, 52), 4, 5, false, rng_2f, true, more)
	_parking_row(Vector3(5.8, LEVEL2_Y, 52), 4, 5, false, rng_2f, true, more)
	# 2층 난간벽(앞·옆·뒤)
	_block(Vector3(-8, LEVEL2_Y, DECK_Z0), Vector3(8, LEVEL2_Y + 1.0, DECK_Z0 + 0.25), wall)
	_block(Vector3(-8, LEVEL2_Y, DECK_Z1 - 0.25), Vector3(8, LEVEL2_Y + 1.0, DECK_Z1), wall)
	_block(Vector3(-8, LEVEL2_Y, DECK_Z0), Vector3(-7.75, LEVEL2_Y + 1.0, DECK_Z1), wall)
	_block(Vector3(7.75, LEVEL2_Y, DECK_Z0), Vector3(8, LEVEL2_Y + 1.0, DECK_Z1), wall)
	# 천장 형광등(1·2층 통로 위)과 실내 조명
	# 형광등은 통로 가운데(차·카메라가 지나는 줄)를 피해 양옆 두 줄로
	for z in range(42, 66, 4):
		for x: float in [-2.2, 2.2]:
			_block(Vector3(x - 0.08, LEVEL2_Y - 0.36, z - 0.65), Vector3(x + 0.08, LEVEL2_Y - 0.3, z + 0.65), _lamp_mat(), false)
			_block(Vector3(x - 0.08, DECK_Y - 0.66, z - 0.65), Vector3(x + 0.08, DECK_Y - 0.6, z + 0.65), _lamp_mat(), false)
	for z: float in [44.0, 53.0, 62.0]:
		_omni(Vector3(0, LEVEL2_Y - 0.6, z), 11.0, 1.3)
	for z: float in [47.0, 59.0]:
		_omni(Vector3(0, DECK_Y - 0.9, z), 11.0, 1.0)

	# 입구(앞, z 40): 높이 제한 봉, 만차 전광판, 층 표시, P 간판
	for k in 14:
		var x := -3.5 + k * 0.5
		_block(Vector3(x, 2.25, DECK_Z0 - 0.45), Vector3(x + 0.5, 2.4, DECK_Z0 - 0.3), _stripe(k % 2 == 0), false)
	_block(Vector3(-3.6, 0, DECK_Z0 - 0.45), Vector3(-3.5, 2.4, DECK_Z0 - 0.3), _stripe(false), false)
	_block(Vector3(3.5, 0, DECK_Z0 - 0.45), Vector3(3.6, 2.4, DECK_Z0 - 0.3), _stripe(false), false)
	# 글씨와 전광판은 통로 가운데를 피한다: 추적 카메라가 입구를 지날 때 바로 앞을 스쳐 화면을 가렸다(10/23)
	_sign("높이제한 2.3m", Vector3(-2.2, 2.32, DECK_Z0 - 0.5), 180.0, 34, Color(1, 0.85, 0.2))
	_block(Vector3(4.2, LEVEL2_Y + 0.15, DECK_Z0 - 0.08), Vector3(7.0, LEVEL2_Y + 0.85, DECK_Z0), _plain(Color(0.05, 0.05, 0.06)), false)
	_sign("만차", Vector3(5.6, LEVEL2_Y + 0.5, DECK_Z0 - 0.1), 180.0, 110, Color(1, 0.25, 0.2))
	_sign("1F", Vector3(-3.4, 1.9, DECK_Z0 + 0.04), 180.0, 70)
	_sign("2F", Vector3(-3.4, LEVEL2_Y + 1.6, DECK_Z0 - 0.02), 180.0, 70)
	_block(Vector3(6.2, DECK_Y + 0.6, DECK_Z0 - 0.15), Vector3(7.8, DECK_Y + 2.2, DECK_Z0 - 0.05), _plain(Color(0.1, 0.3, 0.75)), false)
	_block(Vector3(6.95, DECK_Y, DECK_Z0 - 0.15), Vector3(7.05, DECK_Y + 0.6, DECK_Z0 - 0.05), wall, false)
	_sign("P", Vector3(7.0, DECK_Y + 1.4, DECK_Z0 - 0.2), 180.0, 150)

	# 옥상: 칸 두 줄과 가운데 통로, 왼쪽 줄 가운데가 빈칸. 난간벽, 조명 기둥
	_parking_row(Vector3(-5.8, DECK_Y, 56), 5, 3, true, rng)
	_parking_row(Vector3(5.8, DECK_Y, 56), 5, 3, false, rng)
	_block(Vector3(-8, DECK_Y, DECK_Z0), Vector3(-7.7, DECK_Y + 0.9, 47.0), wall)
	_block(Vector3(-8, DECK_Y, 48.2), Vector3(-7.7, DECK_Y + 0.9, DECK_Z1), wall)
	_block(Vector3(7.7, DECK_Y, 44.0), Vector3(8, DECK_Y + 0.9, DECK_Z1), wall)
	_block(Vector3(-8, DECK_Y, DECK_Z0), Vector3(8, DECK_Y + 0.9, DECK_Z0 + 0.3), wall)
	# 조명 기둥은 오른쪽 난간 위에 세우고 팔을 통로 쪽으로 뻗는다(통로 한가운데 기둥은 차 길과 추적 카메라를 막는다)
	for z: float in [46.0, 60.0]:
		var steel := _plain(Color(0.3, 0.32, 0.36))
		_block(Vector3(7.76, DECK_Y + 0.9, z - 0.09), Vector3(7.94, DECK_Y + 4.5, z + 0.09), steel)
		_block(Vector3(5.6, DECK_Y + 4.42, z - 0.06), Vector3(7.94, DECK_Y + 4.5, z + 0.06), steel, false)
		_block(Vector3(5.0, DECK_Y + 4.32, z - 0.18), Vector3(6.2, DECK_Y + 4.42, z + 0.18), _lamp_mat(), false)
	# 계단실(사람이 내려가는 문)
	_block(Vector3(-11, 0, 45.6), Vector3(-8, DECK_Y + 2.6, 49.6), wall)
	_block(Vector3(-8.06, DECK_Y, STAIR_DOOR.z - 0.6), Vector3(-7.98, DECK_Y + 1.9, STAIR_DOOR.z + 0.6), _plain(Color(0.08, 0.1, 0.14)), false)
	_sign("계단", Vector3(-7.95, DECK_Y + 2.3, STAIR_DOOR.z), 90.0, 90)

	# 앞차가 오르는 바깥 경사로(난간 턱, 받침 기둥)와 윗 평지
	_ramp(9.5, 2.4, Vector3(9.5, 0, 8), Vector3(9.5, DECK_Y, 36), slab)
	for side: float in [-1.0, 1.0]:
		_ramp(9.5 + side * 1.3, 0.2, Vector3(9.5, 0.35, 8), Vector3(9.5, DECK_Y + 0.35, 36), wall)
	for z: float in [16.0, 24.0, 32.0]:
		var top := (z - 8.0) / 28.0 * DECK_Y - 0.45
		_block(Vector3(9.25, 0, z - 0.25), Vector3(9.75, top, z + 0.25), wall)
	_block(Vector3(8.0, DECK_Y - 0.4, 36), Vector3(10.7, DECK_Y, 44), slab)

	# 1층 통로 끝 뒤쪽의 곡면 옹벽(흡착 팬으로 오르면 거꾸로 튀어 나가 옥상으로 떨어진다). 차가 다니는 곳이 아니라 '진입금지'
	_arc(Vector2(CURL_Z, CURL_R), CURL_R, 0.0, 135.0, 36, 6.0, 0.0, wall)
	_block(Vector3(-3.2, 0, CURL_Z + CURL_R + 0.2), Vector3(3.2, CURL_R + 0.5, CURL_Z + CURL_R + 0.7), wall)
	for side: float in [-1.0, 1.0]:
		for i in 18:
			var th := deg_to_rad(135.0) * (i + 0.5) / 18.0
			var p3 := Vector3(side * 3.05, CURL_R - CURL_R * cos(th), CURL_Z + CURL_R * sin(th))
			var n3 := Vector3(0, cos(th), -sin(th))
			_box(Transform3D(Basis(Vector3.RIGHT, -th), p3 + n3 * 0.03), Vector3(0.12, 0.05, 0.7), _stripe(i % 2 == 0), false)
	_block(Vector3(3.6, 0, CURL_Z - 1.05), Vector3(3.7, 2.4, CURL_Z - 0.95), _plain(Color(0.3, 0.32, 0.36)), false)
	_block(Vector3(3.15, 1.6, CURL_Z - 1.12), Vector3(4.15, 2.6, CURL_Z - 1.06), _plain(Color(0.85, 0.12, 0.12)), false)
	_sign("진입금지", Vector3(3.65, 2.1, CURL_Z - 1.16), 180.0, 56)

	# 10/23 추가 Tripo 소품(모델 버전, 파일이 있을 때만): 입구 차단기, 옥상 칸 머리 충전기, 길가 사람
	if _has_model("barrier_gate"):
		_prop("barrier_gate", Vector3(-5.7, 0, DECK_Z0 - 1.4), 90.0) # 나가는 줄(닫힌 차단기), 들어가는 길은 비운다
	if _has_model("ev_charger"):
		for k in [-1, 1]:
			_prop("ev_charger", Vector3(-7.4, DECK_Y, SPOT.z + k * spot_size.x), 90.0)
	if _has_model("walker_b"):
		_pedestrian("walker_b", [Vector3(-6.2, 0, 4.0), Vector3(-6.2, 0, 34.0)], 1.2, 0.2)

	# 배경
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 33
	_skyline(rng2, 14.0, -30.0, 130.0)
	_skyline(rng2, -42.0, -30.0, 130.0)


## 거친 콘크리트(얼룩 무늬가 세계 좌표로 이어진다)
func _conc(key: String) -> StandardMaterial3D:
	if _mats2.has(key):
		return _mats2[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.6, 0.58) if key == "wall" else Color(0.4, 0.405, 0.41) # 옥상이 해를 받아 하얗게 날리지 않게(10/23)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.78, 0.78))
	ramp.set_color(1, Color(1, 1, 1))
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.color_ramp = ramp
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.2, 0.2, 0.2)
	m.roughness = 0.92
	_mats2[key] = m
	return m


func _stripe(yellow: bool) -> StandardMaterial3D:
	var key := "stripe_y" if yellow else "stripe_k"
	if not _mats2.has(key):
		_mats2[key] = _plain(Color(0.95, 0.75, 0.1) if yellow else Color(0.06, 0.06, 0.07))
	return _mats2[key]


func _lamp_mat() -> StandardMaterial3D:
	if not _mats2.has("lamp"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.97, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.92, 0.96, 1.0)
		m.emission_energy_multiplier = 2.5
		_mats2["lamp"] = m
	return _mats2["lamp"]


func _omni(pos: Vector3, range_m: float, energy: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.omni_range = range_m
	l.light_energy = energy
	l.light_color = Color(0.95, 0.97, 1.0)
	add_child(l)
