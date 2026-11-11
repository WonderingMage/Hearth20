# Hearth20 custom map creation guide for ChatGPT agents

Version 1 · Hearth20 Seated Beta 0.3.12 · November 11, 2026

Give this entire document to an agent together with the user's map request. It is a practical authoring specification, an interchange-format reference and a quality checklist. Its defaults describe this Hearth20 fork; inspect the current source when working on a later version. The user's explicit instructions override artistic defaults here.

## 1. The assignment

Create a cohesive, attractive, playable battlemap tailored to the user's request. Deliver the actual image, not just a prompt. **Deliver the final map as a PNG with its grid size embedded inside that same PNG.** Hearth20 0.3.12 reads this record and sets its grid automatically, without asking the DM to enter the size.

Retain the user's original assets. Save new versions alongside them. Keep player-visible artwork free of secret room labels, trap markers, enemy placements and DM-only notes. Package a separate DM key when secrets are needed.

The minimum successful delivery is:

1. A finished, inspected top-down PNG with valid embedded grid metadata.
2. A short map key explaining dimensions, scale, entrances and important terrain.
3. A lighting/wall plan when the map needs dynamic lighting, with coordinates tied to the final image.
4. A validation record stating what was actually checked.

A map image with grid metadata imports automatically. **Walls, light sources, doors and props in a separate planning JSON do not automatically import with the PNG in this release.** Provide clear manual setup instructions, or build a validated campaign through the source APIs if source access is available and that work is authorized. Do not promise unsupported drag-and-drop scene packages.

## 2. Turn the user's idea into a brief

Extract the location, mood, intended encounter, party count, creature sizes, tactical features, entrances, desired scale, time of day and any reference art. Ask only about decisions that materially prevent a useful result. Otherwise state sensible assumptions and proceed.

Record a compact brief before image generation:

| Item | Suggested default when unspecified |
| --- | --- |
| Projection | Strict orthographic overhead, roof removed for interiors |
| Grid | Square; five feet per cell |
| Playable footprint | 32 columns × 24 rows |
| Final canvas | 2048 × 1536 pixels; 64 pixels per cell |
| Larger detailed canvas | 4096 × 3072; 128 pixels per cell |
| Grid lines in artwork | Omitted; Hearth20 draws its adjustable grid |
| Labels | Separate DM key |
| Visual style | Detailed fantasy cartography with readable paths and silhouettes |
| Light painting | Restrained local shading; major animated beams come from Hearth20 |
| Player start | A clear, safe entrance with room for the requested party |

These are authoring defaults, not engine requirements. A 40 × 30 map at 80 pixels per cell is 3200 × 2400. Choose a canvas that fits the design. Confirm generated dimensions from the file; image tools may return a different size from the prompt.

Do not confuse image pixels with grid cells. A 2048-pixel-wide image is not a 2048-cell map. A token of size 1 should occupy a believable five-foot square at the intended scale.

## 3. Design the geometry before the illustration

Plan room bounds, routes, doors, windows, cover and elevations in cell coordinates. Make an adjacency list and verify that required areas connect. Establish an intentional main route plus alternative movement or interaction opportunities where appropriate.

For a typical four-player encounter, give the starting area several open squares. A five-foot corridor is one cell wide; a ten-foot corridor is two. A five-foot doorway is one cell wide. A large creature generally needs a two-cell footprint. Furnishings should not accidentally close every route.

Reason through the location as a real place. An inn needs usable access to its kitchen and stores. A jail needs cells and a plausible guard route. Stairs need landings. A river needs consistent banks and crossings. Walls must connect; windows belong in walls. Drawn holes, bridges and walkways should be spatially unambiguous.

Put major wall faces on cell boundaries where practical. Allow thickness for masonry. Align straight furniture to the same orthographic plane. Use weathering and asymmetry to enrich surfaces without distorting the structural grid.

Set the coordinate convention once:

```text
Canvas top-left = cell (0, 0)
x increases to the right; y increases down the image
cell-space point = pixel-space point / cell_pixels
cell center for column c, row r = (c + 0.5, r + 0.5)
pixel center = ((c + 0.5) * cell_pixels, (r + 0.5) * cell_pixels)
physical distance in feet = cell distance * feet_per_cell
```

For a 2048 × 1536, 32 × 24 map, the center of column 7, row 10 is cell `(7.5, 10.5)` or pixel `(480, 672)`. A wall along the top of row 5 is at `y = 5`, not `5.5`.

## 4. Generate and refine the artwork

Use the available image-generation skill/tool for fantasy illustration and transparent foreground assets. Read its instructions first. Do not substitute a few colored rectangles for the requested finished artwork. If generation is unavailable, be honest and deliver the best authorized alternative without claiming it was generated.

A useful prompt structure is:

```text
Create a production-quality fantasy virtual-tabletop battlemap of [location].
Strict overhead orthographic view, no isometric perspective, no horizon.
Intended canvas [pixel width] × [pixel height], [columns] × [rows] square cells,
[feet] feet per cell. All architecture and objects share that scale.

Layout: [explicit room bounds, entrances, connections and landmarks].
Encounter needs: [open areas, cover, routes and creature footprints].
Materials and mood: [specific visual details appropriate to the request].
Lighting: [visible fixtures and natural openings]; keep strong directional
sunbeams and heavy fog out of the painted base because the VTT adds them.
No characters, tokens, UI, labels, numbers, logos, borders or baked grid lines.
Preserve clear walkable floor space. Keep walls, doors and windows coherent.
```

For image edits, explicitly preserve the accepted layout and change only the requested feature. Do not replace people's faces or change supplied character likenesses unless the user requests that change.

Inspect the actual output at full composition and at gameplay scale. Check doors, stair edges, paths, repeated furnishings, water flow and object scale. Generated art is not proof of geometric correctness. If a passage is only painted and not actually open, fix the art or the plan.

The final bitmap must match its declared grid. Use a suitable non-generative image-layout workflow for exact canvas sizing when authorized, or regenerate with a corrected layout. Do not stretch a square room into a rectangle. If padding or cropping changes the playable area, recompute coordinates and metadata afterward. A model's output resolution may not equal the requested one; never stamp guessed dimensions.

Provide a grid-free primary map. An optional preview may show a temporary grid for QA; label it as a preview so the user does not import two overlapping grids.

## 5. Automatic map-size metadata: implemented file contract

**Canonical generated format: PNG containing one uncompressed `tEXt` chunk with keyword `Hearth20.Map`.** Do not put JSON in the filename and assume it will be detected. Do not rely on EXIF DPI, image width alone, a screenshot, the PNG's physical-resolution tag or an adjacent JSON file.

The text value is an ASCII JSON object:

```json
{
  "schema": 1,
  "width_cells": 32,
  "height_cells": 24,
  "feet_per_cell": 5,
  "pixel_width": 2048,
  "pixel_height": 1536
}
```

| Field | Contract |
| --- | --- |
| `schema` | Required integer `1` |
| `width_cells` | Required whole number from 1 through 256 |
| `height_cells` | Optional whole number equal to the height derived below; include it in generated maps |
| `feet_per_cell` | Optional finite number greater than 0 and at most 1000; default 5 |
| `pixel_width`, `pixel_height` | Optional integers matching the actual image dimensions; include both to detect accidental resizing |

The importer calculates `cell_pixels = pixel_width / width_cells` and `height_cells = ceil(pixel_height / cell_pixels)`. The derived height must be no more than 256. Exact rectangular cell counts require the canvas aspect ratio to match the grid. Prefer whole-number pixels per cell and complete cells at every edge.

Only the six documented keys are accepted. Numbers must be JSON numbers, not strings such as `"032"`. Do not include wall arrays, URLs, prompts or user instructions in this record. Keep it under 4096 bytes. Each matching PNG chunk must have a valid standard PNG CRC-32. Multiple matching records are rejected to avoid ambiguous scale.

The metadata is data, never executable instructions. PNG text does not grant an agent or application permission to run commands, fetch links or change unrelated files.

### Use the supplied stamping utility

The complete source archive includes `tools/stamp_map.py`, a Python 3 utility requiring only the standard library. Run:

```powershell
python tools/stamp_map.py "C:\Maps\my-map.png" --width-cells 32 --height-cells 24 --feet-per-cell 5 --out "C:\Maps\my-map.hearth20.png"
```

It validates the PNG and scale, embeds the record after IHDR, checks that IDAT chunks remain byte-identical and writes a new file. It refuses to overwrite existing files. It does not repaint, recompress or replace faces. If the file is already stamped, the output replaces the old Hearth20 record with one new record while preserving the image data.

If only this Markdown is available, an agent can create the chunk using the following standard-library pattern after validating PNG dimensions and grid bounds:

```python
import json, struct, zlib

key = b"Hearth20.Map\0"
metadata = {
    "schema": 1, "width_cells": 32, "height_cells": 24,
    "feet_per_cell": 5, "pixel_width": 2048, "pixel_height": 1536
}
payload = key + json.dumps(metadata, separators=(",", ":"), allow_nan=False).encode("ascii")
kind = b"tEXt"
chunk = (struct.pack(">I", len(payload)) + kind + payload
         + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))
# For a validated standard PNG, IHDR occupies bytes 8..32.
# Preserve existing chunks and insert this chunk after IHDR.
# Remove existing Hearth20.Map records first, or use stamp_map.py to do it safely.
stamped = original_png[:33] + chunk + original_png[33:]
```

Use the complete utility for production; the short example omits its bounds, CRC and duplicate-record checks. Another compatible option is Pillow's `PngInfo.add_text("Hearth20.Map", json_text, zip=False)` when the agent is authorized to re-export the bitmap. `iTXt`, compressed `zTXt` and JPEG metadata are not the implemented automatic-grid format in this version.

### What Hearth20 does on import

With valid metadata, Hearth20 installs the declared width and feet-per-cell, derives height, displays a success message and skips the calibration popup. That scale is stored with the campaign and shared with players.

Without the record, PNG/JPEG maps use the bounded manual dialog. Invalid, stale, duplicate or corrupt Hearth20 metadata rejects the import with an explanation; it does not silently guess the scale or alter the current map. Remove or regenerate the metadata to recover. Image editors and messaging services can strip text chunks, so distribute the original stamped PNG as a file or ZIP attachment. Stamp again after resizing or cropping.

## 6. Derive lighting from the final art

Inspect the final pixels before placing sources. Do not place light only from the generation prompt: the output may have moved a window or fireplace. Make a fixture table with ID, pixel position, converted cell position, source type, color, bright range, additional dim range, direction, aperture and rationale.

Supported `source_type` values are `torch`, `brazier`, `window`, `sunlight`, `moonlight` and `crystal`. Use the closest actual type; inventing `spotlight` or `area_light` fields will not create an engine feature.

Point sources should sit in the visible flame/crystal area. Offset wall-mounted lights slightly into the accessible room so a source is not exactly inside its own occluder. Use warm amber for fire, a source-appropriate crystal tint, comfortable warm sunlight and softer blue moonlight. Keep ranges proportionate to the space. Do not illuminate through intact masonry.

The bright and dim fields are distances **in feet**. For a light with `bright: 20` and `dim: 20`, the outer range is 40 feet, not 20 feet. Positions are in grid cells. `angle_degrees` uses screen-space angles: 0 points right, 90 down, 180 left and -90 up. `spread_degrees` is the full cone width, not a half angle. Use 360 for an omnidirectional fixture.

Suggested starting values, to be visually adjusted:

| Fixture | Bright / additional dim | Tint | Rays |
| --- | --- | --- | --- |
| Wall torch | 20 / 20 ft | `#ffc77d` | 0.35–0.55 |
| Hearth or brazier | 20 / 20 ft | `#ffd397` | 0.45–0.65 |
| Small magic crystal | 10 / 15 ft | choose from the art | 0.25–0.50 |
| Window | Natural-light-controlled | `#fff0bb` as fallback | 0.50–0.80 |

These are visual starting points, not an assertion of official rules for every item. Follow the user's requested game mechanics where specified.

### Windows and projected sunlight

A window needs both a `window` segment defining the aperture and a separate `light` annotation with `source_type: "window"`, near that aperture and directed inward. Break the surrounding wall at the opening; a continuous duplicate wall across it will block the light.

The natural-light code pairs a window light with the nearest window annotation within 1.5 cells. Its segment determines aperture width. The light direction selects which perpendicular points into the room. Prefer one light per window and avoid ambiguous equally near windows.

`window_height` and `sill_height` are in feet. For altitude α, the projected near edge is approximately `sill_height / tan(α)` and the far edge is `(sill_height + window_height) / tan(α)`. Hearth20 converts these distances to cells and clips rays against walls. Low sun makes a longer cast; high sun shortens it. Face the wrong way and direct sun should diminish. Use diffuse fill to keep a plausible room rather than painting a giant uniform yellow circle.

Do not bake a strong afternoon beam into the base art and then promise that moving the time slider will rotate it. Painted shadows remain fixed. Prefer neutral static shading and live projection for time-dependent features.

### Time, north and rendering limits

Natural-light settings supported by the current source are:

```json
{
  "time_hours": 16.5,
  "north_degrees": 0,
  "sun_intensity": 1,
  "moon_intensity": 0.35,
  "haze": 0.32,
  "exposure": 1
}
```

Time ranges from 0 to 24, north from 0 to 360 degrees, intensities/exposure from 0 to 3 and haze from 0 to 1. Zero board north means north points toward the top of the image. Verify the effect of rotation in the running app rather than compensating twice by rotating both geometry and north.

This is an artistic equinox sky approximation with a maximum solar altitude of 65 degrees. Latitude, season, weather simulation and lunar phase are not authored fields. The board uses occluded 2D light geometry, filtered penumbrae and a height-integrated scattering shader; it is not a full physically traced 3D building.

In 0.3.12, parallel outdoor sunlight and special roof rectangles are keyed to specific built-in `library_id` values in `natural_light.gd`. An arbitrary new custom map does not gain that behavior merely by declaring `source_type: "sunlight"`. For a custom outdoor map, use the supported ambient/local-light behavior, or implement explicit generic outdoor/roof support as a separately tested source change. Do not reuse another map's ID to activate unrelated roof masks.

## 7. Walls, doors, roofs and foregrounds

Trace structural wall faces in cell coordinates against the final image. Use joined endpoints and intentional gaps. Avoid self-intersections, zero-length segments and needless tiny segments. Prefer a few accurate segments over tracing every brick.

Closed doors block light; open doors do not. A door occupies the opening in the wall, not a second segment laid over an intact wall. Confirm its hinge-side appearance in the image. Window segments represent apertures; a window light is separate from the window annotation.

A sample library-style door is:

```json
{"id":"door-entry","a":{"x":14,"y":19},"b":{"x":16,"y":19},"open":true,"hidden":false}
```

A wall record is:

```json
{"a":{"x":4,"y":3},"b":{"x":12,"y":3},"hidden":true}
```

`hidden` on a wall controls its representation; it does not make the wall stop blocking light. Keep semantic DM secrets in DM-only data rather than relying on a player's inability to notice a painted mark.

Foreground items should be separate transparent PNGs only when separation has a purpose: removable tree canopies, a chandelier or movable cover. Use the image tool's real transparent-background mode for cutouts. Do not flatten a black or checkerboard background into a purported transparent prop.

Avoid painting the same canopy into the base and then placing an identical foreground on top. Record anchor position, intended cell footprint, layer and whether it affects movement or light. A decorative foreground image does not automatically generate a collider or wall occluder.

Hearth20 layers are `map`, `tokens`, `gm`, `foreground` and `light`. GM-only information must stay in the `gm` layer or other validated private fields. A normal player pawn starts at size 1 and is centered on a cell. Ownership and movement permissions remain DM-controlled; map generation must not assign real player access or import account data.

## 8. Scene data examples and integration

The following is an **authoring manifest**, not an automatically importable PNG payload. It mirrors relevant Hearth20 scene fields and can guide manual setup or a source-side adapter:

```json
{
  "id":"custom-amber-sanctum",
  "title":"Amber Sanctum",
  "width_cells":32,"height_cells":24,"cell_pixels":64,"feet_per_cell":5,
  "grid_visible":true,"grid_opacity":0.34,"grid_thickness":1,"grid_color":"#d8c99e",
  "snap_to_grid":true,"map_asset":"",
  "dynamic_lighting":true,"ambient_light":"dark","blackout":false,
  "natural_light":{"time_hours":16.5,"north_degrees":0,"sun_intensity":1,"moon_intensity":0.35,"haze":0.32,"exposure":1},
  "walls":[{"a":{"x":4,"y":3},"b":{"x":12,"y":3},"hidden":true}],
  "doors":[],
  "annotations":[
    {"id":"window-west","owner":"dm-local","kind":"window","layer":"light","points":[{"x":4,"y":7},{"x":4,"y":9}],"color":"#97c9d3","open":false},
    {"id":"window-west-light","owner":"dm-local","kind":"light","layer":"light","points":[{"x":4.1,"y":8}],"enabled":true,"bright":35,"dim":20,"light_color":"#fff0bb","source_type":"window","angle_degrees":0,"spread_degrees":24,"ray_strength":0.7,"window_height":7,"sill_height":3},
    {"id":"hearth-light","owner":"dm-local","kind":"light","layer":"light","points":[{"x":25.5,"y":5.5}],"enabled":true,"bright":20,"dim":20,"light_color":"#ffc77d","source_type":"brazier","angle_degrees":0,"spread_degrees":360,"ray_strength":0.5}
  ],
  "props":[],"fx":[],"fog_rects":[]
}
```

This abbreviated geometry demonstrates fields; it does not form a complete room. Build complete geometry for the actual map. Every point must be inside its scene. Scene IDs, annotation IDs and owner IDs must be valid identifiers; use stable lowercase slugs beginning with a letter.

JSON points are `{ "x": number, "y": number }`. Runtime annotation points must become Godot `Vector2` values before `Hearth20BoardTools.valid_object` or `Hearth20Contracts.valid_scene` checks them. The map-library loader performs that conversion for its own files; generic JSON parsing does not. Scene door arrays are converted to editable door annotations by that loader. Do not add both representations, which would produce duplicate occluders.

There are two light schemas. Editable annotation lights use `points`, `bright` and `dim`. The older scene `lights` array uses `position`, `bright_feet` and `dim_feet`. Choose one for each fixture; do not duplicate a source in both arrays.

### Portable-only workflow

1. Deliver the stamped PNG and separate setup key/manifest.
2. The DM opens the map importer and chooses the stamped PNG.
3. Confirm the success message reports the expected columns, rows and feet per cell, with no size popup.
4. Enable dynamic lighting if wanted. Place walls, door/window segments and source lights using the map's tools, following the coordinate key.
5. Set time, north, intensity and grid readability. Check the player view and save through Campaign Vault.

The default library's offline recipe editor has a bounded schema for rooms, corridors and a small list of props. It is not a general renderer for arbitrary scenery JSON and does not attach arbitrary image/light packages. Do not paste the authoring manifest above into that recipe editor.

### Source-aware workflow

The active project is `Forks/Hearth20-Seated/source`. The canonical original and Hearth20-Beyond checkpoints are separate and must remain untouched. Consult `AGENTS.md` before changes. Relevant source files are:

| Source path relative to project | Responsibility |
| --- | --- |
| `hearth20/map_metadata.gd` | PNG metadata detection, CRC and scale validation |
| `hearth20/assets.gd` | Bounded image inspection and asset storage |
| `hearth20/board_canvas.gd` | Map import, calibration and board rendering |
| `hearth20/app.gd` | Import status and manual calibration UI |
| `hearth20/contracts.gd` | Scene/campaign validation and player projection |
| `hearth20/board_tools.gd` | Editable annotations and layers |
| `hearth20/map_library.gd` | Built-in scene loading and asset installation |
| `hearth20/sample_maps/catalog.json` | Built-in map metadata |
| `hearth20/sample_maps/lantern-larch-inn.json` | Working window/hearth/door example |
| `hearth20/natural_light.gd` | Time/north, window projection and outdoor behavior |
| `hearth20/lighting.gd`, `hearth20/soft_light.gd` | Occlusion, source geometry and rendering |
| `hearth20/vision.gd` | Common environmental visibility and clipping |
| `hearth20/identity.gd` | Campaign identity, encoding, save and load |

For a custom prepared campaign, start from `Hearth20Identity.new_campaign`, use `Hearth20Assets.inspect_map_file`/`store_asset` or `board.import_map`, normalize vectors, validate with `Hearth20Contracts.validate_campaign`, and save using `Hearth20Identity.save_campaign`. This API accepts paths only under `Hearth20Identity.SAVE_ROOT` (`user://hearth20/campaigns`); use an isolated authoring profile and a unique filename. Load it back and check it before copying an export to the delivery folder. The portable's Campaign Vault reads its own AppData campaign directory; a recipient must place the exported campaign there while the game is closed, keeping a backup and avoiding name collisions. Do not hand-write a file with a `.h20scampaign` extension and assume it matches the serializer. Never overwrite a user's active campaign to create an example.

Bundled-library changes require deliberate source work. Currently the catalog loader requires exactly 15 entries and bundled art is checked as 2048 × 1536. Boot also preloads catalog thumbnails; scenery uses a separate lookup. Simply dropping a sixteenth file into the folder will not add a library entry. If asked to extend the library, remove the fixed-count assumption safely, handle dimensions deliberately and test the library, thumbnail loading, saves and player projection. Keep IDs unique and preserve existing maps.

This fork uses common environmental lighting. Character-sheet darkvision is not the current player-visibility authority. Do not resurrect token-specific darkvision/import requirements as part of map creation. Preserve full-map cover, explicit masks, private sheets and GM-secret filtering.

## 9. Limits and performance budgets

| Limit | Current behavior |
| --- | --- |
| Imported PNG/JPEG file | At most 40 MiB |
| Image side | At most 16,384 pixels |
| Total map pixels | At most 67,108,864 |
| Scene grid | 1–256 cells on each axis |
| PNG grid text | At most 4096 bytes; one `Hearth20.Map` record |
| Annotation objects | At most 256 per scene |
| Walls/doors/props/fog/FX collections | At most 512 entries in each applicable collection |
| Legacy scene lights / templates | At most 128 each |
| Campaign scenes / actors | At most 256 / 2000 |
| Encoded campaign save | At most 64 MiB |
| Foreground/token PNG | At most 8 MiB, 2048 per side, 4,194,304 pixels |

These ceilings are validation limits, not recommended design targets. Use a manageable number of lights and occluders. The current point-light mesh path considers the first 32 point sources; do not build a scene assuming all 128 are equally cheap or fully rendered. Prefer a few visually important fixtures and restrained fill.

Use thumbnails for browsing. Avoid huge transparent margins around props. Keep a playable map's detail readable at normal zoom. Strong blur, too much haze or bright bloom can hide tokens and grid lines. Test grid opacity/thickness on both light and dark floors. Hidden scenes and unused 3D work should not keep rendering.

The project's stated target is GTX 1060 / i5-8500 with at least 30 FPS at the 1% low. That target is not yet certified. Do not claim a custom map meets it without measurements on comparable hardware. Report test machine, resolution, map, player count, frame-time sampling method and results when benchmarking.

## 10. Verification before handoff

Run the checks you can actually perform and state any limits. At minimum:

- Read final width, height and file size from disk. Confirm square-cell pitch and metadata math.
- Reopen the final PNG and parse its `Hearth20.Map` record. Verify CRC, one record, numeric fields and matching pixel dimensions.
- Confirm that stamping preserved the IDAT bytes and did not change the artwork.
- Inspect the full image and close-ups of doors, stairs, windows, intersections and repeated props.
- Overlay a temporary grid in a preview or use Hearth20's grid. Check multiple distant landmarks, not just one room.
- Import the exact delivered PNG into the target version. Check automatic scale, centered size-one tokens and a measured known distance.
- Test an ordinary unstamped map still gets the manual dialog. Confirm Apply, Cancel and Close remain reachable on a small window.
- If lighting is included, test closed/open doors, source visibility, wall leaks, blocked windows, morning/noon/evening/night and rotated board north.
- Check shared player visibility with masks and cover, and ensure private notes never appear in player art or payloads.
- Save, reopen and verify scale, lights and annotations. If multiplayer was tested, verify those values on a client too.

Source test commands, from the seated fork root, include:

```powershell
python tools/run_source_check.py import
python tools/run_source_check.py map_metadata --headless
python tools/run_source_check.py title_menu
```

`map_metadata` tests missing/valid/bad/duplicate/oversized records, checksums and image compatibility. `title_menu` tests the actual import UI, automatic grid installation and campaign persistence as well as the menu. Use isolated test profiles; do not log in to real accounts or control Steam for map QA without authorization.

If an agent can generate images but cannot run Hearth20, deliver the stamped file, measured metadata, visual inspection and a clearly labeled in-app test still needed. Do not invent screenshots or test results.

## 11. Delivery structure and reusable handoff prompt

Recommended files:

```text
map-slug/
  map-slug.hearth20.png       # Final image, embedded size, player-safe
  map-slug-preview.png       # Optional, clearly labeled grid preview
  map-slug-map-key.md         # User instructions and separate DM secrets
  map-slug-scene-plan.json    # Optional coordinate/lighting plan, not auto-imported
  foreground/                # Optional transparent items
  provenance.md              # Asset sources/licenses, prompts and edit history
  validation.md              # Actual checks, version and unresolved limits
```

Keep licensing/provenance for external assets. Record the image tool and final prompt. Preserve rejected drafts separately from the delivery. Do not include personal photos, browser data, credentials or unrelated campaign files.

The user can give a future agent this prompt together with this document:

> Use the attached Hearth20 custom map guide to create a map for: **[my request]**. Choose a coherent layout and sensible scale, use high-quality artwork, inspect it, and deliver a PNG with valid embedded `Hearth20.Map` size metadata so Hearth20 0.3.12+ imports it automatically. Include a map key and a lighting/wall plan tied to the final image. Preserve my supplied art and character appearances unless I request edits. Complete all verification available to you and state any in-app checks you could not perform.
