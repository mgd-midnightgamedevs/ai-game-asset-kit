class_name CarPaint
## Tripo 차 모델의 원래 칠을 다른 색으로 바꾼다(shaders/car_paint.gdshader). 세워 둔 차가 쓴다.
## 모델마다 원래 칠이 한 가지라(해치백·세단·밴 흰색, SUV 남색) 그대로 두면 같은 차가 같은 색으로 줄지어 선다.
## 실제 길처럼 흰·검정·회색·은색 위주로, 바로 옆 차와 같은 색이 되지 않게 고른다.

const SHADER := preload("res://shaders/car_paint.gdshader")
## 원래 칠: white면 채도 없는 밝은 픽셀(평균 밝기 v), 아니면 색상·채도·밝기 평균(hsv)
const SOURCES := {
	"hatchback": {"white": true, "v": 0.9},
	"sedan": {"white": true, "v": 0.88},
	"van": {"white": true, "v": 0.92},
	"suv": {"white": false, "hsv": Vector3(0.646, 0.686, 0.656)},
}
## [이름, 칠 HSV(sRGB), 금속도, 뽑힐 비중]. 흰색 원본 모델의 "white"는 텍스처 그대로 둔다
const PALETTE := [
	["white", Vector3(0.6, 0.02, 0.9), 0.2, 26],
	["black", Vector3(0.62, 0.1, 0.09), 0.3, 18],
	["gunmetal", Vector3(0.6, 0.08, 0.32), 0.4, 14],
	["silver", Vector3(0.6, 0.04, 0.68), 0.5, 16],
	["navy", Vector3(0.63, 0.6, 0.3), 0.3, 8],
	["burgundy", Vector3(0.985, 0.7, 0.42), 0.3, 6],
	["champagne", Vector3(0.09, 0.2, 0.74), 0.35, 6],
	["slate_blue", Vector3(0.6, 0.45, 0.52), 0.3, 6],
]

static var _cache := {}


## 바로 앞 색(last)과 다른 색 이름을 비중대로 뽑는다
static func pick(rng: RandomNumberGenerator, last := "") -> String:
	var total := 0
	for p in PALETTE:
		total += p[3]
	for _try in 8:
		var r := rng.randi_range(0, total - 1)
		for p in PALETTE:
			r -= p[3]
			if r < 0:
				if p[0] != last:
					return p[0]
				break
	return "silver" if last != "silver" else "black"


## node 아래 모델 메시를 color_name 색으로 칠한다(같은 모델·색은 재질을 같이 쓴다)
static func paint(node: Node, model_name: String, color_name: String) -> void:
	var src: Dictionary = SOURCES.get(model_name, {})
	if src.is_empty() or (src.white and color_name == "white"):
		return
	var entry: Array = []
	for p in PALETTE:
		if p[0] == color_name:
			entry = p
	if entry.is_empty():
		return
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var key := "%s|%d|%s" % [model_name, i, color_name]
			if not _cache.has(key):
				var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
				if m == null:
					continue
				var sm := ShaderMaterial.new()
				sm.shader = SHADER
				sm.set_shader_parameter("albedo_tex", m.albedo_texture)
				sm.set_shader_parameter("orm_tex", m.roughness_texture)
				sm.set_shader_parameter("normal_tex", m.normal_texture)
				sm.set_shader_parameter("normal_scale", m.normal_scale)
				sm.set_shader_parameter("paint_on", true)
				sm.set_shader_parameter("paint_hsv", entry[1])
				sm.set_shader_parameter("paint_metallic", entry[2])
				if src.white:
					sm.set_shader_parameter("src_white", true)
					sm.set_shader_parameter("paint_ref_v", src.v)
				else:
					var h: Vector3 = src.hsv
					sm.set_shader_parameter("mask_wide", true)
					sm.set_shader_parameter("src_hue", h.x)
					sm.set_shader_parameter("paint_ref_s", h.y)
					sm.set_shader_parameter("paint_ref_v", h.z)
				_cache[key] = sm
			mi.set_surface_override_material(i, _cache[key])
