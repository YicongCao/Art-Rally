class_name RallySynthAudio
extends RefCounted

static var cache: Dictionary = {}


static func stream(kind: String) -> AudioStreamWAV:
	if cache.has(kind): return cache[kind]
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var count := 5512 if kind=="impact" else 11025
	var pcm := PackedByteArray()
	pcm.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var filtered := 0.0
	for i: int in range(count):
		var t := float(i)/audio.mix_rate
		var noise := rng.randf_range(-1,1)
		filtered = lerpf(filtered,noise,0.12 if kind in ["mud","water"] else 0.45)
		var value := 0.0
		match kind:
			"engine": value = sin(TAU*100*t)*0.4+sin(TAU*200*t)*0.21+sin(TAU*400*t)*0.10
			"load": value = sin(TAU*100*t)*0.23+sin(TAU*300*t)*0.18+sin(TAU*600*t)*0.08+filtered*0.20
			"asphalt": value = filtered*0.28+sin(TAU*780*t)*0.08
			"gravel": value = filtered*0.55+(noise*0.22 if rng.randf()<0.05 else 0.0)
			"mud": value = filtered*0.8+sin(TAU*58*t)*0.08
			"water": value = filtered*0.7+noise*0.17
			"impact": value = (sin(TAU*64*t)*0.5+filtered*0.45)*exp(-t*24)
		var fade := minf(minf(i/80.0,(count-i-1)/80.0),1.0)
		pcm.encode_s16(i*2,int(clampf(value*fade*0.6,-0.8,0.8)*32767))
	audio.data = pcm
	if kind!="impact":
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
		audio.loop_end = count
	cache[kind] = audio
	return audio
