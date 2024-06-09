package main

import "core:fmt"
import "core:c"
import "core:os"
import "core:math"
import "core:runtime"
import gl "vendor:OpenGL"
import "vendor:glfw"
import stbi "vendor:stb/image"
import glm "core:math/linalg/glsl"
import imgui "imgui"
import "imgui_impl_glfw"
import "imgui_impl_opengl3"
import "core:strings"
import "core:reflect"

PROGRAMNAME :: "Engine?"
GL_MAJOR_VERSION : c.int : 4
GL_MINOR_VERSION :: 6

// settings
SCR_WIDTH :: 1270
SCR_HEIGHT :: 720

camera := new_camera(0.0, 0.0, 8.0)

// camera
//cam_pos   := glm.vec3{0.0, 0.0, 8.0}
cam_front := glm.vec3{0.0, 0.0, -1.0}
cam_up    := glm.vec3{0.0, 1.0, 0.0}
cam_right := glm.vec3{1.0, 0.0, 0.0}


first_mouse := true
yaw         :f32 = -90.0	// yaw is initialized to -90.0 degrees since a yaw of 0.0 results in a direction vector pointing to the right so we initially rotate a bit to the left.
pitch       :f32 =  0.0
lastX       :f32 =  f32(SCR_WIDTH) / 2.0
lastY       :f32 =  f32(SCR_HEIGHT)/ 2.0
//fov         :f32 =  45.0


// time
delta_time := 0.0
last_frame := 0.0

// lighting
//lightPos :[3]f32 = {1.2, 1.0, 2.0}
//lightColor :glm.vec3 = {0.0, 1.0, 1.0}

light := new_light(1.2, 1.0, 2.0)
/* light_ambient  :glm.vec3= {0.2, 0.2, 0.2} */
/* light_diffuse  :glm.vec3= {0.5, 0.5, 0.5} */
light_specular :glm.vec3= {1.0, 1.0, 1.0}
/* specularStrength : glm.vec3 = {0.5, 0.5, 0.5} */
specularStrength : f32 = 0.5
albedo_color : [3]f32 = {1.0, 0.5, 0.31}


nodes : []^Node = {&light, &camera}

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
	// glfw.SetCursorPosCallback(window, mouse_callback)
	glfw.SetScrollCallback(window, scroll_callback)
	gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

	// tell GLFW to capture our mouse
    // glfw.SetInputMode(window, glfw.CURSOR, 	glfw.CURSOR_DISABLED)

	// configure global opengl state
    // -----------------------------
    gl.Enable(gl.DEPTH_TEST)


	// initialize dearImgui
	imgui.CHECKVERSION()
	imgui.CreateContext()
	defer imgui.DestroyContext()
	io := imgui.GetIO()
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}
	when imgui.IMGUI_BRANCH == "docking" {
		io.ConfigFlags += {.DockingEnable}
		io.ConfigFlags += {.ViewportsEnable}

		style := imgui.GetStyle()
		style.WindowRounding = 0
		style.Colors[imgui.Col.WindowBg].w = 1
	}

	imgui.StyleColorsDark()

	imgui_impl_glfw.InitForOpenGL(window, true)
	defer imgui_impl_glfw.Shutdown()
	imgui_impl_opengl3.Init("#version 150")
	defer imgui_impl_opengl3.Shutdown()

	

	// set up vertex data
	shader := new_shader("shaders/shader.vs", "shaders/shader.fs")
	light_cube_shader := new_shader("shaders/light_cube.vs", "shaders/light_cube.fs")

	vertices2 := [?]f32 {
		// vertices       , normal,          text pos
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


	VBO, VBO2, VAO: u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	gl.GenBuffers(1, &VBO2)
	
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices2), &vertices2, gl.STATIC_DRAW)

	gl.BindVertexArray(VAO)
	// position attribute
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)
	// normal attribute
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), uintptr(3 * size_of(f32)))
	gl.EnableVertexAttribArray(1)
	// texture coord  attribute
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), uintptr(6 * size_of(f32)))
	gl.EnableVertexAttribArray(2)

	// -- LAMP --
	lightCubeVAO: u32
	gl.GenVertexArrays(1, &lightCubeVAO)
	gl.BindVertexArray(lightCubeVAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO2)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices2), &vertices2, gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)


	// load texture
	texture1 : u32 = load_texture("assets/container2.png")

	use_shader(shader)
	set_tex(shader, "material.diffuse", 0)
	

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

		// draw interface
		interface(window)

		// input
		// -----
		process_input(window)

		// render
		rendering(shader, light_cube_shader, texture1, VAO, lightCubeVAO, cubePositions)

		// check and call events and swap the buffers
		glfw.SwapBuffers((window))
		glfw.PollEvents()
	}

	// optional: de-allocate all resources once they've outlived their purpose:
	gl.DeleteVertexArrays(1, &VAO);
	gl.DeleteBuffers(1, &VBO);
	gl.DeleteBuffers(1, &VBO2);
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
		camera.position += camera_speed * cam_front
	}

	if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
		camera.position -= camera_speed * cam_front
	}

	if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
		// when move the camera we want to move sideways relative to the front position
		// and not absolute
		camera.position += glm.normalize_vec3(glm.cross_vec3(cam_up, cam_front)) * camera_speed
	}

	if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
		// when move the camera we want to move sideways relative to the front position
		// and not absolute
		camera.position -= glm.normalize_vec3(glm.cross_vec3(cam_up, cam_front)) * camera_speed
	}
}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}

error_callback :: proc "c" (error: i32, description : cstring)
{
	context = runtime.default_context()
	//fmt.eprintf("Error: %s\n", description)
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
	camera.fov -= f32(yoffset)

	if camera.fov < 1.0 {
		camera.fov = 1.0
	}
	if (camera.fov > 45.0){
		camera.fov = 45.0
	}
}


rendering :: proc(shader, light_cube_shader: Shader, texture1, VAO, lightCubeVAO: u32, cubePositions: [10]glm.vec3) {
	// render
	gl.ClearColor(0.1, 0.1, 0.1, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	use_shader(shader)
	p := glm.vec3(light.position)
	set_vec3(shader, "light.position", &p)
	set_vec3(shader, "viewPos", &camera.position)

	// light properties
	diffuse_light := light.color * glm.vec3(0.5)
	ambient_light := diffuse_light * glm.vec3(0.2)
	set_vec3(shader, "light.ambient", &ambient_light)
	set_vec3(shader, "light.diffuse", &diffuse_light)
	set_vec3(shader, "light.specular", &light_specular)

	// material properties
	s := glm.vec3(specularStrength)
	set_vec3(shader, "material.specular", &s)
	set_float(shader, "material.shininess", 32.0)

	// view/projection transformationse
	view := glm.mat4LookAt(camera.position, camera.position + cam_front, cam_up)
	projection := glm.mat4Perspective(glm.radians_f32(camera.fov), SCR_WIDTH/SCR_HEIGHT, 0.1, 100.0) // we use the perspective projection (instead of orthogonal)
	set_mat4(shader, "view", &view)
	set_mat4(shader, "projection", &projection)
	

	// bind textures on corresponding texture units
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, texture1)

	
	// obj_color := glm.vec3(albedo_color)
	// set_vec3(shader, "material.ambient", &obj_color)
	// set_float(shader, "material.diffuse", 0.0)

	
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

	lightCubeT := glm.mat4Translate(glm.vec3(light.position))
	lightCubeS := glm.mat4Scale(glm.vec3(0.2))
	lightCubeModel : glm.mat4 = lightCubeT * lightCubeS
	set_mat4(light_cube_shader, "model", &lightCubeModel)
	set_vec3(light_cube_shader, "lightColor", &light.color)

	gl.BindVertexArray(lightCubeVAO)
	gl.DrawArrays(gl.TRIANGLES, 0, 36)
}


to_array :: proc(v: glm.vec3) -> [3]f32 {
	return {v[0], v[1], v[2]}
}


load_texture :: proc(path: cstring) -> u32 {
	// the reference for this texture
	texture_id : u32

	// we create a new texture "space"
	gl.GenTextures(1, &texture_id)

	width, height, nrComponents: i32

	data := stbi.load(path, &width, &height, &nrComponents, 0)
    if data != nil
    {

		// if the image just have 1 channel we treat it as just RED
		// if it has 3 channels we treat it as RGB, and for four RGBA
        format: i32
        if nrComponents == 1 {
            format = gl.RED			
		}
        else if (nrComponents == 3) {
            format = gl.RGB
		}
        else if (nrComponents == 4) {
            format = gl.RGBA
		}


		// we say open gl that we want to start configuring "texture_id" we created earlier
        gl.BindTexture(gl.TEXTURE_2D, texture_id)
		// we pass the data(image loaded) with some parameters
        gl.TexImage2D(gl.TEXTURE_2D, 0, format, width, height, 0, u32(format), gl.UNSIGNED_BYTE, data)
		// we say to opengl we want to generate a mipmap (required)
        gl.GenerateMipmap(gl.TEXTURE_2D);

		// we say that we want to repeat the texture in the s coordinate (horizontal, like x) if needed (optional)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
		// we say that we want to repeat the texture in the t coordinate (vertical, like y) if needed (optional)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
		// apply some filters to the texture based on the mipmap, things like blur the texture etc (optional)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

		stbi.image_free(data);
    }
    else
    {
		fmt.println("Texture failed to load at path: ", path)
        stbi.image_free(data);
    }

    return texture_id;
}


interface :: proc(window: glfw.WindowHandle) {
	imgui_impl_glfw.NewFrame()
	imgui_impl_opengl3.NewFrame()
	imgui.NewFrame()

	/* imgui.ShowDemoWindow() */
	if imgui.Begin("Window") {
		for node in nodes {
			n : cstring = strings.unsafe_string_to_cstring(node.name)
			if imgui.TreeNode(n) {
				pos_range: f32
				switch node.type {
				case Light:
					tmpColor : [3]f32 = {light.color[0], light.color[1], light.color[2]}
					imgui.ColorEdit3("Color", &tmpColor)
					light.color = glm.vec3(tmpColor)
					pos_range = 5.0
				case Camera:
					imgui.DragFloat("Fov", &camera.fov, 1.0, 1.0, 120.0)
					pos_range = 8.0
				}

				p := to_array(node.position)
				imgui.SliderFloat3("Position", &p, -pos_range, pos_range)
				node.position = glm.vec3(p)

				imgui.TreePop()
				imgui.Spacing()
			}
		}

		if imgui.TreeNode("Model") {
			imgui.ColorEdit3("Color", &albedo_color)
			imgui.SliderFloat("Specular Strength", &specularStrength, 0.0, 1.0)
			imgui.TreePop()
			imgui.Spacing()
		}

		if imgui.Button("Quit") {
			glfw.SetWindowShouldClose(window, true)
		}
	}
	imgui.End()

	imgui.Render()

	imgui_impl_opengl3.RenderDrawData(imgui.GetDrawData())

	when imgui.IMGUI_BRANCH == "docking" {
		backup_current_window := glfw.GetCurrentContext()
		imgui.UpdatePlatformWindows()
		imgui.RenderPlatformWindowsDefault()
		glfw.MakeContextCurrent(backup_current_window)
	}
}
