class_name RallyContentCatalog
extends RefCounted

const STAGES := ["sunset_ridge","sunlit_cape","misty_highlands","redrock_canyon"]
const VEHICLES := ["F160","R200","A240","I20","DELTA","EVO6","WRX","P7"]
const POWER_MULTIPLIERS := [1.0,1.5,2.0]
const POWER_LABELS := ["原厂组","进阶组","极限组"]


static func stage(id: String) -> RallyStageDefinition:
	if id not in STAGES: return null
	return load("res://resources/stages/"+id+".tres").duplicate(true) as RallyStageDefinition


static func vehicle(id: String,tier: int = 0) -> RallyVehicleDefinition:
	if id not in VEHICLES or tier<0 or tier>=POWER_MULTIPLIERS.size(): return null
	var result := load("res://resources/content/"+id+".tres").duplicate(true) as RallyVehicleDefinition
	# Livery belongs to the visual revision; mechanical resources and keys stay stable.
	if id in ["F160","R200","A240"]: result.paint={"F160":Color("246263"),"R200":Color("ae4e36"),"A240":Color("493e5c")}[id]
	if id in ["F160","R200","A240"]: result.accent=Color("eee2c5") if id!="A240" else Color("d6a83c")
	result.power_tier = tier
	result.power_ps *= POWER_MULTIPLIERS[tier]
	if tier>0: result.revision += "-p%d"%int(POWER_MULTIPLIERS[tier]*100)
	return result


static func challenge(stage_id: String,vehicle_id: String,tier: int = 0) -> RallyChallengeDefinition:
	var track := stage(stage_id)
	var car := vehicle(vehicle_id,tier)
	if track==null or car==null: return null
	var result := RallyChallengeDefinition.new()
	result.stage = track
	result.vehicle = car
	var targets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/content/challenge_targets.json"))
	var target: Dictionary = targets.challenges[stage_id+"/"+vehicle_id+("/p%d"%int(POWER_MULTIPLIERS[tier]*100) if tier>0 else "")]
	assert(target.stage_version==track.stage_version and target.vehicle_revision==car.revision)
	result.reference_seconds = float(target.reference_seconds)
	result.human_calibrated = bool(target.human_calibrated)
	result.rules_version = str(targets.rules_version)
	return result


static func power_label(id: String,tier: int) -> String:
	return "%d PS"%vehicle(id,tier).power_ps
