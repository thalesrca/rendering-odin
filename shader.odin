package main

import gl "vendor:OpenGL"
import "core:fmt"
import "core:os"
import "core:strings"

Shader :: struct {
  program_id : u32,
}

new_shader :: proc(vs_file_path: string, fs_file_path: string) -> Shader {
  vs_content, vs_ok := os.read_entire_file_from_filename(vs_file_path)

	if !vs_ok {
		fmt.println("Failed to read vertex shader file.")
		return Shader{}
	}

	//fmt.println(string(vs_content))

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
		fmt.eprintf("ERROR :: cannot compile fragment shader\n%s", info_log)
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
		fmt.eprintf("ERROR :: cannot compile fragment shaderr\n%s", info_log)
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

use_shader :: proc(shader: ^Shader) {
  gl.UseProgram(shader.program_id)
}