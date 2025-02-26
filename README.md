https://shadertoyunofficial.wordpress.com/2019/07/23/shadertoy-media-files/
*(For running locally instead of relying on default Shadertoy channel assets.)*


## Table of Contents
1. [Overview](#overview)  
2. [Resolution and Pixelation](#resolution-and-pixelation)  
3. [Texture Inputs](#texture-inputs)  
4. [Displacement Layers](#displacement-layers)  
5. [Caustics Layers](#caustics-layers)  
6. [Background Layer](#background-layer)  
7. [Thresholds and Opacity Logic](#thresholds-and-opacity-logic)  
8. [Mathematical Domain Analysis](#mathematical-domain-analysis)  
9. [Constants Summary](#constants-summary)  

<a name="overview"></a>
## 1. Overview

This shader combines multiple **grayscale noise** and **caustic** textures to produce a water-like effect over a background image. In particular, two displacement noise layers and two caustics layers are sampled, then composited over a background texture. The final output is controlled by specific thresholds that determine whether to:

- Negate (suppress) the effect,
- Use a medium (base) opacity, or
- “Blast” the effect to full white.

The shader code is structured as follows:

- **Pixelation** (optional) modifies the UV coordinates.  
- **Displacement Layers** (noise) scroll over time and can offset the background UVs slightly.  
- **Caustics Layers** also scroll but are used to add bright water-reflection patterns.  
- **Opacity** is dynamically computed by comparing average intensities of the layers against user-defined thresholds.  
- **Final Composition** sums the displacement color and background color, with an alpha factor determined by the threshold logic.

---

<a name="resolution-and-pixelation"></a>
## 2. Resolution and Pixelation

```c
#define VIRTUAL_DS_RES_X 256.0
#define VIRTUAL_DS_RES_Y 192.0
```

These define a “virtual resolution” used when **DO_PIXELATION** is active. If pixelation is enabled:

$$
\text{pixelated\_uv} 
= \left\lfloor \mathbf{uv} \times 
\begin{bmatrix}
\text{VIRTUAL\_DS\_RES\_X} \\
\text{VIRTUAL\_DS\_RES\_Y}
\end{bmatrix}
\right\rfloor
\; / \;
\begin{bmatrix}
\text{VIRTUAL\_DS\_RES\_X} \\
\text{VIRTUAL\_DS\_RES\_Y}
\end{bmatrix}
$$

This effectively downscales the UV coordinates to a discrete grid of 256×192 “virtual pixels,” creating a pixelation effect.


<a name="texture-inputs"></a>
## 3. Texture Inputs

1. **iChannel0**: A grayscale noise texture (stored in the `r` channel). Used for displacement.  
2. **iChannel1**: A full-color “rocks” background texture.  
3. **iChannel2**: A grayscale caustics texture (stored in the `r` channel).  

Each of these textures is sampled differently, with optional offsets and velocity scrolls.


<a name="displacement-layers"></a>
## 4. Displacement Layers

There are two displacement layers, each sampling the same noise texture (`iChannel0`), but scrolling at different velocities and starting offsets.

### 4.1 Initial Offsets

```c
#define DISP1_INITIAL_OFFSET_X -0.1
#define DISP1_INITIAL_OFFSET_Y  0.0
#define DISP2_INITIAL_OFFSET_X  0.1
#define DISP2_INITIAL_OFFSET_Y  0.0
```

These define the base offsets for each displacement layer:

- For layer 1:  
  $$ \mathbf{offset}_1 = \begin{bmatrix} -0.1 \\ 0.0 \end{bmatrix} $$
- For layer 2:  
  $$ \mathbf{offset}_2 = \begin{bmatrix} 0.1 \\ 0.0 \end{bmatrix} $$

### 4.2 Scrolling Velocities

```c
#define DISP1_SCROLL_VELOCITY_X  0.02
#define DISP1_SCROLL_VELOCITY_Y  0.02
#define DISP2_SCROLL_VELOCITY_X -0.02
#define DISP2_SCROLL_VELOCITY_Y -0.02
```

- Layer 1 velocity:  
  $$ \mathbf{v}_1 = \begin{bmatrix} 0.02 \\ 0.02 \end{bmatrix} $$
- Layer 2 velocity:  
  $$ \mathbf{v}_2 = \begin{bmatrix} -0.02 \\ -0.02 \end{bmatrix} $$

The UV coordinate for each displacement layer at time \( t = \text{iTime} \) is thus:

$$
\mathbf{uv}_{\text{dispX}}(t)
= \mathbf{uv} 
+ \mathbf{v}_X \times t
+ \mathbf{offset}_X,
$$

where \( X \in \{1,2\} \).

### 4.3 Darkening Factor

```c
#define DISP_LAYER_DARKENING_FACTOR 0.33
```

When sampled, each displacement layer’s raw brightness (in [0,1]) is multiplied by 0.33. Hence the maximum brightness of the displacement layer is capped at 0.33. Formally:

$$
\text{disp\_color} 
= \langle n, n, n, 1 \rangle \times 0.33
= \langle 0.33n,\, 0.33n,\, 0.33n,\, 1 \rangle,
$$

where \( n \) is the red channel of the noise texture, \( n \in [0,1] \).


<a name="caustics-layers"></a>
## 5. Caustics Layers

There are two caustics layers, sampling from `iChannel2` (a texture containing caustics in its `r` channel). Similar to the displacement layers, each caustics layer has distinct scroll velocities and an intensity/darkening factor.

### 5.1 Scrolling Velocities

```c
#define CAUSTICS1_SCROLL_VELOCITY_X -0.1
#define CAUSTICS1_SCROLL_VELOCITY_Y  0.01
#define CAUSTICS2_SCROLL_VELOCITY_X  0.1
#define CAUSTICS2_SCROLL_VELOCITY_Y  0.01
```

- Caustics layer 1 velocity:  
  $$ \mathbf{v}_{c1} = \begin{bmatrix} -0.1 \\ 0.01 \end{bmatrix} $$
- Caustics layer 2 velocity:  
  $$ \mathbf{v}_{c2} = \begin{bmatrix} 0.1 \\ 0.01 \end{bmatrix} $$

### 5.2 Darkening Factor

```c
#define CAUSTICS_LAYER_DARKENING_FACTOR 0.22
```

The raw brightness of each caustics texture sample (from [0,1]) is scaled by 0.22. So the maximum possible brightness contributed by a single caustics layer is 0.22. Formally:

$$
\text{caustics\_color} 
= \langle c, c, c, 1 \rangle \times 0.22 
= \langle 0.22c,\, 0.22c,\, 0.22c,\, 1 \rangle,
$$

where \( c \in [0,1] \) is the sampled red-channel value.

---

<a name="background-layer"></a>
## 6. Background Layer

```c
#define BACKGROUND_DISP_FACTOR 0.05
```

The background texture (in `iChannel1`) is sampled at UV coordinates offset by the displacement’s brightness:

$$
\mathbf{uv}_{\text{bg}} 
= \mathbf{uv} 
+ \bigl(\text{disp\_layer\_brightness}\bigr) \times 0.05.
$$

Here, `disp_layer_brightness` is typically taken from one of the displacement layers’ **red** values (`disp_layer.r`), effectively shifting the background by up to 0.05 in UV space. This small distortion creates a subtle “rippling” effect.

<a name="thresholds-and-opacity-logic"></a>
## 7. Thresholds and Opacity Logic

Two main thresholds govern how the final color is combined:

```c
#define NOISE_INTENSITY_THRESHOLD             0.30
#define NOISE_AND_CAUSTIC_INTENSITY_THRESHOLD 0.75
```

In the code, we first compute:

1. **`disp_layers_mean_intensity`**  

   $$
   \text{disp\_layers\_mean\_intensity}
   = \text{average\_rgb}(\text{disp1} + \text{disp2}).
   $$

   This sums the two displacement layers (each in [0,0.33] per channel) and finds their average brightness across the RGB channels.

2. **`all_layers_mean_intensity`**  

   $$
   \text{all\_layers\_mean\_intensity}
   = \text{average\_rgb}(\text{disp1} + \text{disp2} + \text{caustics1} + \text{caustics2}).
   $$

### 7.1 Base, Negate, and Full “Blast” Opacities

```c
#define BASE_ALPHA 0.4
#define FULL_ALPHA 4.0
```

- We start with $$\alpha = \text{BASE\_ALPHA} = 0.4$$ This would be the “normal” overlay opacity.
- If $$\text{disp\_layers\_mean\_intensity} > 0.30$$, we set $$\alpha = 0.0$$ (“NEGATE THE EFFECT”).
- If $$\text{all\_layers\_mean\_intensity} > 0.75 $$, we set $$\alpha = 4.0 $$ (“BLAST TO FULL WHITE”).

Hence:

$$
\alpha = 
\begin{cases}
0, & \text{if } \text{disp\_layers\_mean\_intensity} > 0.30, \\[6pt]
4, & \text{if } \text{all\_layers\_mean\_intensity} > 0.75, \\[6pt]
0.4, & \text{otherwise}.
\end{cases}
$$

Finally, the output color is:

$$
\text{frag\_color}
= (\text{disp1} + \text{disp2}) \times \alpha
+ \text{background}.
$$


<a name="mathematical-domain-analysis"></a>
## 8. Intensity Domain Analysis

In order to understand how the thresholds (0.30 and 0.75) map onto the possible range of displacement + caustics intensities, we consider:

1. **Each displacement layer** has range in \([0,0.33]\) (due to the darkening factor).  
2. **Each caustics layer** has range in \([0,0.22]\).  

### 8.1 Summation of Displacement Layers

For two displacement layers (`disp1` and `disp2`):

- **Max** per pixel (grayscale channel): \( 0.33 + 0.33 = 0.66 \).  
- Averaging R, G, B (all equal in grayscale) means the possible mean is in \([0,0.66]\).

Hence:

$$
\text{disp\_layers\_mean\_intensity} \in [0,\, 0.66].
$$

### 8.2 Summation of All Layers

For **two** displacement layers and **two** caustics layers:

- Displacement contribution: up to 0.66  
- Caustics contribution: up to 0.44 (0.22 + 0.22)  
- **Maximum** combined grayscale per pixel: 0.66 + 0.44 = 1.10  

Thus:

$$
\text{all\_layers\_mean\_intensity} \in [0,\, 1.10].
$$

### 8.3 Threshold Comparison

- \( $$\text{NOISE\_INTENSITY\_THRESHOLD} = 0.30$$ \) is within \([0, 0.66]\).  
- \($$ \text{NOISE\_AND\_CAUSTIC\_INTENSITY\_THRESHOLD} = 0.75 $$\) is within \([0, 1.10]\).  

This allows the first threshold (0.30) to “negate” the effect if displacement layers alone are too strong, and the second threshold (0.75) to “blast to white” if the combined displacement + caustics are especially bright.

<a name="constants-summary"></a>
## 9. Constants Summary

Below is a concise list of all constants, along with their roles and typical ranges:

| **Constant**                             | **Definition/Role**                                                                                            | **Value**    | **Remarks**                                                                                      |
|-----------------------------------------|-----------------------------------------------------------------------------------------------------------------|-------------:|---------------------------------------------------------------------------------------------------|
| `VIRTUAL_DS_RES_X`, `VIRTUAL_DS_RES_Y`  | Virtual resolution for pixelation.                                                                             | 256, 192     | Used if `DO_PIXELATION` is enabled.                                                              |
| `DISP1_INITIAL_OFFSET_X/Y`              | Initial UV offset for displacement layer 1.                                                                    | -0.1, 0.0    | Shifts the sampling origin for layer 1.                                                          |
| `DISP2_INITIAL_OFFSET_X/Y`              | Initial UV offset for displacement layer 2.                                                                    | 0.1, 0.0     | Shifts the sampling origin for layer 2.                                                          |
| `DISP1_SCROLL_VELOCITY_X/Y`             | UV scroll velocity for displacement layer 1.                                                                   | 0.02, 0.02   | Speed in normalized texture space.                                                               |
| `DISP2_SCROLL_VELOCITY_X/Y`             | UV scroll velocity for displacement layer 2.                                                                   | -0.02, -0.02 | Opposite direction from layer 1, giving crossing noise.                                          |
| `CAUSTICS1_SCROLL_VELOCITY_X/Y`         | UV scroll velocity for caustics layer 1.                                                                       | -0.1, 0.01   | Faster horizontal scroll.                                                                        |
| `CAUSTICS2_SCROLL_VELOCITY_X/Y`         | UV scroll velocity for caustics layer 2.                                                                       | 0.1, 0.01    | Opposite horizontal direction from layer 1.                                                      |
| `BACKGROUND_DISP_FACTOR`                | Amount of UV offset applied to the background using displacement brightness.                                   | 0.05         | Creates subtle “ripple” distortion in background.                                               |
| `DISP_LAYER_DARKENING_FACTOR`           | Intensity/darkening factor for displacement layers.                                                            | 0.33         | Caps brightness at ~1/3 for displacement.                                                        |
| `CAUSTICS_LAYER_DARKENING_FACTOR`       | Intensity/darkening factor for caustics layers.                                                                | 0.22         | Caps brightness at ~2/9 for caustics.                                                            |
| `BASE_ALPHA`                            | Base overlay opacity (40% = 0.4).                                                                              | 0.4          | Used when intensities are below thresholds.                                                      |
| `FULL_ALPHA`                            | Full “blast” overlay opacity (400% = 4.0).                                                                     | 4.0          | Used when combined intensities exceed second threshold.                                          |
| `NOISE_INTENSITY_THRESHOLD`             | Threshold for displacement layers to negate effect if exceeded.                                                | 0.30         | If displacement alone is too strong, effect is negated.                                          |
| `NOISE_AND_CAUSTIC_INTENSITY_THRESHOLD` | Threshold for “full white” effect if both noise + caustics are bright.                                         | 0.75         | If combined layers exceed 0.75 average, overlay is forced to full white.                         |

---

### Final Composition

Finally, the fragment color is computed as:

$$
\text{frag\_color}
= \bigl(\text{disp\_layer1} + \text{disp\_layer2}\bigr) \times \alpha
+ \text{background},
$$

where \( \alpha \) is determined by threshold comparisons against the **mean** intensities of the displacement and caustics layers.
