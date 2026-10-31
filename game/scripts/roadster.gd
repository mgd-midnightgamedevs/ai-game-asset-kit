class_name Roadster extends RigidBody3D
## 로켓 로드스터.
##
## 겉모습 두 가지(M 키로 바꾼다, 물리 규칙은 같다):
## - "roadster": Tripo로 만든 로드스터 모델(assets/models/roadster). 기본. 2.5m 모델을 1.1배(2.75m)로 키워
##   세워 둔 3m 차 옆에서 너무 작아 보이지 않게 했다. 바퀴 넷이 따로 구르고 앞바퀴가 꺾인다.
## - "box": 처음 만든 상자 차(0.96 x 1.8m).
##
## 로드스터 차체는 Tripo 부품 나누기 결과(서피스 21개)다. 세게 박으면 부딪힌 쪽 범퍼·사이드미러가 떨어져 튕겨 나가고
## (respawn_at이나 장면을 다시 불러오면 제자리), P 키로 배색을 바꾼다(PALETTES).
##
## 주행: 레이캐스트 서스펜션 차량. 차체는 상자 모양 강체이고, 바퀴 4개 자리에서 차체 아래로 쏜 광선이
## 스프링·댐퍼 힘(차를 띄운다)과 타이어 힘(옆 미끄러짐을 잡는 접지, 가속·제동)을 만든다.
## 그래서 차가 실제로 기울고, 착지할 때 출렁이고, 지붕으로 떨어지면 지붕으로 떨어진다.
## (2026-10-19까지 쓰던 Kenney Starter Kit Racing의 구체 차는 물리로는 공이라 미끄럽고 뒤집히지 않았다.)
##
## 능력은 2026년 공개된 로켓 로드스터 시연의 구성을 따른다(로켓리그식 불꽃 부스트가 아니다).
## - 냉가스 추진기 10개: 압축 공기를 흰 분사로 내뿜는다. 아래 4(리프트), 뒤 2(메인), 옆 4(자세 제어).
## - 공기 탱크: 추진기가 쓴다. 땅에서는 압축기로 천천히 차고, 패드에 주차하면 가득 찬다.
## - 흡착 팬: 차 바닥 팬이 최대 2G로 빨아들여 곡면 램프를 따라 거꾸로까지 달린다.
##   곡면만 따라가고, 각진 모서리에서는 떨어져 나간다(그 순간 추진기로 자세를 잡는다).

signal attached_changed(is_attached: bool)
signal landed(upright: bool, air_time: float, spin_deg: float)
## kind: "crash"(차체가 무언가에 세게 박음) 또는 "flip"(지붕·옆으로 떨어지거나 넘어감)
signal crashed(kind: String, impact: float)
signal style_changed(style: String)
signal part_lost(part: String)

const GRAVITY := 9.8 * 1.5 ## 예전 Kenney 차의 gravity_scale 1.5를 그대로 둔다(코스 높이·점프가 그 기준)
const WORLD_MASK := 1

## 겉모습마다 다른 값. 위치는 모두 Container 기준(차의 앞 +Z, 왼쪽 +X, 바퀴가 쉬는 땅은 y 0.15).
## mount_y = 땅 0.15 + 바퀴 반지름 + 차 무게로 눌린 스프링 길이(0.189)
## footprint: 주차 칸 판정용 차체 [반폭, 반길이, 가운데 z]
## steer_low/high: 바퀴 사이가 길수록 더 꺾어 두 차의 회전 반지름을 같게 한다(tan(조향) x 앞뒤 바퀴 거리 일정)
const STYLES := {
	"box": {
		"model": "Model", "shapes": ["Chassis", "Cabin"],
		"wheel_x": 0.5, "wheel_z": 0.6, "wheel_radius": 0.19, "mount_y": 0.53, "steer_low": 0.6, "steer_high": 0.2,
		"footprint": Vector3(0.48, 0.9, 0.0), "fan_scale": 1.0,
		"thrusters": {
			"LiftFL": Vector3(0.38, 0.27, 0.62), "LiftFR": Vector3(-0.38, 0.27, 0.62),
			"LiftRL": Vector3(0.38, 0.27, -0.62), "LiftRR": Vector3(-0.38, 0.27, -0.62),
			"MainL": Vector3(0.22, 0.45, -0.98), "MainR": Vector3(-0.22, 0.45, -0.98),
			"SideFL": Vector3(0.5, 0.45, 0.72), "SideFR": Vector3(-0.5, 0.45, 0.72),
			"SideRL": Vector3(0.5, 0.45, -0.72), "SideRR": Vector3(-0.5, 0.45, -0.72),
		},
	},
	# 모델(1.1배)을 z +0.053 옮겨 앞뒤 바퀴 가운데를 차 원점에 맞췄다. 차체 -1.32~+1.43, 폭 ±0.73, 지붕(창틀) 0.96
	"roadster": {
		"model": "RoadsterModel", "shapes": ["RoadsterBody"],
		"wheel_x": 0.584, "wheel_z": 0.798, "wheel_radius": 0.243, "mount_y": 0.582, "steer_low": 0.74, "steer_high": 0.264,
		"footprint": Vector3(0.73, 1.375, 0.053), "fan_scale": 1.3,
		"thrusters": {
			"LiftFL": Vector3(0.36, 0.19, 0.8), "LiftFR": Vector3(-0.36, 0.19, 0.8),
			"LiftRL": Vector3(0.36, 0.19, -0.8), "LiftRR": Vector3(-0.36, 0.19, -0.8),
			"MainL": Vector3(0.25, 0.45, -1.36), "MainR": Vector3(-0.25, 0.45, -1.36),
			"SideFL": Vector3(0.72, 0.53, 1.1), "SideFR": Vector3(-0.72, 0.53, 1.1),
			"SideRL": Vector3(0.72, 0.53, -1.12), "SideRR": Vector3(-0.72, 0.53, -1.12),
		},
	},
}
## 고른 겉모습. 장면을 다시 불러와도(DAY 다음 날, 재시작) 남는다. 실행 인자 "car=box"로도 고른다.
static var current_style := "roadster"

## 로드스터 body 메시의 서피스 번호(부품 나누기 결과를 렌더로 확인). 미러는 차의 왼쪽이 +X
const DETACHABLE := {"bumper_front": 6, "bumper_rear": 2, "mirror_left": 8, "mirror_right": 7}
## 다른 색으로 칠할 수 있는 부품(옆 치마 0, 범퍼, 미러)과 그 부품 텍스처의 평균 밝기(sRGB, 명암 비율 기준)
const TRIM_LUMA := {0: 0.111, 2: 0.100, 6: 0.121, 7: 0.096, 8: 0.095}
const PAINT_SHADER := preload("res://shaders/car_paint.gdshader")
const BOX_PAINT := Color(0.93, 0.2, 0.16) ## 상자 차 원래 색
## [이름, 차체 칠(null = 원래 빨강), 범퍼·미러·옆 치마 칠(null = 원래 검정)]
const PALETTES := [
	["원래 빨강", null, null],
	["파랑", Color(0.12, 0.35, 0.95), null],
	["흰색 · 주황 범퍼", Color(0.95, 0.95, 0.93), Color(1.0, 0.42, 0.05)],
	["노랑 · 검정", Color(1.0, 0.86, 0.15), null],
	["검정 · 빨강 범퍼", Color(0.17, 0.17, 0.19), Color(0.85, 0.08, 0.08)],
	["초록 · 금색 범퍼", Color(0.08, 0.42, 0.22), Color(0.62, 0.45, 0.14)],
	["은색 · 파랑 범퍼", Color(0.72, 0.74, 0.78), Color(0.12, 0.35, 1.0)],
]
static var palette_index := 0
static var _split_cache := {} ## body 메시를 부품별로 나눈 결과(장면을 다시 불러와도 다시 나누지 않는다)

@export_group("Drive")
@export var top_speed := 11.0 ## m/s
@export var reverse_speed := 4.5
@export var accel := 10.0 ## m/s², 출발 가속 상한
@export var accel_gain := 3.0 ## 목표 속도와의 차이에 곱한다(목표에 가까울수록 부드럽게)
@export var brake := 13.0 ## m/s²
@export var coast_gain := 1.2 ## 손을 떼면 속도 x 이만큼 줄어든다(초당)
@export var coast_max := 5.0
@export var steer_low := 0.6 ## rad, 저속 최대 조향
@export var steer_high := 0.2 ## rad, 최고 속도에서 최대 조향
@export var steer_rate := 6.0 ## rad/s
@export var grip := 1.6 ## 타이어 마찰 계수(바퀴가 받는 힘 x 이만큼까지 옆·앞뒤로 잡는다)
@export var lateral_tau := 0.06 ## 초. 옆 미끄러짐을 이 시간 안에 없애려 한다

@export_group("Suspension")
@export var wheel_x := 0.5
@export var wheel_z := 0.6
@export var mount_y := 0.53 ## 차체 기준 스프링 윗점
@export var rest_length := 0.25
@export var wheel_radius := 0.19
@export var spring := 60000.0 ## N/m, 바퀴 하나
@export var damper := 4000.0
@export var rebound := 1.5 ## 늘어날 때 댐퍼 배수
@export var landing_absorb := 0.3 ## 초. 크게 떨어진 뒤 이 시간 동안 위로 튀는 속도를 없앤다(트램펄린처럼 튀지 않게)
@export var bump_start := 0.14 ## 이만큼 눌리면 범프 스톱이 같이 받친다

@export_group("Air tank")
@export var air_max := 100.0
@export var lift_burn := 22.0 ## 초당. 아래 노즐 4개
@export var main_burn := 14.0 ## 뒤 노즐 2개
@export var attitude_burn := 4.0 ## 공중에서 자세를 직접 돌릴 때
@export var lift_kick_air := 5.0
@export var ground_recharge := 6.0 ## 땅(바닥)에서 압축기 재충전, 초당

@export_group("Thrusters")
@export var lift_accel := 27.0 ## m/s², 차체 위쪽. 중력은 14.7
@export var lift_kick := 4.0 ## m/s, 땅에서 리프트를 켜는 순간 튀어 오르는 속도
@export var main_accel := 16.0 ## m/s², 차체 앞쪽
@export var air_pitch_speed := 2.6 ## rad/s
@export var air_yaw_speed := 4.8 ## 킥플립(수평 회전)이 한 번 점프에 한 바퀴 돌 만큼
@export var air_level_rate := 3.0 ## 손을 떼면 추진기가 차를 바로 세우는 최대 속도(rad/s)
@export var attitude_response := 8.0 ## 자세 추진기가 목표 회전 속도를 따라가는 빠르기(1/s)
@export var roll_speed := 7.5 ## F: 공중에서 옆으로 한 바퀴(앞뒤 축 회전)의 최대 속도(rad/s). 웹 프로토타입은 6
@export var roll_response := 16.0 ## 옆 회전은 리프트 노즐 한쪽을 세게 써서 빨리 붙는다(1/s)

@export_group("Fan suction")
@export var fan_gravity := 19.6 ## m/s², 붙은 면 쪽으로. 2G
@export var fan_seek_distance := 2.5 ## 공중에서 팬을 켜면 이 거리 안의 면에 붙는다
@export var fan_align_rate := 4.0 ## 붙은 면에 차체를 맞추는 보조(1/s)

@export_group("Crash")
@export var crash_speed := 6.0 ## 바퀴가 아닌 곳으로 이 속도(m/s) 넘게 부딪히면 "crash"
@export var auto_recover := true ## 스턴트 코스: 넘어지면 recover_time 뒤 노즐이 차를 바로 세운다. DAY는 끈다(넘어지면 실패)
@export var recover_time := 1.2

var air := 100.0
var up_dir := Vector3.UP ## 지금 '바닥'으로 삼는 면의 법선(흡착 중에만 바뀐다)
var normal := Vector3.UP ## 바퀴가 닿은 면의 평균 법선
var attached := false
var lift_firing := false
var main_firing := false
var fan_on := false
var on_wall := false
var controls_enabled := true
var steer := 0.0 ## 앞바퀴 조향각(rad, + = 왼쪽)
var throttle := 0.0 ## -1..1
var linear_speed := 0.0 ## 앞 방향 속도 / top_speed (예전 Kenney 차와 같은 의미)

var vehicle_model: Node3D ## 차체 방향·위치(예전 코드와 같은 이름). 강체와 같은 변환
var style := ""
var footprint := Vector3(0.48, 0.9, 0.0) ## 주차 칸 판정용 차체 [반폭, 반길이, 가운데 z]

var _grounded := 0 ## 땅에 닿은 바퀴 수
var _pitch_cmd := 0.0
var _yaw_cmd := 0.0
var _leveling := 0.0
var _air_time := 0.0
var _cloud: GroundCloud
var _lift_stretch := 0.0
var _air_spin := 0.0
var _air_roll := 0.0 ## 이번 점프에서 앞뒤 축으로 돈 각도(rad)
var _roll_left := 0.0 ## F로 시작한 옆 회전에서 남은 각도(rad, +는 오른쪽으로: 왼쪽 옆구리가 올라간다)
var _roll_was_pressed := false
var last_air_roll := 0.0 ## 마지막 착지 전 점프에서 옆으로 돈 각도(도)
var _lift_was_firing := false
var _kick_pending := false
var _coyote := 0.0
var _flip_time := 0.0
var _flip_reported := false
var _slip := 0.0
var _impact := 0.0
var _reset_xform = null
var _crash_cool := 0.0
var _absorb := 0.0
var debug_contacts := false

## 바퀴: [노드 이름, 차체 기준 x 부호, z 부호, 앞바퀴?]. 차의 앞은 +Z, 왼쪽은 +X
const WHEELS := [
	["wheel-front-left", 1.0, 1.0, true],
	["wheel-front-right", -1.0, 1.0, true],
	["wheel-back-left", 1.0, -1.0, false],
	["wheel-back-right", -1.0, -1.0, false],
]
var _wheels: Array[Dictionary] = []

## [노드 이름, 분사 방향]. 자리는 STYLES의 "thrusters"
const THRUSTER_LAYOUT := [
	["LiftFL", Vector3.DOWN], ["LiftFR", Vector3.DOWN], ["LiftRL", Vector3.DOWN], ["LiftRR", Vector3.DOWN],
	["MainL", Vector3.FORWARD], ["MainR", Vector3.FORWARD],
	["SideFL", Vector3.RIGHT], ["SideFR", Vector3.LEFT], ["SideRL", Vector3.RIGHT], ["SideRR", Vector3.LEFT],
]
var thrusters := {}
var _paint_mats: Array[ShaderMaterial] = [] ## 로드스터 서피스마다 하나(번호 = body 서피스 번호)
var _parts := {} ## 떨어질 수 있는 부품 이름 → MeshInstance3D
var _debris: Array[Node3D] = []

@onready var fan_glow: Node3D = $Container/FanGlow
@onready var screech_sound: AudioStreamPlayer3D = $Container/ScreechSound
@onready var engine_sound: AudioStreamPlayer3D = $Container/EngineSound
@onready var impact_sound: AudioStreamPlayer3D = $Container/ImpactSound


func _ready() -> void:
	vehicle_model = $Container
	air = air_max
	for w in WHEELS:
		_wheels.append({
			"node": null, "to_model": Transform3D.IDENTITY,
			"mount": Vector3.ZERO, "front": w[3],
			"hit": false, "point": Vector3.ZERO, "normal": Vector3.UP,
			"len": rest_length, "load": 0.0, "spin": 0.0,
		})
	for t in THRUSTER_LAYOUT:
		var th := Thruster.new()
		th.name = t[0]
		th.basis = Thruster.basis_for_exhaust(t[1])
		vehicle_model.add_child(th)
		thrusters[t[0]] = th
	if "car=box" in OS.get_cmdline_user_args():
		current_style = "box"
	_split_body()
	apply_style(current_style)
	apply_palette(palette_index)
	_cloud = GroundCloud.new()
	add_child(_cloud)
	_setup_sounds()


## 겉모습을 바꾼다: 보이는 모델, 충돌 모양, 바퀴 자리·반지름, 노즐 자리, 팬 표시 크기.
func apply_style(s: String) -> void:
	var cfg: Dictionary = STYLES[s]
	style = s
	current_style = s
	for k in STYLES:
		var other: Dictionary = STYLES[k]
		(vehicle_model.get_node(other.model) as Node3D).visible = k == s
		for shape_name: String in other.shapes:
			(get_node(shape_name) as CollisionShape3D).disabled = k != s
	wheel_x = cfg.wheel_x
	wheel_z = cfg.wheel_z
	wheel_radius = cfg.wheel_radius
	mount_y = cfg.mount_y
	steer_low = cfg.steer_low
	steer_high = cfg.steer_high
	footprint = cfg.footprint
	var model: Node3D = vehicle_model.get_node(cfg.model)
	for i in WHEELS.size():
		var w: Dictionary = _wheels[i]
		var node := model.find_child(WHEELS[i][0], true, false) as Node3D
		w.node = node
		w.mount = Vector3(WHEELS[i][1] * wheel_x, mount_y, WHEELS[i][2] * wheel_z)
		# 바퀴 노드의 부모 좌표 → Container 좌표(로드스터 모델은 1.1배·위치가 옮겨져 있다)
		var xf := Transform3D.IDENTITY
		var n := node.get_parent()
		while n != vehicle_model:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		w.to_model = xf.affine_inverse()
	for t in THRUSTER_LAYOUT:
		thrusters[t[0]].position = cfg.thrusters[t[0]]
	fan_glow.scale = Vector3.ONE * cfg.fan_scale
	style_changed.emit(s)


func toggle_style() -> void:
	apply_style("box" if style == "roadster" else "roadster")


# --- 부품·배색 -----------------------------------------------------------------

## 로드스터 body(서피스 21개)에서 범퍼·미러를 따로 떼어 낼 수 있는 MeshInstance3D로 나누고, 모든 서피스에 칠 셰이더를 씌운다.
func _split_body() -> void:
	var body := vehicle_model.get_node_or_null("RoadsterModel/roadster/body") as MeshInstance3D
	if body == null:
		return
	var src: Mesh = body.mesh
	var key := src.resource_path if src.resource_path != "" else str(src.get_instance_id())
	if not _split_cache.has(key):
		var rest := ArrayMesh.new()
		var rest_index: Array[int] = [] # rest의 서피스 → 원래 서피스 번호
		var pieces := {}
		for i in src.get_surface_count():
			var target := ArrayMesh.new() if i in DETACHABLE.values() else rest
			target.add_surface_from_arrays(src.surface_get_primitive_type(i), src.surface_get_arrays(i))
			if target == rest:
				rest_index.append(i)
			else:
				pieces[i] = target
		_split_cache[key] = {"rest": rest, "rest_index": rest_index, "pieces": pieces}
	var split: Dictionary = _split_cache[key]
	for i in src.get_surface_count():
		var m := src.surface_get_material(i) as StandardMaterial3D
		var sm := ShaderMaterial.new()
		sm.shader = PAINT_SHADER
		sm.set_shader_parameter("albedo_tex", m.albedo_texture)
		sm.set_shader_parameter("orm_tex", m.roughness_texture)
		sm.set_shader_parameter("normal_tex", m.normal_texture)
		sm.set_shader_parameter("normal_scale", m.normal_scale)
		sm.set_shader_parameter("trim_luma", TRIM_LUMA.get(i, 0.1))
		_paint_mats.append(sm)
	body.mesh = split.rest
	var rest_index: Array[int] = split.rest_index
	for k in rest_index.size():
		body.set_surface_override_material(k, _paint_mats[rest_index[k]])
	for part: String in DETACHABLE:
		var i: int = DETACHABLE[part]
		var mi := MeshInstance3D.new()
		mi.name = part
		mi.mesh = split.pieces[i]
		mi.material_override = _paint_mats[i]
		body.get_parent().add_child(mi)
		mi.transform = body.transform
		_parts[part] = mi


## 배색을 바꾼다. 로드스터는 빨간 칠만 새 색(명암·광택은 텍스처 그대로), 트림 색이 있으면 범퍼·미러·옆 치마 전체를 칠한다.
func apply_palette(i: int) -> void:
	palette_index = posmod(i, PALETTES.size())
	var pal: Array = PALETTES[palette_index]
	for si in _paint_mats.size():
		var sm := _paint_mats[si]
		sm.set_shader_parameter("paint_on", pal[1] != null)
		if pal[1] != null:
			var c: Color = pal[1]
			sm.set_shader_parameter("paint_hsv", Vector3(c.h, c.s, c.v))
		sm.set_shader_parameter("trim_on", pal[2] != null and TRIM_LUMA.has(si))
		if pal[2] != null:
			var t: Color = pal[2]
			sm.set_shader_parameter("trim_color", Vector3(t.r, t.g, t.b))
	var box_mat := (vehicle_model.get_node("Model/body/Chassis") as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
	box_mat.albedo_color = pal[1] if pal[1] != null else BOX_PAINT


func next_palette() -> String:
	apply_palette(palette_index + 1)
	return PALETTES[palette_index][0]


func is_part_attached(part: String) -> bool:
	return _parts.has(part) and (_parts[part] as Node3D).visible


## 부딪힌 쪽 부품을 떼어 튕겨 보낸다. away: 부딪힌 물체에서 멀어지는 방향(차가 받은 충격 방향)
func _break_off(part: String, away: Vector3) -> void:
	if style != "roadster" or not is_part_attached(part):
		return
	var mi: MeshInstance3D = _parts[part]
	mi.visible = false
	var xf := mi.global_transform
	var aabb := mi.get_aabb()
	var rb := RigidBody3D.new()
	rb.name = "Debris_" + part
	rb.collision_layer = 16 # 세상(1)과만 부딪힌다. 차 몸체·바퀴 광선은 무시한다
	rb.collision_mask = WORLD_MASK
	rb.mass = 6.0
	rb.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.7
	rb.physics_material_override = pm
	var piece := MeshInstance3D.new()
	piece.mesh = mi.mesh
	piece.material_override = mi.material_override
	rb.add_child(piece)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (aabb.size * xf.basis.get_scale()).max(Vector3.ONE * 0.06)
	cs.shape = box
	rb.add_child(cs)
	get_parent().add_child(rb)
	rb.global_transform = Transform3D(xf.basis.orthonormalized(), xf * aabb.get_center())
	piece.global_transform = xf
	var scatter := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 1.2
	rb.linear_velocity = linear_velocity * 0.4 + away.normalized() * 3.5 + Vector3.UP * 3.5 + scatter
	rb.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 9.0
	_debris.append(rb)
	part_lost.emit(part)


## 떨어진 부품을 제자리에 붙이고 튕겨 나간 조각을 치운다.
func reset_parts() -> void:
	for d in _debris:
		if is_instance_valid(d):
			d.queue_free()
	_debris.clear()
	for part: String in _parts:
		(_parts[part] as Node3D).visible = true


# --- 입력(메인 스레드) --------------------------------------------------------

func _physics_process(delta: float) -> void:
	var has_air := air > 0.0
	var steer_in := 0.0
	if controls_enabled:
		throttle = Input.get_axis("back", "forward")
		steer_in = Input.get_axis("right", "left")
	else:
		throttle = 0.0
	lift_firing = controls_enabled and has_air and Input.is_action_pressed("rocket")
	main_firing = controls_enabled and has_air and Input.is_action_pressed("boost")
	# 흡착 팬은 전기로 돈다(공기를 쓰지 않는다). 리프트를 켜면 팬은 잠시 꺼진다(면에서 뛰어오르기)
	fan_on = controls_enabled and Input.is_action_pressed("magnet") and not lift_firing
	if lift_firing and not _lift_was_firing and (_grounded > 0 or attached):
		_kick_pending = true # 켜는 순간 한 번 튀어 올라 이륙을 또렷하게 한다
		air = maxf(air - lift_kick_air, 0.0)
	_lift_was_firing = lift_firing

	var in_air := _grounded == 0 and not attached
	_pitch_cmd = 0.0
	_yaw_cmd = 0.0
	if in_air and controls_enabled and has_air:
		# W: 기수 내림(뒤 리프트 노즐), S: 기수 올림(앞 리프트 노즐), A/D: 수평 회전(옆 노즐)
		_pitch_cmd = Input.get_axis("air_back", "air_forward")
		_yaw_cmd = steer_in
	# F: 옆으로 돌기(앞뒤 축). 누르는 순간 한 번 시작하고 자세 노즐이 끝까지 돌린다.
	# 바로 서 있으면 한 바퀴(실제 시연의 킥플립), 뒤집혀 있으면 바퀴가 아래로 오는 데까지 반 바퀴(램프 천장에서 떨어질 때).
	# A를 누른 채면 왼쪽으로, 아니면 오른쪽으로 한 바퀴 돈다.
	# 천장에서 팬을 막 뗀 순간은 바퀴 감지가 아직 천장에 닿아 있다. 뒤집혀 있고 붙어 있지 않으면 공중으로 친다.
	var can_roll := not attached and (_grounded == 0 or global_basis.y.y < -0.3)
	var roll_pressed := controls_enabled and Input.is_action_pressed("barrel_roll")
	if roll_pressed and not _roll_was_pressed and can_roll and has_air and _roll_left == 0.0:
		_roll_left = _roll_amount(Input.is_action_pressed("left"))
	_roll_was_pressed = roll_pressed
	if not can_roll:
		_roll_left = 0.0
	if _roll_left != 0.0:
		_pitch_cmd = 0.0
		_yaw_cmd = 0.0

	# 조향: 속도가 빠를수록 덜 꺾는다
	var v_fwd := forward_speed()
	var max_steer := lerpf(steer_low, steer_high, clampf(absf(v_fwd) / top_speed, 0.0, 1.0))
	steer = move_toward(steer, 0.0 if in_air else steer_in * max_steer, steer_rate * delta)
	linear_speed = v_fwd / top_speed

	var burn := 0.0
	if lift_firing: burn += lift_burn
	if main_firing: burn += main_burn
	if absf(_pitch_cmd) > 0.1 or absf(_yaw_cmd) > 0.1 or _roll_left != 0.0: burn += attitude_burn
	air = maxf(air - burn * delta, 0.0)
	if burn == 0.0 and _grounded > 0 and not on_wall:
		air = minf(air + ground_recharge * delta, air_max)

	_check_flip(delta)
	_update_visuals(delta)
	_update_effects()


# --- 물리 ---------------------------------------------------------------------

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	if _reset_xform != null:
		state.transform = _reset_xform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_reset_xform = null
	var xf := state.transform
	var b := xf.basis.orthonormalized()
	var com := xf * center_of_mass
	var space := state.get_space_state()

	# 1) 바퀴 광선 + 스프링
	_grounded = 0
	var n_sum := Vector3.ZERO
	for w in _wheels:
		var o: Vector3 = xf * w.mount
		var q := PhysicsRayQueryParameters3D.create(o, o - b.y * (rest_length + wheel_radius), WORLD_MASK, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.normal.dot(b.y) < 0.2:
			w.hit = false
			w.len = rest_length
			w.load = 0.0
			continue
		var spring_len := maxf(o.distance_to(hit.position) - wheel_radius, 0.0)
		var comp := rest_length - spring_len
		var pv := state.linear_velocity + state.angular_velocity.cross(hit.position - com)
		var vs := pv.dot(b.y) # + 이면 스프링이 늘어나는 중(차체가 튀어 오른다)
		var f := spring * comp - damper * vs * (rebound if vs > 0.0 else 1.0)
		if comp > bump_start:
			f += spring * 6.0 * (comp - bump_start)
		f = maxf(f, 0.0)
		state.apply_force(b.y * f, hit.position - xf.origin)
		w.hit = true
		w.point = hit.position
		w.normal = hit.normal
		w.len = spring_len
		w.load = f
		_grounded += 1
		n_sum += hit.normal
	normal = n_sum.normalized() if _grounded > 0 else Vector3.UP

	# 2) 흡착 팬
	_update_fan(state, b, dt)

	# 3) 중력(흡착 중에는 팬이 붙은 면 쪽으로 당긴다)
	if attached:
		state.apply_central_force(-up_dir * fan_gravity * mass)
	else:
		state.apply_central_force(Vector3.DOWN * GRAVITY * mass)

	# 4) 타이어
	if _grounded > 0:
		_apply_tires(state, b, com, xf.origin)

	# 5) 추진기
	if _kick_pending:
		_kick_pending = false
		state.linear_velocity += (up_dir if attached else b.y) * lift_kick
	if lift_firing:
		state.apply_central_force(b.y * lift_accel * mass)
	if main_firing:
		state.apply_central_force(b.z * main_accel * mass)

	# 6) 자세(자세 복원 분사 표시는 매 스텝 새로 정한다. 땅에 내려오면 꺼진다)
	_leveling = 0.0
	if attached:
		_align_to_surface(state, b, dt)
	elif _grounded == 0 or _roll_left != 0.0:
		_air_attitude(state, b, dt)

	# 7) 부딪힘·착지
	_read_contacts(state, b)
	_track_landing(state, b, dt)
	if _absorb > 0.0:
		_absorb -= dt
		var vn := state.linear_velocity.dot(normal)
		if vn > 0.3 and not lift_firing and not _kick_pending:
			state.linear_velocity -= normal * (vn - 0.3)


func _apply_tires(state: PhysicsDirectBodyState3D, b: Basis, com: Vector3, origin: Vector3) -> void:
	var fwd_ground := b.z - normal * b.z.dot(normal)
	var v_fwd := state.linear_velocity.dot(fwd_ground.normalized()) if fwd_ground.length() > 0.1 else 0.0
	var a := _drive_accel(v_fwd)
	var m_wheel := mass / 4.0
	_slip = 0.0
	for w in _wheels:
		if not w.hit:
			continue
		var n: Vector3 = w.normal
		var wf: Vector3 = b.z.rotated(b.y, steer) if w.front else b.z
		var fg := wf - n * wf.dot(n)
		if fg.length() < 0.1:
			continue
		fg = fg.normalized()
		var sg := n.cross(fg)
		var pv := state.linear_velocity + state.angular_velocity.cross(w.point - com)
		var v_side := pv.dot(sg)
		var f := -sg * v_side * (m_wheel / lateral_tau) + fg * (mass * a / _grounded)
		var lim: float = grip * w.load
		var fl := f.length()
		if fl > lim and fl > 0.0:
			f *= lim / fl
			_slip = maxf(_slip, absf(v_side))
		state.apply_force(f, w.point - origin)


## 앞 방향 가속(m/s²). 목표 속도를 따라가되 상한이 있다. 메인 추진으로 최고 속도를 넘어도 막지 않는다.
func _drive_accel(v: float) -> float:
	var z := throttle
	if z > 0.05:
		if v < -0.3:
			return brake
		var target := z * top_speed
		if v < target:
			return minf(accel, (target - v) * accel_gain)
		return -minf(coast_max, (v - target) * 0.3)
	if z < -0.05:
		if v > 0.3:
			return -brake
		var target_r := z * reverse_speed
		return maxf(-accel, (target_r - v) * accel_gain)
	# 손을 뗐다: 굴러가다 서고, 거의 서면 세워 둔다(경사로에서 밀려 내려가지 않게)
	if absf(v) < 0.6:
		return -v / 0.1
	return -signf(v) * minf(coast_max, absf(v) * coast_gain)


func _air_attitude(state: PhysicsDirectBodyState3D, b: Basis, dt: float) -> void:
	_air_roll += absf(state.angular_velocity.dot(b.z)) * dt
	if _roll_left != 0.0:
		_leveling = 0.0
		_air_roll_step(state, b, dt)
		return
	var target := b.x * _pitch_cmd * air_pitch_speed + b.y * _yaw_cmd * air_yaw_speed
	_leveling = 0.0
	if absf(_pitch_cmd) < 0.1:
		# 손을 떼면 자세 제어 노즐이 차를 바로 세운다(뒤집혀 날아가도 바퀴로 내려앉게).
		# 기수가 향한 수평 방향은 그대로 둔다: 말린 램프 끝에서 거꾸로 튀어 나가면 반 바퀴 비틀어 진행 방향으로 착지한다.
		var fh := Vector3(b.z.x, 0.0, b.z.z)
		if fh.length() < 0.3:
			var alt := -b.y * signf(b.z.y) # 기수가 하늘·땅을 보면 기수를 숙이거나 드는 쪽
			fh = Vector3(alt.x, 0.0, alt.z)
		if fh.length() > 0.05:
			var q := (Basis.looking_at(-fh.normalized(), Vector3.UP) * b.inverse()).get_rotation_quaternion()
			if q.w < 0.0:
				q = -q
			var angle := q.get_angle()
			if angle > 0.05:
				target += q.get_axis() * minf(angle * 3.0, air_level_rate)
				if angle > 0.25: # 14도 넘게 기울었을 때만 옆 노즐 분사를 보인다(작은 보정까지 보이면 계속 뿜는 것 같다)
					_leveling = clampf(angle, 0.3, 1.0)
	var w := state.angular_velocity
	state.angular_velocity = w.lerp(target, clampf(attitude_response * dt, 0.0, 1.0))
	_air_spin += absf(w.dot(b.y)) * dt


## F 한 번에 돌 각도(+는 오른쪽: 왼쪽 옆구리가 올라간다).
func _roll_amount(to_left: bool) -> float:
	var b := global_basis.orthonormalized()
	if b.y.dot(Vector3.UP) < -0.3:
		var u := Vector3.UP - b.z * Vector3.UP.dot(b.z) # 앞뒤 축에 수직인 면에 놓은 하늘 방향
		if u.length() > 0.1:
			return b.y.signed_angle_to(u.normalized(), b.z)
	return TAU * (-1.0 if to_left else 1.0)


## F 옆 회전: 앞뒤 축(b.z) 둘레로 남은 각도만큼 돈다. 끝나면 _roll_left = 0으로 돌아가 자세 복원이 이어받는다.
func _air_roll_step(state: PhysicsDirectBodyState3D, b: Basis, dt: float) -> void:
	var w := state.angular_velocity
	var rate := w.dot(b.z)
	var before := _roll_left
	_roll_left -= rate * dt
	if absf(_roll_left) < 0.06 or signf(_roll_left) != signf(before):
		_roll_left = 0.0
		state.angular_velocity = b.z * rate * 0.3 # 남은 회전을 반대쪽 분사로 거의 멈춘다
		return
	var want := signf(_roll_left) * clampf(absf(_roll_left) * 4.0, 1.2, roll_speed)
	state.angular_velocity = w.lerp(b.z * want, clampf(roll_response * dt, 0.0, 1.0))


func _align_to_surface(state: PhysicsDirectBodyState3D, b: Basis, dt: float) -> void:
	# 흡착 중에는 차체 바닥을 붙은 면에 맞추는 회전을 살짝 보탠다(바퀴 힘만으로는 곡면에 늦게 따라간다)
	var err := b.y.cross(up_dir)
	var w := state.angular_velocity
	var w_up := up_dir * w.dot(up_dir)
	var w_perp := w - w_up
	state.angular_velocity = w_up + w_perp.lerp(err * 8.0, clampf(fan_align_rate * dt, 0.0, 1.0))


func _update_fan(state: PhysicsDirectBodyState3D, b: Basis, dt: float) -> void:
	if not fan_on:
		if attached:
			_detach()
		return
	if attached:
		if _grounded > 0:
			up_dir = normal
			_coyote = 0.0
			on_wall = up_dir.dot(Vector3.UP) < 0.7
		else:
			# 면이 끝났다(곡면 램프 끝, 모서리): 잠깐 뒤 떨어져 나간다
			_coyote += dt
			if _coyote > 0.06:
				_detach()
		return
	if _grounded >= 2:
		_attach(normal)
		return
	# 공중: 가까운 면을 찾아 붙는다
	var c := state.transform * center_of_mass
	for d: Vector3 in [-b.y, Vector3.DOWN]:
		var q := PhysicsRayQueryParameters3D.create(c, c + d * (0.4 + fan_seek_distance), WORLD_MASK, [get_rid()])
		var hit := state.get_space_state().intersect_ray(q)
		if not hit.is_empty():
			_attach(hit.normal)
			return


func _attach(n: Vector3) -> void:
	up_dir = n
	attached = true
	_coyote = 0.0
	on_wall = up_dir.dot(Vector3.UP) < 0.7
	attached_changed.emit.call_deferred(true)


func _detach() -> void:
	if not attached:
		return
	attached = false
	on_wall = false
	up_dir = Vector3.UP
	_coyote = 0.0
	attached_changed.emit.call_deferred(false)


## 한 번 부딪힐 때 힘이 접점 여러 개로 나뉘어 들어오므로 이번 스텝의 충격량을 모두 더해 속도 변화로 본다.
func _read_contacts(state: PhysicsDirectBodyState3D, b: Basis) -> void:
	var all := Vector3.ZERO
	var side := Vector3.ZERO
	for i in state.get_contact_count():
		var n := state.get_contact_local_normal(i)
		var imp := state.get_contact_impulse(i)
		if debug_contacts:
			print("    contact n=%s imp=%s vel=%s with=%s pos=%s" % [n, imp, state.linear_velocity, state.get_contact_collider_object(i), state.transform.origin])
		all += imp
		# 경사로·곡면(meta "ramp")은 빠르게 들이받아 코가 닿아도 사고로 치지 않는다: Shift로 달려 램프에 들어가면 부서졌다(10/24 사용자)
		var other := state.get_contact_collider_object(i)
		if other is Node and (other as Node).has_meta("ramp"):
			continue
		if n.dot(b.y) < 0.5: # 바퀴 쪽(차체 바닥)이 아닌 곳: 앞·뒤·옆·지붕
			side += imp
	_impact = all.length() / mass
	_crash_cool = maxf(_crash_cool - state.step, 0.0)
	var dv := side.length() / mass
	if dv > crash_speed and _crash_cool <= 0.0:
		_crash_cool = 1.0
		_report_crash.call_deferred("crash", dv)
		# 받은 충격의 반대쪽에 부딪힌 물체가 있다: 앞·뒤면 범퍼, 옆이면 그쪽 미러(차의 왼쪽이 +X)
		var hit := b.inverse() * -side
		var part := ""
		if absf(hit.z) >= absf(hit.x):
			part = "bumper_front" if hit.z > 0.0 else "bumper_rear"
		else:
			part = "mirror_left" if hit.x > 0.0 else "mirror_right"
		_break_off.call_deferred(part, side)


func _track_landing(state: PhysicsDirectBodyState3D, b: Basis, dt: float) -> void:
	var touching := _grounded > 0 or attached or state.get_contact_count() > 0
	if not touching:
		_air_time += dt
		return
	if _air_time > 0.45:
		_absorb = landing_absorb
		_play_landing.call_deferred(_air_time)
		var up_dot := b.y.dot(normal if _grounded > 0 else Vector3.UP)
		last_air_roll = rad_to_deg(_air_roll)
		landed.emit.call_deferred(up_dot > 0.75, _air_time, rad_to_deg(_air_spin))
		if b.y.dot(Vector3.UP) < 0.3:
			_report_crash.call_deferred("flip", 0.0) # 지붕·옆으로 떨어졌다
	_air_time = 0.0
	_air_spin = 0.0
	_air_roll = 0.0


## 넘어진 채 0.3초: "flip". 스턴트 코스에서는 recover_time 뒤 노즐이 차를 바로 세운다.
func _check_flip(delta: float) -> void:
	var lying := get_up().dot(Vector3.UP) < 0.3 and _grounded <= 1 and get_contact_count() > 0 and get_speed() < 3.0
	if not lying:
		_flip_time = 0.0
		return
	_flip_time += delta
	if _flip_time > 0.3:
		_report_crash("flip", 0.0)
	if auto_recover and _flip_time > recover_time:
		_flip_time = 0.0
		_flip_reported = false
		var fwd := get_forward()
		fwd.y = 0.0
		if fwd.length() < 0.1:
			fwd = get_up()
			fwd.y = 0.0
		var t := Transform3D(Basis.looking_at(-fwd.normalized(), Vector3.UP), global_position + Vector3.UP * 0.6)
		_teleport(t)


func _report_crash(kind: String, impact: float) -> void:
	if kind == "flip":
		if _flip_reported:
			return
		_flip_reported = true
	crashed.emit(kind, impact)
	if not impact_sound.playing:
		impact_sound.volume_db = 0.0
		impact_sound.play()


func _teleport(t: Transform3D) -> void:
	global_transform = t
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_reset_xform = t


# --- 리스폰·조회 --------------------------------------------------------------

func respawn_at(xform: Transform3D) -> void:
	_detach()
	reset_parts()
	var up := xform.basis.y.normalized()
	_teleport(Transform3D(xform.basis.orthonormalized(), xform.origin - up * 0.1))
	steer = 0.0
	throttle = 0.0
	air = air_max
	_air_time = 0.0
	_air_spin = 0.0
	_air_roll = 0.0
	_roll_left = 0.0
	_flip_time = 0.0
	_flip_reported = false


func refill_air() -> void:
	air = air_max


## 주차 보조: 목표 칸 안에서 바퀴가 닿아 있고 가속을 안 하면 빠르게 세운다("딱" 멈추는 느낌).
func settle(delta: float) -> void:
	var k := exp(-6.0 * delta)
	var v := linear_velocity
	var vy := v.dot(up_dir)
	linear_velocity = (v - up_dir * vy) * k + up_dir * vy
	var w := angular_velocity
	angular_velocity = w - get_up() * w.dot(get_up()) * (1.0 - k)


func get_vehicle_position() -> Vector3:
	return global_position


func get_forward() -> Vector3:
	return global_basis.z.normalized()


func get_up() -> Vector3:
	return global_basis.y.normalized()


func get_planar_velocity() -> Vector3:
	var v := linear_velocity
	v.y = 0.0
	return v


func forward_speed() -> float:
	return linear_velocity.dot(get_forward())


func angular_velocity_y() -> float:
	return angular_velocity.dot(get_up())


func get_speed() -> float:
	return linear_velocity.length()


## 바퀴 둘 이상이 땅에 닿아 있다(흡착 중이면 하나도 된다)
func is_grounded() -> bool:
	return _grounded >= 2 or (attached and _grounded >= 1)


func air_spin() -> float:
	return _air_spin


func fan_g() -> float:
	return fan_gravity / 9.8


# --- 보이는 것·소리 -----------------------------------------------------------

func _update_visuals(delta: float) -> void:
	var v_fwd := forward_speed()
	for w in _wheels:
		var node: Node3D = w.node
		if node == null:
			continue
		var m: Vector3 = w.mount
		var to_model: Transform3D = w.to_model
		node.position = to_model * Vector3(m.x, m.y - w.len, m.z)
		w.spin = wrapf(w.spin + v_fwd / wheel_radius * delta, -PI, PI)
		var yaw: float = steer if w.front else 0.0
		node.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, w.spin)

	var speed_factor := clampf(absf(v_fwd) / top_speed, 0.0, 1.0)
	var throttle_factor := clampf(absf(throttle), 0.0, 1.0)
	# 전기차라 엔진 소리 대신 낮은 모터 소리(EngineSound에 motor_hover를 씌운다): 서 있으면 작고, 빨라질수록 커지고 높아진다
	var motor_db := lerpf(-20.0, -4.0, speed_factor) + throttle_factor * 3.0
	engine_sound.volume_db = lerpf(engine_sound.volume_db, motor_db, delta * 5.0)
	var pitch := lerpf(0.85, 1.3, speed_factor) + throttle_factor * 0.05
	engine_sound.pitch_scale = lerpf(engine_sound.pitch_scale, pitch, delta * 3.0)
	var skid := -80.0 if _slip < 1.2 or _grounded == 0 else remap(clampf(_slip, 1.2, 6.0), 1.2, 6.0, -12.0, 0.0)
	screech_sound.volume_db = lerpf(screech_sound.volume_db, skid, clampf(delta * 10.0, 0.0, 1.0))
	if _impact > 2.0 and not impact_sound.playing:
		impact_sound.volume_db = clampf(remap(_impact, 2.0, 8.0, -20.0, 0.0), -20.0, 0.0)
		impact_sound.play()


func _update_effects() -> void:
	var lift := 1.0 if lift_firing else 0.0
	var pitch_front := maxf(-_pitch_cmd, 0.0) # 기수 올림: 앞 리프트
	var pitch_rear := maxf(_pitch_cmd, 0.0) # 기수 내림: 뒤 리프트
	# 공중에서 리프트를 계속 뿜으면(착지 분사) 기둥이 길고 굵어진다
	# 옆 회전: 올라가는 쪽 옆구리의 리프트 노즐 둘(오른쪽으로 돌면 왼쪽(+X) 노즐)
	var roll_l := 1.0 if _roll_left > 0.0 else 0.0
	var roll_r := 1.0 if _roll_left < 0.0 else 0.0
	_lift_stretch = move_toward(_lift_stretch, 1.0 if lift_firing and _grounded == 0 and not attached else 0.0, get_physics_process_delta_time() * 4.0)
	thrusters["LiftFL"].fire(maxf(maxf(lift, pitch_front * 0.7), roll_l), _lift_stretch * lift)
	thrusters["LiftFR"].fire(maxf(maxf(lift, pitch_front * 0.7), roll_r), _lift_stretch * lift)
	thrusters["LiftRL"].fire(maxf(maxf(lift, pitch_rear * 0.7), roll_l), _lift_stretch * lift)
	thrusters["LiftRR"].fire(maxf(maxf(lift, pitch_rear * 0.7), roll_r), _lift_stretch * lift)
	var main := 1.0 if main_firing else 0.0
	thrusters["MainL"].fire(main)
	thrusters["MainR"].fire(main)
	# 왼쪽 회전: 앞-오른쪽 + 뒤-왼쪽 노즐, 오른쪽 회전: 앞-왼쪽 + 뒤-오른쪽
	var yaw_l := maxf(_yaw_cmd, 0.0)
	var yaw_r := maxf(-_yaw_cmd, 0.0)
	var flicker := _leveling * 0.45 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)) # 자세 복원 중 짧게 깜빡이는 분사
	thrusters["SideFR"].fire(maxf(yaw_l, flicker))
	thrusters["SideRL"].fire(maxf(yaw_l, flicker))
	thrusters["SideFL"].fire(maxf(yaw_r, flicker))
	thrusters["SideRR"].fire(maxf(yaw_r, flicker))
	fan_glow.visible = attached
	# 바닥 가까이에서 리프트를 뿜으면 차 아래 바닥에 가스 구름(착지 직전·이륙 순간)
	var ground: Variant = null
	var height := INF
	if lift_firing:
		var o := global_position
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + Vector3.DOWN * GroundCloud.NEAR, WORLD_MASK, [get_rid()]))
		if hit:
			ground = hit.position
			height = o.y - hit.position.y
	_cloud.update_cloud(lift_firing, ground, height)
	_update_sounds(height)


# --- 모터·흡착 팬·분사·착지 소리 -----------------------------------------------
# 모터·팬·분사는 ElevenLabs 효과음 생성 후보 중 사용자가 고른 소리(10/23: motor_6, fan_4, jet_6, tools/elevenlabs_sfx.py),
# 착지 '쿵'은 tools/make_sounds.py로 만든 소리. 처음에 코드로 합성한 모터·팬·분사 소리는 청소기 같다는 의견으로 뺐다.

const MOTOR_STREAM := "res://assets/sfx/motor_hover.wav"
## [파일, 반복 재생]
const SFX := {
	"fan": ["res://assets/sfx/fan_jet.wav", true],
	"lift": ["res://assets/sfx/thrust_burn.wav", false],
	"main": ["res://assets/sfx/thrust_burn.wav", false],
	"puff": ["res://assets/sfx/thrust_burn.wav", false],
	"land": ["res://assets/sfx/land_thump.wav", false],
}
var _snd := {}
var _snd_on := {}
## 소리마다 버스(default_bus_layout.tres). 크기는 버스 볼륨으로 한 번에 맞춘다(Master에 압축기·리미터)
const SFX_BUS := {"fan": &"Fan", "lift": &"Jet", "main": &"Jet", "puff": &"Jet", "land": &"Hit"}


func _setup_sounds() -> void:
	for k: String in SFX:
		var stream: AudioStreamWAV = load(SFX[k][0])
		if stream == null:
			continue
		if SFX[k][1]:
			stream = _looped(stream)
		var p := AudioStreamPlayer3D.new()
		p.stream = stream
		p.unit_size = 14.0
		p.max_db = 3.0
		p.volume_db = -60.0
		p.bus = SFX_BUS.get(k, &"Master")
		add_child(p)
		_snd[k] = p
	# 엔진 소리 자리(EngineSound)에 전기 모터 소리를 반복으로 씌운다
	engine_sound.bus = &"Motor"
	screech_sound.bus = &"Hit"
	impact_sound.bus = &"Hit"
	var motor: AudioStreamWAV = load(MOTOR_STREAM)
	if motor:
		engine_sound.stream = _looped(motor)
		engine_sound.volume_db = -40.0
		engine_sound.play()


func _looped(stream: AudioStreamWAV) -> AudioStreamWAV:
	var s := stream.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate) # 압축(QOA)돼 있어도 샘플 수로
	return s


## 반복 소리를 부드럽게 켜고 끈다. vol: 0~1
func _loop_sound(k: String, on: bool, vol: float, pitch: float) -> void:
	var p: AudioStreamPlayer3D = _snd.get(k)
	if p == null:
		return
	var target := linear_to_db(maxf(vol, 0.001)) if on else -60.0
	p.volume_db = lerpf(p.volume_db, target, 0.3 if on else 0.15)
	p.pitch_scale = pitch
	if on and not p.playing:
		p.play()
	elif not on and p.playing and p.volume_db < -50.0:
		p.stop()


## 분사 소리(3초짜리 한 번): 켜는 순간 처음부터, 3초보다 오래 뿜으면 몸통(0.6초)부터 다시, 끄면 짧게 줄여 멈춘다.
func _thrust_sound(k: String, on: bool, vol_db: float, pitch: float) -> void:
	var p: AudioStreamPlayer3D = _snd.get(k)
	if p == null:
		return
	var was: bool = _snd_on.get(k, false)
	if on and not was:
		p.volume_db = vol_db
		p.pitch_scale = pitch * randf_range(0.97, 1.03)
		p.play()
	elif on:
		p.volume_db = lerpf(p.volume_db, vol_db, 0.3)
		if not p.playing:
			p.play(0.6)
	elif p.playing:
		p.volume_db -= 2.5 # 약 0.25초에 걸쳐 줄인다
		if p.volume_db < -45.0:
			p.stop()
	_snd_on[k] = on


func _update_sounds(_ground_height: float) -> void:
	# 크기 맞춤(10/23 사용자: 제트 소리가 너무 크다): 분사는 모터보다 8~10dB 위, 흡착 팬은 그 사이, 착지 쿵은 짧게
	_thrust_sound("lift", lift_firing, -9.0, 1.0)
	_thrust_sound("main", main_firing, -11.0, 0.92)
	# 자세 노즐(옆으로 돌기, 공중 기울이기·수평 회전, 자세 복원): 같은 분사 소리를 작고 높게
	var puff := _roll_left != 0.0 or absf(_pitch_cmd) > 0.1 or absf(_yaw_cmd) > 0.1 or _leveling > 0.3
	_thrust_sound("puff", puff and not lift_firing, -19.0, 1.35)
	# 흡착 팬 소리는 팬이 실제로 차를 붙잡고 있을 때만: 붙은 면이 14도 넘게 기울었을 때(램프·벽·천장). 평지에서 E를 눌러 둬도 조용하다.
	# 가파를수록(벽·천장) 크게.
	var sucking := attached and up_dir.y < 0.97
	var steep := clampf(remap(up_dir.y, 0.97, 0.0, 0.0, 1.0), 0.0, 1.0)
	_loop_sound("fan", sucking, lerpf(0.28, 0.6, steep), 0.92 + clampf(get_speed() / top_speed, 0.0, 1.0) * 0.18)


func _play_landing(air_time: float) -> void:
	var p: AudioStreamPlayer3D = _snd.get("land")
	if p:
		p.volume_db = clampf(remap(air_time, 0.45, 2.5, -14.0, -3.0), -14.0, -3.0)
		p.play()
