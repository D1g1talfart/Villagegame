shader_type spatial;

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
    // Basic rock coloring
    ALBEDO = vec3(0.4, 0.35, 0.3); // Grayish-brown rock color
    ROUGHNESS = 0.8;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
