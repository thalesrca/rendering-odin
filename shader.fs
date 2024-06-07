#version 460 core
out vec4 FragColor;

in vec2 TexCoord;
in vec3 Normal;
in vec3 FragPos;


uniform vec3 objectColor;
uniform vec3 lightColor;
uniform vec3 lightPos;
uniform vec3 viewPos;
uniform float specularStrength;
uniform sampler2D texture1;
uniform sampler2D texture2;

void main()
{
  float ambientStrength = 0.1;
  vec3 ambient = ambientStrength * lightColor;


  vec3 norm = normalize(Normal);
  vec3 lightDir = normalize(lightPos - FragPos);
  float diff = max(dot(norm, lightDir), 0.0);
  vec3 diffuse = diff * lightColor;

  
  //float specularStrength = 0.5;
  vec3 viewDir = normalize(viewPos - FragPos);
  vec3 reflectDir = reflect(-lightDir, norm);

  float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
  vec3 specular = specularStrength * spec * lightColor;

  vec4 t = mix(texture(texture1, TexCoord), texture(texture2, TexCoord), 0.5);

  vec3 result = (ambient + diffuse + specular) * objectColor;
  FragColor = t * vec4(result, 1.0);
}
