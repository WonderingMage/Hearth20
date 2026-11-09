# Hearth20 0.3.10-beta — clearer layouts and routed token movement

Download Hearth20_Beta_Portable.exe on each PC. Open Steam with a different account on each PC, then open Hearth20.

## Hosting

Choose Host a new game on the title screen. Hearth20 loads the table, connects Steam, fills your display name and opens a private lobby automatically. For a saved campaign, open it and choose Host a game at the table.

The guided screen advances to Invite your friends. Select a Steam friend and press Invite selected friend. The next screen confirms the invitation and shows arriving players. Choose Enter my table to prepare the adventure, or Invite another friend. Start preparing my table lets the DM work while waiting. New character pawns arrive in Tokens for placement and movement permission.

If Steam is closed, choose Open Steam & continue and sign in. Hearth20 checks readiness for up to ninety seconds and continues automatically. A timeout gives a retry action.

## Joining

Choose Join a table. Hearth20 connects Steam, remembers your chosen name or supplies your Steam name, and shows Ready for your DM’s invitation. It identifies which Steam account the DM should invite. Accept while Hearth20 is open. The lobby, handshake and map transfer proceed automatically with progress.

Copied invitations work through Paste & join or Enter in the invitation box after the DM has invited you to the private lobby. Cancelling clears the pending invitation. Choose a character name and PNG when prompted. Invalid portraits block submission. Returning players use their saved campaign identity and pawn.

Expired or incompatible invitations now return a retryable error. Explicit hosting clears an older pending invitation. Leave an active table before starting a different connection.

## Advanced connections

Advanced connection opens Direct IP. The DM hosts and copies local connection details. Players use the address, UDP port and generated code. Same-PC play uses 127.0.0.1. Same-Wi-Fi play uses the DM’s local IPv4 address. Internet Direct IP requires UDP forwarding. The guided Steam flow uses the shared test AppID 480 and may appear as Spacewar.

## Coins and typed numbers

Player gold, silver and copper use decimal whole coins. 0100 gold means 100 gold. Grouped input such as 1,000 is accepted. Blank coin denominations mean zero. The preview shows the exact total. Invalid values block submission. A lobby refresh preserves the balance being typed. Update D&D Beyond to the exact balance shown after payout or refund.

Dice counts/modifiers and casino buy-ins, raises, wagers, reserve and payout settings commit typed entries when their action is pressed. Whole-number fields reject fractional, empty, invalid and excessive entries with feedback. Correct the entry and retry. Dice and numeric casino controls retain supported arithmetic. Casino reserve steps are individual gold pieces.

## Token movement and compact layouts

With grid snapping enabled, drag a token with left held. The preview endpoints sit in square centers. Right-click while holding left to add a waypoint, then continue the route. Release left to submit the whole move. Escape cancels. The displayed feet sum the route segments using the existing straight-distance calculation. The host checks ownership, the current table revision, every wall/door segment and the complete movement allowance. Free-placement maps retain free placement.

For a DM inventory drag, move outside the map toward the token vault or inventory drop target. Dragging inside the map keeps the route preview active.

The map's top-left return arrow goes back to the 3D table. Toolbars condense when the window is narrower. Dialogs fit within the game. Scroll long lists and map-library details. The casino board reserves its bottom navigation area and scrolls on short windows. Da Rolls has a chapter picker, previous/next page controls and a close button, with game pieces hidden while reading.

Rendered checks cover 1000×650, 1280×720 and 1920×1080. Actual viewport mouse input verifies a centered, bent movement preview and release. These checks supplement the isolated malformed-input and local networking checks.

## Recoverable saves

Focus battlemap → Save opens the Campaign Vault. Give the table a name and choose Save new table, or select an existing slot. Progress confirms completion. Open saved table on the title screen lists these AppData saves with previews. The vault can open the save folder.

The previous save copy is offered when the primary file is missing or unreadable. Loading also tries the previous copy if the primary parses but fails campaign validation. The progress window identifies recovery. Save the recovered table to restore its main file. Repeated writes use unique temporary files and retain a recovery copy.

## Verification and updates

Both editions pass 31 background suites and 17 isolated failure probes. Additional real localhost processes exercise a DM with two players, casino play, dice privacy and streamed image reuse/cancellation. Native browser restoration uses three synthetic windows. These checks use isolated profiles and simulated Steam callbacks. A fresh two-PC test and the actual Opera GX exit retest remain pending.

The launch updater checks the selected channel and offers a verified download/restart. From an older candidate use Settings → Updates → Beta + Steam test builds, or download this EXE. This release stays in the opt-in Steam-test channel.

## Source and credits

Extract Hearth20-Full-Source.zip from the 0.2.4 release, then apply Hearth20-Steam-Source-Overlay.zip into that folder. Open source/project.godot with Godot 4.5.1. The overlay contains current code, resource metadata and native components. Keep Hearth20-Credits.md with redistributed copies. SHA256SUMS.txt lists release checksums.
