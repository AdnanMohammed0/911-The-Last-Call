# Station 4 interior dressing — P2-18

The additional furniture is an instance of `scenes/dispatch/station/station_interior.tscn`
inside `operations_room.tscn`. Open that subscene in Godot to move or edit individual
props. It contains ordinary saved nodes; there is no runtime generation script on it.

## Rooms

| Scene group | Dressing |
| --- | --- |
| Dispatch | Main 911 console, supervisor desk with CAD monitor and arm lamp, two radio/CAD equipment racks, three-screen video wall with live map, unit status and incident log, ON AIR sign, radio credenza, coffee station, water cooler, mobile whiteboard, photocopier, coat rack, carpet tiles, ceiling fan, call archives, duty board, clock |
| BreakRoom | Four-seat dining table, sink sideboard, kitchenette with microwave and dish rack, refrigerator, cue rack, notices, clock, fire point |
| Briefing | Seven-seat briefing table, projector screen, three investigator desks with retro terminals, cork case board, credenza, cabinets, water cooler, camera, fire point |
| EvidenceArchive | Eight numbered shelving bays, sealed evidence boxes, intake table, camera |
| ArmoryPrep | Weapon cleaning bench (rifle, kit, ammo cans), issue counter with plate carrier, clearing barrel and rule sign, helmet shelf, rack safety line, sign-out log, clock |
| StaffLockers | Eight personal lockers, changing benches, duty desk, roll-call board, clock, fire point |
| PublicGallery | Visitor seating (three benches), wall-mounted news TV, public forms, records cabinet, water cooler, wet-floor sign, clock, camera, fire point |
| Corridor | Wayfinding, fire points with pull stations, most-wanted board, clock, fluorescent fixtures |
| Washroom | Two toilet stalls, twin washbasins, mirror panels, wet-floor sign, lighting |
| GarageWorkshop | Tool cabinet and wall, service cart, roller tool chests, welding cart, parts shelves, fuel cans, ladder, hand truck, portable generator, propane, oil stains; service aisle crates, cartons, pallet and drums |
| UtilityRooms | Communications racks, UPS cabinet, service desk, two standby generators with keep-clear markings, switchgear line-up, cable trays, distribution panels, diesel day tank, spares shelves and workbench, fire points, camera |

174 imported model instances. The first pass reuses repository assets (office chairs, waiting
benches, metal lockers, filing cabinets, phones, papers, plants, wastebaskets, tires, equipment
cases, server racks, retro terminal, cork board, water dispenser, rifle and plate carrier). The
later passes add 33 CC0 props from Poly Haven under `assets/3D/polyhaven/` (tools, shelving, drums,
crates, switchgear, power panels, extinguishers, pull stations, security cameras, projector screen,
metal desks, microwave, TV, wet-floor sign, ceiling fan, arm lamp, desk organizer); sources are listed in
`assets/3D/polyhaven/CREDITS.md`. Tables, cabinetry, shelving, binders, signs and service fixtures
use shared materials and simple meshes. Imported models are normalized to metre dimensions and
grounded before saving.

The decorative security cameras sit in rooms the StationMart CCTV package does not cover, so the
purchasable cameras keep their own positions.

## Dispatch console and CAD monitor

The builder also writes `scenes/dispatch/station/dispatch_console.tscn` (desk, angled side monitors,
keyboard, headset, gooseneck mic, phone, PC tower) and `cad_monitor.tscn` (retro CRT housing with a
0.448 × 0.336 m screen opening). The main computer in `dispatch_setup.tscn` uses the CAD monitor as its
model, so the live Station OS display fills the opening exactly; nothing from the old PC-9801 model sits
in front of it any more. StationMart workstations instance the same console and monitor and mirror the
shared Station OS viewport. The phone's `StatusScreen` label now heads the video wall's left display.

## Ambient animation

Small local-only scripts under `scenes/dispatch/station/props/` keep the station alive. Nothing is
replicated; every peer animates its own copy.

| Script / shader | Used for |
| --- | --- |
| `prop_motion.gd` | Ceiling fans (dispatch, break room, gallery), generator radiator fans, panning security cameras |
| `analog_clock.gd` | Wall clocks: hour and minute hands follow the shift clock, the second hand ticks |
| `on_air_lamp.gd` | Console mic rings and the ON AIR sign light while a call rings or is connected |
| `unit_status_board.gd` | Unit status list on the video wall |
| `flicker_light.gd` | Faulty fluorescents in the washroom and the garage service aisle |
| `screen_feed.gdshader` | Procedural screens: unit map with radar sweep, incident log, status table, idle CAD, TV news |
| `led_blink.gdshader` | Equipment rack, radio, copier, PC and generator status LEDs |

The coffee station has a small steam particle effect.

Large furniture has simple box collisions. Small tabletop objects, labels and wall
decorations do not block players. The central corridor, spawn positions, door approaches
and StationMart item footprints are reserved. Purchasable workstations, lounge furniture,
medical equipment and vehicle upgrades still appear through the existing economy system.

The main scene's ambient fill is cooler and dimmer; local fluorescents and warm table
lighting provide the interior contrast. Added lights fade at distance, and only four
of the added fixtures cast shadows.

## Rebuild and verify

The generator deterministically reconstructs the initial layout:

```text
godot --headless --path . tools/level_kit/furnish_station.tscn
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_station_interior -gexit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_station4_greybox -gexit
```

Rebuilding replaces `station_interior.tscn`, including any manual edits to that subscene.
To preserve edited placement through regeneration, update the builder coordinates first.

Validation: the layout tests check collider bounds against door/spawn clearance (including both
armory doors and the generator hall exit) and
all StationMart items at maximum ownership. The existing station tests cover loading,
dispatch setup, spawning markers, armory and purchasable furniture. Visual inspection uses
the real operations-room scene in Godot 4.7.2 Forward+, with starter inventory. This is
an art/layout pass; no new multiplayer gameplay logic is added.
