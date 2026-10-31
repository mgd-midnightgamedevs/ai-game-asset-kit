class_name RivalCar extends AnimatableBody3D
## 깜빡이를 켜고 마지막 칸으로 천천히, 주춤주춤 가는 앞차.
## 정해진 경로(점 목록 → Curve3D)를 따라 움직인다. 경사로·엘리베이터(수직 구간)도 된다.
## 플레이어 차가 길을 막거나 이미 칸 안에 있으면 멈추고 경적을 울린다.
## 경로 끝(칸 안)까지 다 가면 parked 신호(플레이어 실패).
## police면 경찰차: 경광등·사이렌, 플레이어에게 양보하지 않고 따라붙으면 caught 신호. 속도는 요일 스크립트가 정한다.
## 겉모습 두 벌: 상자 차와 Tripo 모델(model_name, 텍스처의 원래 칠을 model_paint 색으로 바꾼다). set_look()으로 바꾸고, 충돌 모양도 같이 바뀐다.

signal parked
signal caught

const LENGTH := 3.0
const WIDTH := 1.35
const CLEARANCE := 0.2
const BODY_H := 0.6
const CABIN_H := 0.4
const FONT := preload("res://fonts/Pretendard-Bold.otf")
const PAINT_SHADER := preload("res://shaders/car_paint.gdshader")
## 모델마다: 원래 칠 [색상, 평균 채도, 평균 밝기](텍스처에서 잰 값), 새 칠의 금속도(SUV 칠은 금속이라 그대로면 노랑이 칙칙하다),
## 충돌 상자 크기, 깜빡이 자리(차 앞 +Z, 왼쪽 앞 하나, 나머지는 대칭)
const MODELS := {
	"suv": {"src": Vector3(0.646, 0.686, 0.656), "metallic": 0.05, "box": Vector3(1.5, 1.5, 3.1), "blinker": Vector3(0.58, 0.85, 1.52)},
}

var player: Roadster
var speed := 2.0 ## m/s
var slow_zones: Array = [] ## [시작 비율, 끝 비율, 속도 배율] — 주춤거림, 엘리베이터 등
var progress := 0.0 ## 0~1
var started := false
var finished := false
var blocked := false
var honk_forever := false
var paint := Color(0.86, 0.7, 0.32)
var hold := false ## true인 동안 hold_frac(경로 비율) 앞에서 기다린다(건널목 차단기 등)
var hold_frac := -1.0
var police := false
var catch_distance := 2.6
var model_name := "" ## 비우면 상자 차만
var model_paint := Color.from_hsv(0.065, 0.85, 0.95) ## 모델 칠(귤색). 노랑은 남색 원본과 섞인 테두리가 녹색으로 떠서 바꿨다(10/23). 상자 차는 paint
var show_model := false

var curve := Curve3D.new()
var _offset := 0.0
var _length := 1.0
var _heading := Vector3.BACK
var _spot_center := Vector3.ZERO
var _spot_depth := Vector3.LEFT
var _spot_half := Vector2(1.2, 1.8) ## 폭, 깊이
var _has_spot := false
var _blink_t := 0.0
var _blinkers: Array[MeshInstance3D] = []
var _blink_on := StandardMaterial3D.new()
var _blink_off := StandardMaterial3D.new()
var _honk_label: Label3D
var _honk: AudioStreamPlayer3D
var _honk_cool := 0.0
var _siren_lights: Array[MeshInstance3D] = []
var _siren_mats: Array[StandardMaterial3D] = []
var _siren: AudioStreamPlayer3D
var _caught_sent := false
var _box_look: Node3D
var _model_look: Node3D
var _box_shape: CollisionShape3D
var _model_shape: CollisionShape3D


## 점 목록을 따라가는 경로. smooth면 모서리를 부드럽게 돈다(엘리베이터처럼 꺾이는 곳은 false).
func setup_path(points: Array, smooth := true) -> void:
	curve.clear_points()
	var n := points.size()
	for i in n:
		var p: Vector3 = points[i]
		var h := Vector3.ZERO
		if smooth and i > 0 and i < n - 1:
			h = ((points[i + 1] as Vector3) - (points[i - 1] as Vector3)) * 0.22
		curve.add_point(p, -h, h)
	curve.bake_interval = 0.05
	_length = maxf(curve.get_baked_length(), 0.01)
	_offset = 0.0
	progress = 0.0
	var first: Vector3 = points[1] - points[0]
	first.y = 0.0
	_heading = first.normalized() if first.length() > 0.01 else Vector3.BACK
	global_transform = _xf(0.0, true)


## 2차 베지어(시작 a, 조절점 c, 끝 e)를 점 목록으로 바꿔 쓴다.
func setup_bezier(a: Vector3, c: Vector3, e: Vector3, samples := 14) -> void:
	var pts: Array = []
	for i in samples + 1:
		var t := float(i) / samples
		var u := 1.0 - t
		pts.append(a * u * u + c * 2.0 * u * t + e * t * t)
	setup_path(pts, true)


## 목표 칸: 플레이어가 이 안에 있으면 양보한다.
func set_spot(center: Vector3, depth_dir: Vector3, half_width: float, half_depth: float) -> void:
	_spot_center = center
	_spot_depth = depth_dir.normalized()
	_spot_half = Vector2(half_width, half_depth)
	_has_spot = true


func go() -> void:
	started = true


func _ready() -> void:
	collision_layer = 1
	_box_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, BODY_H + CABIN_H, LENGTH)
	_box_shape.shape = box
	_box_shape.position = Vector3(0, CLEARANCE + (BODY_H + CABIN_H) * 0.5, 0)
	add_child(_box_shape)
	_box_look = Node3D.new()
	add_child(_box_look)

	var glass := _mat(Color(0.08, 0.1, 0.14))
	_box(Vector3(WIDTH, BODY_H, LENGTH), Vector3(0, CLEARANCE + BODY_H * 0.5, 0), _mat(paint))
	_box(Vector3(WIDTH - 0.16, CABIN_H, LENGTH * 0.5), Vector3(0, CLEARANCE + BODY_H + CABIN_H * 0.5, -0.15), glass)
	_box(Vector3(WIDTH - 0.2, CLEARANCE, LENGTH - 0.6), Vector3(0, CLEARANCE * 0.5, 0), glass)
	# 운전자 머리(창 너머로 보이게)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.14
	sph.height = 0.28
	head.mesh = sph
	head.material_override = _mat(Color(0.95, 0.78, 0.62))
	head.position = Vector3(0.3, CLEARANCE + BODY_H + 0.22, 0.05)
	_box_look.add_child(head)

	# 깜빡이(차 양쪽 앞뒤 — 비상등처럼 다 깜빡여 어느 쪽으로 돌든 보이게)
	_blink_on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blink_on.albedo_color = Color(1.0, 0.6, 0.05)
	_blink_off.albedo_color = Color(0.35, 0.22, 0.08)
	if not police:
		for sx: float in [-1.0, 1.0]:
			for z: float in [LENGTH * 0.5 - 0.05, -LENGTH * 0.5 + 0.05]:
				_blinkers.append(_box(Vector3(0.26, 0.13, 0.1), Vector3(sx * (WIDTH * 0.5 - 0.16), CLEARANCE + BODY_H - 0.1, z), _blink_off))
	else:
		# 경찰차: 옆구리 검은 띠, 지붕 경광등(빨강·파랑 번갈아)
		_box(Vector3(WIDTH + 0.02, 0.22, LENGTH * 0.62), Vector3(0, CLEARANCE + 0.2, 0.05), _mat(Color(0.06, 0.07, 0.1)))
		for i in 2:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_siren_mats.append(m)
			_siren_lights.append(_box(Vector3(0.4, 0.14, 0.26), Vector3((i - 0.5) * 0.44, CLEARANCE + BODY_H + CABIN_H + 0.07, -0.15), m))

	if model_name != "":
		_build_model()
	set_look(show_model)

	_honk_label = Label3D.new()
	_honk_label.font = FONT
	_honk_label.font_size = 80
	_honk_label.pixel_size = 0.0022
	_honk_label.fixed_size = true
	_honk_label.outline_size = 18
	_honk_label.modulate = Color(1, 0.9, 0.2)
	_honk_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_honk_label.no_depth_test = true
	_honk_label.text = "삐뽀삐뽀!" if police else "빵빵!"
	_honk_label.position = Vector3(0, 0.7, LENGTH * 0.5 + 0.6) # 차 앞머리 아래쪽(운전자 말풍선은 더 위에 뜬다)
	_honk_label.visible = false
	add_child(_honk_label)

	_honk = AudioStreamPlayer3D.new()
	_honk.stream = _make_honk()
	_honk.unit_size = 12.0
	_honk.volume_db = -7.0 # 분사·모터와 맞춘다(10/23)
	_honk.bus = &"World"
	add_child(_honk)
	if police:
		_siren = AudioStreamPlayer3D.new()
		_siren.stream = _make_siren()
		_siren.unit_size = 14.0
		_siren.volume_db = -6.0
		_siren.bus = &"World"
		add_child(_siren)


## Tripo 모델: 원래 칠을 model_paint 색으로 바꾸고(명암·광택은 텍스처 그대로) 깜빡이 넷을 붙인다.
func _build_model() -> void:
	var cfg: Dictionary = MODELS[model_name]
	_model_look = AssetCache.model(model_name).instantiate()
	add_child(_model_look)
	for mi: MeshInstance3D in _model_look.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			var sm := ShaderMaterial.new()
			sm.shader = PAINT_SHADER
			sm.set_shader_parameter("albedo_tex", m.albedo_texture)
			sm.set_shader_parameter("orm_tex", m.roughness_texture)
			sm.set_shader_parameter("normal_tex", m.normal_texture)
			sm.set_shader_parameter("normal_scale", m.normal_scale)
			var src: Vector3 = cfg.src
			sm.set_shader_parameter("src_hue", src.x)
			sm.set_shader_parameter("paint_ref_s", src.y)
			sm.set_shader_parameter("paint_ref_v", src.z)
			sm.set_shader_parameter("paint_on", true)
			sm.set_shader_parameter("mask_wide", true)
			sm.set_shader_parameter("paint_metallic", cfg.metallic)
			sm.set_shader_parameter("paint_hsv", Vector3(model_paint.h, model_paint.s, model_paint.v))
			mi.set_surface_override_material(i, sm)
	var b: Vector3 = cfg.blinker
	for sx: float in [-1.0, 1.0]:
		for sz: float in [1.0, -1.0]:
			var bl := _box(Vector3(0.2, 0.11, 0.12), Vector3(sx * b.x, b.y, sz * b.z), _blink_off)
			bl.reparent(_model_look, false)
			_blinkers.append(bl)
	_model_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = cfg.box
	_model_shape.shape = box
	_model_shape.position = Vector3(0, CLEARANCE * 0.5 + box.size.y * 0.5, 0)
	add_child(_model_shape)


## true면 Tripo 모델, false면 상자 차. 모델이 없으면 늘 상자 차.
func set_look(model: bool) -> void:
	show_model = model and _model_look != null
	_box_look.visible = not show_model
	_box_shape.disabled = show_model
	if _model_look:
		_model_look.visible = show_model
		_model_shape.disabled = not show_model


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	_box_look.add_child(mi)
	return mi


func _pos(off: float) -> Vector3:
	return curve.sample_baked(clampf(off, 0.0, _length), true)


## 경로 위치와 방향. 수직 구간(엘리베이터)에서는 마지막 수평 방향을 유지하고 기울이지 않는다.
func _xf(off: float, snap := false, delta := 0.0) -> Transform3D:
	var p := _pos(off)
	var d := _pos(off + 0.3) - p
	if off + 0.3 > _length:
		d = p - _pos(off - 0.3)
	var flat := Vector3(d.x, 0.0, d.z)
	if flat.length() > 0.02:
		var target := flat.normalized()
		_heading = target if snap else _heading.slerp(target, clampf(delta * 6.0, 0.0, 1.0)).normalized()
	var fwd := _heading
	if flat.length() > 0.02 and absf(d.normalized().y) < 0.6:
		fwd = (_heading * flat.length() + Vector3.UP * d.y).normalized() # 경사로에서는 앞머리를 든다
	return Transform3D(Basis.looking_at(-fwd, Vector3.UP), p)


func _speed_factor(frac: float) -> float:
	for z in slow_zones:
		if frac >= z[0] and frac < z[1]:
			return z[2]
	return 1.0


func _player_blocks(next_pos: Vector3) -> bool:
	if player == null:
		return false
	var pp := player.get_vehicle_position()
	if pp.y > next_pos.y + 1.3:
		return false # 머리 위로 날아가는 중
	if absf(pp.y - next_pos.y) > 3.0:
		return false # 다른 층
	# 플레이어가 이미 그 칸 안에 들어와 있으면, 칸 가까이(5.5m)까지 와서 멈추고 경적을 울린다
	if _has_spot and absf(pp.y - _spot_center.y) < 1.5 and next_pos.distance_to(_spot_center) < 5.5:
		var to_spot := pp - _spot_center
		var side := Vector3.UP.cross(_spot_depth)
		if absf(to_spot.dot(_spot_depth)) < _spot_half.y + 0.2 and absf(to_spot.dot(side)) < _spot_half.x + 0.1:
			return true
	return Vector2(pp.x - next_pos.x, pp.z - next_pos.z).length() < 2.2


func _physics_process(delta: float) -> void:
	_blink_t += delta
	var lit := fmod(_blink_t, 0.7) < 0.35
	for b in _blinkers:
		b.material_override = _blink_on if lit else _blink_off
	if police:
		var red := fmod(_blink_t, 0.36) < 0.18
		_siren_mats[0].albedo_color = Color(1, 0.12, 0.12) if red else Color(0.3, 0.05, 0.05)
		_siren_mats[1].albedo_color = Color(0.15, 0.35, 1) if not red else Color(0.05, 0.08, 0.3)
		if started and not _siren.playing:
			_siren.play()
		_honk_label.visible = started and fmod(_blink_t, 0.6) < 0.4
		_check_caught()

	if honk_forever:
		_honk_tick(delta)
		return
	if not started or finished:
		return
	var next := minf(_offset + speed * _speed_factor(progress) * delta, _length)
	if hold and hold_frac >= 0.0 and _offset <= hold_frac * _length + 0.01:
		next = minf(next, hold_frac * _length)
	if not police and _player_blocks(_pos(next)):
		blocked = true
		_honk_tick(delta)
		return
	blocked = false
	if not police:
		_honk_label.visible = false
	_offset = next
	progress = _offset / _length
	global_transform = _xf(_offset, false, delta)
	if _offset >= _length:
		finished = true
		parked.emit()


## 경찰차: 플레이어가 같은 높이에서 바로 옆까지 오면 잡았다
func _check_caught() -> void:
	if _caught_sent or not started or player == null:
		return
	var pp := player.get_vehicle_position()
	if absf(pp.y - global_position.y) < 1.6 and Vector2(pp.x - global_position.x, pp.z - global_position.z).length() < catch_distance:
		_caught_sent = true
		caught.emit()


## 사이렌: 두 음을 번갈아 내는 부드러운 사각파(되풀이)
func _make_siren() -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	for f: float in [660.0, 880.0]:
		for i in int(rate * 0.45):
			var t := float(i) / rate
			var v := signf(sin(TAU * f * t)) * 0.16 + sin(TAU * f * t) * 0.1
			var env := minf(1.0, minf(t / 0.02, (0.45 - t) / 0.02))
			var s := int(clampf(v * env, -1.0, 1.0) * 32767.0)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = data.size() >> 1
	return wav


func _honk_tick(delta: float) -> void:
	_honk_cool -= delta
	_honk_label.visible = fmod(_blink_t, 0.5) < 0.32
	if police:
		return # 경찰차는 사이렌이 계속 울린다
	if _honk_cool <= 0.0:
		_honk_cool = 1.3
		_honk.play()


## 빵빵: 두 음을 섞은 짧은 사각파 두 번(소리 파일 없이 코드로 만든다)
func _make_honk() -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	for _beep in 2:
		for i in int(rate * 0.17):
			var t := float(i) / rate
			var v := (signf(sin(TAU * 415.0 * t)) + signf(sin(TAU * 523.0 * t))) * 0.22
			var env := minf(1.0, minf(t / 0.01, (0.17 - t) / 0.02))
			var s := int(clampf(v * env, -1.0, 1.0) * 32767.0)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
		for i in int(rate * 0.07):
			data.append(0)
			data.append(0)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
