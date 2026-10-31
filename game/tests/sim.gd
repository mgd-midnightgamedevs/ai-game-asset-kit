extends Node
## 헤드리스 주행 시험. 입력을 흉내 내 로그를 찍는다.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/sim.tscn -- --scenario=curl
## 에디터에서 화면을 볼 때는 tests/sim_args.txt(로컬 전용)에 "--scenario=curl --freeze=3.2"처럼 적고 sim.tscn을 실행한다.
## 시나리오:
##   kick  출발 → 차 5대 위로 리프트 점프 + 공중 회전 → P1 근처 착지
##   curl  P1 → 데크 아래 → 말린 램프(흡착 팬) → 거꾸로 튀어 나감 → 데크 위 착지
##   hop   데크 가장자리 → 옆 건물 옥상(15m)으로 추진기 점프
##   park  P1 바로 앞에서 출발해 칸 안에 멈춰 주차 완료
##   tower P3 → 쿼터파이프 → 타워 벽 → 모서리에서 튀어 나가 지붕(30m)

var scenario := "kick"
var t := 0.0
var _log_t := 0.0
var _max_y := -INF
var _freeze_at := -1.0 ## 이 시각에 트리를 멈춰 화면을 고정한다(에디터에서 스크린샷용)
var _mark := -1.0
var _showcase := false
var game
var car: Roadster

const DURATION := {"park": 5.0, "kick": 7.0, "curl": 9.0, "hop": 6.0, "tower": 9.0}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() and FileAccess.file_exists("res://tests/sim_args.txt"):
		args = FileAccess.get_file_as_string("res://tests/sim_args.txt").strip_edges().split(" ")
	for a in args:
		if a.begins_with("--scenario="):
			scenario = a.split("=")[1]
		elif a == "--cam=showcase":
			_showcase = true
		elif a.begins_with("--freeze="):
			_freeze_at = float(a.split("=")[1])
	game = $Main
	car = game.get_node("Roadster")
	game.practice = true # 시험 판은 최고 기록에 남기지 않는다
	car.landed.connect(func(up, air_t, spin): print("LANDED t=%.2f upright=%s air=%.2f spin=%.0f pos=%s" % [t, up, air_t, spin, str(car.get_vehicle_position())]))
	await get_tree().physics_frame
	match scenario:
		"curl":
			_spawn(Vector3(0, 0, 44), 0.0)
		"park":
			_spawn(Vector3(0, 0, 38), 0.0)
		"hop":
			_spawn(Vector3(4, 7, 62), 90.0)
		"tower":
			_spawn(Vector3(19, 15, 62), 90.0)
	if _showcase:
		game.cam.mode = 1 # Mode.SHOWCASE
		game.cam.snap()
	print("SCENARIO ", scenario)


func _spawn(p: Vector3, yaw_deg: float) -> void:
	car.respawn_at(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), p))
	game.cam.snap()


func _press(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _physics_process(delta: float) -> void:
	t += delta
	if _freeze_at > 0.0 and t >= _freeze_at:
		var rt := get_node_or_null("/root/MCPRuntime")
		if rt:
			rt.process_mode = Node.PROCESS_MODE_ALWAYS
		print("FROZEN at t=%.2f" % t)
		get_tree().paused = true
		return
	var pos := car.get_vehicle_position()
	_max_y = maxf(_max_y, pos.y)
	match scenario:
		"kick":
			# 직선 가속 → z 13에서 리프트 0.75초 → 공중에서 왼쪽으로 한 바퀴 → 착지 후 브레이크
			_press("forward", t > 0.2 and pos.z < 13.0)
			_press("boost", t > 0.2 and pos.z < 16.0)
			if _mark < 0.0 and pos.z >= 13.0:
				_mark = t
			_press("rocket", _mark > 0.0 and t < _mark + 0.75)
			_press("left", _mark > 0.0 and t > _mark + 0.15 and t < _mark + 1.4)
			_press("back", _mark > 0.0 and t > _mark + 1.6 and car.get_speed() > 0.5)
		"curl":
			# 램프 끝에서 떨어져 나갈 때까지 W·팬 유지, 그 뒤엔 손을 떼 추진기가 차를 바로 세우게 둔다
			if _mark < 0.0 and pos.y > 3.0 and not car.attached:
				_mark = t
			_press("forward", _mark < 0.0)
			_press("magnet", _mark < 0.0)
			_press("back", _mark > 0.0 and car.is_grounded() and car.get_speed() > 0.5)
		"hop":
			_press("forward", t > 0.2 and t < 0.9)
			_press("rocket", t > 0.5 and t < 1.35)
			_press("boost", t > 0.9 and t < 1.5)
			_press("back", t > 2.4 and car.get_speed() > 0.5)
		"park":
			# P1 앞에서 출발해 칸 안에 멈춘다 → 주차 완료(패드 수 1)
			_press("forward", pos.z < 42.4 and _mark < 0.0)
			if _mark < 0.0 and pos.z >= 42.4:
				_mark = t
			_press("back", _mark > 0.0 and car.linear_velocity.z > 0.3)
		"tower":
			_press("forward", pos.y < 28.5)
			_press("magnet", pos.y < 29.0 and t < 6.0)
			if _mark < 0.0 and pos.y >= 29.0:
				_mark = t
			_press("air_forward", _mark > 0.0 and t < _mark + 0.55)
			_press("boost", _mark > 0.0 and t > _mark + 0.25 and t < _mark + 0.8)
			_press("back", _mark > 0.0 and t > _mark + 1.4 and car.get_speed() > 0.5)

	_log_t += delta
	if _log_t >= 0.25:
		_log_t = 0.0
		print("t=%5.2f pos=(%6.2f,%6.2f,%6.2f) spd=%5.2f up=(%5.2f,%5.2f,%5.2f) att=%s gnd=%s air=%5.1f pads=%s wheels=%d contacts=%d" % [
			t, pos.x, pos.y, pos.z, car.get_speed(), car.up_dir.x, car.up_dir.y, car.up_dir.z,
			car.attached, car.is_grounded(), car.air, _pad_states(), car._grounded, car.get_contact_count()])
	if t >= DURATION.get(scenario, 8.0):
		print("END max_y=%.2f final=%s pads_done=%d" % [_max_y, str(pos), game.pads_done])
		get_tree().quit()


func _pad_states() -> String:
	var s := ""
	for p in game.pads:
		s += str(p.state)
	return s
