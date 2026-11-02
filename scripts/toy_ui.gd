extends RefCounted

const CREAM = Color("fffbef")
const EDGE = Color("a7a5bd")
const TEXT = Color("5d607f")
const MUTED = Color("8a8ca5")

static func slab(n: Node2D, rect: Rect2, color: Color = CREAM, radius: int = 22, depth: float = 4) -> void:
	var shadow = StyleBoxFlat.new()
	shadow.bg_color = Color(0.27,0.36,0.45,0.10)
	shadow.set_corner_radius_all(radius+2)
	n.draw_style_box(shadow,Rect2(rect.position+Vector2(0,depth+4),rect.size+Vector2(0,1)))
	var lower = StyleBoxFlat.new()
	lower.bg_color = color.darkened(0.14)
	lower.set_corner_radius_all(radius)
	lower.set_border_width_all(2)
	lower.border_color = EDGE
	n.draw_style_box(lower,Rect2(rect.position+Vector2(0,depth),rect.size))
	var face = StyleBoxFlat.new()
	face.bg_color = color
	face.set_corner_radius_all(radius)
	face.set_border_width_all(2)
	face.border_color = Color("ffffff")
	n.draw_style_box(face,rect)
	var lip = StyleBoxFlat.new()
	lip.bg_color = Color(1,1,1,0.28)
	lip.set_corner_radius_all(maxi(4,radius-5))
	n.draw_style_box(lip,Rect2(rect.position+Vector2(5,4),Vector2(rect.size.x-10,rect.size.y*0.32)))

static func bead(n: Node2D, p: Vector2, filled: bool) -> void:
	n.draw_circle(p+Vector2(0,2),7.3,Color("c4c8d3"),true,-1,true)
	n.draw_circle(p,7,Color("89c8b4") if filled else Color("e3e5ec"),true,-1,true)
	n.draw_circle(p-Vector2(1.7,2),3.2,Color("d7f1ce") if filled else Color("f7f7fc"),true,-1,true)

static func progress(n: Node2D, rect: Rect2, value: float) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("e8e3ef")
	style.set_corner_radius_all(6)
	n.draw_style_box(style,rect)
	if value < 0.01: return
	style = StyleBoxFlat.new()
	style.bg_color = Color("f1be77")
	style.set_corner_radius_all(6)
	var fill = Rect2(rect.position,Vector2(maxf(rect.size.y,rect.size.x*value),rect.size.y))
	n.draw_style_box(style,fill)
	n.draw_line(fill.position+Vector2(4,2),fill.position+Vector2(fill.size.x-4,2),Color("ffdf9b"),2,true)

static func star(n: Node2D, center: Vector2, size: float, filled: bool) -> void:
	var points = PackedVector2Array()
	for i in range(10):
		var a = -PI/2+i*PI/5
		points.append(center+Vector2.from_angle(a)*size*(1.0 if i%2 == 0 else 0.52))
	var shadow = points.duplicate()
	for i in range(shadow.size()): shadow[i] += Vector2(0,3)
	n.draw_colored_polygon(shadow,Color("d1b18b") if filled else Color("d4cede"))
	n.draw_colored_polygon(points,Color("f5ca7a") if filled else Color("ebe7f0"))
	n.draw_circle(center-Vector2(2,4),size*0.20,Color("ffe7b0") if filled else Color("f8f6fb"),true,-1,true)
