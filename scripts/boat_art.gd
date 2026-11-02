extends RefCounted

# Presentation only. Hit shapes, arrow paths and boat transforms live in boat.gd.
static func oval(n: Node2D, p: Vector2, r: Vector2, c: Color) -> void:
	var points = PackedVector2Array()
	for i in range(64): points.append(p + Vector2(cos(i*TAU/64),sin(i*TAU/64))*r)
	n.draw_colored_polygon(points,c)

static func line(n: Node2D, a: Vector2, b: Vector2, c: Color, w: float = 1.0) -> void:
	n.draw_line(a,b,c,w,true)

static func draw_arrow(n: Node2D, tip: Vector2, a: float, length: float = 48) -> void:
	var d = Vector2.from_angle(a)
	var normal = d.orthogonal()
	var tail = tip-d*length
	line(n,tail+Vector2(1,2),tip+Vector2(1,2),Color(0.01,0.04,0.06,0.35),3)
	line(n,tail,tip,Color("b88b53"),2.7)
	line(n,tail-normal*0.65,tip-normal*0.65,Color("f3d59a"),1)
	for side in [-1,1]:
		var points = PackedVector2Array([tail+d*9,tail-d*4+normal*side*5.5,tail-d*10+normal*side*4,tail-d*4])
		n.draw_colored_polygon(points,Color("d8e6df") if side > 0 else Color("9bbebd"))
		line(n,tail-d*6+normal*side*3,tail+d*6,Color(1,1,0.89,0.55),0.8)
	n.draw_colored_polygon(PackedVector2Array([tip+d*4,tip-d*5+normal*3,tip-d*4-normal*3]),Color("d0e5e5"))

