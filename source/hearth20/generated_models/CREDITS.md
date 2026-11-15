# Hearth20 static tavern assets

The reconstructed room and generated props were supplied by the Hearth20 creator. Original GLBs are retained outside the runtime project in `Hearth20 Development/generated models`.

The separate `wizard_body.glb` and `wizard_hat.glb` were supplied by the creator on November 14, 2026, from the Hearth20 wizard reference workflow. Runtime copies retain their painted cloth, embroidery, gloves and normal maps, with mesh reduction and compressed 2K textures. The originals are unmodified. Chains and facial marks are generated in code; the original procedural pendant is superseded by the supplied replacement below.

The replacement D20 pendant was supplied as `ComfyUI_00080.glb` on November 15, 2026. Its original is retained as `generated models/dm_d20_pendant.glb`. The fused rear projection is trimmed and the opening capped; the original front geometry and embedded textures are preserved. A reduced runtime copy replaces the previous procedural charm, using its own engraved number and bail. Gold/silver appearance is handled in a material shader. The model remains host-exclusive.

These additional kits were supplied in the same folder:

- "Stylized Low-poly Wooden beam" by Rocco Giandomenico: https://sketchfab.com/3d-models/stylized-low-poly-wooden-beam-01b16abea26646c8ba334c905374f83e — author: https://sketchfab.com/Rocco.Giandomenico
- "Stylized Modular Stonewalls" by @blue.blender.print: https://sketchfab.com/3d-models/stylized-modular-stonewalls-4477c00b74574ab9a413dfd76e2362ce — author: https://sketchfab.com/arobaco
- "Tileable Stylized Wooden Floor Texture" by JennyB: https://sketchfab.com/3d-models/tileable-stylized-wooden-floor-texture-167a3fd14d65456dacfacd9eee793e6f — author: https://sketchfab.com/jenny77

All three kits are licensed under Creative Commons Attribution 4.0: https://creativecommons.org/licenses/by/4.0/

Modifications: Godot conversion, stripped unused static vertex channels, resized and block-compressed textures with mipmaps, material finish adjustments, fitted/rotated/instanced meshes, selected atlas regions and projection backfill for the reconstructed room. The authors do not endorse Hearth20.

The room uses a reduced image-grid mesh with its original photo and UV mapping; the main table uses a simplified mesh preserving its UVs. Detached fragments were removed from selected generated props. Animated rulebook, live map/sheet surfaces, special dice and the supplied animated lizard remain separate from the static replacements.
