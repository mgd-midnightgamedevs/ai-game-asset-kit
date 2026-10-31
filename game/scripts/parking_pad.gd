class_name ParkingPad extends Node3D
## 옥상 주차 패드. 차가 칸 안에 방향을 맞춰 멈춰 있으면 charge가 차오르고, 다 차면 주차 완료.
## 원점은 패드 표면 중앙, +Z가 주차 방향(화살표).

enum State { IDLE, NEXT, CHARGED }

const COL_IDLE := Color(1.0, 0.82, 0.2)
const COL_NEXT := Color(0.25, 0.85, 1.0)
const COL_DONE := Color(0.35, 0.95, 0.45)
const COL_FINISH := Color(1.0, 0.55, 0.15)
const FONT := preload("res://fonts/Pretendard-Bold.otf")
const MAX_HEADING_DEG := 25.0

var index := 0
var size := Vector2(3.0, 4.4) ## x 폭, z 길이. 로드스터(1.46 x 2.75)도 옆 0.77m·앞뒤 0.8m씩 남는다
var is_finish := false
var title := ""

var state := State.IDLE
var charge := 0.0
var latched := false ## 이번 주차로 이미 충전했으면 차가 떠날 때까지 다시 충전하지 않는다

var _mat_surface := StandardMaterial3D.new()
var _mat_line := StandardMaterial3D.new()
var _mat_beam := StandardMaterial3D.new()
var _mat_fill := StandardMaterial3D.new()
var _fill: MeshInstance3D
var _beam: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	for m in [_mat_surface, _mat_line, _mat_beam, _mat_fill]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_fill.albedo_color = Color(1, 1, 1, 1)
	_build()
	set_state(state)


func _build() -> void:
	_add_box(Vector3(size.x, 0.02, size.y), Vector3(0, 0.03, 0), _mat_surface)
	var w := 0.14
	_add_box(Vector3(w, 0.03, size.y), Vector3(-size.x / 2 + w / 2, 0.05, 0), _mat_line)
	_add_box(Vector3(w, 0.03, size.y), Vector3(size.x / 2 - w / 2, 0.05, 0), _mat_line)
	_add_box(Vector3(size.x, 0.03, w), Vector3(0, 0.05, -size.y / 2 + w / 2), _mat_line)
	_add_box(Vector3(size.x, 0.03, w), Vector3(0, 0.05, size.y / 2 - w / 2), _mat_line)

	var arrow := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.9, 0.9, 0.03)
	arrow.mesh = prism
	arrow.material_override = _mat_line
	arrow.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.05, size.y / 2 - 0.75))
	add_child(arrow)

	_fill = _add_box(Vector3(size.x - 0.4, 0.02, 1.0), Vector3(0, 0.06, 0), _mat_fill)
	_fill.visible = false

	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.6
	cyl.height = 60.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam.mesh = cyl
	_beam.material_override = _mat_beam
	_beam.position = Vector3(0, 30.0, 0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)

	_label = Label3D.new()
	_label.font = FONT
	_label.font_size = 64
	_label.pixel_size = 0.01
	_label.outline_size = 18
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = false
	_label.no_depth_test = false
	_label.position = Vector3(0, 2.6, 0)
	_label.text = title
	add_child(_label)


func _add_box(box_size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func set_state(s: State) -> void:
	state = s
	var col := COL_IDLE
	if is_finish:
		col = COL_FINISH
	if s == State.NEXT:
		col = COL_NEXT if not is_finish else COL_FINISH
	elif s == State.CHARGED:
		col = COL_DONE
	_mat_surface.albedo_color = Color(col, 0.35)
	_mat_line.albedo_color = col
	_mat_fill.albedo_color = col.lightened(0.4)
	_mat_beam.albedo_color = Color(col, 0.28 if s == State.NEXT else 0.1)
	_beam.visible = s != State.CHARGED
	_label.modulate = col.lightened(0.3)
	_label.visible = s != State.CHARGED


func reset() -> void:
	charge = 0.0
	latched = false
	set_state(State.IDLE)


func spawn_transform() -> Transform3D:
	return global_transform


func car_inside(car: Roadster) -> bool:
	var inv := global_transform.affine_inverse()
	var local := inv * car.get_vehicle_position()
	if local.y < -0.6 or local.y > 1.2:
		return false
	var rel: Basis = global_basis.inverse() * car.vehicle_model.global_basis
	if absf(rel.z.normalized().z) < cos(deg_to_rad(MAX_HEADING_DEG)):
		return false
	var half := car.footprint # 차체 반폭·반길이·가운데 z(겉모습마다 다르다)
	var mid := local + rel.z * half.z
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p: Vector3 = mid + rel.x * half.x * sx + rel.z * half.y * sz
			if absf(p.x) > size.x / 2 or absf(p.z) > size.y / 2:
				return false
	return true


func update_fill() -> void:
	_fill.visible = charge > 0.01 and not latched
	if _fill.visible:
		var length := (size.y - 0.4) * charge
		_fill.scale = Vector3(1, 1, maxf(length, 0.01))
		_fill.position = Vector3(0, 0.06, -size.y / 2 + 0.2 + length / 2)
