# Hearth20 Custom Map Agent Guide

**Target: Hearth20 Beta 0.3.13 or newer · `.hearth20map` format version 1 · guide revision 2**

Give this entire document to an agent with the user's map request. The deliverable is one playable **`.hearth20map` file**, not a picture accompanied by setup instructions. It includes the final map art, exact grid scale, walls, doors, windows, lighting, foreground PNGs and party entry positions. Hearth20 installs those together and adds a campaign map tab without asking the user to measure the image.

## 1. Your job as the map-making agent

Build an attractive, coherent, usable top-down battlemap tailored to the user. Resolve routine creative decisions yourself. Ask only about missing information that materially changes play, such as a required physical size or encounter location. If nothing is specified, use a 32 × 24 grid with five feet per cell and artwork at 100–128 pixels per cell. State the chosen dimensions when delivering the file.

Use image generation for original raster artwork when available, and follow the tool's image-editing and provenance instructions. An image-generation prompt alone is not a finished map. Inspect the actual generated image, repair contradictions, measure the final features and build the data from those measurements. The final image is the authority for feature placement. Do not invent coordinates from a prompt that the image failed to follow.

Deliver:

1. `descriptive-map-name.hearth20map`, ready to import through **+ Map**.
2. A preview image showing the map, plus its dimensions in cells and feet.
3. A short description of the setting, lighting setup, entry position and any intentional gameplay restrictions.
4. When possible, an editable authoring folder or ZIP containing `map.json` and `assets/`. This is optional source material; the playable package is mandatory.

Use original, user-supplied or suitably licensed art. Keep credits in the manifest. Exclude account information, campaign saves, character PDFs, API keys and unrelated reference photos. Do not modify a person's appearance unless the user requested it.

## 2. Plan the encounter and its scale before making art

Write a compact private design brief: location, style, overall dimensions, intended party entry, important routes, sight lines, encounter spaces, cover, doors, windows, light sources and removable overhead objects. Every important doorway should connect real traversable space. Avoid rooms that cannot be reached, stairs that lead nowhere, mismatched floor levels and furniture that changes size between rooms.

Use a strict orthographic overhead camera. Walls and furniture may have shallow relief and contact shadows, but roofs and tall facades must not obscure the playable floor. Do not use isometric perspective, a horizon, a cinematic side view or dramatic perspective convergence. No labels, watermark, legend, UI, compass or baked-in grid unless the user specifically asks. Hearth20 draws its own adjustable grid.

Keep scale consistent. With five feet per square, a typical single doorway is approximately one square wide, a corridor is at least one square wide, a bed is about 1 × 1.5 squares, and a dining table might span 1 × 2. Leave clear squares for tokens and distinct walkable boundaries. Use contrasting floor materials to explain terrain without making noise compete with pawns.

The entire raster must correspond to complete square cells:

`pixels_per_cell = image_width / width_cells = image_height / height_cells`

For example, a 32 × 24 map at 128 px/cell is 4096 × 3072 pixels and covers 160 × 120 feet at five feet/cell. A 2048 × 1152 image fits 32 × 18 cells at 64 px/cell; it does not fit 32 × 24. Resize/crop/outpaint the art intentionally before measuring objects. Do not lie in the metadata to make a mismatched image pass. If image tools cannot reach the planned ratio exactly, choose a coherent grid that matches the actual finished raster and keep the promised encounter scale clear.

Useful generation prompt structure:

> Strict orthographic overhead fantasy tactical battlemap of [setting], [width] by [height] complete square cells, final aspect [ratio], consistent five-foot scale. [Precise room/terrain layout, entrances, traversable routes, furnishing scale]. [Visible light fixtures and window apertures]. [Palette/materials/weather]. Painterly high detail with restrained contact shadows and clean playable floor. No grid, labels, interface, people, perspective horizon or opaque roof over playable rooms. Leave [foreground feature] out of the floor image because it will be a separate transparent overhead prop.

Use separate reference/repair passes for structural problems. Preserve the composition while correcting inaccessible doors, impossible walls or inconsistent scale. Inspect at full size and at a typical 1000 × 650 game window.

## 3. Coordinate system and tracing the final art

All manifest positions and lengths are **grid cells**, not pixels or feet. Origin `(0,0)` is the image's top-left. X increases right; Y increases down. A cell's center is `(column + 0.5, row + 0.5)`. Grid corners are integer coordinates.

Convert a measured point in the final raster using:

`x_cells = x_pixels / pixels_per_cell`

`y_cells = y_pixels / pixels_per_cell`

Keep fractional positions where the art needs them; do not force a wall onto the nearest grid line if that would put it across a doorway. Segment endpoints may reach the map edges. Token/entry positions must remain inside the map. Foreground positions describe the **center** of their image, including transparent margins.

Make a temporary diagnostic preview of the final art with cell lines, traced segments, aperture IDs, light arrows, prop rectangles and entry markers. Inspect that every data element matches its visual source. Do not include that diagnostic image as the actual background. After any crop, rescale or regeneration, remeasure every affected coordinate and recompute image hashes.

## 4. The actual `.hearth20map` container

The extension is `.hearth20map`. Its content is a small, tightly constrained **ZIP_STORED archive**. No compression is used because images are already compressed. Changing the extension of a normal compressed ZIP is insufficient.

Expected structure:

```text
ashen-watch.hearth20map
├── map.json
└── assets/
    ├── map.png
    ├── chandelier.png
    └── canopy.png
```

There are no directory entries in the actual ZIP; the paths contain `assets/` directly. It contains only the manifest and the raster files referenced by that manifest. No scripts, models, URLs, executable files, extra thumbnails, OS metadata or unused assets. Hearth20 reads the archive in memory and does not extract it into arbitrary folders.

Use the standard-library packing tool from **Hearth20-Map-Authoring-Kit.zip** or `tools/pack_hearth20map.py` in [WonderingMage/Hearth20](https://github.com/WonderingMage/Hearth20). Run:

```text
python pack_hearth20map.py AshenWatch/map.json --out AshenWatch.hearth20map
```

The tool reads final image dimensions, checks the recipe, calculates SHA-256 hashes, fills the image records and writes a new stored archive. It never overwrites the input art or an existing output. Choose a new output name when rebuilding. Its successful JSON result includes dimensions, object counts, byte size and final SHA-256. Keep that as build evidence.

If the helper is unavailable, construct the file with Python's `zipfile.ZipFile(..., compression=zipfile.ZIP_STORED, allowZip64=False)`, using a seekable new output file. Write UTF-8 `map.json` and referenced asset paths only. Calculate each raster's SHA-256 from its exact final file bytes with `hashlib.sha256(data).hexdigest()`. The full schema below still applies. Do not use ZIP64, encryption, streaming data descriptors, comments, extra fields, nested archive roots or directory entries. Use only ASCII filenames.

### Hard limits

| Item | Supported bound |
| --- | --- |
| Complete archive | 64 MiB, 2–66 entries |
| Manifest | 262,144 UTF-8 bytes; nesting depth ≤16; ≤20,000 JSON nodes |
| Background | PNG/JPEG; ≤40 MiB; each side ≤16,384 px; ≤67,108,864 pixels |
| Foreground image | PNG; ≤8 MiB; each side ≤2,048 px; ≤4,194,304 pixels |
| Grid | 1–256 whole cells in each dimension; square pixel pitch |
| Feet per cell | 0.01–1,000; normally 5 |
| Walls + doors + windows + lights | At most 256 records combined |
| Foreground placements | At most 64 |
| Entry points | 1–16 distinct cell centers |
| Campaign | At most 256 maps, and 64 MiB encoded campaign save including all assets |

Use practical sizes below these maxima; a 64 MiB import may still exceed a populated campaign's total save budget because saves encode embedded images. Prefer 2–8 MiB map images, reuse identical foreground assets, and avoid dozens of unnecessary lights. A limit is not a quality target.

An asset path must match `assets/[a-z0-9][a-z0-9_-]{0,63}.png`, `.jpg` or `.jpeg`. No uppercase letters, spaces, subfolders, `..`, absolute paths or backslashes. IDs use `[A-Za-z_][A-Za-z0-9_-]{0,95}`. Object IDs must be unique across all geometry, lights and foreground placements. Unknown manifest fields are rejected. Use finite JSON numbers, true/false booleans, no comments and no duplicate keys.

## 5. Full schema and a complete small example

The following authoring example describes a 16 × 12 room. Use a matching 2048 × 1536 `assets/map.png`. The north wall has one window and the south wall one door. The chandelier image must be a separate transparent PNG. The helper inserts the omitted image `sha256` fields; **inside the final archive every image record must contain its exact hash**.

```json
{
  "format": "hearth20-map",
  "version": 1,
  "id": "ashen-watch",
  "title": "Ashen Watch",
  "description": "An abandoned watch hall at late afternoon.",
  "credits": "Map and foreground art: original artwork created for this encounter.",
  "grid": {"width_cells": 16, "height_cells": 12, "feet_per_cell": 5},
  "background": {"path": "assets/map.png"},
  "walls": [
    {"id": "north-west", "a": {"x": 2, "y": 2}, "b": {"x": 7, "y": 2}},
    {"id": "north-east", "a": {"x": 9, "y": 2}, "b": {"x": 14, "y": 2}},
    {"id": "east", "a": {"x": 14, "y": 2}, "b": {"x": 14, "y": 10}},
    {"id": "south-east", "a": {"x": 14, "y": 10}, "b": {"x": 9, "y": 10}},
    {"id": "south-west", "a": {"x": 7, "y": 10}, "b": {"x": 2, "y": 10}},
    {"id": "west", "a": {"x": 2, "y": 10}, "b": {"x": 2, "y": 2}}
  ],
  "doors": [
    {"id": "entry-door", "a": {"x": 7, "y": 10}, "b": {"x": 9, "y": 10}, "open": true}
  ],
  "windows": [
    {"id": "north-window", "a": {"x": 7, "y": 2}, "b": {"x": 9, "y": 2}}
  ],
  "lights": [
    {
      "id": "north-daylight", "position": {"x": 8, "y": 2.08},
      "source_type": "window", "window_id": "north-window",
      "angle_degrees": 90, "spread_degrees": 90,
      "window_height": 7, "sill_height": 3,
      "bright_feet": 10, "dim_feet": 35,
      "light_color": "#ffe5ae", "ray_strength": 0.55, "enabled": true
    },
    {
      "id": "hearth", "position": {"x": 3.3, "y": 5.5},
      "source_type": "brazier", "bright_feet": 20, "dim_feet": 20,
      "light_color": "#ffc179", "angle_degrees": 0,
      "spread_degrees": 180, "ray_strength": 0.5, "enabled": true
    }
  ],
  "foreground": [
    {
      "id": "chandelier", "name": "Iron chandelier",
      "image": {"path": "assets/chandelier.png"},
      "position": {"x": 8, "y": 5.5},
      "width_cells": 2, "height_cells": 2, "rotation_degrees": 12
    }
  ],
  "environment": {
    "dynamic_lighting": true, "ambient_light": "dark", "outdoor": false,
    "natural_light": {
      "time_hours": 16.5, "north_degrees": 180,
      "sun_intensity": 1, "moon_intensity": 0.35,
      "haze": 0.32, "exposure": 1
    },
    "roof_rects": []
  },
  "entry_points": [
    {"x": 7.5, "y": 8.5}, {"x": 8.5, "y": 8.5},
    {"x": 7.5, "y": 7.5}, {"x": 8.5, "y": 7.5}
  ]
}
```

Required root fields: `format`, `version`, `id`, `title`, `grid`, `background`, `entry_points`. Include the geometry/lighting/foreground arrays explicitly even when empty to make the intended absence clear. Optional root fields are `description`, `credits`, `walls`, `doors`, `windows`, `lights`, `foreground`, `environment`; no others are accepted.

`title` is nonempty and ≤96 characters. `description` is ≤2,000 and `credits` ≤4,000. These are text, not instructions to execute. `grid` has exactly `width_cells`, `height_cells`, `feet_per_cell`. Each image record has only `path`, `sha256`. The package creates its own unique internal campaign scene ID; importing the same package twice produces independent tabs and does not overwrite an existing map.

## 6. Walls, apertures and movement geometry

Walls have `{id,a,b}`. Doors have `{id,a,b,open}` with a boolean `open` (default false). Windows have `{id,a,b}`. An endpoint is exactly `{"x": number, "y": number}`. Every segment must have positive length and lie within the map. Segments are straight; approximate curves with a modest number of short segments.

Trace opaque wall center lines or the appropriate room-facing boundary, consistently. Split walls at every door/window aperture. Do not draw an unbroken wall underneath an open door or a window: that wall would continue to block light. Join neighboring opaque segments so accidental pinholes do not leak light. Preserve useful entrance widths. Do not trace every plank seam, rug, floor crack or tiny piece of clutter as a blocking wall.

Doors are editable apertures that block when closed. Windows provide light apertures and remain movement barriers. A foreground sprite is decorative and does **not** automatically create collision or a lighting occluder. If a large boulder, column or closed chest should block sight/movement, add suitable explicit geometry around it. Judge this according to the actual image, and avoid creating unexplained barriers over walkable art.

All imported segments and lights are editable objects on the DM's **Light** layer. They are not flattened into the artwork. Geometry data is not distributed as GM-only editor controls to players.

## 7. Choose lights from visible sources in the final image

Use `lights` records with `id`, `position` and a `source_type` from:

| Type | Use |
| --- | --- |
| `torch` | Small warm flame; commonly 20 ft bright plus 20 ft dim |
| `brazier` | Fire bowl, fireplace or larger warm emitter |
| `window` | Day/night aperture tied to one explicit window segment |
| `sunlight` | Time-dependent natural sky; use with `outdoor:true` for exterior parallel illumination |
| `moonlight` | Natural night source; same exterior sky system changes with time |
| `crystal` | Magical localized colored emitter |

Do not place lights at arbitrary decorative coordinates just to make the map bright. Put each position on the fixture or just on its room-facing side. Use warm oranges for fire, pale warm sunlight, subdued blue moonlight, and deliberate magical hues. Keep enough shadow for the geometry to matter without making the entire playable area illegible.

Optional light fields and bounds:

| Field | Meaning / allowed value |
| --- | --- |
| `bright_feet` | Bright reach in feet, 0–1,000; default 20 |
| `dim_feet` | Additional dim reach beyond bright reach, 0–1,000; default 20 |
| `light_color` | `#RRGGBB` or `#RRGGBBAA`; default warm light |
| `angle_degrees` | Board-space direction, −360–360; 0 right, 90 down, 180 left, 270 up |
| `spread_degrees` | 1–360; default 360; a directional cone for localized lights |
| `ray_strength` | 0–1; default 0.55; avoid washing out the floor |
| `enabled` | Boolean; default true |
| `window_id` | Exact window-segment ID for `window` sources |
| `window_height` | Window opening height in feet, 0.1–100; default 7 |
| `sill_height` | Sill above floor in feet, 0.1–100; default 3 |

For a window, place the source within 1.5 cells of the referenced aperture midpoint. Set its direction **inward across the aperture**, not along the wall. The runtime uses the window's perpendicular normal, choosing its inward sign from your angle. A source whose axis is nearly parallel to the aperture is rejected. Each window light names its aperture explicitly; proximity alone is not the binding rule.

For example, a north wall with a horizontal window and the room below it uses 90° inward; a room left of an east wall uses 180°. A fireplace facing into a room uses an appropriate half-plane or narrower spread. Multiple candles on a chandelier generally need one modest emitter, not one expensive light per flame. A dangling foreground chandelier may have a separate light at its actual center.

### Daylight, moonlight and physical plausibility

`environment.natural_light` accepts exactly `time_hours` (0–24), `north_degrees` (0–360), `sun_intensity` (0–3), `moon_intensity` (0–3), `haze` (0–1), `exposure` (0–3). The DM can change time and rotate board north after import. Use a coherent time and north orientation, and inspect whether the desired windows actually face the sky direction then.

Hearth20 uses an artistic equinox sky model, not geographic ephemerides: a day/night sine drives altitude, with a 65° maximum sun altitude, and azimuth rotates with time. Board-space light travel is `Vector2.from_angle(radians(azimuth + 90 + north_degrees))`. At 16:30 with north 0°, rays travel approximately toward the upper-right; rotating north 180° reverses that direction. Do not assume a window will cast direct sun at every hour.

Window projection uses physical aperture width and the floor distances:

`near_feet = sill_height / tan(solar_altitude)`

`far_feet = (sill_height + window_height) / tan(solar_altitude)`

Converted to cells, these create the finite elongated rectangular/slanted patch rather than a generic spotlight. Low sun creates long casts; high sun short casts. Inward-facing sky alignment scales the direct beam. Rays clip against the wall solver. A subdued radial, wall-occluded diffuse contribution approximates scattered/first-bounce illumination. It is not full path-traced global illumination, and this file cannot supply arbitrary volumetric meshes or a custom renderer.

For outdoors, set `outdoor:true` and include **one** `sunlight` or `moonlight` source. The runtime uses the active day/night sky across the board, so do not scatter hundreds of suns over the image. Optional `roof_rects` are axis-aligned covered areas: `{x,y,width,height}` in cells, positive width/height, fully inside the map, at most 64. They exclude direct sky under intact roofs. Walls also cast projected exterior shadows. An interior-only map usually uses `outdoor:false`, dark ambient, windows and fixture lights. `ambient_light` accepts only `bright`, `dim`, `dark`; bright ambient intentionally reduces dramatic darkness.

Avoid painting strong contradictory directional beams permanently into the base artwork. Use restrained local fixture glow/contact shadow in the raster, allowing the dynamic overlay to change when the DM moves the sun or extinguishes a fire. Test noon, late afternoon and midnight, including windows facing away from the sun and rooms behind closed doors.

## 8. Separate foreground objects

Foreground records have exactly `id`, `name`, `image`, `position`, `width_cells`, `height_cells`, optional `rotation_degrees`. `name` is ≤64 characters. Width/height are 0.1–64 cells. Rotation is −360–360°, clockwise on the downward-Y board. The entire rotated footprint must fit within the map.

Generate transparent **RGBA PNGs** with matching overhead perspective, material style, scale and light direction. Suitable objects include chandeliers, tree crowns, hanging banners, awnings, overhead bridges and removable canopy sections. Keep their true silhouette and soft contact/occlusion detail; avoid opaque rectangular backgrounds, halos and excessive empty margins.

Do not bake the exact same object into the floor image and also place it in the foreground. If the user should be able to hide/move an overhead object, leave the underlying floor complete. Derive placement from final image measurements, use its actual aspect ratio, and make the raster's center match the declared anchor. Verify alignment after rotating it.

Several placements may reuse the same asset path/hash. They still need unique object IDs. Imported objects appear as decorative foreground-layer actors; they do not grant player movement or ownership. The host can edit or hide them using layer controls. Explicit concealment masks and map cover continue to take priority over foreground display.

## 9. Party entry and map tabs

Give `entry_points` as 1–16 distinct **square centers**, on genuinely clear walkable floor. Prefer enough positions for the expected party, separated from closed walls and hazards. Four points in a 2 × 2 floor area are a reasonable default. The importer may search nearby clear square centers for additional heroes; do not rely on that to rescue an inaccessible start.

Importing the package adds a map to the current campaign and moves the currently deployed heroes from the prior active map to clear entry positions, preserving their identity and control grants. Stored heroes remain stored during ordinary import. Existing NPCs remain with their existing map. Do not define new player accounts, ownership policies, imported character sheets or financial balances in the map manifest; those belong to the campaign.

The host sees loaded maps as horizontal tabs. Left-click opens a map. Right-click a particular tab and choose **Bring all heroes here** to gather heroes, including stored heroes, onto that specific map. This action is host-only. Map names and editor controls are not shown to players while the map is covered.

From Beta 0.3.14, a successful import removes the unused default **New scene** tab. Stored tokens survive that cleanup. A starter board containing tokens, drawings or a custom name is retained as authored campaign content. The map context menu closes before changing scenes, and Escape or a click outside dismisses it.

## 10. Import, concealment and delivery behavior

The user imports the single `.hearth20map` through **+ Map** or the map-file picker. It installs the correct grid immediately, along with editable geometry, source-aware lights and foreground actors. It does not open the manual width-calibration prompt. Save the campaign afterward to persist all embedded assets and placements. Saving/reopening does not require the authoring folder to remain on disk.

The host's **Cover map** toggle is a campaign-wide cover. It stays active across tab switches, imports and hero transfers until the host explicitly reveals the map. A package cannot silently turn it off. A malformed package is rejected before the current campaign is changed. The importer creates no partially loaded map on failure.

Players see a thin gold progress indicator at the bottom of the map while an actual map transfer is underway: percentage/received bytes, then **Preparing map…** while the received scene is installed. First-time art, changed masked art or an evicted cached map can require download. Returning to recently received exact map/lighting data uses bounded caches rather than resending it. This avoids repeated large transfers but does not make an unseen map instantaneous or change the host's network connection speed.

If a package is rejected, fix the stated cause in the authoring folder and produce a new package. Do not ask the user to disable validation. Common causes include wrong image/grid aspect ratio, missing/stale image hash, a window light pointing along its wall, off-map foreground corners, duplicated IDs, unsupported ZIP compression and unreferenced thumbnail files.

Legacy fallback: a PNG may carry `Hearth20.Map` tEXt metadata for automatic **scale only**. That is supported for older simple imports, but it does not install walls/lights/foregrounds. JPEG/plain PNG without metadata still needs manual calibration. For this assignment, deliver `.hearth20map`; do not substitute the legacy PNG format or a `.hearth20map` file that is merely renamed JSON.

## 11. Required quality checks before handing over

Check the final picture and the final data together:

- Orthographic plan, consistent scale, connected routes, intentional bottlenecks and no accidental blocked entrance.
- Exact image/grid ratio; grid origin at the actual image corner; no decorative frame counted as playable cells.
- Every opaque wall aligned with art, door/window gaps split correctly, no pinhole leakage or duplicate full wall behind an aperture.
- Every light visibly motivated, correctly oriented, appropriately colored and bounded; explicit window IDs and plausible sill/opening heights.
- Afternoon/day/night behavior coherent with board north, roofs and room boundaries; flame and magic sources remain independent of the sun.
- Foregrounds transparent, registered to the map, separately removable, neither duplicated in the base nor floating off-map after rotation.
- Entry squares clear, centered and large enough for the party. Hero controls are preserved by the application rather than hardcoded in the package.
- Strict manifest fields, all unique IDs, exact hashes, local raster paths only, ZIP_STORED, no extra entries, limits respected.
- Packer completes successfully. If the game is available, import the actual package, inspect each relevant layer, cover/switch/reveal, move a hero, save/reopen, and verify foreground/lighting/scale persistence. Test a player window when possible.
- If runtime testing is unavailable, say so plainly. A successful packer/header check does not prove that a visual layout is attractive, every PNG decodes, a real Steam session transfers quickly or a user-specific encounter is balanced.

Useful game implementation references for an agent with source access:

```text
source/hearth20/map_package.gd      archive/manifest validation and atomic import
source/hearth20/map_metadata.gd     legacy PNG grid metadata
source/hearth20/contracts.gd        scene bounds, projection, masks and cover
source/hearth20/natural_light.gd    sun/moon and window projection
source/hearth20/lighting.gd         source types and wall-clipped light geometry
source/hearth20/token_inventory.gd  foreground bounds and clear party entries
tools/pack_hearth20map.py           standalone package builder
```

The kit's complete inn example is a working format/lighting reference, not a template that must be copied for every new setting. Build the user's requested location, take time to make its art cohesive, and return an actual playable package.
