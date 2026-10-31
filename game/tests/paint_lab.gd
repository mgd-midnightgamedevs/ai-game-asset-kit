extends Node3D
## 칠 실험실: 세워 둔 차 모델 4종 × CarPaint 배색(뒤 네 줄), 맨 앞줄은 앞차 SUV 색 후보.
## DAY 1과 같은 하늘·해 아래에서 한 장을 찍어 저장하고 끝낸다(창이 있는 실행에서만 찍힌다).
##   Godot --path . res://tests/paint_lab.tscn -- out=C:/경로/lab.png

const MODELS := ["hatchback", "sedan", "van", "suv"]
## 앞차 후보: [이름, 칠 HSV, 금속도, 넓은 칠 판정]
const RIVAL := [
	["now_yellow", Vector3(0.134, 0.94, 1.0), 0.15, false],
	["yellow_fix", Vector3(0.12, 0.85, 0.95), 0.05, true],
	["tangerine", Vector3(0.065, 0.85, 0.95), 0.05, true],
	["teal", Vector3(0.49, 0.75, 0.62), 0.1, true],
	["mint", Vector3(0.42, 0.35, 0.82), 0.05, true],
	["sky", Vector3(0.56, 0.55, 0.9), 0.05, true],
	["cherry", Vector3(0.0, 0.8, 0.75), 0.15, true],
	["white", Vector3(0.6, 0.02, 0.92), 0.1, true],
]

var out := "user://paint_lab.png"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	_world()
	for r in MODELS.size():
		for c in CarPaint.PALETTE.size():
			var name_c: String = CarPaint.PALETTE[c][0]
			var car := _car(MODELS[r], Vector3(c * 2.7, 0, (MODELS.size() - r) * 5.0))
			CarPaint.paint(car, MODELS[r], name_c)
			_label("%s %s" % [MODELS[r], name_c], Vector3(c * 2.7, 0.05, (MODELS.size() - r) * 5.0 - 2.2))
	for c in RIVAL.size():
		var car := _car("suv", Vector3(c * 2.7, 0, 0))
		_rival_paint(car, RIVAL[c])
		_label("rival " + String(RIVAL[c][0]), Vector3(c * 2.7, 0.05, -2.2))
	var vp := SubViewport.new()
	vp.size = Vector2i(2600, 1500)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	cam.global_position = Vector3(9.45, 12.0, -14.0)
	cam.look_at(Vector3(9.45, 0.4, 10.5), Vector3.UP)
	cam.current = true
	for i in 20:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("PAINT_LAB saved ", out)
	get_tree().quit()


func _car(model_name: String, pos: Vector3) -> Node3D:
	var n: Node3D = (load("res://assets/models/%s/%s.glb" % [model_name, model_name]) as PackedScene).instantiate()
	n.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(205.0)), pos)
	add_child(n)
	return n


func _rival_paint(node: Node, c: Array) -> void:
	var src: Vector3 = CarPaint.SOURCES.suv.hsv
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			var sm := ShaderMaterial.new()
			sm.shader = CarPaint.SHADER
			sm.set_shader_parameter("albedo_tex", m.albedo_texture)
			sm.set_shader_parameter("orm_tex", m.roughness_texture)
			sm.set_shader_parameter("normal_tex", m.normal_texture)
			sm.set_shader_parameter("normal_scale", m.normal_scale)
			sm.set_shader_parameter("paint_on", true)
			sm.set_shader_parameter("mask_wide", c[3])
			sm.set_shader_parameter("src_hue", src.x)
			sm.set_shader_parameter("paint_ref_s", src.y)
			sm.set_shader_parameter("paint_ref_v", src.z)
			sm.set_shader_parameter("paint_hsv", c[1])
			sm.set_shader_parameter("paint_metallic", c[2])
			mi.set_surface_override_material(i, sm)


func _label(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.006
	l.outline_size = 10
	l.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).rotated(Vector3.UP, PI), pos)
	add_child(l)


func _world() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.36, 0.62)
	sky_mat.sky_horizon_color = Color(0.86, 0.74, 0.62)
	sky_mat.ground_bottom_color = Color(0.2, 0.22, 0.26)
	sky_mat.ground_horizon_color = Color(0.86, 0.74, 0.62)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3(0.866025, 0, -0.5), Vector3(-0.321394, 0.766044, -0.55667), Vector3(0.383022, 0.642788, 0.663414)), Vector3.ZERO)
	sun.light_color = Color(1, 0.93, 0.82)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.31, 0.33)
	ground.material_override = gm
	ground.position = Vector3(10, 0, 10)
	add_child(ground)
