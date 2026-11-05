# Hearth20 0.3.5-beta — Steam test candidate

Download **Hearth20_Beta_Portable.exe** and run it on 64-bit Windows. This is an opt-in Steam test build; 0.2.4 remains the ordinary Beta/update channel. Both PCs need this same candidate, Steam running, and different Steam accounts.

## Join the test

1. Open Hearth20 on both PCs before accepting an invite.
2. DM: start/open a campaign, then **Host a game → Steam → Connect Steam → Host private table**.
3. Player: **Join a table → Steam → Connect Steam** and enter a display name.
4. DM: select the player in the built-in Steam friend list and send an invitation. The Steam overlay is optional. For a private lobby, send an invitation before relying on the copied lobby link/number.
5. Player: accept while Hearth20 is already open. If using a copied invitation, paste it into **Join invitation**. Choose a character name and PNG when asked.
6. DM: place the pawn from Tokens and grant movement. Test map changes, lighting, public/private dice, casino play, leaving and rejoining.

Steam may display Spacewar because this uses Valve's shared test AppID 480. No separate Spacewar download is performed automatically. Try Connect Steam first; a missing-license/setup error should be reported rather than silently installing another application. Steam's requirements are documented at https://partner.steamgames.com/doc/sdk/api.

This candidate contains the Steam runtime components. Direct IP remains available. D&D Beyond credentials/cookies stay local; never share your browser/profile folder with other players.

Background checks cover both packaged editions, native component loading without sign-in, simulated lobbies/invites, bounded image transfers over real localhost RPCs, campaign/casino networking, and dice privacy. The live two-PC internet connection and visible behavior are still being tested. No target-hardware performance certification is implied.

## Source

The tag's `source` tree contains current code and resource metadata. **Hearth20-Steam-Source-Overlay.zip** adds this candidate's current code and native Steam files to the complete 0.2.4 source/assets. To obtain a complete project, extract **Hearth20-Full-Source.zip** from the 0.2.4 release, then extract the overlay into that same folder, allowing replacements. Open `source/project.godot` with Godot 4.5.1. The source overlay contains no campaigns, PDFs, cookies, live-test logs or player data.

Keep **Hearth20-Credits.md** with redistributed copies. SHA-256 checksums are in SHA256SUMS.txt.

## Save and reopen a table

DM: Focus battlemap → Save opens the Campaign Vault. Give the table a name and choose Save new table, or select an existing slot. A progress window confirms completion. Open saved table on the title screen lists these same AppData saves with previews. The vault also has an Open AppData save folder button. Saves include map data, placed and stored tokens, original PNGs, and ownership; a .previous copy is retained when replacing a slot.

This build also enables adaptive Steam transfer rates and reuses previously received map/portrait images for unchanged reveal and token-inventory updates. Update both PCs for image-reference reuse; older candidates remain wire-compatible but use the older image transfer path. Actual internet responsiveness still needs the ongoing two-PC retest.

## Use your actual Windows browser on the character sheet

1. Close the old portable and open this one. Click the papyrus sheet.
2. Leave the selector on **My Windows browser**. Click **Open my Windows browser** in the sheet area. Hearth20 resolves Windows' default HTTPS browser and opens a dedicated D&D Beyond window with that browser's normal profile.
3. The new browser window is placed in the sheet area when it can be identified unambiguously. Otherwise select the D&D Beyond window from the local list and click **Place selected window on my sheet**. Use a dedicated window; its entire browser UI belongs to that window.
4. Sign in using your usual browser. Cookies, password management, extensions and 2FA remain with the browser. Hearth20 does not import browser credentials, enable debugging ports or read profile databases.
5. **Return browser to desktop** restores its normal window. **Choose browser window** lets you select it again. Normal game exit and restart-to-update wait for the helper to restore the window. A browser that Windows refuses to reparent remains available outside the game. Browser behavior and account login still require the user's real-browser check; regression tests use isolated synthetic windows.

The launcher handles Opera GX's launcher/versioned executable layout, plus common Chromium and Firefox-family browser windows. There is an optional **Built-in browser** backend, whose previous typing fix is retained. Changing modes releases the existing browser first.

Native browser docking displays the actual window while the sheet is focused; it does not stream it as a texture onto the 3D papyrus. No browser content or credentials are sent to the DM or other players.

## Update channel

Settings → Updates now offers **Beta releases** and **Beta + Steam test builds**. Prereleases were already supported; the old updater filtered out the separate Steam-test tag/manifest. This candidate defaults to the combined channel. Apply changes to remember a different choice. Updates still require matching product/protocol/schema and GitHub SHA-256 asset checksums. A Beta-only check tells you when a newer Steam test exists rather than claiming every published build is current.

Older portables need this one manual download to gain the new channel selector. The existing 0.3.3/0.3.4 DM is wire-compatible with this local browser/updater change.
