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
	# Replace only with documented, three-run human baselines at release calibration.
	var references := {"sunset_ridge":[265.0,260.0,240.0],"sunlit_cape":[220.0,215.0,205.0],"misty_highlands":[290.0,285.0,265.0]}
	result.reference_seconds = references[stage_id][VEHICLES.find(vehicle_id)]
	return result
