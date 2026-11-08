# Hearth20 0.3.8-beta — guided automatic connections

Download Hearth20_Beta_Portable.exe on each PC. Open Steam with a different account on each PC, then open Hearth20.

## Hosting

Choose Host a new game on the title screen. Hearth20 loads the table, connects Steam, fills your display name and opens a private lobby automatically. For a saved campaign, open it and choose Host a game at the table.

The guided screen advances to Invite your friends. Select a Steam friend and press Invite selected friend. The next screen confirms the invitation and shows arriving players. Choose Enter my table to prepare the adventure, or Invite another friend. Start preparing my table lets the DM work while waiting for friends. New character pawns arrive in Tokens for placement and movement permission.

If Steam is closed, choose Open Steam & continue and sign in. Hearth20 checks readiness for up to ninety seconds, then continues automatically. A timeout gives a retry action. Steam sign-in is completed by the user.

## Joining

Choose Join a table. Hearth20 connects Steam, remembers your chosen name or supplies your Steam name, and shows Ready for your DM’s invitation. It tells you which Steam account the DM should invite. Accept the invitation while Hearth20 is open. The lobby, handshake and map transfer proceed automatically with progress.

Copied invitations work through Paste & join or Enter in the invitation box after the DM has invited you to the private lobby. Cancelling clears the pending invitation. During character setup your name is supplied, then you choose a PNG and send it to the DM. Invalid portraits block submission. Returning players use their saved campaign identity and pawn.

## Advanced connections

Advanced connection opens Direct IP. The DM hosts and copies local connection details. Players use the address, UDP port and generated code. Same-PC play uses 127.0.0.1. Same-Wi-Fi play uses the DM’s local IPv4 address. Internet Direct IP requires UDP forwarding. The main guided flow uses Steam. The shared test AppID is 480 and Steam may display Spacewar.

## Exact coin declarations

Player gold, silver and copper are parsed as decimal whole coins. 0100 gold is 100 gold. Grouped input such as 1,000 is accepted, and blank denominations mean zero. The total preview shows the exact amount before submission. Invalid numbers and amounts over the table limit show an error and block submission. A lobby refresh preserves the balance being typed. A new casino game uses its own draft. Update D&D Beyond to the exact balance shown after a payout or refund.

## Verification and updates

Both editions pass 26 background suites. Targeted checks cover missing Steam, automatic continuation, duplicate clicks, cancelled creation, late callbacks, stale friend entries, Steam shutdown, invalid PNGs, numeric edge cases and wallet serialization. A real localhost host/two-player test covers gameplay and casino messages. Rendered guided screens were reviewed. These are simulated Steam and local network checks. A fresh two-PC test of this revision and the actual Opera GX exit retest are pending.

The launch updater introduced in 0.3.7 checks the selected channel and offers a verified download/restart. From an older candidate use Settings → Updates → Beta + Steam test builds once, or download this EXE. This release is in the opt-in Steam-test channel.

## Source and credits

Extract Hearth20-Full-Source.zip from the 0.2.4 release, then apply Hearth20-Steam-Source-Overlay.zip into that folder. Open source/project.godot with Godot 4.5.1. The overlay contains current code, resource metadata and native components. Keep Hearth20-Credits.md with redistributed copies. SHA256SUMS.txt lists release checksums.
