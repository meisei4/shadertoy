## MATH FOR water_caustics_01.glsl vanilla

## 1. Converting Fragment Coordinates to UV

We first convert the 2D fragment coordinates `frag_coord` to normalized texture coordinates `uv` by dividing by the viewport (resolution) size:

```math
\text{uv} = \frac{\text{frag\_coord}}{\text{iResolution}.xy}
```

## 2. (Optional) Pixelation

When `PIXELATE_UV` is enabled, the UVs are "chunked" into discrete blocks:

```math
\text{pixelated\_uv} 
= \left\lfloor \text{uv} \times 
(\text{VIRTUAL\_DS\_RES\_X}, \text{VIRTUAL\_DS\_RES\_Y}) \right\rfloor 
\;\big/\; 
(\text{VIRTUAL\_DS\_RES\_X}, \text{VIRTUAL\_DS\_RES\_Y})
```

This creates a pixelation effect by forcing UV coordinates to snap to a smaller grid.


## 3. Displacement Map Sampling

### 3.1. Scrolling Displacement Maps

Each displacement map is optionally scrolled (animated) over time. Given original UV, the shader applies:

```math
\text{offset\_uv} 
= \text{uv} 
+ \text{iTime} \cdot \text{velocity} 
+ \text{positional\_offset}
```

### 3.2. Sampling and Dim Factor

The `sample_disp_map(...)` function reads the **red** channel **R** from the texture at `offset_uv` and scales it by an intensity factor. For example, noise maps might use `0.33`, caustics maps `0.22`, etc. Formally:

```math
\text{disp\_value} = \text{texture}(tex, \text{offset\_uv}).r
```
```math
\text{scaled\_disp} = \text{disp\_value} \times \text{intensity\_factor}
```

Then the shader packs this as an RGBA vector:

```math
(\text{scaled\_disp},\, \text{scaled\_disp},\, \text{scaled\_disp},\, 1.0)
```

## 4. Summing Displacement Map Intensities

Two noise maps and two caustics maps are sampled. We look only at their **red** channels (since everything is effectively grayscale):

- **Noise Sum:**

```math
\text{noise\_disp\_sum} 
= \text{noise\_disp\_map\_1}.r + \text{noise\_disp\_map\_2}.r
```

- **All Maps Sum (noise + caustics):**

```math
\text{all\_disp\_sum} 
= \text{noise\_disp\_sum}
 + \text{caustics\_disp\_map\_1}.r
 + \text{caustics\_disp\_map\_2}.r
```

## 5. Computing the Opacity



```math
\alpha =
\begin{cases}
  \text{FULL\_ALPHA}, & \text{if } \text{all\_disp\_sum} > \text{ALL\_DISP\_MAP\_INDUCED\_INTENSITY\_THRESHOLD}, \\
  \text{NORMAL\_ALPHA}, & \text{else if } \text{noise\_disp\_sum} > \text{NOISE\_DISP\_INDUCED\_INTENSITY\_THRESHOLD}, \\
  \text{BLURRY\_ALPHA}, & \text{otherwise}.
\end{cases}
```

## 6. Background Texture Warping

When we sample the background (`iChannel1`), we optionally warp the UV by the displacement map to create a subtle shifting effect:

```math
\text{warped\_bg\_uv} 
= \text{uv} 
+ \bigl(\text{disp\_map}.r \times \text{warp\_factor}\bigr)
```

We then fetch the background texture with:

```math
\text{background} 
= \text{texture}(\text{iChannel1}, \text{warped\_bg\_uv})
```

## 7. Final Color

We combine the displaced noise maps (scaled by `alpha`) on top of the warped background:

```math
\text{frag\_color} 
= (\text{noise\_disp\_map\_1} + \text{noise\_disp\_map\_2}) \times \alpha 
+ \text{background}
```

This accumulates the grayscale displacement contributions in RGB and blends them with the background according to the computed opacity.

Resources:
https://www.youtube.com/watch?v=8rCRsOLiO7k - displacement mapping essay
https://www.shadertoy.com/view/wdG3Rz - original inspiration in shadertoy