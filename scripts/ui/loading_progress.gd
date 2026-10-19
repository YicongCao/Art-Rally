class_name RallyLoadingProgress
extends ProgressBar

var checks := ColorRect.new()
var visual_ratio: float = 0

func _ready() -> void:
	show_percentage=false
	var track := StyleBoxFlat.new()
	track.bg_color=Color("333a42")
	add_theme_stylebox_override("background",track)
	add_theme_stylebox_override("fill",StyleBoxEmpty.new())
	checks.mouse_filter=Control.MOUSE_FILTER_IGNORE
	checks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ink := ShaderMaterial.new()
	ink.shader=preload("res://assets/shaders/loading_checks.gdshader")
	checks.material=ink
	add_child(checks)
	value_changed.connect(func(_value: float): refresh())
	resized.connect(refresh)
	refresh()

func refresh() -> void:
	if checks.material==null: return
	checks.material.set_shader_parameter("completion",visual_ratio)
	checks.material.set_shader_parameter("extent",size)


func _process(dt: float) -> void:
	advance_visual(minf(dt,.05))

func advance_visual(dt: float) -> void:
	# The renderer may stall during scene assembly; never turn that long frame
	# into a jump. Ease toward the real target and never get ahead of it.
	if ratio<visual_ratio: visual_ratio=ratio
	visual_ratio=move_toward(visual_ratio,ratio,maxf((ratio-visual_ratio)*15,.12)*dt)
	refresh()
