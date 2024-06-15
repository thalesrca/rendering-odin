package main

import "core:os"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "core:strings"
import "vendor:cgltf"
import stbi "vendor:stb/image"

Vertex :: struct {
	position: glm.vec3,
	normal: glm.vec3,
	textCoords: glm.vec3,
}

Texture :: struct {
	id: u32,
	type: string,
}

Mesh :: struct {
	vertices: [dynamic]Vertex,
	indices: [dynamic]u32,
	textures: [dynamic]Texture,
	VAO, VBO, EBO: u32,
}


Model :: struct {
	meshes: [dynamic]^Mesh,
}


drawModel :: proc(model: ^Model, shader: ^Shader){
	fmt.println("drawModel")
	/* fmt.printfln("the model has %d meshes", len(model.meshes)) */
	for i:uint = 0; i < len(model.meshes); i+=1 {
		drawMesh(model.meshes[i], shader)
	}
}

drawMesh :: proc(mesh: ^Mesh, shader: ^Shader) {
	/* fmt.println("drawMesh") */
	/* fmt.println("the mesh has", len(mesh.textures), " textures") */
	diffuseNr  : u32 = 1
	specularNr : u32 = 1

	for i := 0; i < len(mesh.textures); i+=1 {
		gl.ActiveTexture(gl.TEXTURE0 + u32(i))

		number : string
		name : string = mesh.textures[i].type

		if name == "texture_diffuse" {
			number = fmt.aprintf("%d", (diffuseNr + 1))
		} else if name == "texture_specular" {
			number = fmt.aprintf("%d", (specularNr + 1))
		}

		s : string = strings.concatenate({"material.", name, number})
		location : cstring = strings.unsafe_string_to_cstring(s)

		fmt.println("setting the texture location: ", location)
		set_int(shader^, location, i32(i))
	}

	gl.ActiveTexture(gl.TEXTURE0)

	// draw mesh
	gl.BindVertexArray(mesh.VAO);
    gl.DrawElements(gl.TRIANGLES, i32(len(mesh.indices)), gl.UNSIGNED_INT, rawptr(uintptr(0)));
    gl.BindVertexArray(0);
}


setup_mesh :: proc(mesh: ^Mesh){
	using mesh

	fmt.println("setup_meshhh")
	gl.GenVertexArrays(1, &VAO);
    gl.GenBuffers(1, &VBO);
    gl.GenBuffers(1, &EBO);

    gl.BindVertexArray(VAO);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);

    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(Vertex), &vertices[0], gl.STATIC_DRAW);  

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), 
                  &indices[0], gl.STATIC_DRAW);

    // vertex positions
    gl.EnableVertexAttribArray(0);	
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), uintptr(0));
    // vertex normals
    gl.EnableVertexAttribArray(1);	
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), uintptr(3 * size_of(f32)));
    // vertex texture coords
    gl.EnableVertexAttribArray(2);	
    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), uintptr(6 * size_of(f32)));

    gl.BindVertexArray(0);

	fmt.println("end setup_mesh")
}


load_model :: proc(path: string) -> ^Model{
	options : cgltf.options

	model_path := strings.unsafe_string_to_cstring(path)
	
	data, res := cgltf.parse_file(options, model_path)
	defer if res == cgltf.result.success do cgltf.free(data)

	if res != cgltf.result.success {
		fmt.println("Unable to open gltf file")
		os.exit(-1)
	}

	r := cgltf.load_buffers(options, data, model_path)

	if r != cgltf.result.success {
		fmt.println("Failed to load buffers")
		os.exit(-1)
	}

	/* fmt.println(r) */

	/* fmt.println("buffer count:", len(data.buffers)) */
	/* fmt.println("buffer data size:", data.buffers[0].size) */
	fmt.println("mesh size:", len(data.meshes))
	fmt.println("mesh primitives size:", len(data.meshes[0].primitives))
	/* /\* fmt.println("mesh attributes:", data.meshes[0].primitives[0].attributes[0].data.count) *\/ */
	/* fmt.println("materials size:", len(data.materials)) */

	model := new(Model)
	/* defer free(model) */

	// mesh
	for data_mesh in data.meshes {
		mesh := new(Mesh)
		/* defer free(mesh) */

		position  : [dynamic]glm.vec3
		normal    : [dynamic]glm.vec3
		textCoord : [dynamic]glm.vec3

		total_size: int = -1

		// primite
		for primitive in data_mesh.primitives {
			attributes := primitive.attributes

			// attributes
			for i in 0..<len(attributes) {
				/* fmt.println(attributes[i]) */
				/* fmt.println() */
				type := attributes[i].type
				accessor := attributes[i].data

				if total_size < 0 {
					total_size = int(accessor.count)
				}

				// if type is position we fill the position list
				if cgltf.attribute_type.position == type {
					for j in 0..<accessor.count {
						vertices : [3]f32
						result := cgltf.accessor_read_float(accessor, j, &vertices[0], uint(3))

						if result {
							append(&position, glm.vec3{vertices[0], vertices[1], vertices[2]})
						}
					}
				// if type is normal we fill the normal list
				} else if cgltf.attribute_type.normal == type {
					for j in 0..<accessor.count {

						vertices : [3]f32
						result := cgltf.accessor_read_float(accessor, j, &vertices[0], uint(3))

						if result {
							append(&normal, glm.vec3{vertices[0], vertices[1], vertices[2]})
						}

					}
				// if type is textcoord we fill the textcoord list
				} else if cgltf.attribute_type.texcoord == type {
					for j in 0..<accessor.count {

						vertices : [3]f32
						result := cgltf.accessor_read_float(accessor, j, &vertices[0], uint(3))

						if result {
							append(&textCoord, glm.vec3{vertices[0], vertices[1], vertices[2]})
						}
					}

				}

			}


			// fill indices 
			indices := primitive.indices

			for i:uint= 0; i < indices.count; i+=1 {
				index : u32
				result := cgltf.accessor_read_uint(indices, i, &index, uint(1))

				if result {
					append(&mesh.indices, index)
				}
			}


			material_data := primitive.material

			if material_data == nil {
				fmt.println("no material")
			}

			fmt.println("Material name: ", material_data.name)

			if material_data.has_pbr_metallic_roughness {
				fmt.println("Base color: ", material_data.pbr_metallic_roughness.base_color_texture.texture.image_.uri)
			}

			/* t := Texture{} */
			/* t.id = 0 */
			/* t.type = "test" */
			/* append(&mesh.textures, t) */
		}


		// fill vertices
		for i in 0..<total_size {
			p := position[i]
			n := normal[i]
			t := textCoord[i]

			vertex := Vertex{p, n, t}
			append(&mesh.vertices, vertex)

		}

		append_elem(&model.meshes, mesh)
	}


	/* for m in model.meshes { */
	/* 	setup_mesh(m) */
	/* } */

	return model
}

texture_from_file :: proc(path: string) -> u32 {
	texture_id: u32
	gl.GenTextures(1, &texture_id)

	filename: cstring = strings.unsafe_string_to_cstring(path)
	
	width, height, nr_components: i32
	data := stbi.load(filename, &width, &height, &nr_components, 0)
	/* defer stbi.image_free(data) */

	if data != nil {

		format: i32
        if nr_components == 1 {
            format = gl.RED			
		}
        else if (nr_components == 3) {
            format = gl.RGB
		}
        else if (nr_components == 4) {
            format = gl.RGBA
		}
		
        gl.BindTexture(gl.TEXTURE_2D, texture_id)
        gl.TexImage2D(gl.TEXTURE_2D, 0, format, width, height, 0, u32(format), gl.UNSIGNED_BYTE, data)
        gl.GenerateMipmap(gl.TEXTURE_2D);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		stbi.image_free(data)
	} else {
		fmt.println("Texture failed to load at path: ", path)
		stbi.image_free(data)
	}

	return texture_id
}
