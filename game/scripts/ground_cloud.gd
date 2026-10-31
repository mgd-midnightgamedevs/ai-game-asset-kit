class_name GroundCloud extends Node3D
## 리프트 노즐의 압축 공기가 바닥에 부딪혀 사방으로 퍼지는 가스 구름.
## 실제 시연에서 착지 직전 차를 통째로 덮던 흰 구름. 차가 바닥 가까이(NEAR m 안)에서 리프트를 뿜을 때만 생긴다.
## 입자는 가장자리가 흐린 둥근 연기 그림(카메라를 보는 판)이고, 세계 좌표에 남아 차가 떠나도 그 자리에서 피어오르며 흩어진다.

const NEAR := 7.5 ## 이 높이보다 낮을 때만 구름이 생긴다(센 분사는 몇 m 위에서도 바닥을 때린다)

static var _mesh: QuadMesh
static var _ramp: Gradient
static var _tint: Gradient
static var _scale: Curve

var _particles: CPUParticles3D


static func _init_shared() -> void:
	if _mesh != null:
		return
	# 가운데가 진하고 가장자리로 갈수록 투명해지는 둥근 연기 한 덩이
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	soft.add_point(0.45, Color(1, 1, 1, 0.7))
	var tex := GradientTexture2D.new()
	tex.gradient = soft
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	var mat := ShaderMaterial.new() # 검은 덩이를 막으려고 표준 재질 대신(shaders/cloud.gdshader)
	mat.shader = preload("res://shaders/cloud.gdshader")
	mat.set_shader_parameter("soft", tex)
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(1.6, 1.6)
	_mesh.material = mat
	_ramp = Gradient.new() # 시간에 따라: 진하게 나왔다가 옅어진다
	_ramp.set_color(0, Color(1, 1, 1, 0.0))
	_ramp.set_color(1, Color(1, 1, 1, 0.0))
	_ramp.add_point(0.06, Color(1, 1, 1, 0.85))
	_ramp.add_point(0.6, Color(1, 1, 1, 0.55))
	_tint = Gradient.new() # 덩이마다 조금씩 다른 흰색·회색(입체감)
	_tint.set_color(0, Color(0.72, 0.75, 0.84))
	_tint.set_color(1, Color(1.0, 1.0, 1.0))
	_scale = Curve.new()
	_scale.add_point(Vector2(0, 1.0))
	_scale.add_point(Vector2(1, 5.5))


func _ready() -> void:
	_init_shared()
	_particles = CPUParticles3D.new()
	_particles.mesh = _mesh
	_particles.amount = 320
	_particles.lifetime = 3.2
	_particles.emitting = false
	_particles.local_coords = false
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 1.4
	_particles.direction = Vector3(1, 0, 0)
	_particles.spread = 180.0
	_particles.flatness = 0.95 # 바닥을 따라 옆으로 깔린다
	_particles.gravity = Vector3(0, 0.3, 0) # 아주 천천히 피어오른다
	_particles.initial_velocity_min = 2.0
	_particles.initial_velocity_max = 10.0
	_particles.damping_min = 2.5
	_particles.damping_max = 4.5
	_particles.angle_min = -180.0
	_particles.angle_max = 180.0
	_particles.angular_velocity_min = -25.0
	_particles.angular_velocity_max = 25.0
	_particles.scale_amount_min = 0.7
	_particles.scale_amount_max = 1.4
	_particles.scale_amount_curve = _scale
	_particles.color_ramp = _ramp
	_particles.color_initial_ramp = _tint
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)


## 매 물리 프레임: 뿜는 중이고 ground(바닥 점)가 가까우면 그 자리에서 구름을 낸다.
func update_cloud(firing: bool, ground: Variant, height: float) -> void:
	var on := firing and ground != null and height < NEAR
	_particles.emitting = on
	if on:
		global_position = ground
		_particles.speed_scale = lerpf(1.3, 0.8, clampf(height / NEAR, 0.0, 1.0)) # 바닥에 가까울수록 세게 퍼진다
