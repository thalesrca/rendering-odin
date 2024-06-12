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

DirectionalLight :: struct {
	using node: Node,
	color: glm.vec3,
	direction: glm.vec3,
}

new_directional_light :: proc(x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0) -> DirectionalLight {
	l: DirectionalLight
	l.name = "DirectionalLight"
	l.direction = glm.vec3{x, y, z}
	l.color = Color[.White]
	l.type = typeid_of(type_of(l))
	return l
}

PointLight :: struct {
	using node: Node,
	color: glm.vec3,
}

new_point_light :: proc(x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0) -> PointLight {
	l: PointLight
	l.name = "PointLight"
	l.position = glm.vec3{x, y, z}
	l.color = Color[.White]
	l.type = typeid_of(type_of(l))
	return l
}

SpotLight :: struct {
	using node: Node,
	direction: glm.vec3,
	color: glm.vec3,
	cutOff: f32,
}

new_spot_light :: proc(x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0) -> SpotLight {
	l: SpotLight
	l.name = "SpotLight"
	l.position = glm.vec3{x, y, z}
	l.direction = glm.vec3{x, y, z}
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
