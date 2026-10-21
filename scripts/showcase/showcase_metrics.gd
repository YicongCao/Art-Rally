class_name RallyShowcaseMetrics
extends RefCounted

# Wall-clock frame cadence, independent of the replay clock and Engine FPS smoothing.
var frames: Array[Vector2] = []
var previous_usec := -1
var enabled := true

func reset() -> void:
	frames.clear()
	break_interval()

func break_interval() -> void:
	previous_usec=-1

func tick(now_usec: int,film_time: float) -> void:
	if not enabled: return
	if previous_usec>=0 and now_usec>previous_usec:
		frames.append(Vector2(film_time,float(now_usec-previous_usec)/1000000.0))
	previous_usec=now_usec

func report() -> Dictionary:
	if frames.is_empty(): return {}
	var total := 0.0
	var shortest := INF
	var longest := 0.0
	var bins := {}
	for frame: Vector2 in frames:
		total+=frame.y
		shortest=minf(shortest,frame.y)
		longest=maxf(longest,frame.y)
		var key := mini(149,int(frame.x*2))
		if not bins.has(key): bins[key]=Vector2.ZERO
		bins[key]+=Vector2(1,frame.y)
	var curve: Array[Vector2]=[]
	for key: int in bins:
		var bin: Vector2=bins[key]
		curve.append(Vector2((key+.5)*.5,bin.x/bin.y))
	return {"average":frames.size()/total,"maximum":1.0/shortest,"minimum":1.0/longest,"seconds":total,"frames":frames.size(),"curve":curve}
