# Hearth20 0.3.7-beta — automatic updates and a party field guide

Download **Hearth20_Beta_Portable.exe** for Windows x64. Open Steam and Hearth20 on each PC with different Steam accounts.

## Automatic updates

The title screen checks the selected update channel once per launch, in the background. A newer release opens an Update & restart offer. Confirm to download, watch the progress, then choose Restart & update after checksum verification. Later lets you continue playing. Offline or up-to-date checks stay quiet. Settings → Updates contains the manual controls, channel selection and a Check for updates when Hearth20 opens toggle. Closing Settings keeps an active download available. Leave multiplayer before restarting. The updater saves a DM campaign backup and releases the docked browser before replacement.

Older versions gain this feature by updating once through Settings → Updates → Beta + Steam test builds, or by downloading this EXE manually.

## Illustrated instructions

Choose **Host & join guide** at the top of the title screen, or **Illustrated guide** in Gather your party. The black-and-gold field guide has separate three-step illustrated pages for Steam hosting, Steam joining and Direct IP. The connection screen highlights your current step.

## Host with Steam

1. Start or open a campaign. Choose **Host a game**. The game connects to the running Steam client and supplies an empty display name.
2. Press **Host private table**. The friend list loads automatically. Select a friend and send an invitation. The Steam overlay is also available when supported.
3. Players accept while their own Hearth20 is open. Their name and PNG create a pawn in your Tokens inventory. Place it and grant movement. Save to retain the campaign and ownership.

## Join with Steam

1. Open **Join a table** on your own PC. Steam connects automatically. Your remembered name takes precedence over the Steam display name.
2. Accept the DM’s Steam invitation. Lobby details are filled in and joining starts automatically. For a copied link, use **Paste & join**, or paste into the invitation field and press Enter. The DM must first invite you to the private lobby. Cancelling clears the pending invitation.
3. Choose a character name and PNG if prompted. The DM places your pawn and grants movement. Click the papyrus for your private D&D Beyond sheet.

The game provides an **Open Steam** button if the client is closed. Steam sign-in belongs to the user. This test mode uses Valve’s shared AppID 480 and may appear as Spacewar.

## Direct IP

Select Direct IP in Gather your party. The DM chooses Host by Direct IP and Copy local connection details. Players enter the address, port and generated invite code. Same PC uses 127.0.0.1. Same Wi-Fi uses the DM’s local IPv4 address. Internet Direct IP requires UDP forwarding on the host’s router. The Steam route handles the usual internet connection setup.

## Saves and private sheets

Focus battlemap → Save opens the Campaign Vault with named AppData saves and progress confirmation. Open saved campaign on the title screen lists the same slots. Tokens, portraits and ownership are retained. My Windows browser docks a dedicated window using the browser’s usual profile. Return browser to desktop restores it. Browser credentials and contents stay local.

The 0.3.6 browser-exit guard and restoration order are retained. Both editions pass the synthetic three-window native exit regression. The user’s actual Opera GX exit retest remains pending. This remains the opt-in Steam-test release while that check is outstanding.

## Verification and source

Both packaged editions pass 24 background suites, including launch-update, invitation automation, save, privacy and casino regressions. Real localhost Steam-stream RPC checks cover image reuse and transfer cancellation. Visual review uses rendered guide/update screens. Steam callbacks and browser windows are synthetic. The earlier university/home live test was user-confirmed on 0.3.3. The revised onboarding has been tested with simulated Steam callbacks and awaits a fresh two-PC use.

Extract Hearth20-Full-Source.zip from the 0.2.4 release, then apply Hearth20-Steam-Source-Overlay.zip into the same folder with replacements. Open source/project.godot in Godot 4.5.1. The overlay contains current code, resource metadata and native components. Keep Hearth20-Credits.md with redistributed copies. SHA256SUMS.txt lists release checksums.
