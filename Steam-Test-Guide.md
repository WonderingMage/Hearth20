# Hearth20 0.3.2-beta — Steam test candidate

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
