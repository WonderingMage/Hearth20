# Autosave and Steam transfer-rate correction — 0.3.18

## Five-minute autosave

The DM's active table (including offline map preparation) has one `autosave.h20scampaign` in the existing AppData Campaign Vault. The first save is due after five minutes; subsequent saves replace that same slot. Empty title/startup tables and player clients do not overwrite it. Loading another campaign resets the clock. A running manual save/load defers the automatic start.

The main thread detaches campaign dictionaries/arrays and captures the notes editor; worker code validates, serializes, writes and indexes that snapshot. Validation bypasses the renderer's shared image cache, so a large-image validation does not hold its lock against live map reads. The normal save writer preserves the prior copy until successful replacement; the successful autosave then removes its internal `.previous` copy. A failed save retains the old logical slot. There are no timestamped autosave slots.

The bottom-edge gold indicator ignores mouse input and appears over map/table views without an exclusive window or pause. Completion briefly says Autosaved. Saving never installs a campaign, clears tokens, changes the revision, moves the camera, selects a sidebar tab or redirects the manual-save path. The autosave is labeled in Open saved tables; the automatic slot is excluded from manual Save targets.

## Correction to the 0.3.17 bandwidth claim

The user confirmed both devices run 0.3.17 and sustain 300+ Mbps speed tests, but Hearth20 receives about 0.1 MB/s. Those units differ: 300 Mbps is 37.5 decimal MB/s before overhead. This discrepancy should not have been explained primarily as ordinary upload sharing without examining the effective Steam rate.

0.3.17 set SendRateMin to 65,536 bytes/s and raised SendRateMax to 268,435,456, assuming automatic ramp-up. Valve's current header explicitly describes choosing matching minimum/maximum rates. Its open reference initializes an estimate from a small initial flight window divided by RTT; the clamp function does not itself probe available ISP bandwidth. An RTT-based estimate near 64–110 KiB/s is consistent with the observed 0.1 MB/s. The high configured maximum was not proof of a high effective rate. Also, the open reference clamps the setting to 100 MiB/s; the old documentation calling 268,435,456 the SDK's supported maximum was incorrect.

0.3.18 sets matched starting controls and applies matched values directly to each native connection. An application controller starts with an aggregate 4 MiB/s allowance, grows when loaded delivery is healthy, backs off on loss or RTT inflation, and retains a bounded aggregate 64 MiB/s ceiling. Pending/acknowledgement windows adapt to the chosen rate and RTT with headroom below the 16 MiB native send buffer. Refused configuration and a reported effective rate that differs from the request are exposed rather than treated as success. Existing partial map files and token-map privacy are unchanged.

Connections → Connection details shows requested pacing, Steam's actual effective send rate, observed wire throughput, queue sizes, RTT, delivery quality and relay/direct route. Its report excludes IP addresses and Steam account IDs. It does not initialize Steam merely by opening the panel. The generic getConfigValue binding is intentionally avoided because its current upstream buffer handling is unsafe; setters and real-time status are used instead.

Pure controller/fake-SDK tests demonstrate ramp-up/backoff, fair bounds, configuration failure and accepted-but-ineffective settings. Native API inspection checks method availability without signing in. ENet loopback tests do not measure the proprietary Steam transport. The exact cause and achieved speed on the user's real two-PC route still require the effective-rate/throughput report or another authorized live test. Do not claim a verified 300 Mbps transfer from these tests.

Primary references inspected:

- [Valve rate controls](https://github.com/ValveSoftware/GameNetworkingSockets/blob/master/include/steam/steamnetworkingtypes.h)
- [Valve initial estimate and rate clamp](https://github.com/ValveSoftware/GameNetworkingSockets/blob/master/src/steamnetworkingsockets/clientlib/steamnetworkingsockets_snp.cpp)
- [GodotSteam configuration/status wrappers](https://codeberg.org/godotsteam/godotsteam/src/branch/gdextension/godotsteam/godotsteam.cpp)
