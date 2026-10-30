# Steam Deck and Next Fest demo check

## Implemented in the project

- Controller defaults cover movement, camera, combat, interaction, voice, radio and pause. Keyboard rebinding retains the controller mapping.
- Main menu, pause, Station OS and dispatch terminal expose controller focus. Training Night shows controller prompts when a pad is connected.
- Settings fit a 1280 × 800 viewport, including a controller button guide in English and Arabic. Low quality reduces the menu's costly effects, shadows and rain.
- The `demo` export feature routes the operations room to `data/calls/demo` (15 authored calls). Training Night still loads its separate practice call. The full-game test call is unavailable in the demo. The first shift ends at the after-action report; the demo then offers a return to the menu instead of another shift.
- The demo reports `0.9.0-demo.1` in the menu, telemetry and crash reports, independently of the release candidate's project version.

## Local checks

Godot 4.7.2 GUT: 93/93 focused tests passed across demo routing, controller, settings, training, report, lobby, release identity, telemetry and localization. The menu, Controls settings page, Station OS desktop, CAD and StationMart were visually checked at 1280 × 800 using:

```text
Godot --rendering-method gl_compatibility --path . --resolution 1280x800 --windowed res://tools/marketing/capture_deck_ui.tscn -- settings_controls --windowed
```

The demo PCK was built and smoke-checked from the export preset:

```text
Godot --headless --editor --path . --export-pack "Windows Demo (Next Fest)" build/demo/windows/911-the-last-call-demo.pck
Godot --headless --main-pack build/demo/windows/911-the-last-call-demo.pck -s res://tools/verify_demo_pack.gd
```

The pack check confirms the `DEMO` channel, `0.9.0-demo.1`, 15 playable demo calls and the Training Night resource. The generated PCK remains under ignored `build/` and is not a standalone executable.

## Release gates still open

- Run the exported Linux demo through Steam on a physical Steam Deck. Verify controller-only Training Night, all 15 Shift 1 calls, dispatch UI, field missions, report, and return to menu.
- Check text size, keyboard entry and stable frame rate on that device. The local 1280 × 800 capture is a layout check, not a Steam Deck performance result.
- Install the matching [Godot 4.7.2 export templates](https://github.com/godotengine/godot/releases/tag/4.7.2-stable), then produce and smoke-test standalone Windows/Linux demo executables. A local executable export was attempted and failed solely because the templates are absent. Steam upload and store-side compatibility review belong to the release owner.
