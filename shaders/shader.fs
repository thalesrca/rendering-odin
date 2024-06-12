#version 460 core
out vec4 FragColor;

struct Material {
  vec3 ambient;
  sampler2D diffuse;
  sampler2D specular;
  float shininess;
};


struct PointLight {
  vec3 position;
  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
  vec3 color;

  float constant;
  float linear;
  float quadratic;
};

#define NR_POINT_LIGHTS 4
uniform PointLight pointLights[NR_POINT_LIGHTS];
uniform PointLight pointLight;

struct SpotLight {
    vec3 position;  
    vec3 direction;
    float cutOff;
    float outerCutOff;
    vec3 color;
  
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
	
    float constant;
    float linear;
    float quadratic;
};

uniform SpotLight spotLight;

struct DirLight {
  vec3 direction;
  vec3 color;
};

uniform DirLight dirLight;

in vec3 Normal;
in vec3 FragPos;
in vec2 TexCoord;

uniform vec3 viewPos;
uniform Material material;


vec3 CalculateDirLight(DirLight dirLight, vec3 normal, vec3 viewDir)
  {
	 // ambient
	vec3 ambient = 0.1 * texture(material.diffuse, TexCoord).rgb * dirLight.color;

	// diffuse
	vec3 lightDir = normalize(-dirLight.direction);
	float diff = max(dot(normal, lightDir), 0.0);
	vec3 diffuse = diff * texture(material.diffuse, TexCoord).rgb * dirLight.color;
  
	// specular
	vec3 reflectDir = reflect(-lightDir, normal);
	float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
	vec3 specular = spec * texture(material.specular, TexCoord).rgb * dirLight.color;

	return ambient + diffuse + specular;
  }


// unreal, epsilon normally 0.01 (1 cm) - max distance = 5.0 for example
float CalculateAttenuationU(float distance, float maxDistance) {
    float E = 0.1; // Example value, adjust as needed
    float initialIntensity = 1.0; // Example initial intensity
    float r0 = 1.0; // Example reference distance

    // Inverse-square attenuation
    float inverseSquareAttenuation = initialIntensity * (r0 * r0 / (distance * distance + E));

    // Windowing function
    float windowingFactor = pow(1.0 - pow(distance / maxDistance, 4.0), 2.0);

    // Combined attenuation
    float attenuation = inverseSquareAttenuation * windowingFactor;

    // Clamp to zero beyond max distance
    if (distance > maxDistance) {
        attenuation = 0.0;
    }

    return attenuation;
}

// frostbite, rmin normally 0.01 (1 cm) - max distance = 5.0 for example
float CalculateAttenuationF(float distance, float maxDistance) {
  float rMin = 0.01;
  float clampedDistance = max(distance, rMin);

  float inverseSquareAttenuation = 1.0 / (clampedDistance * clampedDistance);

  // Windowing function
  float windowingFactor = pow(1.0 - pow(distance / maxDistance, 4.0), 2.0);

  // Combined attenuation
  float attenuation = inverseSquareAttenuation * windowingFactor;
	
  return attenuation;
}

vec3 CalculatePointLight(PointLight pointLight, vec3 normal, vec3 viewDir) {
	 // ambient
	vec3 ambient = 0.1 *
	  texture(material.diffuse, TexCoord).rgb * pointLight.color;

	// diffuse
	vec3 lightDir = normalize(pointLight.position - FragPos);
	float diff = max(dot(normal, lightDir), 0.0);
	vec3 diffuse = diff * texture(material.diffuse, TexCoord).rgb * pointLight.color;
  
	// specular
	vec3 reflectDir = reflect(-lightDir, normal);
	float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
	vec3 specular = spec * texture(material.specular, TexCoord).rgb * pointLight.color;

	// atenuation
	float distance = length(pointLight.position - FragPos);
	float attenuation = CalculateAttenuationU(distance, 5.0); 
	  //1.0 / (pointLight.constant + pointLight.linear * distance + pointLight.quadratic * (distance * distance));

	return (ambient + diffuse + specular) * attenuation;
}


vec3 CalculateSpotLight(SpotLight spotLight, vec3 normal, vec3 viewDir) {
  vec3 lightDir = normalize(spotLight.position - FragPos);
  vec3 ambient = 0.1 *
	texture(material.diffuse, TexCoord).rgb * spotLight.color;

  // diffuse
  float diff = max(dot(normal, lightDir), 0.0);
  vec3 diffuse = diff * texture(material.diffuse, TexCoord).rgb * spotLight.color;
  
  // specular
  vec3 reflectDir = reflect(-lightDir, normal);
  float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
  vec3 specular = spec * texture(material.specular, TexCoord).rgb * spotLight.color;

  // spotlight soft edges
  float theta = dot(lightDir, normalize(-spotLight.direction));
  float epsilon = (spotLight.cutOff - spotLight.outerCutOff);
  float intensity = clamp((theta - spotLight.outerCutOff) / epsilon, 0.0, 1.0);
  diffuse *= intensity;
  specular *= intensity;

  // atenuation
  float distance = length(spotLight.position - FragPos);
  float attenuation = CalculateAttenuationU(distance, 5.0);

    // float attenuation = 1.0 / (spotLight.constant + spotLight.linear * distance + spotLight.quadratic * (distance * distance));

  return (ambient + diffuse + specular) * attenuation;
	
}



void main()
{
  vec3 norm = normalize(Normal);
  vec3 viewDir = normalize(viewPos - FragPos);

  vec3 result = CalculateDirLight(dirLight, norm, viewDir);
  //vec3 result = CalculatePointLight(pointLight, norm, viewDir);	

  for(int i = 0; i < NR_POINT_LIGHTS; i++) {
	result += CalculatePointLight(pointLights[i], norm, viewDir);	
  }

  //result += CalculateSpotLight(spotLight, norm, viewDir);

  FragColor = vec4(result, 1.0);
}
