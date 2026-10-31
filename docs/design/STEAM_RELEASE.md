# P5-01 Steamworks release integration

The optional GodotSteam extension is initialized once by `NetManager`. `SteamworksService` uses that instance for achievements and rich presence; ENet/offline play still loads without the extension. The Steam friend invitation dialog is available in the lobby and from the in-game pause menu during a Steam session. The `connect` presence key uses the existing `+connect_lobby <id>` launch argument.

## Steamworks partner setup

1. Install GodotSteam and SteamMultiplayerPeer for the exact Godot build and configure the real App ID as described in `STEAM_P2P.md`.
2. Create and publish these achievement API names: `FIRST_RESPONSE` (complete a mission), `TEN_RESPONSES` (ten missions on the local career profile), `FIRST_ARREST` (personally arrest a suspect), `CAPTAIN` (reach Captain rank). `SteamworksService` reads existing unlock state, then calls `setAchievement` and `storeStats` on a new unlock.
3. Upload and publish `marketing/steam/rich_presence.vdf` as an English Rich Presence localization file. The game sets `steam_display` and `status`, plus the join command for active Steam lobbies.
4. Enable Steam Cloud **Auto-Cloud** and set two file patterns in the Steamworks partner dashboard: `career.cfg` and `station_economy.cfg`. Choose the platform root corresponding to the absolute directory returned by `ProjectSettings.globalize_path("user://")` in a release build. On Windows this project's Godot user data is under Roaming AppData, in `Godot/app_userdata/911-The-last-call`. Set the subdirectory accordingly. Configure equivalent Godot user-data roots for each release platform. Auto-Cloud handles launch/exit sync; no direct Remote Storage API is needed. Do not sync `settings.cfg`, `voice.cfg`, `last_session.cfg`, telemetry, or crash reports.
5. Set a Steam Cloud quota adequate for both small ConfigFile profiles, publish all partner changes, and test a real build on two Steam accounts/devices.

## Live verification

Complete a mission, arrest a suspect, and check Steam overlay unlocks. Confirm career rank and ten-mission milestones. Host a Steam lobby and test both the lobby and pause-menu friend invitations and the Friends-list Join Game action. Check presence in the Friends list through station, field, and session exit. Save career/economy changes, exit, launch on another device with the same Steam account, and confirm both profiles synced. Repeat after switching back to catch conflicts. These live checks require the actual Steam App ID, published backend configuration, and GodotSteam binaries; they cannot run in the repository's headless environment.

References: [Steam achievements](https://partner.steamgames.com/doc/features/achievements), [Rich Presence](https://partner.steamgames.com/doc/features/enhancedrichpresence), [Steam Cloud](https://partner.steamgames.com/doc/features/cloud), [GodotSteam API](https://codeberg.org/godotsteam/godotsteam-docs).
