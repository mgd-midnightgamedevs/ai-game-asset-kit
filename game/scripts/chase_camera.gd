extends Camera3D
## 세로(9:16) 화면 기준 추적 카메라. 화면 위쪽은 항상 하늘(세계 위쪽)이다.
## CHASE: 바닥에서는 차 뒤를 따라가고, 벽에 붙으면 벽 바깥으로 물러나 올려다보며,
##        천장에 붙으면 아래에서 올려다본다. 벽을 '오르는' 장면이 화면에 그대로 보이게 하려는 것.
##        (벽에서는 좌우 조향이 화면과 같고, 천장에서만 좌우가 뒤집혀 보인다.)
## SHOWCASE: 비스듬히 멀리서 본다(높이·건물 전체 촬영용). C 키로 전환.

enum Mode { CHASE, SHOWCASE }

@export var target: Roadster
@export var chase_distance := Vector2(5.2, 8.5) ## 정지 ~ 고속
@export var chase_height_ratio := 0.42
@export var wall_out := 7.0 ## 벽·천장에서 면 바깥으로 떨어지는 거리
@export var wall_back := 3.5 ## 벽·천장에서 진행 반대쪽으로 물러나는 거리
@export var showcase_distance := 16.0

var mode := Mode.CHASE
var _n := Vector3.UP ## 부드럽게 따라가는 '붙은 면'의 법선
var _fwd := Vector3.BACK # 차의 앞은 +Z
var _flat_fwd := Vector3.BACK
var _dist := 7.0


func _ready() -> void:
	get_viewport().size_changed.connect(_update_aspect)
	_update_aspect()
	snap()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera"):
		mode = Mode.SHOWCASE if mode == Mode.CHASE else Mode.CHASE


func _update_aspect() -> void:
	var s := get_viewport().get_visible_rect().size
	if s.y > s.x:
		keep_aspect = Camera3D.KEEP_WIDTH # 세로 화면: 가로 시야를 고정해 좌우가 잘리지 않게
		fov = 62.0
	else:
		keep_aspect = Camera3D.KEEP_HEIGHT
		fov = 60.0


func snap() -> void:
	if target == null:
		return
	_n = target.up_dir if target.attached else Vector3.UP
	var b: Basis = target.vehicle_model.global_basis
	_fwd = _flatten(b.z, _n, _fwd)
	_flat_fwd = _flatten(b.z, Vector3.UP, _flat_fwd)
	global_position = _desired()
	_look()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var want_n := target.up_dir if target.attached else Vector3.UP
	if _n.dot(want_n) < -0.98:
		want_n = (want_n + _fwd * 0.2).normalized() # 천장에서 떨어질 때 180도 뒤집힘 방지
	_n = _nlerp(_n, want_n, clampf(delta * 4.0, 0.0, 1.0))

	var b: Basis = target.vehicle_model.global_basis
	_fwd = _nlerp(_fwd, _flatten(b.z, _n, _fwd), clampf(delta * 3.5, 0.0, 1.0))
	_fwd = _flatten(_fwd, _n, _fwd)
	_flat_fwd = _nlerp(_flat_fwd, _flatten(b.z, Vector3.UP, _flat_fwd), clampf(delta * 1.5, 0.0, 1.0))
	_flat_fwd = _flatten(_flat_fwd, Vector3.UP, _flat_fwd)

	var speed := target.get_speed()
	_dist = lerpf(_dist, remap(clampf(speed, 0.0, 20.0), 0.0, 20.0, chase_distance.x, chase_distance.y), delta * 1.5)

	var desired := _avoid_walls(target.get_vehicle_position() + _n * 1.0, _desired())
	global_position = global_position.lerp(desired, clampf(delta * 8.0, 0.0, 1.0))
	_look()


## 0 = 바닥, 1 = 벽·천장
func _wall_weight() -> float:
	return clampf((0.85 - _n.dot(Vector3.UP)) / 0.5, 0.0, 1.0)


func _desired() -> Vector3:
	var car := target.get_vehicle_position()
	if mode == Mode.SHOWCASE:
		# 진행 방향의 옆(측면)에서 본다. 실제 시연 영상처럼 램프·점프의 높이가 보이게
		var side := _flat_fwd.rotated(Vector3.UP, PI * 0.5)
		return car + side * showcase_distance + Vector3.UP * 3.0
	var floor_pos := car - _fwd * _dist + _n * (_dist * chase_height_ratio)
	var wall_pos := car + _n * wall_out - _fwd * wall_back
	return floor_pos.lerp(wall_pos, _wall_weight())


func _look() -> void:
	var car := target.get_vehicle_position()
	var at := car + Vector3.UP * 1.0
	if mode == Mode.CHASE:
		at = car + _fwd * 2.0 + _n * 0.6
	var dir := at - global_position
	if dir.length() < 0.01:
		return
	var up := Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.97:
		up = _fwd
	look_at(at, up)


func _flatten(v: Vector3, up: Vector3, fallback: Vector3) -> Vector3:
	var f := v - up * v.dot(up)
	if f.length() < 0.15:
		f = fallback - up * fallback.dot(up)
		if f.length() < 0.15:
			f = up.cross(Vector3.RIGHT) if absf(up.dot(Vector3.RIGHT)) < 0.9 else up.cross(Vector3.BACK)
	return f.normalized()


func _avoid_walls(from: Vector3, to: Vector3) -> Vector3:
	var params := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return to
	# 천장(아래를 보는 면)은 조금 더 띄운다: 바로 밑에 붙으면 천장 조명이 화면을 가린다
	return hit.position + hit.normal * (0.95 if hit.normal.y < -0.5 else 0.3)


## slerp는 거의 같은 방향끼리 섞을 때 축 정규화 오류를 낸다(차가 출렁이며 미세하게 흔들릴 때). 짧은 보간이라 정규화한 lerp로 충분하다.
func _nlerp(a: Vector3, b: Vector3, w: float) -> Vector3:
	var r := a.lerp(b, w)
	return r.normalized() if r.length() > 0.001 else b
