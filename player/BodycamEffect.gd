extends CanvasLayer
# Full-screen body-cam lens effect. Draws BELOW the UI layer, so buttons stay sharp.

@export var enabled: bool = true
@export_range(0.0, 0.6) var lens_distortion: float = 0.22
@export_range(0.0, 0.03) var chromatic_aberration: float = 0.006
@export_range(0.0, 1.5) var vignette_strength: float = 0.55
@export_range(0.0, 0.3) var grain_strength: float = 0.05
@export_range(0.0, 1.0) var desaturation: float = 0.18
@export_range(0.5, 1.5) var contrast: float = 1.08
@export var tint: Color = Color(0.95, 1.0, 1.03)

const SHADER_CODE: String = """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float distortion = 0.22;
uniform float chroma = 0.006;
uniform float vignette = 0.55;
uniform float grain = 0.05;
uniform float desaturate = 0.18;
uniform float contrast = 1.08;
uniform vec3 tint = vec3(0.95, 1.0, 1.03);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	float r2 = dot(p, p);

	// Barrel / fisheye: centre magnified, edge midpoints unchanged
	vec2 src = p * ((1.0 + distortion * r2) / (1.0 + distortion));

	// Colour fringing that grows toward the edges
	vec2 uv_g = src * 0.5 + 0.5;
	vec2 uv_r = src * (1.0 + chroma * r2) * 0.5 + 0.5;
	vec2 uv_b = src * (1.0 - chroma * r2) * 0.5 + 0.5;
	vec3 col = vec3(
		texture(screen_tex, uv_r).r,
		texture(screen_tex, uv_g).g,
		texture(screen_tex, uv_b).b);

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, 1.0 - desaturate);
	col = (col - 0.5) * contrast + 0.5;
	col *= tint;

	col *= 1.0 - vignette * smoothstep(0.5, 1.6, sqrt(r2));

	// Film grain, updated 24 times a second, stronger in the dark
	float frame = floor(TIME * 24.0);
	float n = hash(SCREEN_UV * vec2(1920.0, 1080.0) + frame * 1.37) - 0.5;
	col += n * grain * (1.0 - luma * 0.6);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
"""


func _ready() -> void:
	layer = -1  # below the UI layer (which is 1)
	visible = enabled

	var rect := ColorRect.new()
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("distortion", lens_distortion)
	material.set_shader_parameter("chroma", chromatic_aberration)
	material.set_shader_parameter("vignette", vignette_strength)
	material.set_shader_parameter("grain", grain_strength)
	material.set_shader_parameter("desaturate", desaturation)
	material.set_shader_parameter("contrast", contrast)
	material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	rect.material = material
