package main

import "core:fmt"
import "core:c"
import "core:runtime"
import gl "vendor:OpenGL"
import "vendor:glfw"

PROGRAMNAME :: "Program"
GL_MAJOR_VERSION : c.int : 4
GL_MINOR_VERSION :: 6


SCR_WIDTH :: 800
SCR_HEIGHT :: 600

vertex_shader_source : cstring = "#version 460 core\n" +
"layout (location = 0) in vec3 aPos;\n" +
"void main()\n" +
"{\n" +
"gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n" +
"}"

fragment_shader_source : cstring = "#version 460 core\n" +
"out vec4 FragColor;\n" +
"void main()\n" +
"{\n" +
"FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n" +
"}"

main :: proc() {

	if glfw.Init() == 0 {
		fmt.println("Error trying to initialized GLFW.")
		return
	}

	glfw.SetErrorCallback(error_callback)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR,GL_MAJOR_VERSION) 
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR,GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE,glfw.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(SCR_WIDTH, SCR_HEIGHT, PROGRAMNAME, nil, nil)
	defer glfw.DestroyWindow(window)

	// If the window pointer is invalid
	if window == nil {
		fmt.println("Unable to create window")
		return
	}
	
	glfw.MakeContextCurrent(window)
	glfw.SetFramebufferSizeCallback(window, size_callback)
	gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address) 

	// VERTEX SHADER
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vertex_shader_source, nil)
	gl.CompileShader(vertex_shader)

	// check for shader compile error
	success: i32
	info_log: [512]u8

	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(vertex_shader, 512, nil, &info_log[0])
		fmt.eprintf("ERROR :: cannot compile fragment shader\n%s", info_log)
		return
	}

	// FRAGMENT SHADER
	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, &fragment_shader_source, nil)
	gl.CompileShader(fragment_shader)

	// check for shader compile error
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(fragment_shader, 512, nil, &info_log[0])
		fmt.eprintf("ERROR :: cannot compile fragment shaderr\n%s", info_log)
		return
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
		return
	}

	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

	// set up vertex data

	vertices := [?]f32 {
		 0.5,  0.5, 0.0, //top right
		 0.5, -0.5, 0.0, // bottom right 
		-0.5, -0.5, 0.0,  // bottom left   
		-0.5,  0.5, 0.0, // top left  
	}
/* 
	vertices := [?]f32 {
	 -0.5, -0.5, 0.0,  // bottom left   
	  0.5, -0.5, 0.0, // bottom right 
	  0.0,  0.5, 0.0, // top left  
 } */


	indices := [?]u32 {
		0, 1, 3, // first triangle
		1, 2, 3  // second triangle
		/* 0, 3, 2,
		2, 1, 0, */
	}

	VBO, VAO, EBO: u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	gl.GenBuffers(1, &EBO) // elemento buffer objects
	// bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
	gl.BindVertexArray(VAO)

	// 0. copy our vertices array in a buffer for OpenGL to use
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices[:]), gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), raw_data(indices[:]), gl.STATIC_DRAW)

	// 1. then set the vertex attributes pointers
	// tell opengl hwo to interpret our vertices, each 3 float (with their size) is a vertice, total size
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	// note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
	//gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	//gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)

	gl.BindVertexArray(0)
	
	// render loop
	for !glfw.WindowShouldClose(window) {

		process_input(&window)

		// rendering commands
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		// draw our first triangle
		gl.UseProgram(shader_program) // Every shader and rendering call after glUseProgram will now use this program object (and thus the shaders).
		gl.BindVertexArray(VAO)
		//gl.DrawArrays(gl.TRIANGLES, 0, 3)
		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, rawptr(uintptr(0)))
		//gl.BindVertexArray(0)

		// check and call events and swap the buffers
		glfw.SwapBuffers((window))
		glfw.PollEvents()
	}

	// optional: de-allocate all resources once they've outlived their purpose:
	gl.DeleteVertexArrays(1, &VAO);
	gl.DeleteBuffers(1, &VBO);
	gl.DeleteBuffers(1, &EBO)
	gl.DeleteProgram(shader_program);

	// glfw: terminate, clearing all previously allocated GLFW resources.
	glfw.Terminate()

}

process_input :: proc(window: ^glfw.WindowHandle) {
	if glfw.GetKey(window^, glfw.KEY_ESCAPE) == glfw.PRESS {
		glfw.SetWindowShouldClose(window^, true)
	}

	
	// normal polygon
	if glfw.GetKey(window^, glfw.KEY_F1) == glfw.PRESS {
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	}
	// wireframe polygon
	if glfw.GetKey(window^, glfw.KEY_F2) == glfw.PRESS {
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	}
}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}

error_callback :: proc "c" (error: i32, description : cstring)
{
	context = runtime.default_context()
	fmt.eprintf("Error: %s\n", description)
}