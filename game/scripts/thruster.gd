class_name Thruster extends Node3D
## 냉가스(압축 공기) 추진기 하나. 로컬 -Y로 뿜고, 차는 +Y 쪽으로 밀린다.
## 불꽃이 아니라 흰 공기 분사: 노즐에서 끝으로 흐려지는 기둥(shaders/plume.gdshader)과 금방 흩어지는 수증기.

const PLUME_LENGTH := 1.1
const PLUME_SHADER := preload("res://shaders/plume.gdshader")

var power := 0.0

static var _nozzle_mesh: CylinderMesh
static var _nozzle_mat: StandardMaterial3D
static var _plume_mesh: CylinderMesh
static var _plume_mat: ShaderMaterial
static var _puff_mesh: SphereMesh
static var _puff_mat: StandardMaterial3D
static var _puff_ramp: Gradient
static var _puff_scale: Curve

var _plume: MeshInstance3D
var _puffs: CPUParticles3D


static func _init_shared() -> void:
	if _nozzle_mesh != null:
		return
	_nozzle_mesh = CylinderMesh.new()
	_nozzle_mesh.top_radius = 0.05
	_nozzle_mesh.bottom_radius = 0.075
	_nozzle_mesh.height = 0.1
	_nozzle_mesh.radial_segments = 10
	_nozzle_mat = StandardMaterial3D.new()
	_nozzle_mat.albedo_color = Color(0.2, 0.21, 0.24)
	_nozzle_mat.metallic = 0.7
	_nozzle_mat.roughness = 0.35

	_plume_mesh = CylinderMesh.new()
	_plume_mesh.top_radius = 0.05
	_plume_mesh.bottom_radius = 0.2
	_plume_mesh.height = PLUME_LENGTH
	_plume_mesh.radial_segments = 10
	_plume_mesh.cap_top = false
	_plume_mesh.cap_bottom = false
	_plume_mat = ShaderMaterial.new()
	_plume_mat.shader = PLUME_SHADER

	_puff_mesh = SphereMesh.new()
	_puff_mesh.radius = 0.12
	_puff_mesh.height = 0.24
	_puff_mesh.radial_segments = 8
	_puff_mesh.rings = 4
	_puff_mat = StandardMaterial3D.new()
	_puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff_mat.vertex_color_use_as_albedo = true
	_puff_mesh.material = _puff_mat

	_puff_ramp = Gradient.new()
	_puff_ramp.set_color(0, Color(1, 1, 1, 0.7))
	_puff_ramp.set_color(1, Color(0.85, 0.9, 1.0, 0.0))
	_puff_scale = Curve.new()
	_puff_scale.add_point(Vector2(0, 0.5))
	_puff_scale.add_point(Vector2(1, 2.2))


func _ready() -> void:
	_init_shared()
	var nozzle := MeshInstance3D.new()
	nozzle.mesh = _nozzle_mesh
	nozzle.material_override = _nozzle_mat
	add_child(nozzle)

	_plume = MeshInstance3D.new()
	_plume.mesh = _plume_mesh
	_plume.material_override = _plume_mat
	_plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plume.visible = false
	add_child(_plume)

	_puffs = CPUParticles3D.new()
	_puffs.mesh = _puff_mesh
	_puffs.amount = 18
	_puffs.lifetime = 0.45
	_puffs.emitting = false
	_puffs.local_coords = false
	_puffs.direction = Vector3.DOWN
	_puffs.spread = 10.0
	_puffs.gravity = Vector3.ZERO
	_puffs.initial_velocity_min = 7.0
	_puffs.initial_velocity_max = 10.0
	_puffs.damping_min = 14.0
	_puffs.damping_max = 18.0
	_puffs.scale_amount_curve = _puff_scale
	_puffs.color_ramp = _puff_ramp
	_puffs.position = Vector3(0, -0.08, 0)
	_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_puffs)


## p: 0~1. 매 물리 프레임 호출. stretch(0~1): 공중에서 리프트로 내려앉을 때처럼 길고 굵은 분사 기둥(실제 시연의 착지 분사)
func fire(p: float, stretch := 0.0) -> void:
	power = p
	var on := p > 0.02
	_plume.visible = on
	_puffs.emitting = on
	if on:
		var len_scale := (0.45 + 0.55 * p) * randf_range(0.85, 1.1) * (1.0 + 2.6 * stretch)
		var width := 1.0 + 0.9 * stretch
		_plume.scale = Vector3(width, len_scale, width)
		_plume.position = Vector3(0, -0.05 - PLUME_LENGTH * 0.5 * len_scale, 0)


## 분사 방향(차가 받는 힘의 반대)을 받아 노즐의 -Y가 그쪽을 보게 하는 기저.
static func basis_for_exhaust(exhaust: Vector3) -> Basis:
	var y := -exhaust.normalized()
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
	x = (x - y * x.dot(y)).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)
