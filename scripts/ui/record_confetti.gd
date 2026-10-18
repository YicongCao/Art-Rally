class_name RallyRecordConfetti
extends Control

var pieces: Array[Dictionary] = []
var clock: float = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 2749
	for i: int in range(62):
		pieces.append({"p":Vector2(220+rng.randf_range(-80,80),42),"v":Vector2(rng.randf_range(-210,210),rng.randf_range(-185,-60)),"spin":rng.randf_range(-8,8),"phase":rng.randf_range(0,TAU),"color":[Color("eeb65a"),Color("e66c75"),Color("64b3c6"),Color("bfa2de"),Color("9fc375")][i%5]})

func _process(dt: float) -> void:
	clock += dt
	if clock>2.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for piece: Dictionary in pieces:
		var at: Vector2 = piece.p+piece.v*clock+Vector2(0,125*clock*clock)
		var color: Color = piece.color
		color.a = 1-smoothstep(1.2,2.0,clock)
		draw_set_transform(at,piece.phase+clock*piece.spin,Vector2(1,cos(clock*5+piece.phase)))
		draw_rect(Rect2(-3,-1.8,6,3.6),color)
	draw_set_transform(Vector2.ZERO)
