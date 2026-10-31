extends Node3D
## 한 판의 규칙.
## - 패드에 방향을 맞춰 멈추면(PARK_TIME초) 주차 완료: 공기 탱크 가득, 복귀 지점 갱신.
## - 처음 주차한 패드는 초록으로 바뀌고 다음 목표 패드가 하늘색 빛기둥으로 표시된다.
## - 결승 패드(타워 30m)에 주차하면 기록 저장. 떨어져도 죽지 않고 R로 마지막 패드에 복귀한다.
## - 숫자 1~7: 해당 패드로 순간 이동(연습·촬영용). 한 번이라도 쓰면 그 판 기록은 저장하지 않는다.

const PARK_TIME := 0.8
const PARK_MAX_SPEED := 0.9
const FALL_Y := -20.0
const SAVE_PATH := "user://best.cfg"
const DRIVE_ACTIONS := ["forward", "back", "left", "right", "rocket", "boost", "magnet"]

@export var save_section := "run" ## 최고 기록 칸(코스마다 따로)

@onready var level = $Level
@onready var car: Roadster = $Roadster
@onready var cam = $Camera
@onready var hud = $HUD

var pads: Array[ParkingPad] = []
var last_pad: ParkingPad
var run_time := 0.0
var running := false
var finished := false
var best_height := 0.0
var best_time := -1.0
var pads_done := 0
var practice := false


func _ready() -> void:
	pads = level.pads
	car.landed.connect(_on_car_landed)
	car.crashed.connect(_on_car_crashed)
	_load_best()
	restart()


func restart() -> void:
	for p in pads:
		p.reset()
	pads[0].set_state(ParkingPad.State.CHARGED)
	last_pad = pads[0]
	car.controls_enabled = true
	car.respawn_at(last_pad.spawn_transform())
	cam.snap()
	run_time = 0.0
	running = false
	finished = false
	best_height = 0.0
	pads_done = 0
	practice = false
	_update_next()
	var intro = level.get("intro")
	hud.toast(intro if intro != null else "패드에 바퀴로 멈추면 공기 충전\n결승은 타워 꼭대기", 3.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	elif event.is_action_pressed("respawn"):
		_respawn("마지막 패드로 복귀")
	elif event.is_action_pressed("restart"):
		restart()
	elif event.is_action_pressed("help"):
		hud.toggle_help()
	elif event.is_action_pressed("swap_car"):
		car.toggle_style()
		hud.toast("로드스터" if car.style == "roadster" else "상자 차", 1.0)
	elif event.is_action_pressed("paint"):
		hud.toast("배색: " + car.next_palette(), 1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		var i: int = event.physical_keycode - KEY_1
		if i >= 0 and i < pads.size():
			warp_to(i)


func _physics_process(delta: float) -> void:
	if not running and not finished and _any_drive_input():
		running = true
	if running:
		run_time += delta

	var h := car.get_vehicle_position().y
	best_height = maxf(best_height, h)
	var park := _check_parking(delta)

	if h < FALL_Y:
		_respawn("추락! 마지막 패드로 복귀")

	hud.update_state({
		"height": h,
		"best_height": best_height,
		"time": run_time,
		"pads_done": pads_done,
		"pads_total": pads.size() - 1,
		"air_ratio": car.air / car.air_max,
		"lift": car.lift_firing,
		"main": car.main_firing,
		"fan": car.attached,
		"fan_g": car.fan_g(),
		"wall": car.on_wall,
		"park": park,
	}, delta)


func _on_car_landed(upright: bool, air_time: float, spin_deg: float) -> void:
	if finished:
		return
	if not upright:
		return # 크게 기울어 내려앉았다. 아주 뒤집혔으면 crashed("flip")이 따로 온다
	if car.last_air_roll >= 300.0:
		hud.toast("옆으로 %d°!" % (roundi(car.last_air_roll / 90.0) * 90), 1.4)
	elif spin_deg >= 300.0:
		hud.toast("킥플립! %d°" % (roundi(spin_deg / 90.0) * 90), 1.4)
	elif air_time > 1.0:
		hud.toast("착지", 0.8)


## 스턴트 코스는 사고로 끝나지 않는다. 뒤집히면 1.2초 뒤 노즐이 차를 바로 세운다(car.auto_recover).
func _on_car_crashed(kind: String, _impact: float) -> void:
	if finished:
		return
	hud.toast("뒤집힘" if kind == "flip" else "쾅!", 1.0)


func _any_drive_input() -> bool:
	for a in DRIVE_ACTIONS:
		if Input.is_action_pressed(a):
			return true
	return false


func _check_parking(delta: float) -> float:
	var can_park := car.is_grounded() and not car.on_wall and car.get_speed() < PARK_MAX_SPEED
	var shown := 0.0
	for p in pads:
		var inside := p.car_inside(car)
		if inside and not p.latched and car.is_grounded() and not Input.is_action_pressed("forward"):
			car.settle(delta) # 주차 보조
		if inside and can_park and not p.latched:
			p.charge = minf(p.charge + delta / PARK_TIME, 1.0)
			shown = p.charge
			if p.charge >= 1.0:
				p.latched = true
				_on_parked(p)
		elif not inside:
			p.charge = maxf(p.charge - delta * 3.0, 0.0)
			p.latched = false
		else:
			p.charge = maxf(p.charge - delta * 3.0, 0.0)
		p.update_fill()
	return shown


func _on_parked(p: ParkingPad) -> void:
	car.refill_air()
	last_pad = p
	if p.state == ParkingPad.State.CHARGED:
		hud.toast("공기 충전", 1.2)
		return
	p.set_state(ParkingPad.State.CHARGED)
	pads_done += 1
	if p.is_finish:
		_finish()
	else:
		hud.toast("주차 완료! 공기 충전\n%s" % p.title, 2.0)
	_update_next()


func _finish() -> void:
	finished = true
	running = false
	var record := not practice and (best_time < 0.0 or run_time < best_time)
	if record:
		best_time = run_time
		_save_best()
	var t: String = hud._fmt_time(run_time)
	var note: String = "새 기록!" if record else ("최고 " + hud._fmt_time(best_time) if best_time >= 0.0 else "")
	if practice:
		note = "연습 판(기록 안 함)"
	hud.toast("완주! %s\n%s\nEnter 다시 하기" % [t, note], 600.0)


## 연습·촬영용 순간 이동. 그 패드까지는 주차한 것으로 친다.
func warp_to(i: int) -> void:
	practice = true
	for j in pads.size():
		if j <= i and pads[j].state != ParkingPad.State.CHARGED:
			pads[j].set_state(ParkingPad.State.CHARGED)
			if j > 0:
				pads_done += 1
	last_pad = pads[i]
	_update_next()
	_respawn("연습: %s" % pads[i].title)


func _update_next() -> void:
	var found := false
	for p in pads:
		if p.state == ParkingPad.State.CHARGED:
			continue
		p.set_state(ParkingPad.State.IDLE if found else ParkingPad.State.NEXT)
		found = true


func _respawn(message: String) -> void:
	car.respawn_at(last_pad.spawn_transform())
	cam.snap()
	hud.toast(message, 1.2)


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_time = cfg.get_value(save_section, "best_time", -1.0)


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH) # 다른 코스 기록은 그대로 둔다
	cfg.set_value(save_section, "best_time", best_time)
	cfg.save(SAVE_PATH)
