extends "res://scripts/level.gd"
## 시연장: 우리 웹 프로토타입(Three.js)의 무대 배치를 옮겼다.
##   왼쪽 램프: 반원(반지름 8m)으로 말려 올라가 16m 높이 천장(돌출부 6m)에 닿는다. 흡착 팬(E)을 켠 채 올라가
##             천장에 거꾸로 매달려 멈췄다가 E를 떼면 떨어지며 옆으로 돌아(자세 노즐) 바퀴로 내려앉는다.
##             바닥 가까이에서 Space로 받친다.
##   오른쪽 길: 장애물 차 셋과 박스 트럭이 줄지어 서 있다. 달려와 리프트로 뛰어올라 F로 옆으로 한 바퀴 돌고
##             주황 착지 칸에 내린다.
## 간격과 높이는 웹 시연을 따르되 램프는 우리 차의 점프·낙하에 맞춰 줄였다(웹 시연은 반지름 11m).
## 색도 웹 시연과 거의 같다(남색 바닥, 빨간 빛 띠, 주황 표시, 청회색 철골).
## 우리 게임은 앞이 +Z라 웹 시연(앞이 -Z)과 좌우가 뒤집혀 있다: 램프가 왼쪽(+X), 장애물 길이 오른쪽(-X).

const RAMP_X := 14.0
const RAMP_Z := 30.0 ## 반원이 땅에서 시작하는 곳
const RAMP_R := 8.0
const RAMP_W := 8.0
const OVERHANG := 3.0 ## 꼭대기에서 출발 쪽으로 뻗은 천장(입술) 길이. 웹 시연과 같다
const LANE_X := -14.0
const LAUNCH_Z := 0.0 ## 장애물 길: 여기서 뛰어오른다
## 웹 시연은 차 간격 6m에 트럭까지 42m를 뛴다. 우리 차는 중력이 1.5배라 같은 거리를 뛰면 13m 넘게 솟으므로
## 실제 주차 줄처럼 범퍼 사이 1m로 붙여 놓았다(첫 차는 출발선 10m 앞).
const OBSTACLE_Z := [10.0, 15.4, 20.8] ## 장애물 차 가운데
const TRUCK_Z := 28.0
const LANDING_Z := 38.0

## 녹화용 고정 카메라 자리(Shot 자동 로드의 cam=spot:이름): [카메라 위치, 기준점, 차를 따라보는 비율].
## 카메라는 기준점과 차 사이(비율만큼 차 쪽)를 바라본다. 램프는 구조물 전체가 들어오게 램프 가운데를 반쯤 본다.
## Tripo 모델이 없을 때 코드 소품 차에 칠할 색(웹 시연과 같은 회청색 계열)
const PAINTS := {"slate_blue": Color(0.424, 0.478, 0.51), "gunmetal": Color(0.345, 0.431, 0.482), "champagne": Color(0.608, 0.573, 0.518)}
const SHOT_CAMS := {
	"ramp": [Vector3(-3.0, 1.4, 17.0), Vector3(14.0, 8.0, 20.5), 0.35], # 낮게: 램프가 위로 솟아 보이고, 입술과 착지 자리가 한 화면에
	"kick": [Vector3(-4.0, 2.5, 17.0), Vector3(-14.0, 3.0, 20.0), 1.0],
}

var intro := "램프: E로 올라가 천장에서 E 떼기 → Space로 착지\n장애물 길: 리프트로 뛰고 F로 옆으로 한 바퀴"

var _mats := {}


func _ready() -> void:
	_build_ground()
	_build_ramp()
	_build_lane()
	_build_props()
	_build_pads()


## 웹 시연(test-ground.ts, ramp.ts)과 거의 같은 색
func _material(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"ground": m.albedo_color = Color(0.094, 0.137, 0.173); m.roughness = 0.97
		"apron": m.albedo_color = Color(0.17, 0.215, 0.255); m.roughness = 0.88
		"road": m.albedo_color = Color(0.188, 0.235, 0.275); m.roughness = 0.88
		"ramp": m.albedo_color = Color(0.345, 0.396, 0.447); m.roughness = 0.83
		"steel": m.albedo_color = Color(0.2, 0.27, 0.32); m.metallic = 0.55; m.roughness = 0.54
		"white": m.albedo_color = Color(0.608, 0.663, 0.694); m.roughness = 0.8
		"yellow": m.albedo_color = Color(0.949, 0.604, 0.204); m.roughness = 0.8
		"glass": m.albedo_color = Color(0.06, 0.07, 0.09); m.roughness = 0.3
		"edge":
			m.albedo_color = Color(0.851, 0.153, 0.263)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.09, 0.208)
			m.emission_energy_multiplier = 1.6
		"lamp":
			m.albedo_color = Color(0.761, 0.886, 0.933)
			m.emission_enabled = true
			m.emission = Color(0.714, 0.863, 0.961)
			m.emission_energy_multiplier = 2.0
		_: m.albedo_color = Color(0.5, 0.5, 0.5)
	if key in ["ground", "apron", "road"]:
		m.metallic_specular = 0.2 # 낮게 비춘 조명에 바닥이 허옇게 번들거리지 않게
	_mats[key] = m
	return m


func _paint(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.45
	m.metallic = 0.25
	return m


## 충돌 없는 장식(띠, 선, 조명)
func _add_visual(xform: Transform3D, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _flat(x0: float, z0: float, x1: float, z1: float, y: float, key: String) -> void:
	_add_visual(Transform3D(Basis.IDENTITY, Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5)), Vector3(absf(x1 - x0), 0.02, absf(z1 - z0)), _material(key))


func _build_ground() -> void:
	_add_block(Vector3(-200, -1, -150), Vector3(200, 0, 250), "ground")
	_flat(-22.5, -20, 22.5, 52, 0.006, "apron") # 시험장 바닥
	_flat(-6, -60, 6, 140, 0.012, "road") # 가운데 큰길
	for side: float in [-1.0, 1.0]:
		_flat(side * 5.74, -60, side * 5.66, 140, 0.03, "edge") # 길 가장자리 빛 띠
		_flat(side * 5.41, -60, side * 5.29, 140, 0.028, "white")
		_flat(side * 22.03, -20, side * 21.97, 52, 0.03, "edge") # 시험장 둘레
	for i in 26:
		var z := -55.0 + i * 7.0
		_flat(-0.065, z, 0.065, z + 2.8, 0.03, "white") # 가운데 점선
	for k in 4:
		var x := -3.0 + k * 2.0
		_flat(x - 0.4, -4.4, x + 0.4, -3.6, 0.03, "white") # 출발 격자
		_flat(x + 0.6, -3.6, x + 1.4, -2.8, 0.03, "white")


func _build_ramp() -> void:
	# 진입로
	_flat(RAMP_X - RAMP_W / 2, -12, RAMP_X + RAMP_W / 2, RAMP_Z, 0.014, "road")
	for side: float in [-1.0, 1.0]:
		var x := RAMP_X + side * (RAMP_W / 2 - 0.2)
		_flat(x - 0.05, -12, x + 0.05, RAMP_Z, 0.03, "white")
	# 달리는 면: 반원(0~180도) + 꼭대기에서 출발 쪽으로 뻗은 천장
	var segs := 44
	_add_arc("z", Vector2(RAMP_Z, RAMP_R), RAMP_R, 0.0, 180.0, segs, RAMP_W, RAMP_X, "ramp")
	var top := RAMP_R * 2.0
	_add_block(Vector3(RAMP_X - RAMP_W / 2, top, RAMP_Z - OVERHANG), Vector3(RAMP_X + RAMP_W / 2, top + 0.3, RAMP_Z + 0.25), "ramp")
	# 가장자리 빛 띠(반원 + 천장)
	var step := PI / segs
	for i in segs:
		var th := step * (i + 0.5)
		var p := Vector3(0, RAMP_R - RAMP_R * cos(th), RAMP_Z + RAMP_R * sin(th))
		var n := Vector3(0, cos(th), -sin(th)) # 안쪽 법선
		var t := Vector3(0, sin(th), cos(th))
		var b := Basis(n.cross(t), n, t)
		for side: float in [-1.0, 1.0]:
			_add_visual(Transform3D(b, p + n * 0.04 + Vector3(RAMP_X + side * (RAMP_W / 2 - 0.12), 0, 0)), Vector3(0.09, 0.07, 2.0 * RAMP_R * sin(step * 0.5) * 1.05), _material("edge"))
			_add_box(Transform3D(b, p - n * 0.3 + Vector3(RAMP_X + side * (RAMP_W / 2 + 0.14), 0, 0)), Vector3(0.28, 0.35, 2.0 * RAMP_R * sin(step * 0.5) * 1.05), _material("steel"))
	for side: float in [-1.0, 1.0]:
		var x := RAMP_X + side * (RAMP_W / 2 - 0.12)
		_add_visual(Transform3D(Basis.IDENTITY, Vector3(x, top - 0.04, RAMP_Z - OVERHANG / 2)), Vector3(0.09, 0.07, OVERHANG), _material("edge"))
	# 뼈대: 앞·뒤 기둥, 사선 버팀대, 꼭대기 난간, 뒤쪽 가로대(차가 다니는 폭 바깥)
	for side: float in [-1.0, 1.0]:
		var x := RAMP_X + side * (RAMP_W / 2 + 0.7)
		_beam(Vector3(x, 0, RAMP_Z), Vector3(x, top + 0.6, RAMP_Z), 0.34)
		_beam(Vector3(x, 0, RAMP_Z + RAMP_R + 0.7), Vector3(x, RAMP_R + 4.0, RAMP_Z + RAMP_R + 0.7), 0.32)
		_beam(Vector3(x, 0, RAMP_Z + RAMP_R + 3.0), Vector3(x, top + 0.4, RAMP_Z - OVERHANG + 0.2), 0.24)
		_beam(Vector3(x, 0, RAMP_Z - OVERHANG - 1.0), Vector3(x, top + 0.3, RAMP_Z - OVERHANG), 0.26)
		_beam(Vector3(x, top + 0.3, RAMP_Z + 0.2), Vector3(x, top + 0.3, RAMP_Z - OVERHANG), 0.3)
	for h: float in [top / 3.0, top * 2.0 / 3.0, top + 0.35]:
		_beam(Vector3(RAMP_X - RAMP_W / 2 - 0.7, h, RAMP_Z + RAMP_R + 0.7), Vector3(RAMP_X + RAMP_W / 2 + 0.7, h, RAMP_Z + RAMP_R + 0.7), 0.23)
	# 램프 옆 라바콘
	for side: float in [-1.0, 1.0]:
		for z: float in [6.0, 14.0, 22.0]:
			_cone(Vector3(RAMP_X + side * (RAMP_W / 2 + 0.8), 0, z))
	# 입술에서 튀어 나가 떨어지는 차가 밤하늘에 묻히지 않게, 큰길 건너편(녹화 카메라 뒤)에서 램프 앞쪽을 비추는 조명 둘
	_floodlight(Vector3(RAMP_X - 20.0, 0.8, 12.0), Vector3(RAMP_X, 9.0, 19.0))
	_floodlight(Vector3(RAMP_X - 20.0, 0.8, 26.0), Vector3(RAMP_X, 13.0, 25.0))


## 바닥에 놓인 투광등(밤 시연장이라 공중의 차가 그늘에 묻히지 않게)
func _floodlight(at: Vector3, target: Vector3) -> void:
	var lamp := SpotLight3D.new()
	add_child(lamp)
	lamp.look_at_from_position(at, target, Vector3.UP)
	lamp.light_color = Color(0.85, 0.9, 1.0)
	lamp.light_energy = 8.0
	lamp.spot_range = 45.0
	lamp.spot_angle = 26.0
	_add_block(at - Vector3(0.45, 0.7, 0.3), at + Vector3(0.45, 0.3, 0.3), "steel")
	var face := (target - at)
	face.y = 0.0
	_add_visual(Transform3D(Basis.IDENTITY, at + face.normalized() * 0.31), Vector3(0.7, 0.45, 0.7) * Vector3(1, 1, 0.03), _material("lamp"))


func _beam(a: Vector3, b: Vector3, thick: float) -> void:
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD) if absf(up.dot(Vector3.FORWARD)) < 0.9 else up.cross(Vector3.RIGHT)
	var bb := Basis(side.normalized(), up, side.normalized().cross(up)).orthonormalized()
	_add_box(Transform3D(bb, (a + b) * 0.5), Vector3(thick, a.distance_to(b), thick), _material("steel"))


func _cone(p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.22
	mesh.height = 0.6
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.material_override = _material("yellow")
	mi.position = p + Vector3(0, 0.38, 0)
	add_child(mi)
	_add_visual(Transform3D(Basis.IDENTITY, p + Vector3(0, 0.04, 0)), Vector3(0.52, 0.08, 0.52), _material("steel"))


## 길과 나란히(앞이 +Z) 세운 일반형 차. 충돌은 차체·실내 상자 둘(크기는 scripts/prop_vehicle.gd의 실루엣).
## 보이는 것은 Tripo 모델(세단·해치백·SUV)을 그 충돌 상자 안에 들어가게 줄여 CarPaint 색으로 칠한다. 모델이 없으면 코드 소품 차.
func _add_car_z(x: float, z: float, kind: String, paint: String) -> void:
	var spec: Dictionary = PropVehicle.PROFILES[kind]
	var L: float = spec.length
	var W: float = spec.width
	var belt: float = spec.belt
	var roof := 0.0
	for pt: Array in spec.points:
		roof = maxf(roof, pt[1])
	var model_name: String = {"sedan": "sedan", "hatch": "hatchback", "suv": "suv"}[kind]
	if not _tripo(model_name, Vector3(x, 0, z), Vector3(W, roof, L), paint):
		var car := PropVehicle.car(kind, PAINTS.get(paint, Color(0.5, 0.52, 0.55)))
		car.position = Vector3(x, 0, z)
		add_child(car)
	_add_collider(Vector3(x, (PropVehicle.CLEARANCE + belt) * 0.5, z), Vector3(W, belt - PropVehicle.CLEARANCE, L))
	_add_collider(Vector3(x, (belt + roof) * 0.5, z - L * 0.02), Vector3(W * 0.8, roof - belt, L * 0.42))


## Tripo 모델을 바닥 가운데 at에 앞 +Z로 세운다. 폭·높이·길이가 fit 안에 들어가게 같은 비율로 줄이거나 키운다. 모델이 없으면 false
func _tripo(model_name: String, at: Vector3, fit: Vector3, paint := "") -> bool:
	var path := "res://assets/models/%s/%s.glb" % [model_name, model_name]
	if not ResourceLoader.exists(path):
		return false
	var n: Node3D = (load(path) as PackedScene).instantiate()
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(path.get_basename() + ".json"))
	var size: Vector3 = Vector3(meta.size_m[0], meta.size_m[1], meta.size_m[2]) if meta is Dictionary else fit
	var k := minf(fit.x / size.x, minf(fit.y / size.y, fit.z / size.z))
	n.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), at)
	add_child(n)
	if paint != "":
		CarPaint.paint(n, model_name, paint)
	return true


func _add_collider(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _build_lane() -> void:
	for side: float in [-1.0, 1.0]:
		var x := LANE_X + side * 3.4
		_flat(x - 0.05, -18, x + 0.05, 50, 0.03, "white")
	# 웹 시연과 같은 회청색 계열 세 대: 세단, 해치백, SUV
	var cars := [["sedan", "slate_blue"], ["hatch", "gunmetal"], ["suv", "champagne"]]
	for i in OBSTACLE_Z.size():
		_add_car_z(LANE_X + (-0.35 if i % 2 == 0 else 0.35), OBSTACLE_Z[i], cars[i][0], cars[i][1])
	# 박스 트럭: 짐칸 + 앞쪽(먼 쪽) 운전석
	# Tripo 택배 트럭(없으면 코드 소품). 충돌 상자 셋이 덮는 6.8 x 3.15 x 2.5m 안에 들어가게
	if not _tripo("semi_truck", Vector3(LANE_X, 0, TRUCK_Z + 0.1), Vector3(2.5, 3.15, 6.8)):
		var truck := PropVehicle.box_truck(Color(0.78, 0.81, 0.84), Color(0.2, 0.27, 0.32))
		truck.position = Vector3(LANE_X, 0, TRUCK_Z)
		add_child(truck)
	_add_collider(Vector3(LANE_X, 1.85, TRUCK_Z - 0.95), Vector3(2.5, 2.6, 4.7))
	_add_collider(Vector3(LANE_X, 1.32, TRUCK_Z + 2.45), Vector3(2.3, 2.05, 2.1))
	_add_collider(Vector3(LANE_X, 0.5, TRUCK_Z + 0.15), Vector3(1.9, 0.4, 6.6))
	# 뛰어오른 차를 비추는 투광등 둘(길 바깥)
	for side: float in [-1.0, 1.0]:
		_floodlight(Vector3(LANE_X + side * 7.0, 0.7, 2.0), Vector3(LANE_X, 8.0, 20.0))
	# 주황 착지 칸
	for side: float in [-1.0, 1.0]:
		_flat(LANE_X + side * 3.0 - 0.06, LANDING_Z - 4, LANE_X + side * 3.0 + 0.06, LANDING_Z + 4, 0.035, "yellow")
		_flat(LANE_X - 3.0, LANDING_Z + side * 4.0 - 0.06, LANE_X + 3.0, LANDING_Z + side * 4.0 + 0.06, 0.035, "yellow")
	# 길 양옆 라바콘
	for z: float in [-10.0, -2.0, 6.0, 14.0, 22.0, 30.0, 38.0, 46.0]:
		for side: float in [-1.0, 1.0]:
			_cone(Vector3(LANE_X + side * 4.0, 0, z))


func _build_props() -> void:
	# 방호벽(반사띠)
	for side: float in [-1.0, 1.0]:
		for z: float in [-30.0, -24.0, 56.0]:
			_add_block(Vector3(side * 16 - 2.25, 0, z - 0.35), Vector3(side * 16 + 2.25, 0.7, z + 0.35), "steel")
			_add_visual(Transform3D(Basis.IDENTITY, Vector3(side * 16, 0.54, z - 0.37)), Vector3(3.9, 0.13, 0.025), _material("edge"))
	# 가로등
	for z: float in [-20.0, 2.0, 24.0, 46.0, 68.0, 90.0]:
		for side: float in [-1.0, 1.0]:
			var x := side * 25.0
			_add_block(Vector3(x - 0.09, 0, z - 0.09), Vector3(x + 0.09, 9, z + 0.09), "steel")
			_add_visual(Transform3D(Basis.IDENTITY, Vector3(x - side * 1.7, 8.95, z)), Vector3(3.6, 0.16, 0.24), _material("steel"))
			_add_visual(Transform3D(Basis.IDENTITY, Vector3(x - side * 2.2, 8.81, z)), Vector3(2.2, 0.08, 0.56), _material("lamp"))
	# 먼 시험 시설(낮은 건물)
	for i in 9:
		var h := 3.0 + float(i * 7 % 5)
		var w := 6.0 + float(i % 3) * 3.0
		var x := -64.0 + i * 16.0
		_add_block(Vector3(x - w / 2, 0, 106.5), Vector3(x + w / 2, h, 113.5), "steel")


## [x, z, 방향(도), 제목, 폭, 길이]
func _build_pads() -> void:
	var defs := [
		[RAMP_X, -8.0, 0.0, "램프 출발", 3.0, 4.4],
		[RAMP_X, 8.0, 180.0, "램프 착지", 6.0, 8.0], # 입술에서 튀어 나가 약 13m 앞에 내려 구름 밖으로 나온 자리
		[LANE_X, -12.0, 0.0, "킥플립 출발", 3.0, 4.4],
		[LANE_X, LANDING_Z, 0.0, "킥플립 착지", 6.0, 8.0],
	]
	for i in defs.size():
		var d: Array = defs[i]
		var pad := ParkingPad.new()
		pad.index = i
		pad.title = d[3]
		pad.is_finish = i == defs.size() - 1
		pad.size = Vector2(d[4], d[5])
		pad.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(d[2])), Vector3(d[0], 0, d[1]))
		add_child(pad)
		pads.append(pad)
