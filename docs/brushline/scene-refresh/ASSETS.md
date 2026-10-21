# Scene refresh asset provenance

2026-10-21. New artwork is authored for Brushline Rally. No downloaded third-party models or textures were introduced.

## Mountain pigment

- Source: native OpenAI image generation, original text-to-image output; no input photograph.
- Delivered albedo: `assets/brushline/mountain-rock.png`, 1254 × 1254 px, RGB color texture.
- Requested 1536 square; the tool returned 1254 square, retained at its original size.
- Import: mipmaps enabled, repeating triplanar UV sampling. Near terrain/outcrops and final biome backdrop materials bind the same asset; per-biome tint remains in the shader. Distant mountain pigment fades with distance.
- No new collision or tire-grip data is derived from this texture.

Prompt:

> Use case: stylized-concept. Asset type: seamless tileable albedo texture for mountain cliffs in Brushline Rally, a retro hand-painted anime rally game. Flat orthographic surface swatch, no perspective, no landscape or horizon. Weathered sedimentary slate rock face, broad layered diagonal strata and eroded chips, sparse dark fissures, dry brush gouache edges, softly mottled mineral deposits. Mid value desaturated warm grey and cool slate grey, small muted ochre patches. Rich painterly rock structure at medium scale, avoid fine grain or excessive small noise. Uniform diffuse lighting, no cast shadows or glossy reflections baked in. Seamless repeat on all four edges, no border, no text, no logo, no watermarks, no plants, no objects. Square 1536x1536 texture. Must retain readable large rock planes when mapped over huge mountains and tinted by each biome; not photorealistic.

## Birds

- Original Blender model: `art_source/screenprint/props/sky_bird.blend`.
- Generator: `scripts/build_sky_bird.py`; independent WingLeft/WingRight mounts, ivory body, slate wing tips, long gliding silhouette, 1157 exported triangles.
- Export: `assets/screenprint/props/sky_bird.glb`, using `scripts/export_screenprint.py -- --only=sky_bird`.
- Blender 5.2.2 background Python was used because the live Blender MCP was not connected. Source is editable in Blender; the exporter does not overwrite it.
- Runtime: three spaced six-bird flocks per track, approach-triggered, 26-second glides with soft wingbeats and fade in/out. Highland flight locations choose nearby clear vistas using terrain sight-line samples. No vehicle outline is applied.

## Pressure checkpoint

- Updated existing source `art_source/screenprint/props/checkpoint.blend` with five visible fan blades per inlet; generator `scripts/build_pressure_checkpoint.py`.
- `FanRotorOrange` becomes its own shader mask, separate from rigid base, inflated fabric and streamer. Runtime pressure pulses and fan rotation use the existing pause-aware clock.
- Regenerate only this asset, then export with `scripts/export_screenprint.py -- --only=checkpoint`; do not regenerate unrelated hand-authored sources.

## Evidence

All JPGs and the pressure motion MP4 in this directory are native Godot Metal renders from `scripts/dev/scene_refresh_capture.gd`, not generated concept art. The capture uses fixed cameras/positions and mutes only its own test session. It does not constitute subjective audio acceptance.

`road-wear-on.jpg` / `road-wear-off.jpg` use the same paused scene and camera; only the road shader's `wear_strength` changes from 0.48 to 0. The existing generated `assets/brushline/road-wear.png` is bound to actual road meshes. `render-comparison.json` records the image-region difference.
