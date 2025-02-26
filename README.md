**Guide to Customizing Textures and Using the Shader in VSCode (via Shader Toy extension) OR Shadertoy.com**

This shader code uses three texture “channels” (iChannel0, iChannel1, iChannel2), each referenced by a file path or name in the code’s header comments. Below is a step-by-step guide on how to change or customize these textures, both in Visual Studio Code with the Shader Toy extension and in the online Shadertoy environment.

---

## 1. Working with the Visual Studio Code Shader Toy Extension

### 1.1 Installing the Extension
1. Open Visual Studio Code.
2. Go to the Extensions view by clicking on the Extensions icon in the Activity Bar (on the left) or press <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>X</kbd>.
3. In the search bar, type:  
   ```
   stevensona.shader-toy
   ```
4. Click **Install** next to the “Shader Toy” extension by **Stevensona**.
5. Once installed, you can open `.glsl` or `.frag` files, and a Shader Toy preview window can be displayed (using the “Shader Toy: Show Preview” command from the Command Palette).

### 1.2 Customizing Textures
Inside your project folder (where your `.glsl` file lives), you’ll see lines like these at the top:

```glsl
#iChannel0 "file://../textures/gray_noise_small.png" // noise displacement map
#iChannel1 "file://../textures/rocks.jpg"            // background texture
#iChannel2 "file://../textures/pebbles.png"          // caustics displacement map
```

1. **Add or Replace Texture Files**  
   - In VSCode, create a folder (e.g., `textures`) within your project.
   - Copy or place any images you want to use (e.g., `.png`, `.jpg`) into this `textures` folder.  
   - Make sure to confirm the path is correct relative to your shader file.

2. **Update the Channel Paths**  
   - Adjust the lines above to point to your new textures. For example, if you want to use a file called `water_noise.png`, stored in the same `textures` folder, you could change `#iChannel0` to:
     ```glsl
     #iChannel0 "file://../textures/water_noise.png"
     ```
   - Repeat for channels 1 and 2 as needed.

3. **Texture Dimensions**  
   - This shader currently expects **single-channel** grayscale images for displacement maps (stored in the red channel), though it will also work fine with color images (and it just samples the `.r` channel).  
   - Background textures (iChannel1 in the example) are typically **full-color**.  
   - There is no absolute resolution requirement. However, typical sizes like `256x256`, `512x512`, or `1024x1024` are common for displacement maps and backgrounds. 

4. **Preview**  
   - After updating and saving your `.glsl` file, open the Shader Toy preview (via **Command Palette** → “Shader Toy: Show Preview”) to see your changes in real time.  

That’s it—using “file://” references, you have full control over which textures are used in each channel.

---

## 2. Using the Shader on Shadertoy.com

Shadertoy.com provides a simple interface to experiment with GLSL shaders right in the browser. By default, each channel can be set to some internal Shadertoy texture or none at all.

### 2.1 Creating or Editing a Shader
1. Go to [https://www.shadertoy.com](https://www.shadertoy.com).
2. Sign in (or create an account) if you want to save or edit shaders.
3. Create a new shader or open an existing one you own. In the code editor on Shadertoy, you’ll see code referencing channels as `iChannel0`, `iChannel1`, `iChannel2`, etc.

### 2.2 Updating the Channel Textures
1. Look at the **Shader Inputs** panel (usually on the left side or in a tab below the main editor). Each channel (0, 1, 2, 3) has a dropdown for texture type.  
2. Select a preset Shadertoy texture, or choose **“None”** if you do not want to use that channel.  
3. For displacement maps, you can choose from Shadertoy’s default library. For example, there might be a noise or a cloudy texture you can select. 
4. If you have a **Pro** (paid) Shadertoy account, you can upload your own custom textures. Otherwise, you’ll rely on the default library.  

### 2.3 Considerations
- **Single-Channel vs. Full Color**  
  Shadertoy typically provides color textures in RGBA. In this shader, the red channel (`.r`) is used to read displacement intensity. If you choose a color texture, it will work, but just the `.r` component is what’s effectively used as the displacement “height.”
- **Default Texture Dimensions**  
  Shadertoy’s default textures vary in size but are typically large enough (e.g., 512×512 or 1024×1024). The shader only depends on reading normalized `uv` coordinates, so the physical resolution is not strictly an issue.  

---

## 3. Notes on the Current Shader Configuration

1. **Texture Channels**  
   - **iChannel0**: Grayscale noise displacement map(s) stored in red channel.  
   - **iChannel1**: Background image (full color).  
   - **iChannel2**: Grayscale caustics displacement map(s) stored in red channel.

2. **Current Dimensions (as defined in the example)**  
   ```glsl
   #define VIRTUAL_DS_RES_X 256.0
   #define VIRTUAL_DS_RES_Y 192.0
   ```
   - These define a virtual (pixelated) resolution. It’s used by the `pixelate_uv` function (if `PIXELATE_UV` is enabled) to produce a retro “pixel” effect. You can adjust these numbers to get different pixelation.

3. **Dimming Factors**  
   ```glsl
   #define NOISE_DISP_MAP_DIMMING_FACTOR    0.33
   #define CAUSTICS_DISP_MAP_DIMMING_FACTOR 0.22
   ```
   - These scale down the brightness from the red channel. If your textures are too bright or too dark, adjust these to refine how strong the displacement effect appears.

4. **Opacity Thresholds**  
   ```glsl
   #define NOISE_DISP_INDUCED_INTENSITY_THRESHOLD   0.30
   #define ALL_DISP_MAP_INDUCED_INTENSITY_THRESHOLD 0.75
   ```
   - These thresholds drive the final alpha/opacity in the water effect. Feel free to experiment: lower them for more pronounced “peaks,” or raise them for a subtler effect.

---

## 4. Summary
- **If you want an easy, immediate environment:** Shadertoy.com is the fastest way to experiment—just paste the shader code, set your channels (noise, background, etc.), and tweak away.  
- **If you want custom textures locally:** Install the VSCode Shader Toy extension, place your images in the project folder, and update the `#iChannelN "file://"` paths accordingly. This gives full control over which textures are used in each channel.