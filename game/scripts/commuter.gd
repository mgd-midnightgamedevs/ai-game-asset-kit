class_name Commuter extends Node3D
## 출근길 사람. 걷기, 발 구르기(화내기), 말풍선, 김 나기만 한다.
## 겉모습 두 벌: 원기둥·구체로 만든 처음 사람(_rig)과 Tripo 리깅 모델(model_name, assets/models/<이름>).
## set_look()으로 바꾼다(차의 M 키를 따라간다). 모델은 걸을 때 "walk", 발 구를 때 화내는 동작들을 번갈아 튼다.

const FONT := preload("res://fonts/Pretendard-Bold.otf")
## 모델마다 walk 동작(1배속)에서 땅을 디딘 발이 뒤로 가는 속도(m/s, 모델 크기 기준). 걷는 속도에 맞춰 재생 속도를 정해 발이 미끄러지지 않게 한다
const STANCE_SPEED := {"me": 1.07, "karen": 0.94}
const ANGRY_ANIMS := ["angry_01", "complain_01"] ## 있는 것만 차례로 튼다

var body_color := Color(0.16, 0.2, 0.32)
var skin_color := Color(0.95, 0.78, 0.62)
var has_briefcase := false
var model_name := "" ## 비우면 원기둥 사람만 만든다. "me"는 모델이 서류 가방을 들고 있다
var show_model := false

var _rig: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _angry: Array[String] = []
var _angry_i := 0
var _briefcase: Node3D
var _bubble: Label3D
var _steam: CPUParticles3D
var _path: Array[Vector3] = []
var _speed := 1.8
var _walk_t := 0.0
var _stomp := false
var _stomp_t := 0.0
var _bubble_left := 0.0


func _ready() -> void:
	_rig = Node3D.new()
	add_child(_rig)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = 1.15
	body.mesh = cap
	body.material_override = _mat(body_color)
	body.position = Vector3(0, 0.6, 0)
	_rig.add_child(body)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.17
	sph.height = 0.34
	head.mesh = sph
	head.material_override = _mat(skin_color)
	head.position = Vector3(0, 1.36, 0)
	_rig.add_child(head)
	if has_briefcase:
		_briefcase = Node3D.new()
		_briefcase.position = Vector3(0.32, 0.55, 0)
		var bc := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.28, 0.38)
		bc.mesh = bm
		bc.material_override = _mat(Color(0.35, 0.2, 0.1))
		bc.position = Vector3(0, -0.12, 0)
		_briefcase.add_child(bc)
		_rig.add_child(_briefcase)

	_bubble = Label3D.new()
	_bubble.font = FONT
	_bubble.font_size = 64
	_bubble.pixel_size = 0.0022 # fixed_size라 거리와 상관없이 화면에서 같은 크기
	_bubble.fixed_size = true
	_bubble.outline_size = 18
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.position = Vector3(0, 3.4, 0)
	_bubble.visible = false
	add_child(_bubble)

	_steam = CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.1
	puff.height = 0.2
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.vertex_color_use_as_albedo = true
	puff.material = pm
	_steam.mesh = puff
	_steam.amount = 14
	_steam.lifetime = 0.8
	_steam.emitting = false
	_steam.direction = Vector3.UP
	_steam.spread = 25.0
	_steam.gravity = Vector3.ZERO
	_steam.initial_velocity_min = 1.2
	_steam.initial_velocity_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.85))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	_steam.color_ramp = ramp
	_steam.position = Vector3(0, 1.6, 0)
	add_child(_steam)

	if model_name != "":
		_model = AssetCache.model(model_name).instantiate()
		add_child(_model)
		_anim = _model.find_child("AnimationPlayer", true, false)
		_anim.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
		for a: String in ANGRY_ANIMS:
			if _anim.has_animation(a):
				_angry.append(a)
		_anim.play("walk") # 서 있는 자세(T자 기본 자세 대신 걸음 첫 장면)
		_anim.seek(0.0, true)
		_anim.pause()
	set_look(show_model)


## true면 Tripo 모델, false면 원기둥 사람. 모델이 없으면 늘 원기둥 사람.
func set_look(model: bool) -> void:
	show_model = model and _model != null
	_rig.visible = not show_model
	if _model:
		_model.visible = show_model
	_steam.position.y = 2.0 if show_model else 1.6 # 모델은 머리가 더 높다


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m


func walk_to(points: Array[Vector3], speed := 1.8) -> void:
	_path = points.duplicate()
	_speed = speed


func is_walking() -> bool:
	return not _path.is_empty()


func stomp(on: bool) -> void:
	_stomp = on
	_steam.emitting = on


func say(text: String, seconds := 2.5) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_left = seconds


func _process(delta: float) -> void:
	if not _path.is_empty():
		var target: Vector3 = _path[0]
		var to := target - global_position
		to.y = 0.0
		if to.length() < 0.08:
			_path.remove_at(0)
		else:
			var step := minf(_speed * delta, to.length())
			global_position += to.normalized() * step
			global_position.y = lerpf(global_position.y, target.y, 0.2)
			look_at(global_position - to.normalized(), Vector3.UP) # +Z가 앞
		if _anim and (_anim.current_animation != "walk" or not _anim.is_playing()):
			_anim.play("walk", 0.2)
		if _anim:
			_anim.speed_scale = _speed / (STANCE_SPEED.get(model_name, 1.0) * global_basis.get_scale().x)
		_walk_t += delta * 9.0
		_rig.position.y = absf(sin(_walk_t)) * 0.08
		_rig.rotation.z = sin(_walk_t) * 0.06
		if _briefcase:
			_briefcase.rotation.x = sin(_walk_t) * 0.35
	elif _stomp:
		if _anim and (_anim.current_animation == "walk" or not _anim.is_playing()) and not _angry.is_empty():
			_anim.speed_scale = 1.0
			_anim.play(_angry[_angry_i % _angry.size()], 0.25)
			_angry_i += 1
		_stomp_t += delta * 14.0
		_rig.position.y = absf(sin(_stomp_t)) * 0.22
		_rig.scale = Vector3(1.0 + 0.08 * cos(_stomp_t * 2.0), 1.0 - 0.08 * cos(_stomp_t * 2.0), 1.0)
		_rig.rotation.y = sin(_stomp_t * 0.5) * 0.4
	else:
		if _anim and _anim.current_animation == "walk" and _anim.is_playing():
			_anim.pause()
		_rig.position.y = lerpf(_rig.position.y, 0.0, 0.2)
		_rig.rotation.z = lerpf(_rig.rotation.z, 0.0, 0.2)
	if _bubble_left > 0.0:
		_bubble_left -= delta
		_bubble.visible = _bubble_left > 0.0
