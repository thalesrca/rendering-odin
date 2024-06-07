package main

import gl "vendor:OpenGL"
import "core:fmt"
import "core:os"
import "core:strings"
import "vendor:stb/image"
import glm "core:math/linalg/glsl"

Shader :: struct {
  program_id : u32,
}

new_shader :: proc(vs_file_path: string, fs_file_path: string) -> Shader {
  vs_content, vs_ok := os.read_entire_file_from_filename(vs_file_path)

	if !vs_ok {
		fmt.println("Failed to read vertex shader file.")
		return Shader{}
	}

	fs_content, fs_ok := os.read_entire_file_from_filename(fs_file_path)

	if !fs_ok {
		fmt.println("Failed to read fragment shader file.")
		return Shader{}
	}

	//fmt.println(string(fs_content))

  vertex_source : cstring = strings.unsafe_string_to_cstring(string(vs_content))
  fragment_source : cstring = strings.unsafe_string_to_cstring(string(fs_content))

  // VERTEX SHADER
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vertex_source, nil)
	gl.CompileShader(vertex_shader)

	// check for shader compile error
	success: i32
	info_log: [512]u8

	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(vertex_shader, 512, nil, &info_log[0])
		fmt.eprintf("ERROR :: cannot compile vertex shader\n%s", info_log)
		return Shader{}
	}

	// FRAGMENT SHADER
	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, &fragment_source, nil)
	gl.CompileShader(fragment_shader)

	// check for shader compile error
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(fragment_shader, 512, nil, &info_log[0])
		fmt.eprintf("ERROR :: cannot compile fragment shader\n%s", info_log)
		return Shader{}
	}


	// link shaders
	shader_program := gl.CreateProgram()
	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, fragment_shader)
	gl.LinkProgram(shader_program)

	// scheck for linking errors
	gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success)

	if success == 0 {
		gl.GetProgramInfoLog(shader_program, 512, nil, &info_log[0])
		fmt.eprintf("ERROR :: cannot compile shader program.\n%s", info_log)
		return Shader{}
	}

	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)


  return Shader{shader_program}
}

set_mat4 :: proc(shader: Shader, location_name: cstring, value: ^glm.mat4) {
    // get the location to apply the "coordination matrix"
    // the location name needs to be the same uniform name as defined in the vertex shader
	location : i32 = gl.GetUniformLocation(shader.program_id, location_name)

	// associate the matrix using the location as a reference
	gl.UniformMatrix4fv(location, 1, gl.FALSE, &value[0,0])
}

set_vec3 :: proc(shader: Shader, location_name: cstring, value: ^glm.vec3) {
    // get the location to apply the "coordination matrix"
    // the location name needs to be the same uniform name as defined in the vertex shader
	location : i32 = gl.GetUniformLocation(shader.program_id, location_name)

	// associate the matrix using the location as a reference
	gl.Uniform3fv(location, 1, &value[0])
	//gl.UniformMatrix4fv(location, 1, gl.FALSE, &value[0,0])
}


set_tex :: proc(shader: Shader, location_name: cstring, pos: i32) {
	gl.Uniform1i(gl.GetUniformLocation(shader.program_id, location_name), pos)
}

set_float :: proc(shader: Shader, location_name: cstring, value: f32) {
	gl.Uniform1f(gl.GetUniformLocation(shader.program_id, location_name), value)
//	gl.Uniform1i(gl.GetUniformLocation(shader.program_id, location_name), pos)
}



use_shader :: proc(shader: Shader) {
  gl.UseProgram(shader.program_id)
}


create_texture :: proc(image_name: cstring, flipped: bool = false, format: i32 = gl.RGB) -> (texture: u32) {
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	width, height, nr_channels: i32
	image.set_flip_vertically_on_load(1 if flipped else 0)
	data := image.load(image_name, &width, &height, &nr_channels, 0)
	defer image.image_free(data)

	if data != nil {
		gl.TexImage2D(gl.TEXTURE_2D, 0, format, width, height, 0, u32(format), gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	} else {
		fmt.println("Failed to load texture")
	}

	return


}
