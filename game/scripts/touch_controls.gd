class_name TouchControls extends CanvasLayer
## 휴대폰 화면 버튼(터치 화면에서만 보인다, 웹 판 쇼츠 링크용). 세로 화면 아래쪽에 왼손 조향, 오른손 가속·브레이크·추진기.
## 버튼은 키보드와 같은 입력 액션을 누른다(TouchScreenButton.action). 가속·브레이크는 공중 기울이기(W/S)도 같이 누른다.
## 위쪽 가운데에 메뉴·다시, 주차에 성공하면 화면 가운데에 '다음 날' 버튼.

const FONT := preload("res://fonts/Pretendard-Bold.otf")
## [글자, 액션, 같이 누를 액션, 반지름, (x, 화면 아래에서 위로 y), 색]. 글자가 "<" ">"면 삼각형을 그린다
const PAD := [
	["<", "left", [], 96.0, Vector2(118, 500), Color(1, 1, 1)],
	[">", "right", [], 96.0, Vector2(322, 500), Color(1, 1, 1)],
	["흡착", "magnet", [], 70.0, Vector2(560, 470), Color(0.55, 0.85, 1.0)],
	["가속", "forward", ["air_forward"], 104.0, Vector2(952, 500), Color(0.55, 1.0, 0.6)],
	["후진", "back", ["air_back"], 72.0, Vector2(772, 440), Color(1.0, 0.6, 0.55)],
	["리프트", "rocket", [], 90.0, Vector2(952, 740), Color(1, 1, 1)],
	["부스트", "boost", [], 72.0, Vector2(772, 650), Color(1.0, 0.85, 0.45)],
	["옆돌기", "barrel_roll", [], 60.0, Vector2(790, 830), Color(0.9, 0.75, 1.0)],
]
## 위쪽 작은 버튼: [글자, 액션, 반지름, 화면 위에서 (x, y)]. 시계(왼쪽 위)·요일(오른쪽 위)·기록(가운데) 아래 양옆
const TOP := [
	["메뉴", "ui_cancel", 50.0, Vector2(100, 360)],
	["다시", "respawn", 50.0, Vector2(980, 360)],
]

var _bottom: Array = [] ## [버튼, 아래에서 y]
var _next: TouchScreenButton


func _ready() -> void:
	layer = 5
	visible = DisplayServer.is_touchscreen_available() # 버튼 글자(Label)는 TouchScreenButton의 보이기 설정을 따르지 않아 층째 숨긴다
	if not visible:
		return # 키보드 화면에서는 버튼을 만들지 않는다(웹 판에서 DAY를 열 때 시간을 아낀다)
	for p: Array in PAD:
		var b := _button(p[0], p[1], p[3], p[5], 0.34)
		for extra: String in p[2]:
			b.pressed.connect(Input.action_press.bind(extra))
			b.released.connect(Input.action_release.bind(extra))
		if p[1] in ["left", "right"]:
			b.passby_press = true # 손가락을 떼지 않고 좌우로 옮겨도 된다
		_bottom.append([b, p[4]])
	for p: Array in TOP:
		var b := _button(p[0], p[1], p[2], Color(1, 1, 1), 0.28)
		b.position = p[3] - Vector2(p[2], p[2])
	_next = _button("다음 날", "restart", 120.0, Color(1.0, 0.85, 0.3), 0.55)
	_next.visible = false
	get_viewport().size_changed.connect(_layout)
	_layout()


## 주차에 성공했을 때만 '다음 날' 버튼을 보인다
func show_next(on: bool) -> void:
	if _next:
		_next.visible = on


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	for e: Array in _bottom:
		var b: TouchScreenButton = e[0]
		var r: float = b.get_meta("r")
		b.position = Vector2(e[1].x, size.y - e[1].y) - Vector2(r, r)
	_next.position = Vector2(size.x * 0.5, size.y * 0.6) - Vector2(120, 120)


func _button(text: String, action: String, r: float, col: Color, alpha: float) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.action = action
	b.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	b.texture_normal = _disc(r, col, alpha)
	b.texture_pressed = _disc(r, col, minf(alpha + 0.35, 0.9))
	var shape := CircleShape2D.new()
	shape.radius = r
	b.shape = shape
	b.shape_centered = true
	b.set_meta("r", r)
	add_child(b)
	if text == "<" or text == ">":
		var s := 1.0 if text == ">" else -1.0
		var tri := Polygon2D.new()
		tri.polygon = PackedVector2Array([Vector2(r - s * r * 0.26, r - r * 0.4), Vector2(r + s * r * 0.36, r), Vector2(r - s * r * 0.26, r + r * 0.4)])
		tri.color = Color(col, 0.85)
		b.add_child(tri)
	else:
		var l := Label.new()
		var ls := LabelSettings.new()
		ls.font = FONT
		ls.font_size = int(clampf(r * 0.42, 26.0, 52.0))
		ls.outline_size = 8
		ls.outline_color = Color(0, 0, 0, 0.7)
		l.label_settings = ls
		l.text = text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = Vector2(r * 2.0, r * 2.0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	return b


## 반투명 원(테두리 진하게). 그러데이션 텍스처로 만든다(픽셀을 하나씩 칠하면 웹 판에서 느렸다)
func _disc(r: float, col: Color, alpha: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var edge := 1.0 - 6.0 / r
	g.offsets = PackedFloat32Array([0.0, edge, 0.995])
	g.colors = PackedColorArray([Color(col, alpha * 0.55), Color(col, minf(alpha + 0.25, 1.0)), Color(col, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = int(r * 2.0)
	t.height = int(r * 2.0)
	return t
