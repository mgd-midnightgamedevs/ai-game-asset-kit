extends Node
## 촬영 지시(자동 로드 Shot). 녹화할 때만 쓴다. 명령줄 `--` 뒤에 이런 값을 주면 정해진 시각에 그대로 한다.
##   look=roadster|box    시작 겉모습(M과 같다)
##   toggle_look=4.9      이 시각(초)에 M을 한 번 누른 것처럼 바꾼다
##   palette_at=12,13,14  이 시각마다 다음 배색(P)으로
##   cam=showcase|wheel   측면 카메라 / 앞왼쪽 바퀴를 가까이 따라가는 카메라
##   cam=spot:이름        장면 안 스크립트의 SHOT_CAMS[이름] 자리에 카메라를 세워 두고 차를 바라본다(DAY 2: curl)
##   clean=1              HUD와 주차 패드 표시를 숨긴다
##   quit=16              이 시각에 끝낸다(무비 메이커 녹화가 여기서 닫힌다)
## 자동 주행 장면(tests/autopilot*.tscn)과 같이 쓴다. tools/record_shot.py가 샷 목록대로 실행한다.

var args := {}
var t := 0.0
var car: Roadster
var _palette_times: Array = []
var _palette_i := 0
var _toggled := false
var _cam_set := false
var _spot := Vector3.INF
var _anchor := Vector3.ZERO
var _follow := 1.0
var _look := Vector3.ZERO
var _cleaned := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2 and kv[0] in ["look", "toggle_look", "palette_at", "cam", "quit", "clean", "meter"]:
			args[kv[0]] = kv[1]
	if args.is_empty():
		set_physics_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	if args.get("look") in ["roadster", "box"]:
		Roadster.current_style = args.look # 장면이 차를 만들 때 이 겉모습으로 시작한다
	if args.has("palette_at"):
		for x in String(args.palette_at).split(","):
			_palette_times.append(float(x))
	print("SHOT ", args)


func _physics_process(delta: float) -> void:
	t += delta
	if car == null or not is_instance_valid(car):
		car = _find_car(get_tree().current_scene)
		_cam_set = false
		_cleaned = false
	if args.get("clean") == "1" and not _cleaned and car:
		_cleaned = true
		_hide_clutter(get_tree().current_scene)
	if args.has("toggle_look") and not _toggled and t >= float(args.toggle_look) and car:
		_toggled = true
		car.toggle_style()
		print("SHOT look -> %s at %.2f" % [car.style, t])
	while _palette_i < _palette_times.size() and t >= _palette_times[_palette_i]:
		_palette_i += 1
		if car:
			print("SHOT palette %s at %.2f" % [car.next_palette(), t])
	var cam := get_viewport().get_camera_3d()
	if car and cam:
		match args.get("cam", ""):
			"showcase":
				if not _cam_set and "mode" in cam:
					cam.mode = 1
					cam.snap()
					_cam_set = true
			var c when String(c).begins_with("spot:"):
				if _spot == Vector3.INF:
					_find_spot(String(c).substr(5))
					_look = _anchor.lerp(car.get_vehicle_position(), _follow)
				if _spot != Vector3.INF:
					cam.set_physics_process(false)
					cam.global_position = _spot
					var want := _anchor.lerp(car.get_vehicle_position() + Vector3.UP * 0.6, _follow)
					_look = _look.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
					cam.look_at(_look, Vector3.UP)
			"wheel":
				# 앞왼쪽 바퀴(+X가 왼쪽, +Z가 앞) 바깥 앞쪽 낮은 곳에서 바퀴를 본다
				var wheel := car.vehicle_model.find_child("wheel-front-left", true, false) as Node3D
				if wheel:
					cam.set_physics_process(false)
					var b := car.vehicle_model.global_basis
					cam.global_position = wheel.global_position + b * Vector3(1.9, 0.4, 1.7)
					cam.look_at(wheel.global_position + b * Vector3(-0.3, 0.1, -0.6), Vector3.UP)
	if args.get("meter") == "1":
		_meter(delta)
	if args.has("quit") and t >= float(args.quit):
		get_tree().quit()


## 장면 안에서 SHOT_CAMS[이름] = [카메라 위치, 기준점, 차를 따라보는 비율]을 가진 스크립트를 찾아 읽는다
func _find_spot(spot_name: String) -> void:
	var s = _spots_in(get_tree().current_scene, spot_name)
	if s is Array:
		_spot = s[0]
		_anchor = s[1]
		_follow = s[2]
		return
	push_warning("SHOT: 카메라 자리 %s 없음" % spot_name)


func _spots_in(n: Node, spot_name: String) -> Variant:
	if n.get_script():
		var spots = n.get_script().get_script_constant_map().get("SHOT_CAMS")
		if spots is Dictionary and spots.has(spot_name):
			return spots[spot_name]
	for c in n.get_children():
		var r = _spots_in(c, spot_name)
		if r != null:
			return r
	return null


func _hide_clutter(n: Node) -> void:
	if n is CanvasLayer or n is ParkingPad:
		n.visible = false
		return
	for ch in n.get_children():
		_hide_clutter(ch)


func _find_car(n: Node) -> Roadster:
	if n == null:
		return null
	if n is Roadster:
		return n
	for c in n.get_children():
		var r := _find_car(c)
		if r:
			return r
	return null


## meter=1: 버스마다 0.25초 동안의 최대 피크(dB)를 한 줄로 찍는다(소리 크기 맞추기용, 녹화 실행에서만 소리가 섞인다)
var _meter_t := 0.0
var _meter_max := {}
func _meter(delta: float) -> void:
	for i in AudioServer.bus_count:
		var n := AudioServer.get_bus_name(i)
		var db := maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))
		_meter_max[n] = maxf(_meter_max.get(n, -200.0), db)
	_meter_t += delta
	if _meter_t >= 0.25:
		_meter_t = 0.0
		var parts := PackedStringArray()
		for n in _meter_max:
			parts.append("%s=%.0f" % [n, maxf(_meter_max[n], -99.0)])
		print("METER t=%.2f %s" % [t, " ".join(parts)])
		_meter_max.clear()

