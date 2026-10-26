# Station 4 interior dressing — P2-18

The additional furniture is an instance of `scenes/dispatch/station/station_interior.tscn`
inside `operations_room.tscn`. Open that subscene in Godot to move or edit individual
props. It contains ordinary saved nodes; there is no runtime generation script on it.

## Rooms

| Scene group | Dressing |
| --- | --- |
| Dispatch | Call archives, file cabinet, supervisor paperwork and telephone, duty board, wall clock |
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

167 imported model instances. The first pass reuses repository assets (office chairs, waiting
benches, metal lockers, filing cabinets, phones, papers, plants, wastebaskets, tires, equipment
cases, server racks, retro terminal, cork board, water dispenser, rifle and plate carrier). The
second pass adds 31 CC0 props from Poly Haven under `assets/3D/polyhaven/` (tools, shelving, drums,
crates, switchgear, power panels, extinguishers, pull stations, wall clocks, security cameras,
projector screen, metal desks, microwave, TV, wet-floor sign); sources are listed in
`assets/3D/polyhaven/CREDITS.md`. Tables, cabinetry, shelving, binders, signs and service fixtures
use shared materials and simple meshes. Imported models are normalized to metre dimensions and
grounded before saving.

The decorative security cameras sit in rooms the StationMart CCTV package does not cover, so the
purchasable cameras keep their own positions.

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
