# Generated production artwork

Mode: built-in image_gen; transparent RGBA, copied byte-for-byte into this repository. No CLI/API fallback. Region selection, directional mirroring, opacity and scene lighting happen at runtime; no raster post-editing.

## HUD atlas

Asset: `assets/ui/comic_hud/atlas.png` (1448 × 1086). Gauge / banner / timer / map skins and six distinct left-turn silhouettes; right turns are mirrored at runtime. Live text and values are not baked into images.

Prompt:

Use case: ui-mockup. Asset type: one production game HUD sprite atlas, genuinely transparent RGBA, 4 columns by 3 rows of equally sized square cells. Reference image is style reference only: the in-game HUD in its left portion, not the car or poster. Create a single 2048 x 1536 atlas if possible. Each sprite centered in its own cell with 8% transparent padding; no gridlines or labels.
Row 1: (1) blank retro racing speedometer housing, near-black charcoal translucent acrylic, cropped circular arched top and slanted lower left corner, orange outer tachometer ring sweeping from lower-left clockwise over the top to lower-right, fine ivory ticks, small orange outlined empty gear window at upper center, large EMPTY center for live speed, no numbers or letters; (2) wide short right-leaning parallelogram black acrylic title banner, vivid vermilion left slash, empty center; (3) wide short right-leaning black acrylic timer panel with vermilion left slash, empty center; (4) taller right-leaning black acrylic minimap panel, empty center and empty bottom caption area.
Rows 2 and 3: eight isolated chunky golden-yellow comic pacenote arrows with dark charcoal ink contour and small warm cream highlight. All arrows begin at bottom and travel upward before bending LEFT. Row2: slight 20 degree left, 40 degree left, 60 degree left, 90 degree left. Row3: 115 degree left, 145 degree left, 180 degree hairpin left, straight ahead. Bends must be distinct, single continuous thick shaft, large pointed arrowhead at end, clearly indicate route direction. No boxes behind arrows. We will mirror these sprites for right turns.
Match the reference's restrained retro anime racing print aesthetic, crisp legible silhouettes, very subtle casing scuffs only, no full-screen texture. Avoid blue or green frosted glass; use near-black charcoal. No text, numerals, cars, scenery, decorative badges or watermark. Preserve actual transparent exterior, not a painted checkerboard.

## Painted sky banks

Asset: `assets/sky/comic/cloud-banks.png` (1536 × 1024). Four independent painted banks projected into sky direction with slow drift and biome-specific color remapping. Transparent pixels retain their original RGB; shader samples alpha explicitly.

Prompt:

Create a production game texture atlas of painted anime sunset CLOUDS on true transparent RGBA background. Use ONLY the clouds in the supplied reference as visual direction. No scenery, cars, lettering, HUD or blue sky. Wide 1536 by 1024 atlas, four horizontally elongated cloud banks stacked in four separated rows of equal height, each row with generous transparent margins and entirely separate from other rows. Each bank is a unique asymmetrical long cumulus/cirrus cluster extending horizontally, ratio about 6:1, intricately scalloped small puffs, irregular soft yet crisp illustrated edges, tapering wisps, several broad overlapping 2D cel-painted color shapes. Creamy golden-peach sunlit upper edges, warm apricot body, dusty lavender shadow masses underneath. Shadows are painted organic shapes, not blurry spherical gradients. Beautiful Japanese animation background painting with restrained retro color planes. Bank 1 long low cloud with left tall cluster, bank 2 divided small puffs linked by wisps, bank 3 tall clustered centre with long trailing wisps, bank 4 very slender diagonal cirrus strokes. Keep all edges and wisps inside each cell. Do not outline clouds. No white bloom or lens flare. Do not fill background; transparent sky between and around all clouds. The game will map each individual bank into a live moving 3D sky.

