# Steam P2P lobby transport — P1-09

`NetManager` now supports ENet and an optional GodotSteam `SteamMultiplayerPeer` path. ENet remains the default for local tests and players without Steam. Steam lobbies use the existing host-authoritative registration, roster, class, ready, scene load, and reconnect protocol. The host is Godot peer 1; client traffic is relayed through it.

## Setup

1. Install the GodotSteam GDExtension build matching this project's Godot version. The extension must expose both the `Steam` singleton and `SteamMultiplayerPeer`. Do not install only the base GodotSteam module without the multiplayer peer extension.
2. Configure the game's Steam App ID through GodotSteam's Steam initialization project setting or `steam_appid.txt` beside the game executable for local development. Use the project's real App ID for release.
3. Launch Steam and sign in before launching the game. When initialization fails, Steam controls stay disabled; ENet continues working.

The extension and App ID are not bundled in this repository. GodotSteam's binary must match the Godot build and target platform; the App ID belongs to the Steam project.

## Player flow

- Host: **Host a shift → Host via Steam**. Once the lobby opens, select **Invite Steam friends** in the shift lobby. The lobby is friends-only with four slots.
- Client: accept the Steam overlay invitation, use Steam's **Join Game**, or paste the numeric lobby ID under **Join a shift → Steam lobby ID**.
- Steam launching the game with `+connect_lobby <id>` is supported. Existing ENet IP join and UPnP hosting remain available.
- Leave, connection failure, and timeout close the P2P peer and leave the Steam lobby. Rejoin stores the lobby ID and the existing reconnect token.

## Verification with two Steam accounts

Use two accounts that own the App ID on separate Steam clients. Host and invite, then confirm both players appear in the roster, pick different classes, ready up, start a shift, move and interact, disconnect a client, and use **Rejoin**. Repeat with a second client to check host relay. Verify closing the host returns clients to the menu. Also verify an ENet host/client session without the extension.

GodotSteam API: [MultiplayerPeer guide](https://codeberg.org/godotsteam/godotsteam-docs/src/branch/main/docs/tutorials/multiplayer_peer.md), [lobby guide](https://codeberg.org/godotsteam/godotsteam-docs/src/branch/main/docs/tutorials/lobbies.md).
