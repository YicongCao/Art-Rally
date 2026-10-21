class_name RallyStageFacts
extends Control

var definition: RallyStageDefinition
var turns: int = 0
const PAPER := Color("eee2c5")
const MUTED := Color("a7b5b3")
const COLORS := [Color("8c9eaa"),Color("e8b15b"),Color("bc7356")]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(0,208)
	var route := RallyStageRoute.new()
	route.build(definition)
	turns=route.turn_count
	resized.connect(queue_redraw)

func _draw() -> void:
	if definition==null: return
	var w := size.x
	draw_string(RallyFonts.DISPLAY,Vector2(0,23),"03 / STAGE NOTES",HORIZONTAL_ALIGNMENT_LEFT,-1,22,PAPER)
	draw_line(Vector2(0,36),Vector2(w,36),Color("f05a28"),2)
	var proportions := definition.surface_proportions()
	var x := 0.0
	for i: int in range(3):
		var width := w*proportions[i]
		draw_rect(Rect2(x,49,width,7),COLORS[i])
		x+=width
	var remaining := 100
	for i: int in range(3):
		var percent := roundi(proportions[i]*100) if i<2 else remaining
		remaining-=percent
		draw_rect(Rect2(i*w/3,68,4,26),COLORS[i])
		draw_string(RallyFonts.regular(),Vector2(i*w/3+10,78),["柏油","砂石","泥地"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,13,MUTED)
		draw_string(RallyFonts.DISPLAY,Vector2(i*w/3+10,100),"%d%%"%percent,HORIZONTAL_ALIGNMENT_LEFT,-1,21,PAPER)
	var theme_id := definition.environment_id
	var daytime: String={"autumn":"夕照","coast":"晴日","highland":"暮色"}[theme_id]
	var weather: String={"autumn":"晴 · 林风","coast":"晴 · 海风","highland":"薄雾 · 山风"}[theme_id]
	for i: int in range(3):
		var y := 128+i*33
		draw_line(Vector2(0,y-15),Vector2(w,y-15),Color(MUTED,.25),1)
		draw_string(RallyFonts.regular(),Vector2(0,y+7),["弯道","时段","天气"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,15,MUTED)
		var value: String=["%02d"%turns,daytime,weather][i]
		draw_string(RallyFonts.regular(),Vector2(55,y+7),value,HORIZONTAL_ALIGNMENT_RIGHT,w-55,17,PAPER)
