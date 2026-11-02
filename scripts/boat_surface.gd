extends Node2D

var mesh: ArrayMesh

const BOAT = preload("res://assets/boat-plush-v1.png")

func _draw() -> void:
	# Preserve the six gameplay sections while giving the toy short rounded ends.
	var region = BOAT.get_image().get_used_rect()
	var size = Vector2(BOAT.get_size())
	var us = [0.0,0.22,0.78,1.0]
	var xs = [-164.0,-130.0,130.0,164.0]
	var vertices = PackedVector3Array()
	var uv = PackedVector2Array()
	for strip in range(3):
		for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
			var idx = strip+int(corner.x)
			vertices.append(Vector3(xs[idx]+215,44+corner.y*132,0))
			uv.append((Vector2(region.position)+Vector2(us[idx],corner.y)*Vector2(region.size))/size)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	for i in range(8,0,-1):
		preload("res://scripts/boat_art.gd").oval(self,Vector2(217,119),Vector2(164+i,62+i*0.5),Color(0.02,0.06,0.10,0.017))
	draw_mesh(mesh,BOAT)
