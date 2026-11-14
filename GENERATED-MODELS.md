# Generated room and prop integration — November 14, 2026

Active project: `source/project.godot`. These runtime assets are included in the verified Beta 0.3.20 release, together with the corrected camera-relative drinking animation.

## What is in use

The user's room is the front backdrop. It is a textured image-depth mesh, not a Gaussian splat or a complete 360-degree scan. The original photo and image-space UVs remain intact. Matching closed geometry, the supplied modular kits and generated furnishings finish the rear, sides, ceiling and floor. Projected backfill covers holes in the front reconstruction. This arrangement is for a seated camera with head rotation, not free walking through a reconstructed room.

The generated main table, map frame, physical snack menu/side table, ceiling openings, map/casino handles, candles, goblet, pouch, coins, dice cups, race board, plates, bite pieces and room furniture replace their provisional static equivalents. The rejected `map_paper` model is neither loaded nor displayed; the original procedural curled parchment is restored, including its private browser thumbnail and markings. The menu, map and sheet keep their existing interactions. The book, braided ropes, live map/sheet content, special casino dice and actual rigged lizard remain their working interactive implementations.

Thirty-six catalog entries are active: 33 GLBs plus three kits. `map_paper.glb`, `mug.glb` and `ComfyUI_00056.glb` stay prepared but unused. The existing beer/drink models remain tied to the serving system; dynamically rendered card faces remain separate. The manifest records all 39 entries and their original hashes.

## Geometry and textures

| Asset | Delivered triangles | Runtime triangles | Change |
|---|---:|---:|---:|
| Room | 4,565,514 | 282,454 | 93.8% fewer; sampled image grid, same image/UVs |
| Main table | 149,994 | 54,144 | 63.9% fewer; Godot mesh simplification, preserved attributes |
| Map parchment (inactive) | 1,974 | 842 | Original procedural parchment is used instead |
| Map frame | 1,998 | 1,756 | Removed disconnected rear stand |
| Race board | 10,000 | 8,632 | Removed detached underside fragment |
| Potato chip | 2,000 | 1,764 | Removed detached crumb |
| Bar | 10,000 | 9,063 | Removed fused material below the structural base and a detached loop |
| Wooden chip | 496 | 238 | Removed fused loop under its flat body |
| Complete prepared catalog | — | 473,911 | Includes inactive entries and four stone-wall variants |

Most smaller objects already have 500–10,000 triangles, so further aggressive decimation would damage their silhouettes for little benefit. Runtime textures are mipmapped S3TC blocks, capped at 1024 pixels on smaller props and 2048 on the room/table/map/menu surfaces. Base color, normals and packed PBR channels are retained. The catalog declares 152,559,848 bytes of compressed texture data (about 145.5 MiB); this is not total application VRAM. Instances share prepared scenes/textures and cached finish materials. Static models have no skeletons or animation processing. Existing camera culling and hidden map/3D/soul-pass suspension remain enabled.

Detached components were identified from welded mesh connectivity and removed only from the specified copies. Bar/chip fused underside artifacts were also trimmed to their structural base before fitting. `level_generated_props.py` fits the actual lower contact plane on 23 grounded/framed assets, instead of assuming whole-body PCA represents a flat base. It records measured normals and rigid correction matrices; all measured contact normals are within one degree of up. Hanging handles, crests, organic bite pieces and the camera-space room retain their reviewed mounting orientations. Godot uses Y up and the XZ ground plane. The authored beam X is rotated to upright Y before fitting. Bar/cabinet decorations are now seated with downward triangle intersections against the actual counter mesh; the earlier floating support caps are removed.

## Reproduce asset preparation

Use the bundled Python runtime with NumPy and Pillow, and Godot 4.5.1. Run from this fork. No step writes into the original `generated models` folder.

1. `python tools/inventory_generated_models.py` inventories the GLBs and safely extracts the three supplied licensed kits into `qa/generated-models/kit_*`.
2. `python tools/reduce_generated_room.py` generates `qa/generated-models/room-reduced.glb` and its reduction/projection report.
3. `python tools/clean_generated_props.py` produces cleaned copies and `poses.json`.
   Then run `python tools/level_generated_props.py` to fit contact planes. Its stored original orientation makes repeated leveling idempotent. Optional `tools/preview_model_alignment.gd` plus `tools/model_alignment_gallery.py` generates front/side ground-grid inspection sheets in `qa/generated-models/alignment`.
4. Run Godot headlessly with `--path source --script tools/prepare_generated_models.gd -- <absolute qa/generated-models path>`. Use the absolute script path when needed by Godot. Optional trailing IDs reprepare selected assets; the complete pose/projection metadata is merged afterward.
5. `python tools/run_source_check.py import` refreshes Godot classes/imports.
6. `python tools/run_source_check.py generated_models --headless` checks actual scene contents, triangles, UVs, mipmapped block compression, dimensions and bottom-center pivots.
7. `python tools/run_source_check.py seated_visual` checks enclosure rays, actual imported models, picking, rope movement, table switching, book and focus restoration.
8. `python tools/run_source_check.py generated_scene` opens an isolated self-closing native fixture, verifies changed props and records six short rendering measurements plus screenshots. It never signs into Steam or a browser.

The scripts currently target the delivered filenames and layout. Re-run preparation and visual checks when replacing them; the engine does not import arbitrary untrusted GLBs at runtime. The catalog is bundled trusted content. The original inventory and QA logs are evidence, not runtime dependencies. Prepared `.scn` files, `manifest.json` and `CREDITS.md` are runtime dependencies.

## Verification and limits

Evidence lives under `qa/source-checks/{generated_models,generated_scene,seated_visual,render_budget,refreshment_visual}`. `generated_scene/result.json` labels the actual hardware, source build, window size, uncapped/vsync-off settings and warm-load timing; each scenario samples eight seconds after two seconds of settling. It is a short local diagnostic, not a GTX 1060/i5-8500 certification, end-to-end campaign benchmark or comparison against the original room at identical settings. Preserve that distinction when reporting results.

The current paper/alignment proof is `qa/generated-models/verified.json`: 721 passing assertions across the asset contract, native seated interactions and changed serving props. All 23 measured base normals are within one degree of up, and every fitted rotation remains orthonormal with determinant +1. All 32 active generated props were reviewed from front/side views on a ground grid. The seated test confirms the rejected paper is absent and all eleven counter decorations hit their actual support meshes.

The additional native static-prop/performance fixture deliberately omits casino transactions and soul-die effects; real map/casino transitions remain covered by `seated_visual`. Every sampled performance row records the actual frame cap, using the existing performance override so background throttling cannot silently cap a sample at 30 FPS. Its functional assertions pass, but its shutdown reports retained RefCounted instances. This warning and the separate soul-render-budget shutdown warning remain recorded diagnostics, not clean release-gate evidence. No new portable was built. Performance results are short source diagnostics with warm filesystem caches, not cold startup or target-hardware measurements.

The report records exact logs/source hashes, all 36 original GLBs and three ZIPs, and 696 unchanged Original/Beyond source-checkpoint files. The earlier integration pass had 842 assertions across eight suites. No soul runtime code was changed during this alignment pass.

Source originals remain untouched. CC BY credits and modification notes are bundled in `source/hearth20/generated_models/CREDITS.md` and exposed through the title menu's Scene credits dialog. Original/Beyond source checkpoints are preserved. Live multiplayer, account login and publishing are separate from this asset pass.
