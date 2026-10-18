extends "res://tests/test_suite.gd"


class NotePreview extends RallyHUD:
	func _draw() -> void:
		_draw_note()


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"Pacenote preview requires a graphics window")
		finish()
		return
	root.size = Vector2i(800,270)
	root.content_scale_size = Vector2i(800,270)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var codes := ["LEFT_MEDIUM","RIGHT_MEDIUM","LEFT_TIGHT","RIGHT_TIGHT"]
	for i: int in range(codes.size()):
		var card := NotePreview.new()
		root.add_child(card)
		card.position = Vector2(25+(i%2)*400-465,25+(i/2)*120-24)
		card.refresh({"note":codes[i],"note_distance":120})
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/previews")
	check(root.get_texture().get_image().save_png("res://docs/previews/pacenote-arrows.png")==OK,"Four production pacenote cards rendered and saved")
	finish()
