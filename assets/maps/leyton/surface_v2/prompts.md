# Surface v2 prompts

Provider: built-in image_gen. Project assets use the existing pixelize pipeline. Generated source images retained in raw/.

## grass

Generate ONE square seamless top-down terrain texture for Leyton City, dark fantasy pixel-art game. Sparse worn short olive grass mixed with dark soil, small irregular low-contrast flecks, visually quiet and evenly distributed. No distinct tufts, no stripes, no diagonal strokes repeated as motifs, no central patch, no vignette, no obvious large features. Strict orthographic flat ground, uniform overcast ambient light, no directional cast shadows. Intended for a 48x48 pixel tile representing 1 square meter. Muted olive-brown palette, average brightness around 45/255, narrow value range roughly 30-65/255, no highlights above 85. Clear pixel clusters but no photographic noise. Full bleed opaque texture only, no grid, no frame, no text, no rocks or props. Seamlessly tileable on opposite edges. Native48x48 if available; otherwise square source suitable for pixel downsampling. Make this a quiet background material so buildings and paths can read clearly.

## road

ONE seamless square orthographic TOP-DOWN texture of worn medieval paving, for a dark fantasy 48x48 pixel game tile covering one square meter. Small irregular polygonal grey cobblestones, 6 to 9 stones across the meter, tightly set with thin muted charcoal joints. No long rows, NO large horizontal bands, no decorative pattern, no center motif or large crack. Each stone similarly lit with very restrained variation, slightly rounded chipped corners. Quiet cool neutral-grey paving, average luminance about105/255, most values between85 and125, narrow joints about60, no white highlights. Uniform flat overcast light, no directional cast shadows, no perspective. Crisp economical pixel-art clusters after reduction to48x48, no photoreal microtexture. Full bleed opaque paving only, no border, no text, no grass, no props. Seamless opposite edges; native48x48 if supported, otherwise square texture source.

## dirt

Create ONE seamless square terrain material for Leyton medieval dark fantasy pixel-art game: compacted worn dark reddish-brown earth, dry dusty silt with sparse tiny muted stones. Top-down strictly orthographic flat surface, uniform overcast diffuse illumination, no perspective or shadows. Very low contrast, quiet background, no clumps, no striations, no cracks or large unique shapes, no tracks or plants. Native48x48 pixel tile representing one square meter if supported; otherwise square source that downsamples clearly to48x48. Average luminance about75/255, narrow brown range55-95, no highlights. Full bleed opaque material, matching opposite edges for repeat tiling, no frame, no grid, no words. Economical pixel clusters, no photoreal detail.

