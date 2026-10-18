class_name RallyGaugePatina
extends RefCounted

# Printed decoration, not live dirt: stable across frames and kept outside readouts.
static func tread(canvas: CanvasItem, origin: Vector2, angle: float, rows: int, scale: float = 1.0) -> void:
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	for row: int in range(rows):
		for side: int in [-1,1]:
			var points := PackedVector2Array()
			for point: Vector2 in [Vector2(0,2),Vector2(5,13),Vector2(10,13),Vector2(5,2)]:
				points.append(origin+(along*(row*13+point.x)+across*point.y*side)*scale)
			canvas.draw_colored_polygon(points,Color(.73,.62,.42,.17 if row%3==0 else .27))


static func mud(canvas: CanvasItem, origin: Vector2, extent: Vector2, seed_value: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for i: int in range(25):
		var position := origin+Vector2(random.randf_range(-extent.x,extent.x),random.randf_range(-extent.y,extent.y))
		var radius := random.randf_range(.5,2.6) if i%7!=0 else 4.0
		var points := PackedVector2Array()
		for j: int in range(7):
			points.append(position+Vector2.from_angle(j*TAU/7)*radius*random.randf_range(.65,1.3))
		canvas.draw_colored_polygon(points,Color(.58,.39,.20,random.randf_range(.25,.52)))
		if i%7==0:
			canvas.draw_line(position-Vector2(2,2),position-Vector2(6,8),Color(.68,.49,.28,.33),1,true)
