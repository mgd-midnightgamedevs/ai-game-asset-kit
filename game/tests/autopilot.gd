extends "res://tests/pilot_base.gd"
## 전 코스 자동 주행(시연·촬영용). 사람이 누르는 것과 같은 입력 액션만 쓴다(차를 직접 옮기지 않는다).
## 실행: Godot --headless --fixed-fps 60 --path . res://tests/autopilot.tscn
## 에디터에서 녹화: Project Settings > editor/run/main_run_args에 "--write-movie <경로>.avi"를 넣고 이 씬을 실행.
##
## 경로: 출발 → 차 5대 킥플립 → P1 주차 → 데크 아래 → 말린 램프(흡착) → 거꾸로 이탈 → 데크 착지 → P2 주차
##       → 오른쪽으로 돌아 데크 끝 → 옆 건물로 점프 → P3 주차 → 쿼터파이프·타워 벽 → 모서리 이탈 → 결승 주차


## 튜닝값
const KICK_LIFT_Z := 14.0
const KICK_LIFT_TIME := 0.55
const HOP_STOP_X := 3.0
const HOP_LINE_Z := 62.5 ## 옆 건물 P3(z 62) 줄에 맞춰 선다

enum S { KICK_RUN, KICK_AIR, PARK1, CURL, CURL_AIR, SETTLE2, PARK2, TURN, HOP_SET, HOP, PARK3, TOWER, TOWER_POP, PARK4, DONE }

var state := S.KICK_RUN
var t := 0.0
var st := 0.0 ## 현재 상태에 들어온 뒤 흐른 시간
var game
var cam
var _log_t := 0.0


func _ready() -> void:
	game = $Main
	car = game.get_node("Roadster")
	cam = game.cam
	car.landed.connect(func(up, air_t, spin): print("LANDED t=%.2f state=%s upright=%s air=%.2f spin=%.0f pos=%s" % [t, S.keys()[state], up, air_t, spin, _v(car.get_vehicle_position())]))
	await get_tree().process_frame
	game.hud.toggle_help() # 영상에서는 조작 안내를 숨긴다
	game.practice = true # 자동 주행 기록은 사용자 최고 기록에 남기지 않는다
	print("AUTOPILOT start")


func _physics_process(delta: float) -> void:
	t += delta
	st += delta
	_release_all()
	var p := car.get_vehicle_position()
	match state:
		S.KICK_RUN:
			_steer_heading(Vector3.BACK, Vector3.ZERO, true)
			_press("forward")
			if p.z >= KICK_LIFT_Z:
				_go(S.KICK_AIR, 1)
		S.KICK_AIR:
			if st < KICK_LIFT_TIME:
				_press("rocket")
			if st > 0.12 and car._air_spin < TAU * 0.97 and not car.is_grounded():
				_press("left")
			if st > 0.4 and car.is_grounded():
				_go(S.PARK1, 0)
		S.PARK1:
			if _park(game.pads[1], 7.0):
				_go(S.CURL, 0)
		S.CURL:
			_steer_heading(Vector3.BACK, Vector3.ZERO, true)
			_press("forward")
			_press("magnet")
			if p.y > 2.0:
				_set_cam(1)
			if p.y > 3.0 and not car.attached:
				_go(S.CURL_AIR, -1)
		S.CURL_AIR:
			if st > 0.3 and car.is_grounded() and p.y > 5.0:
				_go(S.SETTLE2, 0)
		S.SETTLE2:
			# 뒤집어 착지한 직후엔 방향이 틀어진 채 미끄러진다. 패드 중심선에 맞춰 방향을 잡으며 천천히 줄인다
			var e2 := _steer_heading(Vector3.FORWARD, Vector3(0, 0, 66.5), true)
			if car.get_speed() > 3.0:
				_press("back", 0.6)
			elif car.get_speed() < 1.5:
				_press("forward", 0.4)
			if st > 0.4 and car.get_speed() < 3.0 and absf(e2) < 0.25:
				_go(S.PARK2, -1)
		S.PARK2:
			if _park(game.pads[2], 7.0):
				_go(S.TURN, 0)
		S.TURN:
			# 데크 위에서 +X(오른쪽)로 돌아 끝 쪽으로 간다
			# 주차 브레이크로 살짝 뒤로 구르는 중이면 조향이 반대로 먹으니, 먼저 앞으로 굴러가게 한 뒤 돈다
			var err := 0.0
			if st > 0.3 and car.linear_speed > 0.15:
				err = _steer_heading(Vector3.RIGHT)
			else:
				err = 9.0
			_press("forward", 0.55)
			if absf(err) < 0.12:
				_go(S.HOP_SET, -1)
		S.HOP_SET:
			# 데크 끝 바로 앞(x=3)에 한 번 세워 점프 거리를 일정하게
			if _stop_at(Vector3(HOP_STOP_X, 0, HOP_LINE_Z), Vector3.RIGHT, 5.0, 0.6):
				_go(S.HOP, 1)
		S.HOP:
			_steer_heading(Vector3.RIGHT)
			if st < 0.7: _press("forward")
			if st > 0.3 and st < 1.12: _press("rocket")
			if st > 0.62 and st < 1.05: _press("boost")
			if st > 1.0 and car.is_grounded() and p.y > 13.0:
				_go(S.PARK3, 0)
		S.PARK3:
			if _park(game.pads[3], 4.5):
				_go(S.TOWER, 0)
		S.TOWER:
			_steer_heading(Vector3.RIGHT, Vector3(0, 0, 62), true)
			_press("forward")
			_press("magnet")
			if p.y > 22.0:
				_set_cam(1)
			if p.y >= 29.0:
				_go(S.TOWER_POP, -1)
		S.TOWER_POP:
			if st < 0.55: _press("air_forward")
			if st > 0.25 and st < 0.6: _press("boost")
			if st > 0.5 and car.is_grounded() and p.y > 28.0:
				_go(S.PARK4, 0)
		S.PARK4:
			if game.finished or _park(game.pads[4], 3.5):
				_go(S.DONE, -1)
		S.DONE:
			if st > 3.0:
				print("AUTOPILOT done t=%.2f run_time=%.2f pads=%d finished=%s" % [t, game.run_time, game.pads_done, game.finished])
				get_tree().quit()

	if p.y < -5.0 or t > 120.0:
		print("AUTOPILOT FAIL state=%s t=%.2f pos=%s" % [S.keys()[state], t, _v(p)])
		get_tree().quit(1)

	_log_t += delta
	if _log_t >= 0.5:
		_log_t = 0.0
		print("t=%6.2f %-9s pos=%s spd=%5.2f air=%5.1f pads=%d" % [t, S.keys()[state], _v(p), car.get_speed(), car.air, game.pads_done])


## cam_mode: 0 추적, 1 측면, -1 그대로
func _go(next: S, cam_mode: int) -> void:
	print("STATE %s -> %s at t=%.2f" % [S.keys()[state], S.keys()[next], t])
	state = next
	st = 0.0
	if cam_mode >= 0:
		_set_cam(cam_mode)


func _set_cam(mode: int) -> void:
	if cam.mode != mode:
		cam.mode = mode
		cam.snap()


