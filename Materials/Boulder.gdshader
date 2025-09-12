// NOTE: Shader automatically converted from Godot Engine 4.4.1.stable's ORMMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);
uniform sampler2D texture_orm : hint_roughness_g, filter_linear_mipmap, repeat_enable;

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;
varying vec3 world_position;

void vertex() {
    world_position = VERTEX;
    
    // Create noise-based distortion
    float noise1 = sin(VERTEX.x * 3.0) * cos(VERTEX.y * 4.0) * sin(VERTEX.z * 2.0);
    float noise2 = sin(VERTEX.x * 7.0 + 1.0) * cos(VERTEX.y * 5.0 + 2.0);
    float noise3 = sin(VERTEX.z * 6.0 + 3.0) * cos(VERTEX.x * 8.0 + 1.5);
    
    // Combine noise for rock-like bumps
    float distortion = (noise1 * 0.5 + noise2 * 0.5 + noise3 * 0.5) * 0.5;
    
    // Push vertices outward/inward along their normal
    VERTEX += NORMAL * distortion;
}

void fragment() {
	vec2 base_uv = UV;

	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	vec4 orm_tex = texture(texture_orm, base_uv);
	ROUGHNESS = orm_tex.g;
 	METALLIC = orm_tex.b;
}
