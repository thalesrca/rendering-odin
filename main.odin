package main

import "core:fmt"
import "core:c"
import "core:os"
import "core:math"
import "core:runtime"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "vendor:stb/image"
import glm "core:math/linalg/glsl"

PROGRAMNAME :: "Program"
GL_MAJOR_VERSION : c.int : 4
GL_MINOR_VERSION :: 6

// settings
SCR_WIDTH :: 800
SCR_HEIGHT :: 600

// camera
cam_pos   := glm.vec3{0.0, 0.0, 3.0}
cam_front := glm.vec3{0.0, 0.0, -1.0}
cam_up    := glm.vec3{0.0, 1.0, 0.0}
cam_right := glm.vec3{1.0, 0.0, 0.0}


first_mouse := true
yaw         :f32 = -90.0	// yaw is initialized to -90.0 degrees since a yaw of 0.0 results in a direction vector pointing to the right so we initially rotate a bit to the left.
pitch       :f32 =  0.0
lastX       :f32 =  800.0 / 2.0
lastY       :f32 =  600.0 / 2.0
fov         :f32 =  45.0


// time
delta_time := 0.0
last_frame := 0.0

// lighting
lightPos :glm.vec3 = {1.2, 1.0, 2.0}
lightColor :glm.vec3 = {0.0, 1.0, 1.0}


main :: proc() {
	a := "lsdkjfskdj"

	
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
	glfw.SetCursorPosCallback(window, mouse_callback)
	glfw.SetScrollCallback(window, scroll_callback)
	gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

	// tell GLFW to capture our mouse
    glfw.SetInputMode(window, glfw.CURSOR, 	glfw.CURSOR_DISABLED)

	// configure global opengl state
    // -----------------------------
    gl.Enable(gl.DEPTH_TEST);

	// set up vertex data
	shader := new_shader("shader.vs", "shader.fs")
	light_cube_shader := new_shader("light_cube.vs", "light_cube.fs")

	vertices := [?]f32 {
    -0.5, -0.5, -0.5,  0.0, 0.0,
     0.5, -0.5, -0.5,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
    -0.5,  0.5, -0.5,  0.0, 1.0,
    -0.5, -0.5, -0.5,  0.0, 0.0,

    -0.5, -0.5,  0.5,  0.0, 0.0,
     0.5, -0.5,  0.5,  1.0, 0.0,
     0.5,  0.5,  0.5,  1.0, 1.0,
     0.5,  0.5,  0.5,  1.0, 1.0,
    -0.5,  0.5,  0.5,  0.0, 1.0,
    -0.5, -0.5,  0.5,  0.0, 0.0,

    -0.5,  0.5,  0.5,  1.0, 0.0,
    -0.5,  0.5, -0.5,  1.0, 1.0,
    -0.5, -0.5, -0.5,  0.0, 1.0,
    -0.5, -0.5, -0.5,  0.0, 1.0,
    -0.5, -0.5,  0.5,  0.0, 0.0,
    -0.5,  0.5,  0.5,  1.0, 0.0,

     0.5,  0.5,  0.5,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
     0.5, -0.5, -0.5,  0.0, 1.0,
     0.5, -0.5, -0.5,  0.0, 1.0,
     0.5, -0.5,  0.5,  0.0, 0.0,
     0.5,  0.5,  0.5,  1.0, 0.0,

    -0.5, -0.5, -0.5,  0.0, 1.0,
     0.5, -0.5, -0.5,  1.0, 1.0,
     0.5, -0.5,  0.5,  1.0, 0.0,
     0.5, -0.5,  0.5,  1.0, 0.0,
    -0.5, -0.5,  0.5,  0.0, 0.0,
    -0.5, -0.5, -0.5,  0.0, 1.0,

    -0.5,  0.5, -0.5,  0.0, 1.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
     0.5,  0.5,  0.5,  1.0, 0.0,
     0.5,  0.5,  0.5,  1.0, 0.0,
    -0.5,  0.5,  0.5,  0.0, 0.0,
    -0.5,  0.5, -0.5,  0.0, 1.0
	}

	vertices2 := [?]f32 {
		// vertices, normal, text pos
	-0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  0.0,
     0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  0.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  1.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  1.0,
    -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  1.0,
    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  0.0,

    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  0.0,
     0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  0.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  1.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  1.0,
    -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  1.0,
    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  0.0,

	-0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  0.0,
    -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0,  1.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  1.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  1.0,
    -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0,  0.0,
    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  0.0,

     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0,  0.0,
     0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0,  1.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0,  1.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0,  1.0,
     0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0,  0.0,
     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0,  0.0,

	-0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0,  1.0,
     0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0,  1.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0,  0.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0,  0.0,
    -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0,  0.0,
    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0,  1.0,

    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0,  1.0,
     0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0,  1.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0,  0.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0,  0.0,
    -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0,  0.0,
    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0,  1.0
	}

	// world space positions of our cubes
    cubePositions: [10]glm.vec3 = {
        glm.vec3{ 0.0,  0.0,  0.0},
		glm.vec3{ 2.0,  5.0, -15.0},
		glm.vec3{-1.5, -2.2, -2.5},
		glm.vec3{-3.8, -2.0, -12.3},
		glm.vec3{ 2.4, -0.4, -3.5},
		glm.vec3{-1.7,  3.0, -7.5},
		glm.vec3{ 1.3, -2.0, -2.5},
		glm.vec3{ 1.5,  2.0, -2.5},
		glm.vec3{ 1.5,  0.2, -1.5},
		glm.vec3{-1.3,  1.0, -1.5}
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



	VBO, VBO2, VAO, EBO: u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	gl.GenBuffers(1, &VBO2)
	gl.GenBuffers(1, &EBO)

	gl.BindVertexArray(VAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices2), &vertices2, gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)

	// position attribute
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)
	// normal attribute
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), uintptr(3 * size_of(f32)))
	gl.EnableVertexAttribArray(1)
	// color attribute
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), uintptr(6 * size_of(f32)))
	gl.EnableVertexAttribArray(2)
	// texture coord  attribute

	// load and create a texture
	// ------------------------
	texture1 := create_texture("container.jpg", true)
	texture2 := create_texture("awesomeface.png", false, gl.RGBA)

	use_shader(shader)

	set_tex(shader, "texture1", 0)
	set_tex(shader, "texture2", 1)

	// -- LAMP --
	lightCubeVAO: u32
	gl.GenVertexArrays(1, &lightCubeVAO)
	gl.BindVertexArray(lightCubeVAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO2)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices2), &vertices2, gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	// ----


	camera_pos := glm.vec3{0.0, 0.0, 0.0}
	camera_target := glm.vec3{0.0, 0.0, 0.0}

	camera_direction := glm.normalize(camera_target - camera_pos) // get direction

	up := glm.vec3{0.0, 1.0, 0.0}
	
	
	// render loop
	// ------
	for !glfw.WindowShouldClose(window) {

		current_frame := glfw.GetTime()
		delta_time = current_frame - last_frame
		last_frame = current_frame

		// input
		// -----
		process_input(window)


		rendering(shader, light_cube_shader, texture1, texture2, VAO, lightCubeVAO, cubePositions)

		// render
		/* gl.ClearColor(0.1, 0.1, 0.1, 1.0) */
		/* gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT) */

		/* // bind textures on corresponding texture units */
		/* gl.ActiveTexture(gl.TEXTURE0) */
		/* gl.BindTexture(gl.TEXTURE_2D, texture1) */
		/* gl.ActiveTexture(gl.TEXTURE1) */
		/* gl.BindTexture(gl.TEXTURE_2D, texture2) */

		/* // activate shader */
		/* use_shader(shader) */

		/* // create the transformations */
		/* // we need the model, view (camera) and projection matrices */
		/* //view := glm.mat4Translate(cam_pos) // to simulate camera a little bit to the back, we push the view to the back -3 on the z axis */
		/* view := glm.mat4LookAt(cam_pos, cam_pos + cam_front, cam_up) */
		/* //fmt.println(cam_front) */
		/* // fov -> its like the zoom */
		/* //  */
		/* // near -> clipping near distance, anything before that will be clipped and anything after will be shown */
		/* // far -> clipping far distance, same as the above but the other way around */
		/* projection := glm.mat4Perspective(glm.radians_f32(fov), SCR_WIDTH/SCR_HEIGHT, 0.1, 100.0) // we use the perspective projection (instead of orthogonal) */

		/* set_mat4(shader, "view", &view) */
		/* set_mat4(shader, "projection", &projection) */
		
		/* // render container */
		/* gl.BindVertexArray(VAO) */
        /* for i:= 0; i < 10; i+=1 */
        /* { */
        /*     // calculate the model matrix for each object and pass it to shader before drawing */
        /*     position : glm.mat4 = glm.mat4Translate(cubePositions[i]); */
        /*     angle : f32 = 20.0 * f32(i); */
        /*     rotation : glm.mat4 */

		/* 	if i == 0 || i == 2 || i == 5 || i == 8 { */
		/* 		rotation = glm.mat4Rotate(glm.vec3{1.0, 0.3, 0.5}, glm.radians_f32(angle) * f32(glfw.GetTime())); */
		/* 	} else { */
		/* 		rotation = glm.mat4Rotate(glm.vec3{1.0, 0.3, 0.5}, glm.radians_f32(angle)); */
		/* 	} */

		/* 	model : glm.mat4 = position * rotation */
		/* 	set_mat4(shader, "model", &model) */

        /*     gl.DrawArrays(gl.TRIANGLES, 0, 36) */
        /* } */


		/* // lamp */
		/* use_shader(light_cube_shader) */
		/* set_mat4(light_cube_shader, "projection", &projection) */
		/* set_mat4(light_cube_shader, "view", &view) */

		/* lightCubeT := glm.mat4Translate(lightPos) */
		/* lightCubeS := glm.mat4Scale(glm.vec3(0.2)) */
		/* lightCubeModel : glm.mat4 = lightCubeT * lightCubeS */
		/* set_mat4(light_cube_shader, "model", &lightCubeModel) */

		/* gl.BindVertexArray(lightCubeVAO) */
		/* gl.DrawArrays(gl.TRIANGLES, 0, 36) */

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

process_input :: proc(window: glfw.WindowHandle) {
	if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}

	// normal polygon
	if glfw.GetKey(window, glfw.KEY_F1) == glfw.PRESS {
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	}
	// wireframe polygon
	if glfw.GetKey(window, glfw.KEY_F2) == glfw.PRESS {
		gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	}

	// keyboard inputs

	camera_speed :f32 = 2.5 * f32(delta_time)

	if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
		cam_pos += camera_speed * cam_front
	}

	if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
		cam_pos -= camera_speed * cam_front
	}

	if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
		// when move the camera we want to move sideways relative to the front position
		// and not absolute
		cam_pos += glm.normalize_vec3(glm.cross_vec3(cam_up, cam_front)) * camera_speed
	}

	if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
		// when move the camera we want to move sideways relative to the front position
		// and not absolute
		cam_pos -= glm.normalize_vec3(glm.cross_vec3(cam_up, cam_front)) * camera_speed
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

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	context = runtime.default_context()
	/* fmt.println("mouse", xpos, ypos) */

	if first_mouse {
		lastX = f32(xpos)
		lastY = f32(ypos)
		first_mouse = false
	}
	xoffset := f32(xpos) - lastX
    yoffset := lastY - f32(ypos) // reversed since y-coordinates go from bottom to top
    lastX = f32(xpos)
    lastY = f32(ypos)

    sensitivity :f32 = 0.1 // change this value to your liking
    xoffset *= sensitivity
    yoffset *= sensitivity

    yaw += xoffset
    pitch += yoffset

    // make sure that when pitch is out of bounds, screen doesn't get flipped
    if pitch > 89.0{
        pitch = 89.0
	}
    if pitch < -89.0 {
		pitch = -89.0
	}

    front: glm.vec3
	front[0] = math.cos(glm.radians_f32(yaw)) * math.cos(glm.radians_f32(pitch))
	front[1] = math.sin(glm.radians_f32(pitch))
	front[2] = math.sin(glm.radians_f32(yaw)) * math.cos(glm.radians_f32(pitch))
	cam_front = glm.normalize_vec3(front)
	/* fmt.println(cam_front) */
}


// controls mouse wheel clamping the fov
scroll_callback :: proc "c" (window: glfw.WindowHandle, xoffset, yoffset: f64) {
	fov -= f32(yoffset)

	if fov < 1.0 {
		fov = 1.0
	}
	if (fov > 45.0){
		fov = 45.0
	}
}


rendering :: proc(shader, light_cube_shader: Shader, texture1, texture2, VAO, lightCubeVAO: u32, cubePositions: [10]glm.vec3) {
	// render
	gl.ClearColor(0.1, 0.1, 0.1, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	// bind textures on corresponding texture units
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, texture1)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, texture2)

	// activate shader
	use_shader(shader)

	// create the transformations
	// we need the model, view (camera) and projection matrices
	//view := glm.mat4Translate(cam_pos) // to simulate camera a little bit to the back, we push the view to the back -3 on the z axis
	view := glm.mat4LookAt(cam_pos, cam_pos + cam_front, cam_up)
	//fmt.println(cam_front)
	// fov -> its like the zoom
	// 
	// near -> clipping near distance, anything before that will be clipped and anything after will be shown
	// far -> clipping far distance, same as the above but the other way around
	projection := glm.mat4Perspective(glm.radians_f32(fov), SCR_WIDTH/SCR_HEIGHT, 0.1, 100.0) // we use the perspective projection (instead of orthogonal)

	set_mat4(shader, "view", &view)
	set_mat4(shader, "projection", &projection)
	set_vec3(shader, "objectColor", &glm.vec3{1.0, 1.0, 1.0})
	set_vec3(shader, "lightColor", &lightColor)
	set_vec3(shader, "viewPos", &cam_pos)
	set_vec3(shader, "lightPos", &lightPos)
	
	// render container
	gl.BindVertexArray(VAO)
    for i:= 0; i < 10; i+=1
    {
        // calculate the model matrix for each object and pass it to shader before drawing
        position : glm.mat4 = glm.mat4Translate(cubePositions[i]);
        angle : f32 = 20.0 * f32(i);
        rotation : glm.mat4

		if i == 0 || i == 2 || i == 5 || i == 8 {
			rotation = glm.mat4Rotate(glm.vec3{1.0, 0.3, 0.5}, glm.radians_f32(angle) * f32(glfw.GetTime()));
		} else {
			rotation = glm.mat4Rotate(glm.vec3{1.0, 0.3, 0.5}, glm.radians_f32(angle));
		}

		model : glm.mat4 = position * rotation
		set_mat4(shader, "model", &model)

        gl.DrawArrays(gl.TRIANGLES, 0, 36)
    }


	// lamp
	use_shader(light_cube_shader)
	set_mat4(light_cube_shader, "projection", &projection)
	set_mat4(light_cube_shader, "view", &view)

	lightCubeT := glm.mat4Translate(lightPos)
	lightCubeS := glm.mat4Scale(glm.vec3(0.2))
	lightCubeModel : glm.mat4 = lightCubeT * lightCubeS
	set_mat4(light_cube_shader, "model", &lightCubeModel)
	set_vec3(light_cube_shader, "lightColor", &lightColor)

	gl.BindVertexArray(lightCubeVAO)
	gl.DrawArrays(gl.TRIANGLES, 0, 36)
}
