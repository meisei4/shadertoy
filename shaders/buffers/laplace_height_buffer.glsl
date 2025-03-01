#iChannel0 "self"                                // Feedback from previous height buffer
#iChannel1 "file://laplace_velocity_buffer.glsl" // Feedback from previous velocity buffer

//TODO: this normal domain is unused, because i dont know when to normalize the height such that when it gets fedback into the velocity buffer or the height buffer it doesnt fuck up the formulas..
// i guess what im finding out is that the wave model needs to stay in whatever domain it needs to stay in, and only when we go to the displacement integration on the background textures UVs,
// are we able to practically scale it to achieve the desired effect

// theoretically we could have a target normalized domain for displacement being like [-1, 1].
// That is, once normalized, a height of -1 and 1 means maximum negative and positive warp respectively (corresponding directly to some UV sampling displacement)
#define TARGET_DOMAIN_MIN -1.0
#define TARGET_DOMAIN_MAX  1.0

// The equilibrium height (baseline) is defined as 0.0.
#define HEIGHT_BASELINE 0.0
// RESTORE_RATE (if used) would pull the height back to baseline,
// set to 0.0 means that height is purely the integration of velocity
//TODO: figure out what the units are for this or at least how to conceptualize the scale of its effect on the resulting visual
#define RESTORE_RATE 0.00

void mainImage(out vec4 frag_color, in vec2 frag_coord) {
    vec2 uv = frag_coord / iResolution.xy;
    // 'velocity' is the per-frame change in height (height units per frame)
    float velocity = texture(iChannel1, uv).r;
    // 'old_height' is the previous integrated height (in height units)
    float old_height = texture(iChannel0, uv).r;
    
    // Integrate velocity to get new height.
    //TODO: i still dont know how you can just add velocity to height and say thats the new height...
    //ANSWER: This is an Euler integration step. Velocity is defined as the change in height per frame (height units/frame), so by adding it to the current height (in height units), you’re computing the new height.
    // Think of it like a position update: if you move at a certain speed for one time step, your new position is your old position plus that speed times the time step (here, the time step is implicitly 1 frame).
    float new_height = old_height + velocity;
    
    // Optionally, you could restore some fraction toward baseline:
    new_height = mix(new_height, HEIGHT_BASELINE, RESTORE_RATE);

    frag_color = vec4(new_height, 0.0, 0.0, 1.0);
}
