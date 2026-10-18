class_name RallyContentCatalog
extends RefCounted

const STAGES := ["sunset_ridge","sunlit_cape","misty_highlands"]
const VEHICLES := ["F160","R200","A240"]


static func stage(id: String) -> RallyStageDefinition:
	if id not in STAGES: return null
	return load("res://resources/stages/"+id+".tres").duplicate(true) as RallyStageDefinition


static func vehicle(id: String) -> RallyVehicleDefinition:
	if id not in VEHICLES: return null
	return load("res://resources/content/"+id+".tres").duplicate(true) as RallyVehicleDefinition


static func challenge(stage_id: String,vehicle_id: String) -> RallyChallengeDefinition:
	var track := stage(stage_id)
	var car := vehicle(vehicle_id)
	if track==null or car==null: return null
	var result := RallyChallengeDefinition.new()
	result.stage = track
	result.vehicle = car
	var targets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/content/challenge_targets.json"))
	var target: Dictionary = targets.challenges[stage_id+"/"+vehicle_id]
	assert(target.stage_version==track.stage_version and target.vehicle_revision==car.revision)
	result.reference_seconds = float(target.reference_seconds)
	result.human_calibrated = bool(target.human_calibrated)
	result.rules_version = str(targets.rules_version)
	return result
