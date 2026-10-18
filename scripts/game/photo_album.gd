class_name RallyPhotoAlbum
extends RefCounted

const LIMIT := 64
var directory: String = "user://player/gallery"
var message: String = ""

func entries() -> Array:
	var value: Variant = RallyProfileStore.read_json(directory+"/index.json")
	if not _valid(value): value = RallyProfileStore.read_json(directory+"/index.json.bak")
	if not _valid(value): return []
	var result: Array = []
	for entry: Dictionary in value.photos:
		if FileAccess.file_exists(directory+"/"+entry.file): result.append(entry)
	return result

func store(image: Image,metadata: Dictionary) -> String:
	message = ""
	if image==null or image.is_empty():
		message = "航拍照片未能生成"
		return ""
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error!=OK:
		message = "相册保存失败"
		return ""
	var file := "photo-%d-%d.jpg"%[Time.get_unix_time_from_system()*1000,Time.get_ticks_usec()]
	error = image.save_jpg(directory+"/"+file+".tmp",.88)
	if error==OK: error = DirAccess.rename_absolute(directory+"/"+file+".tmp",directory+"/"+file)
	if error!=OK:
		message = "航拍照片保存失败"
		return ""
	var photos := entries()
	var entry := metadata.duplicate(true)
	entry["file"] = file
	entry["created_at"] = Time.get_unix_time_from_system()
	entry["camera"] = "helicopter"
	entry["time"] = metadata.get("time",0.0)
	photos.push_front(entry)
	var removed: Array = []
	while photos.size()>LIMIT: removed.append(photos.pop_back())
	error = RallyProfileStore.atomic_json(directory+"/index.json",{"version":1,"photos":photos})
	if error!=OK:
		DirAccess.remove_absolute(directory+"/"+file)
		message = "相册索引保存失败，已有照片已保留"
		return ""
	for old: Dictionary in removed: DirAccess.remove_absolute(directory+"/"+old.file)
	return file

func texture(entry: Dictionary,thumbnail: bool = false) -> ImageTexture:
	if not _safe_file(str(entry.get("file",""))): return null
	var file := FileAccess.open(directory+"/"+entry.file,FileAccess.READ)
	if file==null or file.get_length()>8*1024*1024: return null
	var image := Image.new()
	if image.load_jpg_from_buffer(file.get_buffer(file.get_length()))!=OK: return null
	if thumbnail: image.resize(320,180,Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

static func _safe_file(file: String) -> bool:
	return file==file.get_file() and file.begins_with("photo-") and file.ends_with(".jpg")

static func _valid(value: Variant) -> bool:
	if value is not Dictionary or value.get("version",0)!=1 or value.get("photos") is not Array or value.photos.size()>LIMIT: return false
	for photo: Variant in value.photos:
		if photo is not Dictionary or not _safe_file(str(photo.get("file",""))): return false
		if photo.get("stage","") not in RallyContentCatalog.STAGES or photo.get("vehicle","") not in RallyContentCatalog.VEHICLES: return false
		if not RallyGhostRecording.numeric(photo.get("power_ps",null)) or float(photo.power_ps)<=0: return false
		if not RallyGhostRecording.numeric(photo.get("created_at",null)): return false
	return true
