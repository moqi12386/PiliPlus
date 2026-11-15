// Liquid glass specular highlight, ported from Kyant0/AndroidLiquidGlass (Apache-2.0).
// Original: backdrop/src/commonMain/kotlin/com/kyant/backdrop/internal/Shaders.kt
//   - DefaultHighlightShaderString  (directional rim light, BlendMode.Plus)
//   - AmbientHighlightShaderString  (ambient top light, srcOver)
//
// Drawn as a normal paint shader (not an ImageFilter) over a stroked outline, so
// u_size is supplied by the Dart side, in logical pixels.
//
// Uniforms are declared as scalars so the float indices stay exactly in
// declaration order (no vector-alignment padding):
//   0-3    u_radiusTL/TR/BR/BL
//   4-7    u_colorR/G/B/A
//   8      u_width
//   9      u_height
//   10     u_angle         light direction, radians
//   11     u_falloff       exponent shaping the rim falloff
//   12     u_ambient       0 = directional, 1 = ambient

#include <flutter/runtime_effect.glsl>

uniform float u_radiusTL;
uniform float u_radiusTR;
uniform float u_radiusBR;
uniform float u_radiusBL;
uniform float u_colorR;
uniform float u_colorG;
uniform float u_colorB;
uniform float u_colorA;
uniform float u_width;
uniform float u_height;
uniform float u_angle;
uniform float u_falloff;
uniform float u_ambient;

out vec4 fragColor;

float radiusAt(vec2 centeredCoord) {
    if (centeredCoord.x >= 0.0) {
        if (centeredCoord.y <= 0.0) return u_radiusTR;
        else return u_radiusBR;
    } else {
        if (centeredCoord.y <= 0.0) return u_radiusTL;
        else return u_radiusBL;
    }
}

vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        vec2 dir = max(cornerCoord, vec2(0.0));
        float len = max(length(dir), 1e-6);
        return sign(coord) * (dir / len);
    } else {
        float gradX = step(cornerCoord.y, cornerCoord.x);
        return sign(coord) * vec2(gradX, 1.0 - gradX);
    }
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 halfSize = vec2(u_width, u_height) * 0.5;
    vec2 centeredCoord = fragCoord - halfSize;

    float radius = radiusAt(centeredCoord);
    float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));

    vec2 grad = gradSdRoundedRect(centeredCoord, halfSize, gradRadius);
    vec2 normal = vec2(cos(u_angle), sin(u_angle));
    float d = dot(grad, normal);
    float intensity = pow(abs(d), u_falloff);

    // Flutter's runtime effect shaders must return premultiplied colour.
    if (u_ambient > 0.5) {
        // Ambient: only the half facing the light contributes.
        float t = step(0.0, d);
        float a = t * intensity * u_colorA;
        fragColor = vec4(a, a, a, a);
    } else {
        // Directional rim, intended to be drawn with BlendMode.plus.
        float a = intensity * u_colorA;
        fragColor = vec4(u_colorR * a, u_colorG * a, u_colorB * a, a);
    }
}
