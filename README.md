# Hearth20 Beta

<img src="branding/hearth20-beta-icon.png" width="128" alt="A beer mug with a golden d20 inside" />

A black-and-gold virtual tabletop with a first-person fantasy tavern, private D&D Beyond sheets and four multiplayer casino games.

Download the Windows x64 portable from the regular release. Open **Hearth20_Beta_Portable.exe** to play. The player edition includes the guided host/join flow. Diagnostics and the local testing lab are available in the separate development build. [Hearth20 Beta 0.3.12](https://github.com/WonderingMage/Hearth20/releases/tag/hearth20-beta-v0.3.12-beta)

## The Amber Wastes

![Animated tarrasque title](screenshots/title.png)

Join and Host lead the opening menu. An articulated tarrasque breathes, shifts its weight, turns its head and moves its tail above a windblown orange desert. Small travelers and a ruined gate establish its scale. Amber irises and slit pupils, ivory teeth, gums, tongue, throat, horns and claws have their own skinned surfaces and finishes.

The creature and foreground render in 3D. The distant landscape uses an illustrated matte. The scene has a bounded render resolution and releases its viewport when the table opens. Retired rotating-showcase assets are excluded from portable exports.

The tarrasque adapts Miguel Zavala's credited sculpt and rig, with new runtime preparation, animation and materials. Scene credits are available from the title menu. The source archive includes the Blender authoring source, preparation script, texture import settings and generation prompts.

## Gather your party

1. Open Steam and Hearth20 on each PC, using different Steam accounts.
2. The DM chooses **Host a new game**. The guided screen prepares a private lobby and lists friends to invite.
3. Players choose **Join a table** and accept the DM's invitation while Hearth20 is open.
4. Each new player gives a display name, character name and PNG. The character arrives in the DM's token inventory for placement and movement permission.

The title and connection screens include an illustrated host/join guide. Advanced connection provides Direct IP. Optional Steam networking currently uses Valve's shared AppID 480 and may appear as Spacewar.

## At the adventure table

Focus the battlemap to draw, add styled text, measure routes and areas, place effects, roll dice or manage tokens. The DM controls layers, common environmental lighting, day/night settings and map cover. Fifteen prepared maps demonstrate the tools and lighting. Token movement previews snap to square centers when grid snapping is enabled. Hold left and right-click to add movement waypoints, then release left to submit the route.

The DM can store tokens by dragging outside the map to an inventory target. Player ownership, portraits, map data, casino balances and campaign state are saved in the Campaign Vault. Save progress confirms completion and previous-copy recovery handles interrupted saves.

Click the papyrus to focus a private D&D Beyond sheet. The Windows-browser option uses a dedicated window in the user's normal browser. Sign-in, cookies and passwords stay on that PC. A built-in WebView2 option is also available.

## At the gilded casino

The DM uses the ceiling pulls to switch between adventure and casino. Three-Dragon Ante, Gambit of Ord, Run of Luck and Tymora's Spinner share one tavern. Players declare their gold, silver and copper, then receive private payout/refund totals to enter on D&D Beyond. Da Rolls provides chapters and illustrated instructions for each game.

Personal refreshments include fifteen foods and six drinks. Food lasts two bites and drinks three sips. Beer effects accumulate, blackout restricts the player to spectating, and waking clears the beer timers.

## Settings and automatic updates

Display settings include window/fullscreen modes, resolution, monitor, VSync, frame limits and smoothing. Display changes use a timed confirmation. Audio settings separate master, effects, party, creature-showcase and wake-up volumes.

Fresh installations use the ordinary **Beta releases** update channel. The title checks for updates and offers a verified download and restart. Existing Beta users can use **Settings → Updates → Check for updates**. Each download is checked against GitHub's SHA-256 digest and the Hearth20 edition manifest. The installer retains the previous EXE and supports rollback when startup confirmation fails.

Use the same release on all participating PCs. Profiles, campaign saves and browser storage stay local. The optional combined update channel remains available in Settings for development test builds.

## Verification

The release includes **Verification-Report.md** with the exact scope of system checks, adversarial inputs, native UI tests, multiplayer campaign verification and update handling. The report also identifies checks requiring real accounts or target hardware. The GTX 1060 / i5-8500 30 FPS 1% low target still requires measurement on that hardware.

## Source and credits

**Hearth20-Full-Source.zip** contains the complete Godot project, large runtime assets and native components. Extract it and open **source/project.godot** with Godot 4.5.1. GitHub's automatic code archive omits large runtime assets.

Keep **Hearth20-Credits.md** with redistributed copies. **SHA256SUMS.txt** lists the release asset checksums. This repository is separate from the original Hearthtable project. Earlier Hearth20 forks retain their own saved checkpoints.
