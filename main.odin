package main

import "core:fmt"
import "core:c"
import "core:os"
import "core:runtime"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "vendor:stb/image"
import glm "core:math/linalg/glsl"

PROGRAMNAME :: "Program"
GL_MAJOR_VERSION : c.int : 4
GL_MINOR_VERSION :: 6

SCR_WIDTH :: 800
SCR_HEIGHT :: 600

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

	// set up vertex data
	shader := new_shader("shader.vs", "shader.fs")

	vertices := [?]f32 {
		 // positions      // texture coords
		 0.5,  0.5, 0.0,   1.0, 1.0,   // top right
		 0.5, -0.5, 0.0,   1.0, 0.0,   // bottom right
		-0.5, -0.5, 0.0,   0.0, 0.0,   // bottom left
		-0.5,  0.5, 0.0,   0.0, 1.0    // top left 
	}

	indices := [?]u32 {
		0, 1, 3,
		1, 2, 3
	}

	tex_coords := [?]f32 {
		0.0, 0.0,  // lower-left corner  
		1.0, 0.0,  // lower-right corner
		0.5, 1.0   // top-center corner
	}

	// [x]u32 -> [^]u32 => raw_data(array[:])



	VBO, VAO, EBO: u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	gl.GenBuffers(1, &EBO)

	gl.BindVertexArray(VAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)

	// position attribute
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)
	// color attribute
	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(3 * size_of(f32)))
	gl.EnableVertexAttribArray(1)
	// texture coord  attribute

	// load and create a texture
	// ------------------------
	texture1, texture2 : u32
	// texture 1
	// ---------
	gl.GenTextures(1, &texture1)
	gl.BindTexture(gl.TEXTURE_2D, texture1)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	width, height, nr_channels: i32
	image.set_flip_vertically_on_load(1)
	data := image.load("container.jpg", &width, &height, &nr_channels, 0)

	if data != nil {
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	} else {
		fmt.println("Failed to load texture")
	}
	image.image_free(data)
	// texture 2
	// ---------
	gl.GenTextures(1, &texture2)
	gl.BindTexture(gl.TEXTURE_2D, texture2)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	//width, height, nr_channels: i32 
	data = image.load("awesomeface.png", &width, &height, &nr_channels, 0)

	if data != nil {
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	} else {
		fmt.println("Failed to load texture")
	}
	image.image_free(data)

	use_shader(&shader)
	
	gl.Uniform1i(gl.GetUniformLocation(shader.program_id, "texture1"), 0)
	gl.Uniform1i(gl.GetUniformLocation(shader.program_id, "texture2"), 1)
	
	// render loop
	for !glfw.WindowShouldClose(window) {

		process_input(&window)

		// rendering commands
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)


		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, texture1)

		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, texture2)

		translation := glm.mat4Translate(glm.vec3{0.5, -0.5, 0.0})
		rotation := glm.mat4Rotate(glm.vec3{0.0, 0.0, 1.0}, f32(glfw.GetTime()))

		transform := translation * rotation

		use_shader(&shader)

		transform_loc: i32 = gl.GetUniformLocation(shader.program_id, "transform")
		gl.UniformMatrix4fv(transform_loc, 1, gl.FALSE, &transform[0,0])

		gl.BindVertexArray(VAO)
		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, rawptr(uintptr(0)))

		// check and call events and swap the buffers
		glfw.SwapBuffers((window))
		glfw.PollEvents()
	}

	// optional: de-allocate all resources once they've outlived their purpose:
	gl.DeleteVertexArrays(1, &VAO);
	gl.DeleteBuffers(1, &VBO);
	gl.DeleteBuffers(1, &EBO);
	//gl.DeleteProgram(shader_program);

	// glfw: terminate, clearing all previously allocated GLFW resources.
	glfw.Terminate()
}

teste :: proc(m: glm.mat4, v: glm.vec3) -> glm.mat4 {
	a: glm.mat4
	a[0, 3] = m[0, 3] + v.x
	a[1, 3] = m[0, 3] + v.y
	a[2, 3] = m[0, 3] + v.z
	//m[0, 3] += 1
	return a
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
