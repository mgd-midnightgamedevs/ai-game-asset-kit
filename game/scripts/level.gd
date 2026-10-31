extends Node3D
## 박스만으로 만든 시연장 한 바퀴. 실제 로켓 로드스터 시연의 순서를 게임 구간으로 옮겼다.
##   출발(P0) → 세워 둔 차 5대 넘기(킥플립) → P1
##   → 주차 데크 아래를 지나 끝의 '말려 올라가는 램프'에서 거꾸로 튀어 나감 → 뒤집어 착지 → 데크 위 P2
##   → 옆 건물 옥상으로 추진기 점프 → P3(15m)
##   → 쿼터파이프로 타워 벽을 타고 올라 모서리에서 튀어 나감(또는 추진기로 바로) → 결승 P4(30m)
## 흡착 팬은 곡면만 따라간다. 각진 모서리에서는 떨어져 나가므로 그때 추진기로 자세를 잡는다.
## Tripo 에셋으로 바꿀 때는 이 데이터의 상자 위치에 모델을 얹는다.

const GRID_SHADER := preload("res://shaders/grid.gdshader")

## [x0, y0, z0, x1, y1, z1, 색 키]
const BLOCKS := [
	# 출발 직선로 양옆 콘크리트 방호벽
	[-6.1, 0, 6, -5.5, 1.2, 47, "concrete"],
	[5.5, 0, 6, 6.1, 1.2, 47, "concrete"],
	# 주차 데크(아래로 지나간다)
	[-8, 6.2, 52, 8, 7, 78, "deck"],
	[-7.8, 0, 52, -7, 6.2, 52.8, "concrete"],
	[7, 0, 52, 7.8, 6.2, 52.8, "concrete"],
	[-7.8, 0, 64.6, -7, 6.2, 65.4, "concrete"],
	[7, 0, 64.6, 7.8, 6.2, 65.4, "concrete"],
	[-7.8, 0, 77.2, -7, 6.2, 78, "concrete"],
	[7, 0, 77.2, 7.8, 6.2, 78, "concrete"],
	# 옆 건물(B3)과 타워(B4), 그 사이 다리
	[12, 0, 54, 26, 15, 70, "building"],
	[26, 14, 59, 30, 15, 65, "concrete"],
	[30, 0, 55, 40, 30, 69, "tower"],
]

## 곡면 램프: [평면("z"는 z-y, "x"는 x-y), 원 중심(a, y), 반지름, 시작각, 끝각, 조각 수, 폭, 옆 중심, 색 키]
## 진행 방향 +a, 각도 0이 바닥(수평), 90이 수직 벽, 180이 천장.
const ARCS := [
	["z", Vector2(80, 4.5), 4.5, 0.0, 135.0, 36, 6.0, 0.0, "curl"], # 말려 올라가는 램프(데크 끝)
	["x", Vector2(27, 18), 3.0, 0.0, 90.0, 24, 6.0, 62.0, "curl"], # 타워 벽으로 이어지는 쿼터파이프
]

## [종류, z 중심] — 차 길이 방향이 x축(통로를 가로막게) 놓인다. 실제 상표 차가 아닌 일반형.
const VEHICLES := [
	["robotaxi", 22.0],
	["pickup", 24.8],
	["semi", 28.0],
	["suv", 31.2],
	["sedan", 33.8],
]
const VEHICLE_SPECS := {
	# [길이(x), 폭(z), 차체 높이, 실내 높이, 색]
	"robotaxi": [3.6, 1.9, 1.0, 0.5, Color(0.86, 0.86, 0.88)],
	"pickup": [5.6, 2.1, 1.3, 0.7, Color(0.62, 0.64, 0.67)],
	"semi": [9.6, 2.6, 3.0, 1.0, Color(0.9, 0.9, 0.92)],
	"suv": [4.8, 2.0, 1.1, 0.6, Color(0.2, 0.22, 0.27)],
	"sedan": [4.7, 1.9, 0.9, 0.55, Color(0.7, 0.12, 0.12)],
}

## [x, y, z, 방향(도, +Z 기준 +X 쪽으로), 제목, (선택) 폭, 길이]
const PADS := [
	[0, 0, 0, 0, "출발"],
	[0, 0, 44, 0, "P1 · 킥플립"],
	[0, 7, 66.5, 180, "P2 · 데크 7m", 4.5, 6.0], # 뒤집어 착지한 뒤 바로 들어가는 칸이라 넓게
	[21, 15, 62, 90, "P3 · 옥상 15m"],
	[36.5, 30, 62, 90, "결승 · 타워 30m"],
]

const COLORS := {
	"ground": [Color(0.16, 0.17, 0.2), Color(0.24, 0.25, 0.3)],
	"concrete": [Color(0.55, 0.55, 0.56), Color(0.42, 0.42, 0.44)],
	"deck": [Color(0.46, 0.48, 0.52), Color(0.35, 0.37, 0.41)],
	"building": [Color(0.62, 0.58, 0.54), Color(0.46, 0.43, 0.4)],
	"tower": [Color(0.5, 0.54, 0.62), Color(0.36, 0.39, 0.46)],
	"curl": [Color(0.86, 0.45, 0.16), Color(0.62, 0.3, 0.1)],
	"filler": [Color(0.24, 0.27, 0.36), Color(0.19, 0.21, 0.29)],
}
const KEEP_CLEAR := Rect2(-14, -14, 60, 110) ## x, z, 폭, 깊이: 배경 건물을 놓지 않는 구역

var pads: Array[ParkingPad] = []
var _materials := {}


func _ready() -> void:
	_add_block(Vector3(-200, -1, -120), Vector3(200, 0, 260), "ground")
	for b in BLOCKS:
		_add_block(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), b[6])
	for a in ARCS:
		_add_arc(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
	for v in VEHICLES:
		_add_vehicle(v[0], v[1])
	_add_fillers()
	_add_pads()


func _material(key: String) -> Material:
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = GRID_SHADER
		m.set_shader_parameter("base_color", COLORS[key][0])
		m.set_shader_parameter("line_color", COLORS[key][1])
		_materials[key] = m
	return _materials[key]


func _plain(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.4
	m.metallic = 0.2
	return m


func _add_block(a: Vector3, b: Vector3, key: String, mat: Material = null) -> StaticBody3D:
	var size := (b - a).abs()
	var center := (a + b) * 0.5
	return _add_box(Transform3D(Basis.IDENTITY, center), size, mat if mat != null else _material(key))


func _add_box(xform: Transform3D, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = xform
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)
	return body


## 원호를 얇은 상자 조각으로 근사한 곡면. 달리는 면은 원의 안쪽(법선이 중심을 향한다).
func _add_arc(plane: String, center: Vector2, radius: float, from_deg: float, to_deg: float,
		segments: int, width: float, lateral: float, key: String) -> void:
	var thickness := 0.4
	var step := deg_to_rad(to_deg - from_deg) / segments
	var length := 2.0 * radius * sin(step * 0.5) * 1.08
	for i in segments:
		var th := deg_to_rad(from_deg) + step * (i + 0.5)
		var pa := center.x + radius * sin(th)
		var py := center.y - radius * cos(th)
		var n2 := Vector2(-sin(th), cos(th)) # (a, y) 평면의 안쪽 법선
		var t2 := Vector2(cos(th), sin(th))
		var n3: Vector3
		var t3: Vector3
		var p3: Vector3
		if plane == "z":
			n3 = Vector3(0, n2.y, n2.x)
			t3 = Vector3(0, t2.y, t2.x)
			p3 = Vector3(lateral, py, pa)
		else:
			n3 = Vector3(n2.x, n2.y, 0)
			t3 = Vector3(t2.x, t2.y, 0)
			p3 = Vector3(pa, py, lateral)
		var b := Basis(n3.cross(t3), n3, t3)
		_add_box(Transform3D(b, p3 - n3 * (thickness * 0.5)), Vector3(width, thickness, length), _material(key)).set_meta("ramp", true) # 들이받아도 사고로 치지 않는다


func _add_vehicle(kind: String, z: float) -> void:
	var s: Array = VEHICLE_SPECS[kind]
	var length: float = s[0]
	var width: float = s[1]
	var body_h: float = s[2]
	var cabin_h: float = s[3]
	var mat := _plain(s[4])
	var glass := _plain(Color(0.08, 0.1, 0.14))
	var clearance := 0.25
	if kind == "semi":
		# 트레일러 + 앞쪽 운전석
		_add_block(Vector3(-length / 2 + 2.4, clearance + 0.4, z - width / 2), Vector3(length / 2, clearance + 0.4 + body_h, z + width / 2), "", mat)
		_add_block(Vector3(-length / 2, clearance, z - width / 2), Vector3(-length / 2 + 2.2, clearance + 2.6, z + width / 2), "", _plain(Color(0.75, 0.1, 0.1)))
		_add_block(Vector3(-length / 2 + 2.2, clearance, z - 0.3), Vector3(length / 2, clearance + 0.4, z + 0.3), "", glass)
		return
	_add_block(Vector3(-length / 2, clearance, z - width / 2), Vector3(length / 2, clearance + body_h, z + width / 2), "", mat)
	var cabin_len := length * (0.45 if kind != "pickup" else 0.32)
	var cabin_x := 0.0 if kind != "pickup" else -length * 0.18
	_add_block(Vector3(cabin_x - cabin_len / 2, clearance + body_h, z - width / 2 + 0.12),
		Vector3(cabin_x + cabin_len / 2, clearance + body_h + cabin_h, z + width / 2 - 0.12), "", glass)
	# 바퀴 자리(어두운 띠)
	_add_block(Vector3(-length / 2 + 0.4, 0, z - width / 2 + 0.1), Vector3(length / 2 - 0.4, clearance, z + width / 2 - 0.1), "", glass)


func _add_fillers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var placed := 0
	var tries := 0
	while placed < 60 and tries < 600:
		tries += 1
		var w := rng.randf_range(8.0, 16.0)
		var d := rng.randf_range(8.0, 16.0)
		var x := rng.randf_range(-90.0, 110.0)
		var z := rng.randf_range(-60.0, 170.0)
		var r := Rect2(x - w / 2 - 3, z - d / 2 - 3, w + 6, d + 6)
		if r.intersects(KEEP_CLEAR):
			continue
		var h := rng.randf_range(6.0, 45.0)
		_add_block(Vector3(x - w / 2, 0, z - d / 2), Vector3(x + w / 2, h, z + d / 2), "filler")
		placed += 1


func _add_pads() -> void:
	for i in PADS.size():
		var p: Array = PADS[i]
		var pad := ParkingPad.new()
		pad.index = i
		pad.title = p[4]
		pad.is_finish = i == PADS.size() - 1
		if p.size() > 6:
			pad.size = Vector2(p[5], p[6])
		pad.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(p[3])), Vector3(p[0], p[1], p[2]))
		add_child(pad)
		pads.append(pad)
