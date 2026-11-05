# Hearth20 Beta

<img src="branding/hearth20-beta-icon.png" width="128" alt="A beer mug with a golden d20 inside" />

A gilded virtual tabletop with a first-person tavern, private D&D Beyond sheets and four multiplayer fantasy casino games.

**[Download Hearth20 Beta 0.2.4-beta](https://github.com/WonderingMage/Hearth20/releases/tag/hearth20-beta-v0.2.4-beta)** · Windows 64-bit portable. Open `Hearth20_Beta_Portable.exe`; no installer is needed. The player edition omits diagnostic menus and the local testing lab.

Beta 0.2.4 fixes ordinary 3D dice rolls being covered by the focused battlemap. Public and private rolls now render above the map, including after returning from the casino. Existing 0.2.3 users can update from Settings → Updates.

## At your table

Host or join with a display name, character name and PNG. The DM places size-one character tokens from the campaign vault and grants movement. Click the battlemap to focus its controls or the papyrus sheet to open your private D&D Beyond browser. Website sign-in storage stays on your device.

Use drawing, styled text, waypoint rulers, area templates, shared 3D effects, public/private dice and fifteen prepared maps. The DM controls layers, masks, full-map cover and shared environmental lighting, including time of day and board north. Look up and pull an engraved wooden handle to switch the table between adventure and casino.

The casino offers Three-Dragon Ante, Gambit of Ord, Run of Luck and Tymora’s Spinner. Players declare gold, silver and copper, then follow private payout/refund notices to update their website sheet. The physical rulebook explains each game. Personal refreshments use fifteen foods and six drinks; food lasts two bites and drinks three sips.

## Settings and updates

Settings are available from the title, table and battlemap toolbar. Choose window/fullscreen mode, resolution, monitor, VSync, foreground/background frame limits and smoothing. Adjust output device and master, party, creature-video and wake-up volumes. Display changes revert after twenty seconds unless kept.

**Settings → Updates → Check for updates** reads this repository’s Hearth20 Beta releases. Downloads are verified against GitHub’s SHA-256 asset digests and the matching edition manifest. Installation saves a campaign backup, waits for the current portable to close, retains the previous EXE and restores it if the replacement does not finish starting. Leave multiplayer before installing; all participants should use the same version. Existing campaigns, identities, settings and browser storage remain local.

## Source and credits

This repository contains application code and resource metadata. The release’s **Hearth20-Full-Source.zip** contains the complete Godot project with its large models, textures, fonts and bundled helpers. Extract it and open `source/project.godot` with Godot 4.5.1. The generated GitHub source-code ZIP does not include the large runtime assets. No private campaign, character PDF, account cookie or development report is included.

See [asset credits](Hearth20-Credits.md) and [foundation license](THIRD_PARTY/Hearthtable-CC0.txt). This repository is separate from Hearthtable; earlier editions and their save formats are preserved.

## Performance status

Hidden scenes pause, off-camera animation is culled, ordinary token moves reuse exact-source lighting/map caches, and soul calculations use bounded workers. Functional audits use a DM plus four independent players. The GTX 1060 / i5-8500 target of 30 FPS 1% lows still needs measurement on that hardware; faster-PC measurements are not certification.
