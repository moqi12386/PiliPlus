// Liquid glass refraction, ported from Kyant0/AndroidLiquidGlass (Apache-2.0).
// Original: backdrop/src/commonMain/kotlin/com/kyant/backdrop/internal/Shaders.kt
//   - RoundedRectRefractionShaderString
//   - RoundedRectRefractionWithDispersionShaderString
//
// Used as a dart:ui ImageFilter.shader() backdrop filter (Impeller only), so the
// engine binds the first sampler to the filter input (the backdrop) and fills the
// first vec2 uniform with the bound texture size in physical pixels.
//
// Uniforms are declared as scalars after the mandatory vec2 so that the float
// indices stay exactly in declaration order (no vector-alignment padding):
//   0-1    u_size               (engine-provided) texture size, physical px
//   ---    u_texture            (engine-provided) backdrop sampler
//   2      u_rectWidth          glass rect width, physical px
//   3      u_rectHeight         glass rect height, physical px
//   4-7    u_radiusTL/TR/BR/BL  per-corner radii, physical px
//   8      u_refractionHeight   lens band width, physical px
//   9      u_refractionAmount   signed displacement, physical px (negative = inward)
//   10     u_depthEffect        0 or 1
//   11     u_dispersion         chromatic aberration strength, 0 disables the 7-tap path

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture;

uniform float u_rectWidth;
uniform float u_rectHeight;
uniform float u_radiusTL;
uniform float u_radiusTR;
uniform float u_radiusBR;
uniform float u_radiusBL;
uniform float u_refractionHeight;
uniform float u_refractionAmount;
uniform float u_depthEffect;
uniform float u_dispersion;

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

float sdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    float outside = length(max(cornerCoord, 0.0)) - radius;
    float inside = min(max(cornerCoord.x, cornerCoord.y), 0.0);
    return outside + inside;
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

float circleMap(float x) {
    return 1.0 - sqrt(max(0.0, 1.0 - x * x));
}

vec4 sampleBackdrop(vec2 coordPx) {
    vec2 uv = coordPx / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
    // Impeller's GLES backend stores render targets bottom-up.
    uv.y = 1.0 - uv.y;
#endif
    return texture(u_texture, clamp(uv, vec2(0.0), vec2(1.0)));
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // The filter input may be padded symmetrically (e.g. by a composed blur),
    // so re-center the glass rect inside the bound texture.
    vec2 rectSize = vec2(u_rectWidth, u_rectHeight);
    vec2 padding = (u_size - rectSize) * 0.5;
    vec2 local = fragCoord - padding;

    vec2 halfSize = rectSize * 0.5;
    vec2 centeredCoord = local - halfSize;
    float radius = radiusAt(centeredCoord);

    float sd = sdRoundedRect(centeredCoord, halfSize, radius);
    if (sd > 0.0) {
        // Outside the glass shape; the widget clip normally hides this, and a
        // transparent pixel keeps antialiased clip edges clean.
        fragColor = vec4(0.0);
        return;
    }

    float refractionHeight = max(u_refractionHeight, 1e-4);
    if (-sd >= refractionHeight) {
        fragColor = sampleBackdrop(fragCoord);
        return;
    }
    sd = min(sd, 0.0);

    float d = circleMap(1.0 - (-sd) / refractionHeight) * u_refractionAmount;

    float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
    vec2 centerSafe = centeredCoord + vec2(1e-6, 1e-6);
    vec2 grad = normalize(
        gradSdRoundedRect(centeredCoord, halfSize, gradRadius) +
        u_depthEffect * normalize(centerSafe)
    );

    vec2 refractedCoord = fragCoord + d * grad;

    if (u_dispersion <= 0.0) {
        fragColor = sampleBackdrop(refractedCoord);
        return;
    }

    // Chromatic dispersion: 7 tinted taps around the refracted sample.
    float dispersionIntensity =
        u_dispersion * ((centeredCoord.x * centeredCoord.y) / (halfSize.x * halfSize.y));
    vec2 dispersedCoord = d * grad * dispersionIntensity;

    vec4 color = vec4(0.0);

    vec4 red = sampleBackdrop(refractedCoord + dispersedCoord);
    color.r += red.r / 3.5;
    color.a += red.a / 7.0;

    vec4 orange = sampleBackdrop(refractedCoord + dispersedCoord * (2.0 / 3.0));
    color.r += orange.r / 3.5;
    color.g += orange.g / 7.0;
    color.a += orange.a / 7.0;

    vec4 yellow = sampleBackdrop(refractedCoord + dispersedCoord * (1.0 / 3.0));
    color.r += yellow.r / 3.5;
    color.g += yellow.g / 3.5;
    color.a += yellow.a / 7.0;

    vec4 green = sampleBackdrop(refractedCoord);
    color.g += green.g / 3.5;
    color.a += green.a / 7.0;

    vec4 cyan = sampleBackdrop(refractedCoord - dispersedCoord * (1.0 / 3.0));
    color.g += cyan.g / 3.5;
    color.b += cyan.b / 3.0;
    color.a += cyan.a / 7.0;

    vec4 blue = sampleBackdrop(refractedCoord - dispersedCoord * (2.0 / 3.0));
    color.b += blue.b / 3.0;
    color.a += blue.a / 7.0;

    vec4 purple = sampleBackdrop(refractedCoord - dispersedCoord);
    color.r += purple.r / 7.0;
    color.b += purple.b / 3.0;
    color.a += purple.a / 7.0;

    fragColor = color;
}
