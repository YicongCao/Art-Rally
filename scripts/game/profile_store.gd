class_name RallyProfileStore
extends RefCounted

const VERSION := 1
var path: String = "user://player/profile.json"
var data: Dictionary = fresh()
var message: String = ""
var read_only: bool = false
var loaded_from_backup: bool = false


static func fresh() -> Dictionary:
	return {"version":VERSION,"settings":{},"bindings":{},"plate":"","tutorial_complete":false,"last_stage":"sunset_ridge","last_vehicle":"F160","last_power_tier":0,"unlocked_power_tier":0,"challenges":{}}


func load_file() -> Error:
	message = ""
	read_only = false
	loaded_from_backup = false
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"):
		data = fresh()
		var legacy := RallyGameSettings.new()
		legacy.load_file()
		data.settings = legacy.values.duplicate(true)
		if path=="user://player/profile.json" and FileAccess.file_exists("user://stage_results.cfg"):
			var archive := path.get_base_dir()+"/archive/prototype-stage-results.cfg"
			if not FileAccess.file_exists(archive):
				var error := DirAccess.make_dir_recursive_absolute(archive.get_base_dir())
				if error==OK: error = DirAccess.copy_absolute("user://stage_results.cfg",archive)
				if error!=OK: message = "旧原型成绩仍保留在原文件，归档副本创建失败。"
		return OK
	var candidate: Variant = read_json(path)
	if valid(candidate):
		data = candidate
		return OK
	candidate = read_json(path+".bak")
	if valid(candidate):
		data = candidate
		loaded_from_backup = true
		message = "已从上一份有效备份恢复进度"
		return OK
	read_only = true
	data = fresh()
	message = "存档读取失败：原文件已保留。本次可以游玩，但进度不会覆盖原存档。"
	return ERR_FILE_CORRUPT


func save_file() -> Error:
	if read_only: return ERR_FILE_CORRUPT
	if not valid(data): return ERR_INVALID_DATA
	var error := atomic_json(path,data,not loaded_from_backup)
	if error==OK: loaded_from_backup = false
	else: message = "保存失败：已保留上次进度，请检查磁盘空间与权限。"
	return error


func result_for(key: String) -> Dictionary:
	return Dictionary(data.challenges.get(key,{})).duplicate(true)


func unlocked_power_tier() -> int:
	var unlocked := int(data.get("unlocked_power_tier",0))
	# Earned gold from fp1 remains an unlock milestone after the shoulder/rules update.
	# Only known content keys and valid human bests qualify, not arbitrary archived medals.
	for stage_id: String in RallyContentCatalog.STAGES:
		for car_id: String in RallyContentCatalog.VEHICLES:
			var legacy_key := "%s@1|%s@fp1|time-trial-1"%[stage_id,car_id]
			var bucket := result_for(legacy_key)
			if int(bucket.get("medal",0))==3 and valid_result(bucket.get("best",null)):
				unlocked = maxi(unlocked,1)
	return unlocked


func set_plate(value: String) -> Error:
	value = value.strip_edges()
	if not RallyPlateText.valid(value): return ERR_INVALID_PARAMETER
	var original := data.duplicate(true)
	data["plate"] = value
	var error := save_file()
	if error != OK: data = original
	return error


func record(challenge: RallyChallengeDefinition,result: Dictionary,ghost: Dictionary) -> Dictionary:
	if result.get("practice",false) or result.get("source","") not in ["human_keyboard","human_gamepad"]:
		return {"eligible":false,"saved":false,"new_best":false,"reason":"非正式玩家挑战"}
	if not valid_result(result): return {"eligible":false,"saved":false,"reason":"成绩无效"}
	if challenge.vehicle.power_tier>unlocked_power_tier():
		return {"eligible":false,"saved":false,"reason":"动力版本尚未解锁"}
	var previous_unlock := unlocked_power_tier()
	var key := challenge.key()
	var previous: Dictionary = data.challenges.get(key,{})
	var old_best: Dictionary = previous.get("best",{})
	var new_best := old_best.is_empty() or float(result.total_time)<float(old_best.total_time)-0.000001
	var working := data.duplicate(true)
	var bucket: Dictionary = working.challenges.get(key,{"medal":0,"best":{},"recent":[]})
	var earned := challenge.medal(float(result.total_time))
	bucket.medal = maxi(int(bucket.medal),earned)
	var recent: Array = bucket.recent
	recent.append(result.duplicate(true))
	while recent.size()>20: recent.pop_front()
	var created_path := ""
	var ghost_warning := ""
	if new_best:
		var best := result.duplicate(true)
		best["ghost"] = ""
		if RallyGhostRecording.valid(ghost,key):
			var filename := key.sha256_text()+"-"+str(Time.get_ticks_usec())+".json"
			created_path = path.get_base_dir()+"/ghosts/"+filename
			var error := atomic_json(created_path,ghost,false)
			if error!=OK: return {"eligible":true,"saved":false,"new_best":false,"reason":"幽灵保存失败，原纪录仍保留"}
			best.ghost = filename
		else:
			return {"eligible":true,"saved":false,"new_best":false,"reason":"本次轨迹不完整，成绩与幽灵未写入，原纪录仍保留。"}
		bucket.best = best
	working.challenges[key] = bucket
	var unlocked := previous_unlock
	if earned==3 and challenge.vehicle.power_tier==previous_unlock: unlocked = mini(2,previous_unlock+1)
	working["unlocked_power_tier"] = unlocked
	var original := data
	data = working
	var error := save_file()
	if error!=OK:
		data = original
		if not created_path.is_empty(): DirAccess.remove_absolute(created_path)
		return {"eligible":true,"saved":false,"new_best":false,"reason":message}
	_cleanup_ghosts()
	return {"eligible":true,"saved":true,"new_best":new_best,"medal":earned,"previous_best":old_best.get("total_time",-1.0),"unlocked_tier":unlocked if unlocked>previous_unlock else -1,"reason":ghost_warning}


func load_ghost(challenge: RallyChallengeDefinition) -> Dictionary:
	var bucket := result_for(challenge.key())
	var best: Dictionary = bucket.get("best",{})
	var filename := str(best.get("ghost",""))
	if filename.is_empty() or filename!=filename.get_file() or not filename.begins_with(challenge.key().sha256_text()+"-"): return {}
	var value: Variant = read_json(path.get_base_dir()+"/ghosts/"+filename)
	if RallyGhostRecording.valid(value,challenge.key()): return value
	message = "个人最佳仍保留；幽灵文件损坏或不兼容，已跳过播放。"
	return {}


func _cleanup_ghosts() -> void:
	var keep: Array[String] = []
	for profile: Variant in [data,read_json(path+".bak")]:
		if not valid(profile): continue
		for bucket: Dictionary in profile.challenges.values():
			keep.append(str(bucket.get("best",{}).get("ghost","")))
	var directory := path.get_base_dir()+"/ghosts"
	var access := DirAccess.open(directory)
	if access==null: return
	var owned := RegEx.new()
	owned.compile("^[a-f0-9]{64}-[0-9]+[.]json$")
	for file: String in access.get_files():
		if owned.search(file)!=null and file not in keep: DirAccess.remove_absolute(directory+"/"+file)


static func valid_result(value: Variant) -> bool:
	if value is not Dictionary: return false
	for key: String in ["elapsed","penalty","total_time"]:
		if not RallyGhostRecording.numeric(value.get(key,null)) or float(value[key])<0: return false
	if float(value.total_time)<=0 or absf(float(value.total_time)-float(value.elapsed)-float(value.penalty))>0.01: return false
	if value.get("source","") not in ["human_keyboard","human_gamepad"] or value.get("practice",false): return false
	var splits: Variant = value.get("splits",null)
	if splits is not Array or splits.size()!=3: return false
	var previous := 0.0
	for split: Variant in splits:
		if not RallyGhostRecording.numeric(split) or float(split)<previous or float(split)>float(value.total_time)+0.01: return false
		previous = float(split)
	return absf(previous-float(value.total_time))<0.01


static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.get("version",0)!=VERSION: return false
	# Optional additive field: existing profiles keep all results and request setup once.
	if not RallyPlateText.valid(value.get("plate",""),true): return false
	for key: String in ["settings","bindings","challenges"]:
		if value.get(key,null) is not Dictionary: return false
	for field: String in ["last_power_tier","unlocked_power_tier"]:
		var tier: Variant = value.get(field,0)
		if not RallyGhostRecording.numeric(tier) or float(tier)!=floorf(float(tier)) or int(tier)<0 or int(tier)>2: return false
	var mapped: Array[int] = []
	for action: String in value.bindings:
		var code: Variant = value.bindings[action]
		if int(action) not in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_SPACE,KEY_R,KEY_C,KEY_Q,KEY_E]: return false
		if not RallyGhostRecording.numeric(code) or float(code)!=floorf(float(code)) or int(code)<=0 or int(code) in mapped: return false
		mapped.append(int(code))
	if value.get("tutorial_complete",null) is not bool: return false
	if value.get("last_stage","") not in RallyContentCatalog.STAGES or value.get("last_vehicle","") not in RallyContentCatalog.VEHICLES: return false
	for key: Variant in value.challenges:
		var bucket: Variant = value.challenges[key]
		if key is not String or bucket is not Dictionary: return false
		if not RallyGhostRecording.numeric(bucket.get("medal",null)) or int(bucket.medal)<0 or int(bucket.medal)>3: return false
		if not valid_result(bucket.get("best",null)): return false
		if bucket.get("recent",null) is not Array or bucket.recent.size()>20: return false
		for result: Variant in bucket.recent:
			if not valid_result(result): return false
	return true


static func read_json(filename: String) -> Variant:
	var file := FileAccess.open(filename,FileAccess.READ)
	if file==null or file.get_length()>32*1024*1024: return null
	var parser := JSON.new()
	return parser.data if parser.parse(file.get_as_text())==OK else null


static func atomic_json(filename: String,value: Dictionary,backup: bool = true) -> Error:
	var directory := filename.get_base_dir()
	var ancestor := directory
	while not ancestor.is_empty() and ancestor!=ancestor.get_base_dir():
		if FileAccess.file_exists(ancestor): return ERR_FILE_CANT_WRITE
		ancestor = ancestor.get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error!=OK: return error
	var file := FileAccess.open(filename+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value))
	file.flush()
	error = file.get_error()
	file.close()
	if error!=OK: return error
	if backup and FileAccess.file_exists(filename):
		error = DirAccess.copy_absolute(filename,filename+".bak.tmp")
		if error!=OK: return error
		error = DirAccess.rename_absolute(filename+".bak.tmp",filename+".bak")
		if error!=OK: return error
	return DirAccess.rename_absolute(filename+".tmp",filename)
