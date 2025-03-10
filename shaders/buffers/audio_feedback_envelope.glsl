#include "/shaders/common/audio_plotting.glsl"
#iChannel0 "file://assets/audio/Hellion_v2.ogg"
#iChannel1 "self"
#define WAVEFORM_SAMPLE_COUNT 512

float uUpdateInterval = 10.0;    // e.g. 15.0 for more frequent updates.
float uEnvelopeSmoothing = 0.4; // e.g. 0.3 to 0.5 for moderate smoothing.

// Calculate how many waveform samples fall into one bin.
int samplesPerBin = WAVEFORM_SAMPLE_COUNT / NUM_BINS;

// Computes the average absolute amplitude for a given bin.
float sampleWaveformEnvelope(int binIndex) {
    float sumAmplitude = 0.0;
    for (int i = 0; i < samplesPerBin; i++) {
        float sampleX = (float(binIndex * samplesPerBin + i) + 0.5) / float(WAVEFORM_SAMPLE_COUNT);
        float sampleVal = texture(iChannel0, vec2(sampleX, 1.0)).r;
        sumAmplitude += abs(sampleVal);
    }
    return sumAmplitude / float(samplesPerBin);
}

// Shifts the existing envelope history upward by one row.
vec4 shiftEnvelopeHistory(vec2 uv, float rowHeight) {
    return texture(iChannel1, uv + vec2(0.0, rowHeight));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float rowHeight = 1.0 / float(NUM_HISTORY_ROWS);
    
    // For all rows except the bottom, shift the history upward.
    if (uv.y < 1.0 - rowHeight) {
        fragColor = shiftEnvelopeHistory(uv, rowHeight);
        return;
    }
    
    // Bottom row: compute new envelope data and blend with existing data.
    // Use uUpdateInterval to control how often the envelope updates.
    float updateInterval = uUpdateInterval; 
    float blendFactor = mod(float(iFrame), updateInterval) / updateInterval;
    
    int binIndex = int(floor(uv.x * float(NUM_BINS)));
    float newEnvelope = sampleWaveformEnvelope(binIndex);
    float oldEnvelope = texture(iChannel1, uv).r;
    
    // Apply exponential smoothing: effectiveBlend = blendFactor scaled by uEnvelopeSmoothing.
    float effectiveBlend = blendFactor * uEnvelopeSmoothing;
    float blendedEnvelope = mix(oldEnvelope, newEnvelope, effectiveBlend);
    
    fragColor = vec4(blendedEnvelope, blendedEnvelope, blendedEnvelope, 1.0);
}
