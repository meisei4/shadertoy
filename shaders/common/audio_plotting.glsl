#define NUM_BINS 64
#define NUM_HISTORY_ROWS 5

float amplitudeScale = 120.0;    // How much the envelope amplitude affects vertical displacement.
float isometricZoom    = 5.0;     // Overall scaling of the projection.
float rowSpacing       = 5.0;     // Controls the vertical gap between successive history rows.

// Projects a 3D envelope coordinate into 2D space.
//   envCoord.x: bin index (0 .. NUM_BINS-1)
//   envCoord.y: envelope amplitude [0..1]
//   envCoord.z: history row (0 = newest, NUM_HISTORY_ROWS-1 = oldest)
vec2 projectEnvelope(vec3 envCoord) {
    float binIndex      = envCoord.x;
    float envelopeValue = envCoord.y;
    float historyRow    = envCoord.z;
    float effectiveRow  = historyRow * rowSpacing;
    
    // Isometric projection:
    //   X = binIndex - effectiveRow
    //   Y = (binIndex + effectiveRow) * 0.5 - envelopeValue * amplitudeScale
    float projX = binIndex - effectiveRow;
    float projY = (binIndex + effectiveRow) * 0.5 - envelopeValue * amplitudeScale;
    return vec2(projX, projY) * isometricZoom;
}

// Computes the center of the envelope grid (in projected space) for centering.
vec2 computeEnvelopeGridCenter() {
    vec2 projBottomLeft  = projectEnvelope(vec3(0.0, 0.0, 0.0));
    vec2 projBottomRight = projectEnvelope(vec3(float(NUM_BINS - 1), 0.0, 0.0));
    vec2 projTopLeft     = projectEnvelope(vec3(0.0, 1.0, float(NUM_HISTORY_ROWS - 1)));
    vec2 projTopRight    = projectEnvelope(vec3(float(NUM_BINS - 1), 1.0, float(NUM_HISTORY_ROWS - 1)));
    
    vec2 minCorner = min(min(projBottomLeft, projBottomRight), min(projTopLeft, projTopRight));
    vec2 maxCorner = max(max(projBottomLeft, projBottomRight), max(projTopLeft, projTopRight));
    return (minCorner + maxCorner) * 0.5;
}

// Returns the distance from a pixel (screen coordinate) to a line segment.
float distanceToLine(vec2 pixel, vec2 lineStart, vec2 lineEnd) {
    vec2 lineVec = lineEnd - lineStart;
    float lineLenSq = dot(lineVec, lineVec);
    float t = dot(pixel - lineStart, lineVec) / lineLenSq;
    float clampedT = clamp(t, 0.0, 1.0);
    vec2 closestPt = lineStart + clampedT * lineVec;
    return distance(pixel, closestPt);
}

