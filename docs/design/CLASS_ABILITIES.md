# Field class abilities — P3-04

The local player uses **3**, **4**, and **5** for the class ability slots. These actions appear in Controls for rebinding. The owning peer sends only a slot number; the host checks the player's class, life state, cooldown, inventory, and world position. The ability node keeps host authority even when the player node belongs to a client, so the host's drone, shield, and other result RPCs are accepted by that client. The existing **V** door kick and **F** hold-to-revive remain in place.

| Class | 3 | 4 | 5 |
| --- | --- | --- | --- |
| Tech | Recon drone: autonomous 45 s flight, marks nearby active suspects for 10 s; 120 s cooldown | Open a nearby electronic lock from the officer or drone | — |
| Profiler | Megaphone: nearby suspects lose morale and face a surrender check; 60 s cooldown | Tear gas: 6 m radius, 8 s, hostile aim ×0.4; 2 charges | — |
| Breacher | Ballistic shield: toggle, blocks frontal bullet damage until 600 HP spent, movement ×0.7 | Battering ram: opens reinforced door; 3 uses | — |
| Medic | Sedative: +35 sanity, aim stability ×0.9 for 20 s; 3 purchased charges | Salt barrier: 30 s, 2 purchased charges | Reverse tone: 8 s banish channel, 2 uses |

The Breacher's **V** kick now has a 4-second cooldown and cannot be used by another class in a live player session. The Medic's existing **F** revive is still 4 s; other classes need a trauma kit and 8 s. Consumables are deducted through `LoadoutManager.consume_gear`, which does not refund their purchase price. Buy field equipment in the station armory before deployment. The drone, shield, gas, and enemy marks use simple generated visuals, so no new asset dependency is required. The Medic's salt collision barrier now expires with its visible line; the first deployment is available immediately after loading.

Tests: seven `test_class_abilities.gd` cases cover class slot labels, inventory consumption, shield direction/breakage, drone cooldown, and salt barrier expiry. Two `test_class_abilities_network.gd` cases use a real local ENet host and client: an invalid slot is rejected; Tech's drone, Breacher's shield, and Medic's sedative state reach both peers. Multiplayer field QA remains required to confirm rendered visuals and controls for every class with two players.
