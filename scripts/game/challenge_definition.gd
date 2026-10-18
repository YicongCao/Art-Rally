class_name RallyChallengeDefinition
extends RefCounted

const RULES_VERSION := "time-trial-1"
var stage: RallyStageDefinition
var vehicle: RallyVehicleDefinition
var reference_seconds: float = 240
# Provisional engineering targets are usable but never presented as human-calibrated.
var human_calibrated: bool = false


func key() -> String:
	return "%s@%s|%s@%s|%s"%[stage.stage_id,stage.stage_version,vehicle.vehicle_id,vehicle.revision,RULES_VERSION]


func thresholds() -> Array[float]:
	return [ceilf(reference_seconds*1.40),ceilf(reference_seconds*1.20),ceilf(reference_seconds*1.05)]


func medal(seconds: float) -> int:
	if not is_finite(seconds) or seconds<=0: return 0
	var targets := thresholds()
	for i: int in range(2,-1,-1):
		if seconds<=targets[i]: return i+1
	return 0


func next_target(seconds: float) -> float:
	var earned := medal(seconds)
	return -1.0 if earned==3 else thresholds()[earned]
