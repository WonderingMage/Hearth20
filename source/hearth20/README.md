# Hearth20 player-table development preview

Hearth20 is the separate top-down edition in this checkout. The standard project entry remains an inert development gate; the reviewed preview builder launches `hearth20_main.tscn` in its own project and user-data directory. It never replaces Lite or a published release.

## At the table

**0.5 adds material-specific animated FX, persistent authenticated player identities and token grants, a dedicated Tokens side button (K), per-scene grid opacity/thickness/color, and a custom title/loading screen.** The twenty creature showcases include nineteen supplied glTF models and a looping Skeleton video with audio. Gibbering 2 has a new colored flesh material. The debug portable exposes Loading Lab (F6): select any creature/tip and hold the loading preview. [The model replacement guide](../docs/hearth20-model-replacements.md) covers swapping assets, debug exports and deferred loading after the menu appears. [Table-control instructions](../docs/hearth20-05-table-controls.md) cover the new workflows.

**0.4 adds fifteen generated sample maps, black-and-gold / beige-and-gold themes, soft volumetric lighting, compass and time-of-day controls, and richer FX with a live preview.** See the [map and lighting guide](../docs/hearth20-regal-lighting-and-maps.md) for controls, artwork provenance and rendering details.

- **Sheet** opens the assigned character's stat block, ability checks, saving throws, all 18 skills, initiative and custom dice. Choose Normal/Advantage/Disadvantage and Public/Only me + DM before rolling. Dice record an intention/result; the DM determines outcomes. Assigned sheets work during fog and blackout.
- **Chat** shows who rolled, the formula, individual dice and result. Public rolls/messages go to the table; private ones go to the roller and DM. Enter sends a message. `/r 1d20+3`, `/roll 2d6`, `/gmroll 1d20+5` and `/w gm message` are supported. The saved history holds the last 200 entries.
- **Journal** displays published handouts. The DM can edit private session notes, draft a handout and explicitly share or withhold it.
- **S/C/J** opens the corresponding sidebar tab. Hide panel recovers map space. **M** activates the local ruler, **F** fits the map, the wheel zooms at the pointer, Space/middle-drag pans, and Escape cancels a map tool. Shift-click pings a point visible to your character; only participants who can also see that point receive it.

## Prepare a session

The DM uses Workspace → Scene for map import, calibration, fog, lighting, blackout and measured areas; Token for placement/PNG appearance/ownership and movement grants; Connect for hosting/joining; and Build for bounded scene recipes. NPC tokens begin concealed. Only the DM controls doors, visibility, actor values and recorded outcomes.

To test darkvision, enable Dynamic lighting, choose Dark ambient light, select a hero, set Dark to 60 ft and Apply vision. A hero with ordinary sight (Dark 0 ft) needs a light source. The Torch preset sets 20 ft bright light plus an additional 20 ft dim light. Closed doors and walls obstruct both vision and light. Player-view preview uses the same host-filtered projection as that connected player's packets; it is read only.

The DM assigns heroes to connected players and sets their movement policy. The server computes dice and movement authority, filters sheets/history for each owner, masks map image bytes before sending them, and removes unseen tokens/assets/geometry/effects. Disconnect and a fresh join clear the old local player view. Public information already received cannot be made unknown again.

## Validation and build

From this checkout on Windows with the existing pinned Godot 4.5.1 toolchain:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test_h20_tabletop.ps1 -Rendered
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/build_h20_development_preview.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/build_h20_portable.ps1
```

These commands apply the execution setting only to their child PowerShell process. QA copies only the necessary runtime into a unique private Reports folder, proves disposable data, and retains source hashes, raw logs and synthetic captures. The builder creates a new EXE plus source/toolchain checksums and verifies a compiled native startup. These commands never commit, publish, install or start a development loop.

The portable command packages the same reviewed runtime as a single `Hearth20_Portable.exe` in a unique Builds folder. Its engine and application resources are embedded; manifests and logs stay in Reports. Saves use the separate stable Hearth20 AppData directory. Copying the EXE does not copy existing saves. This is a portable development build with the feature limits below; it does not claim full product acceptance.

## Current limits

This package is not full Roll20 parity or complete inherited Lite sheet integration. Full PDF review, advanced spell/action/resource and DM-outcome workflows, an initiative tracker, macros/tables/decks, compendium and table audio/video remain open. Loading-screen video is supported. Scene switching, five editing layers, drawing/text, polygon masks, measuring and fifteen FX styles are included. Lighting uses a physically informed 2.5D approximation and conservative sampled visibility; magical darkness, special senses and explored-map memory are not modeled. Detached sheet/chat windows and targeted player whispers are not included.

See [patch notes](PATCH_NOTES.md), [player UX contract](../docs/hearth20-player-experience.md), [researched Roll20 inventory](../docs/hearth20-roll20-parity.md), and [verification instructions](../tests/README.md). Local scripted Windows/UI and UDP checks do not prove physical mouse/audio or external internet play.
