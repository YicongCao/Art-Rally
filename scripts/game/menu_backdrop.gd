class_name RallyMenuBackdrop
extends Control

var wash := GradientTexture2D.new()
var biome: String = "autumn"
var ink_wash: bool = true
var poster_mode: bool = false
var breakout: bool = false


func _ready() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(.04,.10,.11,.94),Color(.04,.10,.11,.66),Color(.04,.10,.11,.04)])
	gradient.offsets = PackedFloat32Array([0,.42,1])
	wash.gradient = gradient
	wash.fill_to = Vector2(1,0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if poster_mode:
		_poster()
		return
	match biome:
		"coast": _coast()
		"highland": _highland()
		_: _autumn()
	if breakout:
		# Foreground silhouettes break the rectangular landscape frame.
		_pine(.025,1.10,.81,Color("254f45"))
		_pine(.985,1.10,.66,Color("356450"))
		if biome=="autumn":
			_line([[.12,1.03],[.10,.58]],Color("8c6447"),.012)
			_poly([[.035,.72],[.005,.47],[.085,.30],[.17,.37],[.22,.61],[.15,.77]],Color("dc8748"))
	if ink_wash: draw_texture_rect(wash,Rect2(Vector2.ZERO,size),false)
	# Restrained broad print marks remain in the landscape, below foreground UI.
	for row: int in range(8):
		for col: int in range(16):
			draw_circle(Vector2(size.x*(.72+col*.017),size.y*(.08+row*.019)),1.0,Color(.15,.19,.22,.09))


# Normalized vector geometry scales from stage cards to full-window backgrounds.
func _poly(points: Array,color: Color) -> void:
	var scaled := PackedVector2Array()
	for point: Array in points: scaled.append(Vector2(point[0]*size.x,point[1]*size.y))
	draw_colored_polygon(scaled,color)


func _line(points: Array,color: Color,width: float) -> void:
	var scaled := PackedVector2Array()
	for point: Array in points: scaled.append(Vector2(point[0]*size.x,point[1]*size.y))
	draw_polyline(scaled,color,maxf(1,size.y*width),true)


func _pine(x: float,base: float,height: float,color: Color) -> void:
	_poly([[x-.004,base-height*.6],[x+.004,base-height*.6],[x+.004,base],[x-.004,base]],color.darkened(.25))
	for tier: int in range(4):
		var top := base-height+tier*height*.17
		var half_width := height*(.12+tier*.035)
		_poly([[x,top],[x-half_width,top+height*.46],[x-half_width*.45,top+height*.41],[x,top+height*.49],[x+half_width,top+height*.46]],color.lightened(tier*.018))


func _autumn() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("e7b58d"))
	draw_circle(Vector2(size.x*.77,size.y*.25),size.y*.085,Color("f9dbac"))
	_poly([[0,.56],[.12,.22],[.25,.48],[.4,.16],[.57,.53],[.73,.31],[1,.55],[1,1],[0,1]],Color("9291a8"))
	_poly([[0,.64],[.18,.48],[.42,.62],[.64,.40],[.82,.53],[1,.43],[1,1],[0,1]],Color("597c79"))
	_poly([[0,.85],[.17,.69],[.44,.83],[.67,.62],[1,.72],[1,1],[0,1]],Color("d6b34f"))
	_line([[.49,1],[.54,.91],[.71,.85],[.75,.78],[.66,.73],[.73,.65]],Color("bb925b"),.040)
	_poly([[.67,.69],[.75,.69],[.75,.79],[.67,.79]],Color("ae4e36"))
	_poly([[.66,.69],[.71,.61],[.76,.69]],Color("653e39"))
	_poly([[.7,.72],[.72,.72],[.72,.79],[.7,.79]],Color("f6d0a0"))
	for tree: Array in [[.07,.94,.39],[.22,.87,.30],[.42,.78,.33],[.91,.85,.38],[.83,.70,.24],[.54,.68,.22]]:
		_pine(tree[0],tree[1],tree[2],Color("246263"))
	for tree: Array in [[.14,.76,.22],[.35,.97,.25],[.58,.80,.16],[.95,.99,.26]]:
		var x: float = tree[0]
		var base: float = tree[1]
		var h: float = tree[2]
		_line([[x,base],[x,base-h*.7]],Color("73513b"),.009)
		_poly([[x-h*.21,base-h*.38],[x-h*.25,base-h*.72],[x-h*.08,base-h],[x+h*.15,base-h*.92],[x+h*.25,base-h*.59],[x+h*.15,base-h*.32]],Color("ae4e36"))


func _coast() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("eaf0e6"))
	draw_circle(Vector2(size.x*.20,size.y*.21),size.y*.065,Color("fff5ce"))
	_poly([[0,.44],[.16,.37],[.26,.41],[.38,.37],[.50,.46],[1,.48],[1,1],[0,1]],Color("82b8bb"))
	_poly([[0,.57],[.29,.51],[.51,.54],[.71,.49],[1,.56],[1,1],[0,1]],Color("418c99"))
	_poly([[0,.84],[.27,.72],[.56,.76],[.72,.67],[1,.75],[1,1],[0,1]],Color("296c80"))
	for ripple: Array in [[[.05,.55],[.22,.55]],[[.13,.65],[.34,.65]],[[.02,.77],[.15,.77]],[[.29,.86],[.43,.86]],[[.05,.93],[.24,.93]]]:
		_line(ripple,Color("a3dce0"),.006)
	_poly([[.68,.43],[.91,.35],[1,.39],[1,1],[.65,1],[.43,.78],[.52,.62]],Color("eee2c5"))
	_poly([[.43,.78],[.52,.62],[.61,.68],[.65,1]],Color("b0bdad"))
	_poly([[.68,.43],[.91,.35],[1,.39],[1,.75],[.83,.66],[.61,.68],[.52,.62]],Color("b9c48e"))
	_line([[.44,.79],[.51,.81],[.57,.86]],Color("c2e7e4"),.012)
	_line([[.89,1],[.91,.84],[.83,.74],[.70,.65],[.70,.55],[.80,.47],[1,.45]],Color("f7f1d8"),.060)
	_line([[.89,1],[.91,.84],[.83,.74],[.70,.65],[.70,.55],[.80,.47],[1,.45]],Color("657e7d"),.034)
	# White lighthouse, glazed lantern and terracotta cap stay readable on cards.
	_poly([[.72,.29],[.755,.29],[.77,.56],[.705,.56]],Color("eee2c5"))
	_poly([[.738,.29],[.755,.29],[.77,.56],[.74,.56]],Color("d4d9cc"))
	_poly([[.71,.25],[.762,.25],[.762,.31],[.71,.31]],Color("315b65"))
	_poly([[.704,.25],[.736,.19],[.77,.25]],Color("cb7252"))
	_line([[.705,.315],[.77,.315]],Color("315b65"),.012)
	_poly([[.73,.49],[.745,.49],[.745,.56],[.73,.56]],Color("315b65"))
	for shrub: Array in [[.95,.62,.04],[.61,.62,.025],[.82,.50,.025],[.98,.89,.05]]:
		var x: float = shrub[0]
		var y: float = shrub[1]
		var h: float = shrub[2]
		_poly([[x-h,y],[x-h*.6,y-h],[x+h*.2,y-h*1.2],[x+h,y-h*.4],[x+h*.7,y]],Color("3e6c58"))


func _highland() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("d4e1e1"))
	_poly([[0,.25],[.15,.12],[.32,.38],[.47,.49],[.63,.30],[.82,.10],[1,.31],[1,1],[0,1]],Color("91a8b7"))
	_poly([[0,.45],[.19,.25],[.34,.56],[.48,.64],[.67,.47],[.82,.24],[1,.48],[1,1],[0,1]],Color("597b89"))
	_poly([[.04,.40],[.19,.25],[.25,.39],[.17,.34],[.13,.44]],Color("b9c8c9"))
	_poly([[.72,.39],[.82,.24],[.91,.40],[.83,.34],[.79,.43]],Color("a5bbbe"))
	_poly([[0,.68],[.21,.58],[.42,.74],[.57,.68],[.78,.59],[1,.70],[1,1],[0,1]],Color("859e8c"))
	for i: int in range(17):
		var x := float(i)/16
		var base := .68 + .055*sin(i*1.7)
		_pine(x,base,.12+fmod(i*.031,.09),Color("436967"))
	# Low mist opens the saddle; foreground trees and standing stones remain clear.
	_poly([[0,.61],[.3,.65],[.52,.73],[.76,.64],[1,.63],[1,.73],[.68,.75],[.36,.77],[0,.70]],Color(.80,.88,.86,.46))
	_poly([[0,.86],[.20,.78],[.48,.88],[.72,.77],[1,.81],[1,1],[0,1]],Color("b6ba85"))
	_line([[.39,1],[.46,.88],[.60,.82],[.62,.74],[.51,.70],[.49,.64]],Color("b5bdb5"),.045)
	for stone: Array in [[.67,.79,.08],[.72,.76,.11],[.77,.79,.075],[.82,.77,.10]]:
		var x: float = stone[0]
		var base: float = stone[1]
		var h: float = stone[2]
		_poly([[x-.012,base],[x-.016,base-h*.8],[x+.005,base-h],[x+.02,base-h*.88],[x+.023,base]],Color("637c84"))
		_line([[x+.005,base-h],[x+.02,base-h*.88]],Color("a7bcba"),.005)
	_pine(.07,1,.44,Color("214c47"))
	_pine(.23,.91,.32,Color("2d5650"))
	_pine(.94,.98,.41,Color("214c47"))
	_pine(.85,.90,.25,Color("2d5650"))


func _poster() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("f5e9d1"))
	_poly([[.62,0],[1,0],[1,.27],[.53,.48]],Color("e85828"))
	_poly([[.75,0],[1,0],[1,.04],[.70,.20]],Color("20252b"))
	_poly([[0,.78],[.10,.67],[.21,.73],[.34,.57],[.51,.75],[.69,.60],[.84,.69],[1,.51],[1,1],[0,1]],Color("d15b32"))
	_poly([[0,.91],[.17,.73],[.33,.86],[.50,.70],[.69,.81],[.84,.67],[1,.76],[1,1],[0,1]],Color("202b31"))
	for tree: Array in [[.04,1.03,.30],[.12,.95,.22],[.25,1.1,.34],[.78,1.05,.25],[.92,1.04,.44],[.98,.94,.22]]:
		_pine(tree[0],tree[1],tree[2],Color("18262c"))
	# Static print texture lives on page margins, never across driving scenery.
	for row: int in range(18):
		for col: int in range(36):
			var at := Vector2(size.x*(.62+col*.011),size.y*(.03+row*.013))
			draw_circle(at,.7+float(row)/18,Color(.08,.11,.13,.15))
