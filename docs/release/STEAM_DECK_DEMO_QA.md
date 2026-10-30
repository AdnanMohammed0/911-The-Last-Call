# Steam Deck and Next Fest demo check

## Implemented in the project

- Controller defaults cover movement, camera, combat, interaction, voice, radio and pause. Keyboard rebinding retains the controller mapping.
- Main menu, pause, Station OS and dispatch terminal expose controller focus. Training Night shows controller prompts when a pad is connected.
- Settings fit a 1280 × 800 viewport; the General page was visually checked at that size. Low quality reduces the menu's costly effects, shadows and rain.
- The `demo` export feature routes the operations room to `data/calls/demo` (15 authored calls). Training Night still loads its separate practice call. The first shift ends at the after-action report; the demo then offers a return to the menu instead of another shift.

## Local checks

Godot 4.7.2 GUT: 35/35 focused tests passed (`test_demo_route`, `test_steam_deck_input`, `test_settings`, `test_training_night`, `test_shift_report`, `test_lobby_ui`). The menu and General settings page were captured at 1280 × 800 using:

```text
Godot --rendering-method gl_compatibility --path . --resolution 1280x800 --windowed res://tools/marketing/capture_deck_ui.tscn -- settings --windowed
```

## Release gates still open

- Run the exported Linux demo through Steam on a physical Steam Deck. Verify controller-only Training Night, all 15 Shift 1 calls, dispatch UI, field missions, report, and return to menu.
- Check text size, keyboard entry and stable frame rate on that device. The local 1280 × 800 capture is a layout check, not a Steam Deck performance result.
- Produce and smoke-test signed Windows/Linux demo exports when Godot export templates and Steamworks access are available. Steam upload and store-side compatibility review belong to the release owner.
