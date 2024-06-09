package main

import glm "core:math/linalg/glsl"


Node :: struct {
	name: string,
	position: glm.vec3,
	type: typeid,
}

Colors :: enum {
	White,
}

Color :: [Colors]glm.vec3 {
		.White = {1.0, 1.0, 1.0},
}

Light :: struct {
	using node: Node,
	color: glm.vec3,
}

new_light :: proc(x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0) -> Light {
	l: Light
	l.name = "Light"
	l.position = glm.vec3{x, y, z}
	l.color = Color[.White]
	l.type = typeid_of(type_of(l))
	return l
}

Camera :: struct {
	using node: Node,
	fov: f32,
}

new_camera :: proc(x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0) -> Camera {
	c: Camera
	c.name = "Camera"
	c.position = glm.vec3{x, y, z}
	c.fov = 45.0
	c.type = typeid_of(type_of(c))
	return c
}