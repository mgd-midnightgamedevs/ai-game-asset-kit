extends Control
## 첫 화면: 요일 레벨, 스턴트 코스, 시연장을 고른다. 숫자 키 1~9·0 또는 클릭.
## DAY 1~4는 주차 경쟁, DAY 5부터는 기차·배달·고가도로·경찰차처럼 다른 일이 섞인다.

const FONT := preload("res://fonts/Pretendard-Bold.otf")

var _going := false
const ENTRIES := [
	["DAY 1 · 월", "회사 앞 마지막 한 칸", "리프트로 앞차 넘고 공중 90도", "res://scenes/day1.tscn"],
	["DAY 2 · 화", "주차 타워 만차", "말린 램프 흡착 → 거꾸로 날아 옥상", "res://scenes/day2.tscn"],
	["DAY 3 · 수", "옥상 주차장", "엘리베이터보다 먼저, 리프트로 9m", "res://scenes/day3.tscn"],
	["DAY 4 · 목", "길 건너 옥상", "벽 타고 올라가 Space로 차고 건너편 착지", "res://scenes/day4.tscn"],
	["DAY 5 · 금", "철도 건널목", "기차 기다리지 말고 넘어서 주차", "res://scenes/day5.tscn"],
	["DAY 6 · 토", "주말 배달 알바", "고층 빌딩 세 곳, 9시까지 배달", "res://scenes/day6.tscn"],
	["DAY 7 · 일", "브런치 맛집", "고가도로 위 차들 사이로 넘어가기", "res://scenes/day7.tscn"],
	["DAY 8 · 월", "경찰차 따돌리기", "경찰보다 먼저 회사 옥상으로", "res://scenes/day8.tscn"],
	["스턴트 코스", "로켓 로드스터 시연장", "차 5대 넘기·말린 램프·타워 30m", "res://scenes/main.tscn"],
	["시연장", "램프 천장 매달리기·킥플립", "천장에서 떨어지며 옆으로 돌기, 장애물 차 위로 F", "res://scenes/demo_stage.tscn"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.16)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 70
	box.offset_right = -70
	box.offset_top = 120
	box.offset_bottom = -60
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	box.add_child(_label("출근길 주차 전쟁", 84, Color(1, 0.86, 0.3)))
	box.add_child(_label("로켓 로드스터 · 날아서 먼저 대면 내 자리" if WebBridge.demo else "로켓 로드스터 · 그래픽 없는 프로토타입", 36, Color(1, 1, 1, 0.7)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	box.add_child(gap)

	for i in _entries().size():
		var e: Array = _entries()[i]
		var b := Button.new()
		b.text = "%d   %s  ·  %s\n      %s" % [(i + 1) % 10, e[0], e[1], e[2]] # 열 번째는 0
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 36)
		b.custom_minimum_size = Vector2(0, 122)
		b.pressed.connect(_go.bind(e[3]))
		box.add_child(b)
		if i == 0:
			b.grab_focus.call_deferred()

	if WebBridge.has_board:
		var board := Button.new()
		board.text = "랭킹 보기"
		board.add_theme_font_override("font", FONT)
		board.add_theme_font_size_override("font_size", 40)
		board.custom_minimum_size = Vector2(0, 110)
		board.pressed.connect(WebBridge.show_board)
		box.add_child(board)
	if DisplayServer.is_touchscreen_available():
		box.add_child(_label("화면 버튼으로 운전 · 메뉴·다시는 위쪽 버튼", 30, Color(1, 1, 1, 0.55)))
	else:
		box.add_child(_label("방향키·WASD 운전 · Space 리프트 · Shift 부스트 · E 흡착 · F 옆돌기\nEsc: 게임 중 이 화면으로 · R: 다시 · Enter: 성공 뒤 다음 날", 30, Color(1, 1, 1, 0.55)))


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = FONT
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var i: int = 9 if event.physical_keycode == KEY_0 else event.physical_keycode - KEY_1
		if i >= 0 and i < _entries().size():
			_go(_entries()[i][3])


## 웹 판은 DAY 1~4만
func _entries() -> Array:
	return ENTRIES.slice(0, WebBridge.DEMO_DAYS) if WebBridge.demo else ENTRIES


func _process(_delta: float) -> void:
	# 메뉴가 떠 있는 동안 Tripo 모델을 하나씩 미리 불러 둔다(누르면 바로 시작하게)
	if not _going:
		AssetCache.warm_step()


func _go(path: String) -> void:
	if _going:
		return
	_going = true
	AssetCache.clicked_ms = Time.get_ticks_msec()
	# 불러오는 동안 화면이 멈추므로 먼저 '불러오는 중'을 한 번 그린다
	var cover := ColorRect.new()
	cover.color = Color(0.06, 0.08, 0.16, 0.85)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var l := _label("불러오는 중…", 64, Color(1, 0.86, 0.3))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(l)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	while AssetCache.warm_step():
		pass
	get_tree().change_scene_to_file(path)
