# P5-02 — NAT traversal and Steam Datagram Relay validation

`SteamMultiplayerPeer` uses SteamNetworkingSockets `CreateListenSocketP2P` / `ConnectP2P`. Steam selects direct or relayed routing as appropriate. Its `server_relay = true` setting means **clients send gameplay traffic through the game host**; it does not force the Valve relay network. The game's Steam initialization now prewarms relay-network access. F3 shows relay-network readiness and connected peer count in Steam sessions instead of incorrectly saying “offline” or displaying ENet-only statistics.

The peer extension currently does not expose its Steam connection handle to GDScript, so this overlay cannot report whether an individual connection is direct or relayed. Relay readiness alone is not proof that the current connection uses SDR. Start Steam with `-lognetapi` and inspect `Steam/logs/netapi_log.txt` to confirm the route. Launch the game with `-- --netdebug` to enable the peer extension's Steam debug output and the F3 overlay. Capture both clients' logs and the F3 readout for each run.

## Live matrix

Use a release build with a real App ID, the matching GodotSteam MultiplayerPeer extension, and two distinct Steam accounts that own the app. Each row needs two separate machines or isolated network environments. Record account IDs only in private test notes, not public issue attachments.

| Network | Host | Client | Expected result |
| --- | --- | --- | --- |
| Different home routers | Normal NAT | Normal NAT | Invite, join, ready, load scene, gameplay and voice; record chosen route. |
| Carrier-grade NAT | CGNAT/mobile hotspot | Home router | Same flow without port forwarding; relay route if direct traversal fails. |
| Strict NAT pair | Two separate restrictive networks | Strict NAT | Same flow; capture Steam route and connection timing. |
| Relay disruption | Normal NAT | Steam relay access unavailable | Clear failure or recovery, no permanent connecting spinner; verify rejoin after access returns. |
| Host drops | Any of the above | Connected client | Client returns to menu; reconnect token and slot work after host returns within window. |

For each successful connection, play for at least five minutes, exercise movement, door interactions and open mic/radio, note average and worst RTT, packet loss, voice gaps and disconnects, then disconnect/rejoin a client. Repeat with a third client to check the host topology. Try both Steam overlay invitation and the Friends-list Join Game action. Confirm the ENet path still works separately.

Pass criteria: the three NAT rows connect without manual UDP forwarding; the actual route is confirmed from Steam networking logs; gameplay and voice remain functional; disconnection and rejoin behave as specified. Mark P5-02 `done` only after these live observations are recorded. Local headless tests cover status mapping, overlay behavior and the missing-extension path, but cannot validate NAT traversal or SDR.

References: [Steam networking overview](https://partner.steamgames.com/doc/features/multiplayer/networking), [Steam Datagram Relay](https://partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay), [Steamworks debugging](https://partner.steamgames.com/doc/sdk/api/debugging), [GodotSteam MultiplayerPeer source](https://codeberg.org/godotsteam/multiplayerpeer).
