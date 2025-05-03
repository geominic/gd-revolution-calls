shader_type canvas_item;

uniform float blur_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 motion_direction = vec2(1.0, 0.0);

void fragment() {
    vec2 blur_vector = motion_direction * blur_strength;

    vec4 color = vec4(0.0);
    float total_weight = 0.0;

    // Sample multiple times along the blur direction
    for(float i = -4.0; i <= 4.0; i++) {
        float weight = exp(-0.5 * i * i);
        color += texture(TEXTURE, UV + blur_vector * i) * weight;
        total_weight += weight;
    }

    COLOR = color / total_weight;
}