#include "/shaders/common/audio_plotting.glsl"
#iChannel0 "file://shaders/buffers/audio_feedback_envelope.glsl"
float lineRenderWidth = 0.75;

float getEnvelopeFromBuffer(int historyRow, int binIndex) {
    float textureV = 1.0 - (float(historyRow) + 0.5) / float(NUM_HISTORY_ROWS);
    float textureU = (float(binIndex) + 0.5) / float(NUM_BINS);
    return texture(iChannel0, vec2(textureU, textureV)).r;
}

// Offsets a projected envelope coordinate so the full grid is centered on screen.
vec2 projectCenteredEnvelope(vec3 envCoord) {
    vec2 rawProj    = projectEnvelope(envCoord);
    vec2 gridCenter = computeEnvelopeGridCenter();
    vec2 screenCenter = iResolution.xy * 0.5;
    return rawProj + (screenCenter - gridCenter);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float closestDistance = 1e6;
    
    // Loop over each history row (each envelope capture).
    for (int historyRow = 0; historyRow < NUM_HISTORY_ROWS; historyRow++) {
        // Loop over each pair of adjacent bins.
        for (int binIndex = 0; binIndex < NUM_BINS - 1; binIndex++) {
            float envelopeLeft  = getEnvelopeFromBuffer(historyRow, binIndex);
            float envelopeRight = getEnvelopeFromBuffer(historyRow, binIndex + 1);
            
            vec3 envCoordLeft  = vec3(float(binIndex), envelopeLeft, float(historyRow));
            vec3 envCoordRight = vec3(float(binIndex + 1), envelopeRight, float(historyRow));
            
            vec2 screenPosLeft  = projectCenteredEnvelope(envCoordLeft);
            vec2 screenPosRight = projectCenteredEnvelope(envCoordRight);
            
            float d = distanceToLine(fragCoord, screenPosLeft, screenPosRight);
            closestDistance = min(closestDistance, d);
        }
    }
    
    float intensity = 1.0 - smoothstep(lineRenderWidth, lineRenderWidth * 2.0, closestDistance);
    fragColor = vec4(vec3(intensity), 1.0);
}
