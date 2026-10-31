extends "res://tests/pilot_base.gd"
## 시연장 자동 주행. 사람과 같은 입력 액션만 누른다.
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/autopilot_stage.tscn -- mode=ramp|kick [값=...]
##   ramp: 램프 출발 → 흡착 팬(E) 켜고 반원을 올라 천장에서 브레이크 → hang초 매달림 → E를 떼 떨어짐
##         (자세 노즐이 옆으로 돌려 세운다) → cushion_y m 아래로 내려오면 리프트로 받쳐 착지 → 착지 칸에 멈춤
##   kick: 킥플립 출발 → 가속 + 메인 추진 → 출발선(z 0)에서 리프트 lift_t초 → roll_at초 뒤 F(옆으로 한 바퀴) → 착지 칸에 멈춤

@export var mode := "ramp" ## ramp | kick (명령줄 mode=가 이긴다)
var p := {
	"throttle": 0.7, # 램프 진입 가속(천장 6m 안에 멈추려면 너무 빠르면 안 된다)
	"brake_z": -100.0, # 천장에서 이 z를 지나면 브레이크(예: 28 = 돌출부 끝에 선다). 기본은 멈추지 않고 입술 끝에서 튀어 나간다(실제 시연)
	"out_t": 0.9, # 착지 뒤 구름 밖으로 몰고 나오는 시간
	"hang": 0.35, # 끝에서 잠깐 멈춘 뒤 팬을 뗀다
	"cushion_y": 7.5, # 떨어지며 바로 선 뒤 이 높이 아래에서 리프트(빨리 떨어지다 가스 구름 속에서 받쳐 약 3m/s로 착지)
	"lift_t": 0.7, # 장애물 길 리프트 시간(최고 약 10m, 트럭 바로 뒤 착지)
	"boost_z": -2.0, # 이 z까지 메인 추진
	"roll_at": 0.7, # 이륙 뒤 F를 누르는 시각(리프트가 끝난 뒤: 도는 동안 리프트를 뿜으면 옆으로 밀린다)
	"cushion_kick": 4.5, # 한 바퀴 돌고 바로 선 뒤 이 높이 아래로 내려오면 리프트로 받친다(웹 프로토타입 웹 시연도 5m 아래에서 착지 분사). 5 이상이면 떠서 착지 칸을 지나친다
	"freeze": -1.0, # 이 시각에 멈춰 화면을 고정한다(에디터에서 스크린샷용)
}
enum S { WAIT, RUN, BRAKE, HANG, FALL, OUT, LAUNCH, AIR, PARK, DONE }
var state := S.WAIT
var t := 0.0
var st := 0.0
var game
var stage
var _log_t := 0.0
var _launch_t := -1.0
var _max_y := 0.0
var _pads_at_park := 0
var _roll_tap := 0
var _ceiling := false


func _ready() -> void:
	var cmd := OS.get_cmdline_user_args()
	if cmd.is_empty() and FileAccess.file_exists("res://tests/shot_args.txt"):
		cmd = FileAccess.get_file_as_string("res://tests/shot_args.txt").strip_edges().split(" ") # 에디터에서 볼 때(로컬 전용)
	for a in cmd:
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		if kv[0] == "mode":
			mode = kv[1]
		elif p.has(kv[0]):
			p[kv[0]] = float(kv[1])
	game = $DemoStage
	stage = game.get_node("Level")
	car = game.get_node("Roadster")
	car.landed.connect(func(up, air_t, spin): print("LANDED t=%.2f upright=%s air=%.2f spin=%.0f roll=%.0f pos=%s" % [t, up, air_t, spin, car.last_air_roll, _v(car.get_vehicle_position())]))
	await get_tree().process_frame
	game.hud.toggle_help()
	if mode == "kick":
		game.warp_to(2)
	print("AUTOPILOT_STAGE ", mode, " ", p)


func _v(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


func _go(s: S) -> void:
	print("STATE %s -> %s at t=%.2f pos=%s spd=%.2f" % [S.keys()[state], S.keys()[s], t, _v(car.get_vehicle_position()), car.get_speed()])
	state = s
	st = 0.0
	if s == S.PARK:
		_pads_at_park = game.pads_done


func _physics_process(delta: float) -> void:
	t += delta
	st += delta
	if p.freeze > 0.0 and t >= p.freeze:
		var rt := get_node_or_null("/root/MCPRuntime")
		if rt:
			rt.process_mode = Node.PROCESS_MODE_ALWAYS
		print("FROZEN at t=%.2f" % t)
		get_tree().paused = true
		return
	_release_all()
	var pos := car.get_vehicle_position()
	_max_y = maxf(_max_y, pos.y)
	if mode == "ramp":
		_ramp(pos)
	else:
		_kick(pos)
	if state == S.DONE and st > 2.5:
		print("AUTOPILOT_STAGE done mode=%s t=%.2f pads=%d max_y=%.1f pos=%s roll=%.0f" % [mode, t, game.pads_done, _max_y, _v(pos), car.last_air_roll])
		get_tree().quit()
	if t > 40.0:
		print("AUTOPILOT_STAGE FAIL timeout state=%s pos=%s" % [S.keys()[state], _v(pos)])
		get_tree().quit(1)
	_log_t += delta
	if _log_t >= 0.25:
		_log_t = 0.0
		print("t=%5.2f %-6s pos=%s spd=%5.2f up=%s att=%s gnd=%s air=%5.1f" % [t, S.keys()[state], _v(pos), car.get_speed(), _v(car.get_up()), car.attached, car.is_grounded(), car.air])


func _ramp(pos: Vector3) -> void:
	match state:
		S.WAIT:
			if st > 0.5:
				_go(S.RUN)
		S.RUN:
			# 실제 시연처럼 멈추지 않고 꼭대기 입술 끝까지 달려 그대로 튀어 나간다(brake_z를 주면 천장에서 멈췄다 떨어진다)
			_press("magnet")
			_press("forward", p.throttle)
			if not car.attached and pos.z < stage.RAMP_Z - 0.5:
				_steer_heading(Vector3.BACK, Vector3(stage.RAMP_X, 0, 0), true)
			if car.attached and car.up_dir.y < -0.9:
				_ceiling = true
				if pos.z < p.brake_z:
					_go(S.BRAKE)
			if _ceiling and not car.attached:
				_go(S.FALL)
		S.BRAKE:
			_press("magnet")
			if car.get_speed() > 0.3:
				_press("back")
			else:
				_go(S.HANG)
		S.HANG:
			_press("magnet")
			if st > p.hang:
				_go(S.FALL)
		S.FALL:
			# 떨어지자마자 F: 뒤집힌 차를 옆으로 반 바퀴 돌려 세운다. 바로 선 뒤에만 리프트로 받친다(기운 채 뿜으면 옆으로 밀린다)
			if not car.attached and _roll_tap < 6:
				_roll_tap += 1 # 떨어진 뒤 몇 프레임 동안 F
				_press("barrel_roll")
			if pos.y < p.cushion_y and car.linear_velocity.y < -1.0 and car.get_up().y > 0.9:
				_press("rocket")
			if car.is_grounded() and st > 0.3:
				_go(S.OUT)
		S.OUT:
			# 구름 밖으로 몰고 나온다(실제 시연 마지막 장면)
			_press("forward", 0.6)
			if st > p.out_t:
				_go(S.PARK)
		S.PARK:
			var pad: ParkingPad = game.pads[1]
			if game.pads_done > _pads_at_park or st > 8.0:
				_go(S.DONE)
			else:
				var dir := _flat_fwd()
				_stop_at(pad.global_position, dir if dir.dot(Vector3.FORWARD) > 0.0 else Vector3.FORWARD, 0.0, 0.4, 2.0)


func _kick(pos: Vector3) -> void:
	match state:
		S.WAIT:
			if st > 0.5:
				_go(S.RUN)
		S.RUN:
			_press("forward")
			if pos.z < p.boost_z:
				_press("boost")
			_steer_heading(Vector3.BACK, Vector3(stage.LANE_X, 0, 0), true)
			if pos.z >= stage.LAUNCH_Z:
				_launch_t = t
				_go(S.LAUNCH)
		S.LAUNCH:
			if st < p.lift_t:
				_press("rocket")
			if st >= p.roll_at and st < p.roll_at + 0.1:
				_press("barrel_roll")
			if st > p.lift_t:
				_go(S.AIR)
		S.AIR:
			# 내려오는 중이고 바로 서 있으면(한 바퀴를 다 돈 뒤) 바닥 가까이에서 리프트로 착지 충격을 줄인다
			if pos.y < p.cushion_kick and car.linear_velocity.y < -1.0 and car.get_up().y > 0.9:
				_press("rocket")
			if car.is_grounded() and st > 0.2:
				_go(S.PARK)
		S.PARK:
			var pad: ParkingPad = game.pads[3]
			if game.pads_done > _pads_at_park or st > 8.0:
				_go(S.DONE)
			else:
				_stop_at(pad.global_position, Vector3.BACK, 6.0, 0.4, 1.5)
