extends "res://scripts/commute_day.gd"
## DAY 5(금) — 철도 건널목 너머 회사 주차장, 마지막 한 칸.
## 출발하자마자 차단기가 내려오고 2단 컨테이너 화물열차가 길을 가로질러 지나간다. 앞차는 차단기 앞에서 기다린다.
## 나는 옆 차선으로 빠져 리프트(Space)로 열차를 넘고, 건널목 바로 너머 주차장 칸에 먼저 댄다.
## 좌표: 진행 방향 +Z. 선로는 x 방향(z = TRACK_Z), 열차는 +X 쪽으로 달린다.

const TRACK_Z := 20.0
const LANE_X := -1.8 ## 앞차와 내가 선 차선(오른쪽). 왼쪽 차선(+X)은 비어 있다
const GATE_S := 15.6 ## 차단기(남쪽)
const GATE_N := 24.4
const SPOT := Vector3(0.0, 0, 38.0)
const DOOR := Vector3(0.0, 0.15, 49.0)
const TRAIN_SPEED := 14.0
const CAR_LEN := 12.0
const CAR_GAP := 0.6
const CAR_COUNT := 7 ## 기관차 1 + 화차 6
const CAR_H := 5.2 ## 2단 컨테이너 높이(바닥 0.4 위로)
const TRAIN_START_X := -22.0 ## 출발할 때 기관차 앞머리 위치(건널목까지 약 1초)

var _train: Array[AnimatableBody3D] = []
var _train_x := TRAIN_START_X
var _gates: Array[Node3D] = []
var _gate_lights: Array[MeshInstance3D] = []
var _light_on := StandardMaterial3D.new()
var _light_off := StandardMaterial3D.new()
var _bell: AudioStreamPlayer
var _gate_angle := 0.0 ## 0 = 내려옴, 1 = 올라감
var _t := 0.0


func _configure() -> void:
	use_models = true
	day_index = 4
	day_name = "금 · 철도 건널목"
	intro_text = "금요일\n건널목 너머 마지막 한 칸!"
	play_hint = "기차 기다릴 시간 없다"
	start_clock = 8 * 3600 + 59 * 60 + 34.0
	start_xform = Transform3D(Basis.IDENTITY, Vector3(LANE_X, 0, 0))
	spot_center = SPOT
	spot_yaw_deg = 0.0
	cut_cam_pos = Vector3(6.5, 5.5, 30.0)
	cut_cam_target = Vector3(-0.6, 0.8, 37.0)
	win_lines = ["기차 지나가는 거\n기다렸잖아요!!", "…기차를 넘었어?"]
	lose_line = "기다리면\n되잖아요~"
	rival_color = Color(0.55, 0.35, 0.2)
	rival_paint = Color(0.3, 0.62, 0.66)


func _setup_rival(r: RivalCar) -> void:
	var pts := [Vector3(LANE_X, 0, 9.0), Vector3(LANE_X, 0, GATE_S - 1.8), Vector3(LANE_X, 0, 27.0), Vector3(-0.8, 0, 31.5), SPOT]
	r.setup_path(pts, true)
	r.speed = 5.5
	r.hold = true
	r.hold_frac = (GATE_S - 1.8 - 9.0) / r.curve.get_baked_length() # 차단기 앞에서 기다린다
	r.slow_zones = [[0.9, 1.01, 0.4]]


func _walk_points(from: Vector3) -> Array[Vector3]:
	return [Vector3(from.x, 0.15, DOOR.z - 1.2), DOOR]


func _day_process(delta: float) -> void:
	_t += delta
	if phase != Phase.INTRO:
		_train_x += TRAIN_SPEED * delta
	for i in _train.size():
		var tail := _train_x - i * (CAR_LEN + CAR_GAP)
		_train[i].global_position = Vector3(tail - CAR_LEN * 0.5, 0, TRACK_Z)
	# 열차 꼬리가 건널목을 지나고 1초 뒤 차단기가 올라간다
	var tail_x := _train_x - CAR_COUNT * (CAR_LEN + CAR_GAP)
	var blocking := tail_x < 6.0 + TRAIN_SPEED * 1.0
	if rival:
		rival.hold = blocking
	_gate_angle = move_toward(_gate_angle, 0.0 if blocking else 1.0, delta * 0.8)
	for g in _gates:
		g.rotation.z = _gate_angle * PI * 0.5 * signf(g.position.x)
	var lit := fmod(_t, 0.8) < 0.4
	for k in _gate_lights.size():
		var on := blocking and ((k % 2 == 0) == lit)
		_gate_lights[k].material_override = _light_on if on else _light_off
	if blocking and not _bell.playing:
		_bell.play()
	elif not blocking and _bell.playing:
		_bell.stop()


func _build_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	_block(Vector3(-150, -1, -80), Vector3(150, 0, 200), _material("asphalt"))
	var white := _plain(Color(0.9, 0.9, 0.86), true)
	var yellow := _plain(Color(1.0, 0.82, 0.2), true)
	# 중앙선(건널목 앞뒤), 양쪽 인도
	_block(Vector3(-0.05, 0, -20), Vector3(0.05, 0.02, GATE_S - 0.5), yellow, false)
	_block(Vector3(-4.0, 0, -20), Vector3(-3.9, 0.02, GATE_S), white, false)
	_block(Vector3(3.9, 0, -20), Vector3(4.0, 0.02, GATE_S), white, false)
	_block(Vector3(-9.0, 0, -20), Vector3(-4.0, 0.15, GATE_S - 1.0), _material("sidewalk"))
	_block(Vector3(4.0, 0, -20), Vector3(9.0, 0.15, GATE_S - 1.0), _material("sidewalk"))
	_block(Vector3(-4.0, 0, GATE_S - 0.4), Vector3(4.0, 0.02, GATE_S - 0.25), white, false) # 정지선

	# 선로: 자갈(보이기만), 침목, 레일. 바닥은 평평해 차가 걸리지 않는다
	var ballast := _plain(Color(0.33, 0.31, 0.3))
	var sleeper := _plain(Color(0.26, 0.2, 0.15))
	var rail := _plain(Color(0.6, 0.62, 0.66))
	_block(Vector3(-150, 0, TRACK_Z - 2.2), Vector3(150, 0.01, TRACK_Z + 2.2), ballast, false)
	var x := -150.0
	while x < 150.0:
		_block(Vector3(x, 0.01, TRACK_Z - 1.4), Vector3(x + 0.3, 0.03, TRACK_Z + 1.4), sleeper, false)
		x += 0.9
	for rz: float in [TRACK_Z - 0.75, TRACK_Z + 0.75]:
		_block(Vector3(-150, 0.03, rz - 0.04), Vector3(150, 0.06, rz + 0.04), rail, false)

	# 차단기·경보등(보이기만 — 부딪히지 않는다)
	_light_on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_on.albedo_color = Color(1, 0.15, 0.1)
	_light_off.albedo_color = Color(0.25, 0.05, 0.05)
	for gz: float in [GATE_S, GATE_N]:
		var side := 1.0 if gz == GATE_S else -1.0 # 남쪽 차단기는 오른쪽(-X) 기둥, 북쪽은 왼쪽(+X) 기둥
		var post_x := -4.6 * side
		_block(Vector3(post_x - 0.12, 0, gz - 0.12), Vector3(post_x + 0.12, 3.0, gz + 0.12), _plain(Color(0.9, 0.9, 0.9)), false)
		for lx: float in [-0.25, 0.25]:
			var l := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.16
			sm.height = 0.32
			l.mesh = sm
			l.position = Vector3(post_x + lx, 2.6, gz - 0.2 * side)
			add_child(l)
			_gate_lights.append(l)
		var pivot := Node3D.new()
		pivot.position = Vector3(post_x, 1.05, gz)
		add_child(pivot)
		var arm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(8.2, 0.14, 0.14)
		arm.mesh = bm
		arm.position = Vector3(4.1 * side, 0, 0)
		var stripe := StandardMaterial3D.new()
		stripe.albedo_color = Color(0.95, 0.85, 0.2)
		arm.material_override = stripe
		pivot.add_child(arm)
		_gates.append(pivot)
	_sign("건널목", Vector3(-6.0, 3.6, GATE_S - 0.3), 180.0, 110, Color(1, 0.9, 0.3))
	_bell = AudioStreamPlayer.new()
	_bell.stream = _make_bell()
	_bell.volume_db = -14.0
	_bell.bus = &"World"
	add_child(_bell)

	# 열차: 기관차 + 2단 컨테이너 화차
	var box_cols := [Color(0.75, 0.2, 0.15), Color(0.15, 0.35, 0.6), Color(0.85, 0.55, 0.1), Color(0.2, 0.5, 0.3), Color(0.55, 0.55, 0.58)]
	for i in CAR_COUNT:
		var body := AnimatableBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(CAR_LEN, CAR_H, 3.0)
		shape.shape = box
		shape.position = Vector3(0, 0.4 + CAR_H * 0.5, 0)
		body.add_child(shape)
		var chassis := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(CAR_LEN, 0.6, 2.6)
		chassis.mesh = cm
		chassis.position = Vector3(0, 0.4, 0)
		chassis.material_override = _plain(Color(0.12, 0.12, 0.13))
		body.add_child(chassis)
		if i == 0:
			_mesh_on(body, Vector3(CAR_LEN, CAR_H - 0.6, 3.0), Vector3(0, 0.7 + (CAR_H - 0.6) * 0.5, 0), Color(0.9, 0.75, 0.15))
			_mesh_on(body, Vector3(0.1, 1.2, 2.4), Vector3(CAR_LEN * 0.5 + 0.02, CAR_H - 1.0, 0), Color(0.08, 0.1, 0.14))
		else:
			for level in 2:
				var col: Color = box_cols[rng.randi() % box_cols.size()]
				_mesh_on(body, Vector3(CAR_LEN - 0.3, (CAR_H - 0.4) * 0.5 - 0.05, 2.9), Vector3(0, 0.7 + (CAR_H - 0.4) * 0.25 + level * (CAR_H - 0.4) * 0.5, 0), col)
		body.position = Vector3(_train_x - i * (CAR_LEN + CAR_GAP) - CAR_LEN * 0.5, 0, TRACK_Z) # 원점에서 옮기며 내 차를 쓸지 않게
		add_child(body)
		_train.append(body)

	# 회사 주차장(건널목 바로 너머)과 본사
	_block(Vector3(-12, 0, 27.5), Vector3(12, 0.02, 47), _material("deck"), false)
	_parking_row_x(SPOT, 3, 3, true, rng)
	_block(Vector3(-14, 0, 50), Vector3(14, 22, 64), _material("office"))
	_block(Vector3(-1.0, 0, 49.94), Vector3(1.0, 2.0, 50.0), _plain(Color(0.08, 0.1, 0.14)), false)
	_sign("본사", Vector3(0, 2.8, 49.9), 180.0)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 31
	_skyline(rng2, 14.0, -30.0, 46.0)
	_skyline(rng2, -32.0, -30.0, 46.0)


func _mesh_on(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _plain(col)
	parent.add_child(mi)


## 건널목 경보음 "땡땡": 짧게 울리고 사라지는 종소리 두 번(되풀이)
func _make_bell() -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	for i in int(rate * 0.8):
		var t := fmod(float(i) / rate, 0.4)
		var v := (sin(TAU * 1250.0 * t) + 0.5 * sin(TAU * 2600.0 * t)) * exp(-t * 9.0) * 0.4
		var s := int(clampf(v, -1.0, 1.0) * 32767.0)
		data.append(s & 0xFF)
		data.append((s >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = data.size() >> 1
	return wav
