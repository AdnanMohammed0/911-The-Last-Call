# Station 4 interior dressing — P2-18

The additional furniture is an instance of `scenes/dispatch/station/station_interior.tscn`
inside `operations_room.tscn`. Open that subscene in Godot to move or edit individual
props. It contains ordinary saved nodes; there is no runtime generation script on it.

## Rooms

| Scene group | Dressing |
| --- | --- |
| Dispatch | Call archives, file cabinet, supervisor paperwork and telephone, duty board |
| BreakRoom | Four-seat dining table, mugs and newspaper, sink sideboard, staff notices |
| Briefing | Seven-seat briefing table, case documents, briefing board, credenza and cabinets |
| EvidenceArchive | Eight numbered shelving bays, sealed evidence boxes, intake table |
| StaffLockers | Eight personal lockers, changing benches, duty desk and roll-call board |
| PublicGallery | Visitor seating, public forms, records cabinet, noticeboard and plants |
| Corridor | Wayfinding, fire points and fluorescent fixtures |
| Washroom | Two toilet stalls, twin washbasins, mirror panels and lighting |
| GarageWorkshop | Tool cabinet, spare tires, hanging tools and maintenance board |
| UtilityRooms | Communications racks, service desk, two standby generators and maintenance stores |

56 imported model instances reuse existing repository assets: office chairs, waiting
benches, metal lockers, filing cabinets, phones, papers, plants, wastebaskets, tires,
equipment cases and server racks. Tables, cabinetry, shelving, binders, signs and service
fixtures use shared materials and simple meshes. No new downloaded asset licenses are
introduced. Imported models are normalized to metre dimensions and grounded before saving.

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

Validation: the new layout tests check collider bounds against door/spawn clearance and
all StationMart items at maximum ownership. The existing station tests cover loading,
dispatch setup, spawning markers, armory and purchasable furniture. Visual inspection uses
the real operations-room scene in Godot 4.7.2 Forward+, with starter inventory. This is
an art/layout pass; no new multiplayer gameplay logic is added.
