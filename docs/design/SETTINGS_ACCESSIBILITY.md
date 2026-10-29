# Settings and accessibility — P4-14

The settings menu (`ui/settings/settings_menu.gd`) opens from the main menu and the pause menu. Every
change applies at once and is saved to `user://settings.cfg` by `GameSettings`
(`autoload/game_settings.gd`). Pages: General, Video, Audio, Voice, Controls, Accessibility.

## What each page covers

| Page | Options |
| --- | --- |
| General | Language (English / Arabic, right to left) |
| Video | Window mode, V-Sync, FPS cap, FPS counter, quality preset, render scale (FSR 2), FOV, brightness |
| Audio | **Output device** with a **test sound**; volume per bus (master, music, effects, voice chat, radio, phone) |
| Voice | Input device, open mic / push to talk, automatic gain, **microphone volume**, input level with a **voice-detected light**, hear-myself mic test |
| Controls | Sensitivity, aim sensitivity, invert Y, toggle crouch, rebind every action (conflicts are stolen, reset to defaults) |
| Accessibility | See below |

## Accessibility

| Section | Option | Effect |
| --- | --- | --- |
| Subtitles | Dialogue subtitles | Voiced call lines (`EventBus.dialogue_node_changed`) at the bottom of the screen. The player holding the handset doesn't get them, because the phone UI already shows the text |
| | Sound captions | `[Phone ringing]` and captions for every hallucination (phantom steps, phantom ring, radio whisper, shadow figure) |
| | Speaker names, subtitle size (4 steps), background opacity, preview | |
| Vision | HUD colour palette | Standard, blue/orange or high-contrast colours for danger and success indicators (`GameSettings.indicator_color`) |
| | Colour-vision filter | Protanopia, deuteranopia or tritanopia correction (daltonization) over the whole screen, with a strength slider |
| | Interface scale | 80–150 % for menus, HUD and subtitles (window content scale) |
| Comfort and content | Reduce horror effects | Turns off the bodycam distortion and sanity overlay, the damage vignette and the low-health pulse; dims muzzle flashes; steadies the menu light bar |
| | Reduce flashing | Faulty fluorescents stay lit; the ringing phone lamp and ON AIR lamps glow steadily; muzzle flashes and the menu light bar calm down |
| | Bodycam effects | 0–100 % of the film grain, scanlines, chromatic aberration and sanity overlay (finer than the switch above) |
| | Jump-scare stingers | Full / Reduced (−9 dB, the loudest skipped) / Off |
| | Apparitions | Off turns shadow-figure hallucinations into a sound cue only |
| Motor | Toggle sprint, toggle aim, toggle crouch | Press once instead of holding. Sprint releases when you stop moving |

This page merges two parallel P4-14 passes. Their earlier HUD-only `DialogueSubtitles` was replaced by
the shared overlay, which keeps its behaviour: a re-synced node doesn't restart the timer, and the line
clears when the call ends.

The subtitle overlay (`ui/hud/subtitle_overlay.gd`) sits on CanvasLayer 95: above every HUD, below
menus. The colour filter (`ui/shaders/colorblind.gdshader`) sits on layer 126 and is hidden while the
assist is off, so it costs nothing by default.

New strings are in `data/localization/ui_en.loc` and `ui_ar.loc`. Right-to-left toggles use the
theme's mirrored switch icons.

Tests: `tests/test_settings.gd` (19 tests).
