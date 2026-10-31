class_name PropVehicle
## 세워 둔 차·트럭 소품(보이는 것만, 충돌은 만드는 쪽이 따로 단다). 실제 상표 차가 아니라 일반형.
## 옆모습(앞뒤 위치별 지붕 높이)을 따라 단면을 이어 붙여 차체를 만들고, 허리선 위 유리 부분은 어두운 유리색으로 칠한다.
## 앞은 +Z, 바닥은 y=0. Tripo로 만든 주차 차가 생기면 그걸로 바꾼다.

## 옆모습: [뒤(0)~앞(1) 위치, 지붕(위) 높이]. 허리선(belt)보다 높은 구간이 유리창.
const PROFILES := {
	"sedan": {"length": 4.6, "width": 1.82, "belt": 0.92, "points": [
		[0.0, 0.62], [0.04, 0.82], [0.12, 0.9], [0.24, 0.92], [0.33, 1.26], [0.43, 1.42],
		[0.62, 1.42], [0.73, 1.04], [0.8, 0.93], [0.95, 0.84], [1.0, 0.62]]},
	"hatch": {"length": 4.1, "width": 1.78, "belt": 0.94, "points": [
		[0.0, 0.66], [0.03, 0.95], [0.08, 1.38], [0.2, 1.47], [0.58, 1.47], [0.7, 1.06],
		[0.78, 0.95], [0.94, 0.86], [1.0, 0.64]]},
	"suv": {"length": 4.7, "width": 1.92, "belt": 1.12, "points": [
		[0.0, 0.8], [0.03, 1.12], [0.06, 1.7], [0.2, 1.78], [0.62, 1.78], [0.73, 1.26],
		[0.8, 1.14], [0.95, 1.04], [1.0, 0.8]]},
}
const CLEARANCE := 0.3
const GLASS := Color(0.05, 0.06, 0.08)


static func car(kind: String, paint: Color) -> Node3D:
	var spec: Dictionary = PROFILES[kind]
	var root := Node3D.new()
	root.name = "Car_" + kind
	var body := MeshInstance3D.new()
	body.mesh = _loft(spec, paint)
	body.material_override = _vertex_mat(0.35, 0.3)
	root.add_child(body)
	var L: float = spec.length
	var W: float = spec.width
	var r := 0.34 if kind != "suv" else 0.38
	for zs: float in [1.0, -1.0]:
		for xs: float in [1.0, -1.0]:
			root.add_child(_wheel(Vector3(xs * (W / 2 - 0.13), r, zs * (L / 2 - 0.85)), r, 0.24))
	var lamp_y: float = spec.points[spec.points.size() - 2][1] - 0.12
	for xs: float in [1.0, -1.0]:
		root.add_child(_lamp(Vector3(xs * (W / 2 - 0.28), lamp_y, L / 2 - 0.02), Color(0.95, 0.97, 1.0), 2.0))
		root.add_child(_lamp(Vector3(xs * (W / 2 - 0.25), spec.points[1][1] - 0.1, -L / 2 + 0.02), Color(0.9, 0.08, 0.1), 1.6))
	return root


## 박스 트럭: 앞(+Z)에 운전석, 뒤에 짐칸. 길이 약 7m
static func box_truck(cargo: Color, cab: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "BoxTruck"
	var cab_spec := {"length": 2.1, "width": 2.3, "belt": 1.55, "points": [
		[0.0, 2.35], [0.55, 2.35], [0.78, 1.62], [0.92, 1.42], [1.0, 1.0]]}
	var cab_mi := MeshInstance3D.new()
	cab_mi.mesh = _loft(cab_spec, cab, 0.45)
	cab_mi.material_override = _vertex_mat(0.4, 0.25)
	cab_mi.position = Vector3(0, 0, 2.45)
	root.add_child(cab_mi)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.5, 2.6, 4.7)
	box.mesh = bm
	box.material_override = _plain(cargo, 0.6)
	box.position = Vector3(0, 0.55 + 1.3, -0.95)
	root.add_child(box)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(2.52, 0.18, 4.5)
	stripe.mesh = sm
	stripe.material_override = _plain(cab, 0.5)
	stripe.position = Vector3(0, 1.2, -0.95)
	root.add_child(stripe)
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.9, 0.3, 6.6)
	frame.mesh = fm
	frame.material_override = _plain(Color(0.1, 0.1, 0.12), 0.7)
	frame.position = Vector3(0, 0.55, 0.15)
	root.add_child(frame)
	for z: float in [2.55, -1.9, -3.0]:
		for xs: float in [1.0, -1.0]:
			root.add_child(_wheel(Vector3(xs * 1.05, 0.48, z), 0.48, 0.32))
	for xs: float in [1.0, -1.0]:
		root.add_child(_lamp(Vector3(xs * 0.85, 0.85, 3.47), Color(0.95, 0.97, 1.0), 2.0))
		root.add_child(_lamp(Vector3(xs * 1.05, 0.9, -3.32), Color(0.9, 0.08, 0.1), 1.6))
	return root


## 옆모습을 따라 단면을 이어 붙인다. 단면 8점: 바닥 양끝, 허리선, 유리 아래·위 모서리.
static func _loft(spec: Dictionary, paint: Color, y0 := CLEARANCE) -> ArrayMesh:
	var L: float = spec.length
	var W: float = spec.width
	var belt: float = spec.belt
	var pts: Array = spec.points
	var rings: Array = []
	var glassy: Array = []
	for p: Array in pts:
		var t: float = p[0]
		var top: float = p[1]
		var z := -L / 2 + t * L
		var w := W / 2 * (0.93 + 0.07 * sin(PI * clampf(t, 0.0, 1.0)))
		var green := top > belt + 0.12 # 이 단면 위쪽은 유리창
		var yb := minf(belt, top - 0.06)
		var wt := w * (0.8 if green else 0.97)
		var wt2 := wt - 0.07
		rings.append([
			Vector3(-w, y0, z), Vector3(-w, yb, z), Vector3(-wt, top - 0.06, z), Vector3(-wt2, top, z),
			Vector3(wt2, top, z), Vector3(wt, top - 0.06, z), Vector3(w, yb, z), Vector3(w, y0, z)])
		glassy.append(green)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in 8:
			var k2 := (k + 1) % 8
			# 옆 유리(1→2, 5→6)와 앞뒤 유리(지붕 아래 경사)는 두 단면이 다 유리일 때만
			var glass_band: bool = (k == 1 or k == 5) and (glassy[i] or glassy[i + 1])
			var slope_glass: bool = (k == 2 or k == 3 or k == 4) and (glassy[i] != glassy[i + 1])
			var col := GLASS if glass_band or slope_glass else paint
			_quad(st, a[k], a[k2], b[k2], b[k], col)
	for cap in [[rings[0], true], [rings[rings.size() - 1], false]]:
		var ring: Array = cap[0]
		var c := Vector3.ZERO
		for v: Vector3 in ring:
			c += v / 8.0
		for k in 8:
			var k2 := (k + 1) % 8
			st.set_color(paint)
			if cap[1]: # 뒤 끝(-Z를 본다)
				st.add_vertex(c); st.add_vertex(ring[k2]); st.add_vertex(ring[k])
			else: # 앞 끝(+Z를 본다)
				st.add_vertex(c); st.add_vertex(ring[k]); st.add_vertex(ring[k2])
	st.generate_normals()
	return st.commit()


## Godot는 시계 방향이 앞면이다: 바깥에서 보면 a → b → c → d가 시계 방향이 되게 감는다
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)


static func _wheel(pos: Vector3, r: float, w: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = Vector3(0, 0, PI / 2)
	var tire := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = r
	tm.bottom_radius = r
	tm.height = w
	tm.radial_segments = 18
	tire.mesh = tm
	tire.material_override = _plain(Color(0.06, 0.06, 0.07), 0.9)
	n.add_child(tire)
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = r * 0.55
	hm.bottom_radius = r * 0.55
	hm.height = w + 0.03
	hm.radial_segments = 12
	hub.mesh = hm
	hub.material_override = _plain(Color(0.62, 0.64, 0.68), 0.35, 0.7)
	n.add_child(hub)
	return n


static func _lamp(pos: Vector3, col: Color, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.1, 0.04)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	mi.material_override = m
	mi.position = pos
	return mi


static func _vertex_mat(rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic = metal
	return m


static func _plain(col: Color, rough: float, metal := 0.1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m
