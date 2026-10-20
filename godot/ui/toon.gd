class_name Toon
extends RefCounted
## Materiais de desenho animado (sombreamento em faixas, luz de contorno e linha escura ao redor),
## no estilo da arte vetorial de referência. O contorno é um segundo passe com a malha "inflada".

const SHADER_BODY := """
shader_type spatial;
render_mode cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shade : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.9, 0.85, 1.0);
uniform float rim_strength = 0.08;
uniform float rim_power = 2.6;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * fres * rim_strength;
}

void light() {
	float d = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = smoothstep(0.02, 0.2, d);      // transição suave entre luz e sombra
	float hi = smoothstep(0.62, 0.78, d);      // faixa de brilho
	vec3 tone = mix(shade.rgb / max(albedo.rgb, vec3(0.001)), vec3(1.0), lit) + vec3(hi * 0.12);
	DIFFUSE_LIGHT += LIGHT_COLOR * tone * 0.8 / PI;  // LIGHT_COLOR já vem multiplicada por PI
}
"""

const SHADER_OUTLINE := """
shader_type spatial;
render_mode unshaded, cull_front;
uniform float width = 0.03;
uniform vec4 color : source_color = vec4(0.1, 0.05, 0.05, 1.0);

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
"""

static var _body_shader: Shader
static var _outline_shader: Shader


static func outline(width := 0.03, color := Color(0.13, 0.07, 0.07)) -> ShaderMaterial:
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = SHADER_OUTLINE
	var m := ShaderMaterial.new()
	m.shader = _outline_shader
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("color", color)
	return m


## Material em faixas. `shade` é a cor da parte na sombra; com `line` > 0 ganha contorno.
static func make(albedo: Color, shade: Color, line := 0.03, outline_color := Color(0.13, 0.07, 0.07)) -> ShaderMaterial:
	if _body_shader == null:
		_body_shader = Shader.new()
		_body_shader.code = SHADER_BODY
	var m := ShaderMaterial.new()
	m.shader = _body_shader
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("shade", shade)
	if line > 0.0:
		m.next_pass = outline(line, outline_color)
	return m
