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
directional_light : DirectionalLight = new_directional_light(-0.2, -1.0, 0.3)
point_light : PointLight = new_point_light(-0.2, -1.0, 0.3)
spot_light : SpotLight = new_spot_light(-0.2, -1.0, 0.3)

light_specular :glm.vec3= {1.0, 1.0, 1.0}
specularStrength : f32 = 0.5
albedo_color : [3]f32 = {1.0, 0.5, 0.31}


main :: proc() {
	if glfw.Init() == 0 {
		fmt.println("Error trying to initialized GLFW.")
		return
	}

	//glfw.SetErrorCallback(error_callback)
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
	cube_shader := new_shader("shaders/shader.vs", "shaders/shader.fs")
	point_light_shader := new_shader("shaders/light_cube.vs", "shaders/light_cube.fs")
	directional_light_shader := new_shader("shaders/light_cube.vs", "shaders/light_cube.fs")

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

	pointLightsPositions: [4]PointLight = {
		new_point_light( 0.7,  0.2,  2.0),
		new_point_light( 2.3,  -3.3, -4.0),
		new_point_light(-2.0, -2.0, -8.0),
		new_point_light(-0.0, 0.0, -3.0)
	}

	/* 	pointLightsPositions: [4]glm.vec3 = { */

	/* 	glm.vec3{ 0.7,  0.2,  2.0}, */
	/* 	glm.vec3{ 2.3,  -3.3, -4.0}, */
	/* 	glm.vec3{-2.0, -2.0, -8.0}, */
	/* 	glm.vec3{-0.0, 0.0, -3.0} */
	/* } */


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
	pointLightVAO: u32
	gl.GenVertexArrays(1, &pointLightVAO)
	gl.BindVertexArray(pointLightVAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO2)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices2), &vertices2, gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)


	// load texture
	diff_texture : u32 = load_texture("assets/container2.png")
	specular_texture : u32 = load_texture("assets/container2_specular.png")

	use_shader(cube_shader)
	set_tex(cube_shader, "material.diffuse", 0)
	set_tex(cube_shader, "material.specular", 1)
	

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
		interface(window, &pointLightsPositions)

		// input
		// -----
		process_input(window)

		// render
		rendering(cube_shader, directional_light_shader, point_light_shader, diff_texture, specular_texture, VAO, pointLightVAO, cubePositions, pointLightsPositions)

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


rendering :: proc(cube_shader, directional_light_shader, point_light_shader: Shader, diff_texture, spec_texture, VAO, pointLightVAO: u32, cubePositions: [10]glm.vec3, pointLightsPositions: [4]PointLight) {
	// render
	gl.ClearColor(0.1, 0.1, 0.1, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	// ----------- cube shader config --------------
	use_shader(cube_shader)
	dir := glm.vec3(directional_light.direction)
	set_vec3(cube_shader, "dirLight.direction", dir)
	set_vec3(cube_shader, "dirLight.color", directional_light.color)
	

	set_vec3(cube_shader, "viewPos", camera.position)


	// cube light properties
	diffuse_light := directional_light.color * point_light.color * glm.vec3(0.5)
	ambient_light := diffuse_light * glm.vec3(0.2)
	p := glm.vec3(point_light.position)
	set_vec3(cube_shader, "pointLight.position", p)

	set_vec3(cube_shader, "pointLight.ambient", ambient_light)
	set_vec3(cube_shader, "pointLight.diffuse", diffuse_light)
	set_vec3(cube_shader, "pointLight.specular", light_specular)

	set_float(cube_shader, "pointLight.constant", 1.0)
	set_float(cube_shader, "pointLight.linear", 0.09)
	set_float(cube_shader, "pointLight.quadratic", 0.032)
	set_vec3(cube_shader, "pointLight.color", point_light.color)

	//point light 1
	pl := pointLightsPositions[0]
	diffuse_light = directional_light.color * pl.color * glm.vec3(0.5)
	ambient_light = diffuse_light * glm.vec3(0.2)
    set_vec3(cube_shader, "pointLights[0].position", pl.position)
	set_vec3(cube_shader, "pointLights[0].color", pl.color)
    set_vec3(cube_shader, "pointLights[0].ambient", ambient_light)
	set_vec3(cube_shader, "pointLights[0].diffuse", diffuse_light)
    set_vec3(cube_shader, "pointLights[0].specular", glm.vec3{1.0, 1.0, 1.0})
    set_float(cube_shader,"pointLights[0].constant", 1.0)
    set_float(cube_shader,"pointLights[0].linear", 0.09)
    set_float(cube_shader,"pointLights[0].quadratic", 0.032)
    // point light 2
	pl = pointLightsPositions[1]
    set_vec3(cube_shader, "pointLights[1].position", pl.position)
	set_vec3(cube_shader, "pointLights[1].color", pl.color)
    set_vec3(cube_shader, "pointLights[1].ambient", glm.vec3{0.05, 0.05, 0.05})
    set_vec3(cube_shader, "pointLights[1].diffuse", pl.color)
	set_vec3(cube_shader, "pointLights[1].specular", glm.vec3{1.0, 1.0, 1.0})
    set_float(cube_shader,"pointLights[1].constant", 1.0)
    set_float(cube_shader,"pointLights[1].linear", 0.09)
    set_float(cube_shader,"pointLights[1].quadratic", 0.032)
	// point light 3
	pl = pointLightsPositions[2]
    set_vec3(cube_shader, "pointLights[2].position", pl.position)
	set_vec3(cube_shader, "pointLights[2].color", pl.color)
    set_vec3(cube_shader, "pointLights[2].ambient", glm.vec3{0.05, 0.05, 0.05})
    set_vec3(cube_shader, "pointLights[2].diffuse", pl.color)
	set_vec3(cube_shader, "pointLights[2].specular", glm.vec3{1.0, 1.0, 1.0})
    set_float(cube_shader,"pointLights[2].constant", 1.0)
    set_float(cube_shader,"pointLights[2].linear", 0.09)
    set_float(cube_shader,"pointLights[2].quadratic", 0.032)

	// point light 4
	pl = pointLightsPositions[3]
    set_vec3(cube_shader, "pointLights[3].position", pl.position)
	set_vec3(cube_shader, "pointLights[3].color", pl.color)
    set_vec3(cube_shader, "pointLights[3].ambient", glm.vec3{0.05, 0.05, 0.05})
    set_vec3(cube_shader, "pointLights[3].diffuse", pl.color)
	set_vec3(cube_shader, "pointLights[3].specular", glm.vec3{1.0, 1.0, 1.0})
    set_float(cube_shader,"pointLights[3].constant", 1.0)
    set_float(cube_shader,"pointLights[3].linear", 0.09)
    set_float(cube_shader,"pointLights[3].quadratic", 0.032)


	s_pos := glm.vec3(camera.position)
	set_vec3(cube_shader, "spotLight.position", s_pos)
	s_dir := glm.vec3(cam_front)
	set_vec3(cube_shader, "spotLight.direction", s_dir)
	set_float(cube_shader, "spotLight.cutOff", glm.cos(glm.radians_f32(12.5)))
	set_float(cube_shader, "spotLight.outerCutOff", glm.cos(glm.radians_f32(17.5)))
	set_float(cube_shader, "spotLight.constant", 1.0)
	set_float(cube_shader, "spotLight.linear", 0.09)
	set_float(cube_shader, "spotLight.quadratic", 0.032)
	set_vec3(cube_shader, "spotLight.color", point_light.color)

	// cube material properties
	s := glm.vec3(specularStrength)
	set_vec3(cube_shader, "material.specular", s)
	set_float(cube_shader, "material.shininess", 32.0)

	// view/projection transformationse
	view := glm.mat4LookAt(camera.position, camera.position + cam_front, cam_up)
	projection := glm.mat4Perspective(glm.radians_f32(camera.fov), SCR_WIDTH/SCR_HEIGHT, 0.1, 100.0) // we use the perspective projection (instead of orthogonal)
	set_mat4(cube_shader, "view", &view)
	set_mat4(cube_shader, "projection", &projection)
	

	// bind textures on corresponding texture units
	gl.ActiveTexture(gl.TEXTURE0) // we want to configure the first (0) texture
	gl.BindTexture(gl.TEXTURE_2D, diff_texture) // we say it is a texture 2d and pass the texture

	gl.ActiveTexture(gl.TEXTURE1) // now we want to configure the second (1) texture
	gl.BindTexture(gl.TEXTURE_2D, spec_texture)

	
	// render cubes
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
		set_mat4(cube_shader, "model", &model)

		gl.DrawArrays(gl.TRIANGLES, 0, 36)
	}


	// directional light
	use_shader(directional_light_shader)
	set_mat4(directional_light_shader, "projection", &projection)
	set_mat4(directional_light_shader, "view", &view)

	dirLightT := glm.mat4Translate(glm.vec3(directional_light.position))
	dirLightS := glm.mat4Scale(glm.vec3(0.2))
	dirLightModel : glm.mat4 = dirLightT * dirLightS
	set_mat4(directional_light_shader, "model", &dirLightModel)

	/* use_shader(point_light_shader) */
	/* set_mat4(point_light_shader, "projection", &projection) */
	/* set_mat4(point_light_shader, "view", &view) */

	// draw point lights
	for i in 0..<4 {
		pointLightT := glm.mat4Translate(glm.vec3(pointLightsPositions[i].position))
		pointLightS := glm.mat4Scale(glm.vec3(0.2))
		pointLightModel : glm.mat4 = pointLightT * pointLightS
		set_mat4(point_light_shader, "model", &pointLightModel)
		set_vec3(point_light_shader, "lightColor", pointLightsPositions[i].color)
		
		gl.BindVertexArray(pointLightVAO)
		gl.DrawArrays(gl.TRIANGLES, 0, 36)
	}


	/* pointLightT := glm.mat4Translate(glm.vec3(point_light.position)) */
	/* pointLightS := glm.mat4Scale(glm.vec3(0.2)) */
	/* pointLightModel : glm.mat4 = pointLightT * pointLightS */
	/* set_mat4(point_light_shader, "model", &pointLightModel) */
	/* set_vec3(point_light_shader, "lightColor", point_light.color) */
	
	/* gl.BindVertexArray(pointLightVAO) */
	/* gl.DrawArrays(gl.TRIANGLES, 0, 36) */


}


to_array :: proc(v: glm.vec3) -> [3]f32 {
	return {v[0], v[1], v[2]}
}


interface :: proc(window: glfw.WindowHandle, pointLightsPositions: ^[4]PointLight) {
	imgui_impl_glfw.NewFrame()
	imgui_impl_opengl3.NewFrame()
	imgui.NewFrame()

	/* imgui.ShowDemoWindow() */
	if imgui.Begin("Window") {
		if imgui.TreeNode("Directional Light") {
			dir := to_array(directional_light.direction)
			imgui.SliderFloat3("Direction", &dir, -180, 180)
			directional_light.direction = glm.vec3(dir)

			pos := to_array(directional_light.position)
			imgui.SliderFloat3("Position", &pos, -8.0, 8.0)
			directional_light.position = glm.vec3(pos)

			tmpColor : [3]f32 = {directional_light.color[0], directional_light.color[1], directional_light.color[2]}
			imgui.ColorEdit3("Color", &tmpColor)
			directional_light.color = glm.vec3(tmpColor)

			imgui.TreePop()
			imgui.Spacing()
		}

		for i in 0..<4 {
			title := strings.unsafe_string_to_cstring(fmt.aprintf("Point Light %d", i))
			if imgui.TreeNode(title) {
				point_light := &pointLightsPositions[i]

				pos := to_array(point_light.position)
				imgui.SliderFloat3("Position", &pos, -8.0, 8.0)
				point_light.position = glm.vec3(pos)

				tmpColor : [3]f32 = {point_light.color[0], point_light.color[1], point_light.color[2]}
				imgui.ColorEdit3("Color", &tmpColor)
				point_light.color = glm.vec3(tmpColor)

				imgui.TreePop()
				imgui.Spacing()
			}

		}

		/* if imgui.TreeNode("Single point light") { */
		/* 	//point_light := &pointLightsPositions[i] */
		/* 	/\* dir := to_array(point_light.direction) *\/ */
		/* 	/\* imgui.SliderFloat3("Direction", &dir, -180, 180) *\/ */
		/* 	/\* point_light.direction = glm.vec3(dir) *\/ */

		/* 	pos := to_array(point_light.position) */
		/* 	imgui.SliderFloat3("Position", &pos, -8.0, 8.0) */
		/* 	point_light.position = glm.vec3(pos) */

		/* 	tmpColor : [3]f32 = {point_light.color[0], point_light.color[1], point_light.color[2]} */
		/* 	imgui.ColorEdit3("Color", &tmpColor) */
		/* 	point_light.color = glm.vec3(tmpColor) */

		/* 	imgui.TreePop() */
		/* 	imgui.Spacing() */
		/* } */


		if imgui.TreeNode("Spot Light") {
			/* dir := to_array(point_light.direction) */
			/* imgui.SliderFloat3("Direction", &dir, -180, 180) */
			/* point_light.direction = glm.vec3(dir) */

			pos := to_array(spot_light.position)
			imgui.SliderFloat3("Position", &pos, -8.0, 8.0)
			spot_light.position = glm.vec3(pos)

			tmpColor : [3]f32 = {spot_light.color[0], spot_light.color[1], spot_light.color[2]}
			imgui.ColorEdit3("Color", &tmpColor)
			spot_light.color = glm.vec3(tmpColor)

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
