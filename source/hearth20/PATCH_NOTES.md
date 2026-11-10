# Hearth20 source milestone 0.1.0-dev

This uncommitted candidate adds an independent Hearth20 identity and a real top-down 2D board to the separate `edition/hearth20` checkout. The default project remains on the inert development gate; the Hearth20 scene was launched explicitly with disposable user data.

## 2026-11-02: 0.5 living FX, returning players and creature loading

- Eleven FX materials now differ in geometry and motion as well as color. Instant effects place at left-button release with no trajectory; casts keep their source/target line.
- New tokens belong to the DM. The Tokens side button supports placement, appearance and specific-player grants. Display names are explicit and remembered; signed local identities restore saved campaign grants across fresh launches. Same-name or copied-public-key attempts do not inherit permissions.
- Grid opacity, screen-pixel thickness and tint are adjustable per scene and shared with players.
- Original startup artwork replaces the engine splash. A lightweight title menu renders before the selected creature begins loading in a background request. The viewer supports orbit, lift, zoom and 200 tailored notes across twenty 5e creatures. Only one model request runs at a time.
- Nineteen owner-supplied glTF models replace their provisional sculptures, including Gelatinous Cube, with embedded textures and looping pose animations where supplied. Gibbering 2 receives a procedural mottled flesh/vein material. Skeleton is a looping video showcase with the original audio, pause/replay/mute/volume controls, and preserved aspect. Artist credits are available from the title menu. A ZIP/GLB replacement tool preserves IDs and tips for future swaps.
- A true debug portable enables Loading Lab (F6), with all twenty showcases, direct selection of 200 notes and an indefinitely held loading preview. Its data uses a separate Hearth20-Debug directory.
- Network protocol is 4; campaign schema remains 1. Older anonymous grants require one assignment to the new saved identity. Source changes preserve the inert launch gate and existing campaigns.

See [table controls](../docs/hearth20-05-table-controls.md) and [model slots/import workflow](../docs/hearth20-model-replacements.md).

## 2026-11-02: 0.4 regal maps and light

- Fifteen detailed generated overhead maps, calibrated five-foot grids, searchable gallery, live lighting preview and campaign scene switching. All art stays inside saved campaigns. Foreground canopy and chandelier assets fade over tokens.
- Black-and-gold and warm beige-and-gold themes, a saved rosette theme switch, ornamented controls and consistent contrast across native panels.
- Soft radiance, atmospheric scattering, source-aware torch/crystal/brazier lighting, finite rectangular window casts, finite outdoor shadows and warm sun / cool moon. DM compass, midnight-to-midnight time slider and independent sky intensities control natural light.
- Richer GPU FX with volume noise, generated flame/smoke textures, sparks, shockwaves, plasma, shield lattices and a looping local inspector preview. Existing authority, bounded lifetimes and reduced motion remain.
- Cached conservative visibility masks and compressed authorized radiance fields accelerate live multiplayer lighting changes. Private geometry and emitter coordinates stay on the host. Network protocol is 3; campaign schema remains 1.

Controls, the fifteen-map inventory, generation prompts and the 2.5D rendering scope are in the [map and lighting guide](../docs/hearth20-regal-lighting-and-maps.md). Exact native and packaged QA evidence belongs in the accompanying build report.

## 2026-11-01: player table and vision package

- Sheet, Chat and Journal are available in a collapsible sidebar, with preparation tools in a secondary Workspace. S/C/J shortcuts, visible focus, readable save/skill buttons, unread chat counts and a bottom-anchored chat composer support play without leaving the map.
- Assigned sheets remain available off-board and during blackout. Six abilities and saves, all 18 skills, initiative and bounded custom dice use the host's recorded modifiers. Advantage/disadvantage retains both d20s. Public rolls show the table who rolled, the formula, dice and result; Me + DM rolls and messages are filtered before other players' snapshots. Dice never apply damage, conditions, resource spending or turn order.
- The DM can edit basic statistics and save/skill records, choose bright/dim/dark ambient lighting, configure vision/darkvision and carried light, cover/reveal the table, and open a read-only preview of a connected player's actual projected view. A 60 ft darkvision range sees unlit space within that range; ordinary sight requires illumination. Walls and closed doors occlude sight. A torch can illuminate 20 ft brightly plus another 20 ft dimly for the party.
- Maps are redacted before transmission for each owner. Darkvision-only map pixels are grayscale. Unseen actors, assets, geometry, FX and measured areas are withheld. Blackout sends an empty fixed-size board while preserving owned sheets and permitted communication. Short-wall shadows use conservative convex sight-region checks. Concealed NPC light sources do not disclose their locations.
- Added a standalone calibrated ruler, persistent DM circle/rectangle/cone/line areas with individual deletion and removal undo, and visibility-scoped Shift-click pings. Closely spaced token nameplates use collision-aware offsets and connecting lines. Pan/zoom remains stable during sight refreshes and sidebar resizing.
- The DM can publish or withhold text handouts and keep private session notes. History is bounded to 200 entries. `/r`, `/roll`, `/gmroll` and `/w gm` provide bounded shortcuts. Reconnect clears the old local board, sheets, chat, handouts and assets; fresh host-owned player identities prevent a later join from inheriting private history.
- Added a repeatable native QA command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test_h20_tabletop.ps1 -Rendered`. It copies a bounded project into a fresh Reports directory, proves disposable Hearth20 data, retains source hashes/raw logs, and runs DM/two-player captures plus hostile-request/privacy checks. It never stages, commits, publishes or changes Lite data.

The current package has native Windows rendered and local ENet evidence; the final exact-source checks are recorded in the private cycle checkpoint. The previous map-workspace notes below are historical. This is a review preview, not complete Roll20 parity or owner product acceptance.

Final frozen-source results: 90 contract, 42 tabletop and 29 native UI assertions pass, with all 24 rendered DM/two-player audit checks passing. The new isolated Windows development preview also passes compiled startup and the 29 UI checks against its packaged runtime. Checks use synthetic disposable data and scripted controls; physical input/audio and external internet play remain untested.

The owner subsequently requested a single portable build and a stop after packaging. `tools/build_h20_portable.ps1` packages this same runtime into `Hearth20_Portable.exe` with embedded application resources and a stable separate Hearth20 AppData directory. Only the EXE is placed in the delivery folder; provenance and QA stay in Reports. This packaging step adds no gameplay features and does not publish or resume development cycles.

Remaining work includes full inherited Lite PDF review and advanced action/homebrew/DM-outcome integration, manual turn tracker, multi-page/layer editing, richer fog editing, smooth lighting/exploration memory and special senses, targeted whispers and richer dice/macros, rollable tables, decks, compendium, audio/video, production token art and broader FX. The researched inventory and evidence distinctions are in [the Roll20 feature ledger](../docs/hearth20-roll20-parity.md); [the player experience contract](../docs/hearth20-player-experience.md) explains implemented behavior and limits.

## Earlier 2026-11-01: map workspace review slice

- Replaced the overflowing toolbar with a compact header, explicit tool modes, generous top-down canvas, collapsible inspector and focused Scene, Token, Session and Recipe panels. Added a calm dark theme, bounded status footer, import onboarding, pointer-centered zoom, fit, Space/middle pan and Escape cancellation.
- Map imports retain their GPU texture across redraws. Square-grid visibility and snapping have explicit states; whole-image width calibration and fine scale remain available. Border/offset anchors, hex grids and a full guided alignment workflow remain pending.
- Selected PC/NPC controls show a nearest-filtered PNG preview and bounded name, size and position edits. New NPCs start concealed; the DM explicitly reveals/conceals them. PNG appearance remains cosmetic and embedded in the campaign.
- Recipe drafting uses narrative text first, with JSON behind optional Advanced controls. Unresolved terms remain visible and require acknowledgment. Offline prior-scene recovery is revision-gated and does not rewind actor rules or movement grants; general undo/redo is still missing.
- Player mode hides DM editors and describes its limited map/movement scope. Active sessions block campaign replacement and another host; Leave/End table is explicit. Routine snapshots preserve the player's camera.

This is a reviewed source/UI prototype milestone, with native single-process viewport captures and independent regression evidence under `Reports/h20-map-workspace-20261101`. The checkpoint records exact hashes, worker decisions and counts. It is not owner product acceptance or a pass of the full native DM/two-player scenarios. Earlier headless network evidence remains tied to its recorded source hash. No new portable executable, installer, update or release was prepared.

The full roadmap remains open: Lite sheets/PDF review/homebrew/private rolls and DM outcomes are not available end to end; calibration anchors, multi-select, complete editable layers, ruler/templates, lighting, journals, turns/chat/pins and wider FX remain incomplete. Official public documentation was refreshed and the feature evidence ledger expanded in `docs/hearth20-roll20-parity.md`. No full Roll20 or effects parity is claimed.

## Earlier baseline included

- Separate Hearth20 campaign, save, network, and update identity, with a small adapter boundary to Lite rules data. No Lite autoload or classic/Lite product configuration was added.
- Top-down map canvas, map import and grid calibration, per-actor PNG override storage, DM placement, and host-enforced player movement policies and grants.
- Allowlisted per-player snapshots with fog-masked map pixels and concealed actors, assets, geometry, and effects removed before projection.
- One original layered fire rocket and impact effect, isolated from gameplay state.
- Bounded, offline scene recipes with editable data and unresolved prompt terms shown for DM review.
- Creature coverage manifest reconciled against the pinned 334-entry Lite catalog: 334 missing art entries, no finished creature sprites counted. The concept atlas is not treated as production art.
- A limited comparison against current public Roll20 documentation in `docs/hearth20-roll20-parity.md`; no all-effects parity claim.

## Earlier verification (2026-10-31)

Godot 4.5.1 Windows console checks ran on the frozen copy and disposable profiles in `C:\Users\fstre\Desktop\Hearth20 Development\Reports\independent-final4-20261031`:

- Editor import and explicit `hearth20_main.tscn` startup: exit 0.
- GDScript contract suite: 90 assertions, 0 failures.
- PNG, fog, asset, and FX projection audit: 16 passed, 0 failed. Synthetic 126-byte PNG round-tripped with SHA-256 `a7112864883b79879f2a16ec61f7b617e2beefaee0bf785fdc3cfba358c8de92`.
- Separate headless Windows host and two-player ENet processes: host 7/7, Player A 28/28, Player B 28/28; all exited 0.

The host logged two leaked CanvasItem RIDs, ObjectDB instances leaked, and one resource still in use at shutdown. Player stderr was empty. These headless checks do not satisfy the native rendered acceptance plan: no rendered UI, screenshots, RPC-boundary trace, external multiplayer, or measured grid/FX alignment was tested.

## Development preview export

The earlier `Hearth20_Development_Preview.exe` remains in Builds and contains the older UI. Its manifest records source, toolchain and executable hashes. This cycle inspected that existing pack through native Godot and saved a before capture; final source was rendered from an isolated Reports project. The old EXE was not replaced. A new portable/release build remains gated by the broader native acceptance plan and baseline record.

## Earlier baseline gaps (superseded by the package above where applicable)

The visible app does not yet demonstrate Lite's full sheets, PDF review/import, homebrew, private rolls, campaign workflows, or DM outcome controls. Those flows are not claimed as end-to-end preserved. Scene editing and recipe vocabulary remain limited; movement lacks pathfinding, terrain costs, footprints, and diagonal variants. Only one FX family exists. Creature art, sample-atlas cleanup, and provenance review remain outstanding.

The pinned Lite checkout baseline was audited, but the newer owner-local Lite checkpoint and owner-reviewed Stage 0 record were unavailable; no approval is inferred. The inert launch gate stays in place. No `Hearth20_Portable.exe`, installer, update package, commit, push, tag, release, or schedule change was made.
