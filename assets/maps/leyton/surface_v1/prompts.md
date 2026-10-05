# Surface v1 generation prompts

Provider: built-in `image_gen`; generated 2026-09-27. One call per asset. Sources copied into `raw/`, original outputs retained in Codex generated_images. Pixelization uses the existing project pipeline, explicit tileable=True, no cutout/outline/dither.

## water_deep

Create ONE production texture source for Leyton City, a dark fantasy medieval 2D orthogonal game. Asset: seamless square tile of deep opaque NON-NAVIGABLE river water. Strict straight-down orthographic view, FULL BLEED water only, no shore, no objects, no border, no text, no grid, no perspective, no vignette. Pixel-art material designed to resolve cleanly at 48x48 pixels per one square meter. Low-frequency long subtle horizontal current clusters, near-black desaturated blue-green and cold charcoal, no bright sparkles, no foam. Average luminance roughly 35-50/255, highlights below 90. Flat overcast ambient illumination. Make opposite edges match seamlessly for repeated tiling. Prefer native 48x48 PNG if supported; otherwise a clean square texture source with large readable pixel clusters, no tiny photographic detail. This is one texture only, not a sheet or a scene.

## wall_top

ONE square seamless game material texture: the walkable TOP surface of Leyton City's deep desaturated teal medieval curtain wall. Strict orthographic straight-down view. Full-bleed flat masonry paving only: close-fitted rectangular ashlar capstones, staggered courses, dark thin mortar, softly worn chipped corners. Constant stone scale, about three rows of four stones over a one-meter square. Pixel art readable at 48x48 pixels, restrained large clusters, no photographic microtexture. Low saturation deep blue-green grey, near-black joints; average luminance 55-75/255, occasional muted grey mineral flecks below 140, no cyan or gold. Flat overcast ambient light, NO cast shadows, NO wall elevation, NO battlements or parapet silhouette, NO perspective, NO text or grid or decorative border. Opposite edges must repeat seamlessly. Native 48x48 PNG if available; otherwise a square texture source suitable for downsampling into a 48x48 tile.
