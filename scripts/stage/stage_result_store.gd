class_name RallyStageResultStore
extends RefCounted

const SCHEMA_VERSION := 1
const MAX_RECENT := 20

var path: String = "user://stage_results.cfg"
var buckets: Dictionary = {}


func load_file() -> Error:
	var file := ConfigFile.new()
	var error := file.load(path)
	if error == ERR_FILE_NOT_FOUND:
		buckets.clear()
		return OK
	if error != OK:
		return error
	if int(file.get_value("meta","schema_version",0)) != SCHEMA_VERSION:
		return ERR_FILE_UNRECOGNIZED
	var stored: Variant = file.get_value("results","buckets",{})
	if stored is not Dictionary:
		return ERR_FILE_CORRUPT
	buckets = stored.duplicate(true)
	return OK


func save_file() -> Error:
	var file := ConfigFile.new()
	file.set_value("meta","schema_version",SCHEMA_VERSION)
	file.set_value("results","buckets",buckets)
	return file.save(path)


func record(result: Dictionary) -> Dictionary:
	if bool(result.get("practice",false)):
		return {"saved":false,"reason":"practice","new_record":false,"category":""}
	var clean := _sanitize(result)
	if clean.is_empty():
		return {"saved":false,"reason":"invalid","new_record":false,"category":""}
	var key := bucket_key(clean.stage_id,clean.drive_layout,clean.calibration_version)
	var bucket: Dictionary = buckets.get(key,{
		"stage_id":clean.stage_id,
		"drive_layout":clean.drive_layout,
		"calibration_version":clean.calibration_version,
		"human_best":{},
		"auto_best":{},
		"recent":[],
	})
	var recent: Array = bucket.get("recent",[])
	recent.append(clean)
	while recent.size()>MAX_RECENT: recent.pop_front()
	bucket["recent"] = recent
	var category := ""
	var new_record := false
	if bool(clean.eligible_for_human_best):
		category = "human"
		var previous: Dictionary = bucket.get("human_best",{})
		if previous.is_empty() or float(clean.total_time)<float(previous.total_time):
			bucket["human_best"] = clean.duplicate(true)
			new_record = true
	elif str(clean.driver_source) in ["autopilot_vkeyboard","autopilot_vgamepad"] and int(clean.takeover_count)==0:
		category = str(clean.driver_source)
		var auto_best: Dictionary = bucket.get("auto_best",{})
		var previous: Dictionary = auto_best.get(category,{})
		if previous.is_empty() or float(clean.total_time)<float(previous.total_time):
			auto_best[category] = clean.duplicate(true)
			bucket["auto_best"] = auto_best
			new_record = true
	else:
		category = "mixed"
	buckets[key] = bucket
	return {"saved":true,"reason":"","new_record":new_record,"category":category,"result":clean}


func summary(stage_id: String,drive_layout: String,calibration_version: String) -> Dictionary:
	var bucket: Dictionary = buckets.get(bucket_key(stage_id,drive_layout,calibration_version),{})
	var auto_best: Dictionary = bucket.get("auto_best",{})
	return {
		"human_best":Dictionary(bucket.get("human_best",{})).duplicate(true),
		"autopilot_vkeyboard":Dictionary(auto_best.get("autopilot_vkeyboard",{})).duplicate(true),
		"autopilot_vgamepad":Dictionary(auto_best.get("autopilot_vgamepad",{})).duplicate(true),
		"recent":Array(bucket.get("recent",[])).duplicate(true),
	}


static func bucket_key(stage_id: String,drive_layout: String,calibration_version: String) -> String:
	return "%s|%s|%s"%[stage_id,drive_layout,calibration_version]


static func _sanitize(value: Dictionary) -> Dictionary:
	var stage_id := str(value.get("stage_id","")).strip_edges()
	var drive_layout := str(value.get("drive_layout",""))
	var calibration_version := str(value.get("calibration_version","")).strip_edges()
	var source := str(value.get("driver_source",""))
	var elapsed := float(value.get("elapsed",-1))
	var penalty := float(value.get("penalty",-1))
	var total := float(value.get("total_time",-1))
	if stage_id.is_empty() or calibration_version.is_empty() or drive_layout not in ["FWD","AWD","RWD"]:
		return {}
	if source not in RallyAutoDriver.SOURCE_NAMES or not is_finite(elapsed) or not is_finite(penalty) or not is_finite(total):
		return {}
	if elapsed<0 or penalty<0 or total<0 or not is_equal_approx(total,elapsed+penalty):
		return {}
	return {
		"stage_id":stage_id,
		"drive_layout":drive_layout,
		"calibration_version":calibration_version,
		"driver_source":source,
		"eligible_for_human_best":bool(value.get("eligible_for_human_best",false)),
		"elapsed":elapsed,
		"penalty":penalty,
		"total_time":total,
		"reset_count":maxi(0,int(value.get("reset_count",0))),
		"takeover_count":maxi(0,int(value.get("takeover_count",0))),
		"recorded_at":maxi(0,int(value.get("recorded_at",Time.get_unix_time_from_system()))),
	}
