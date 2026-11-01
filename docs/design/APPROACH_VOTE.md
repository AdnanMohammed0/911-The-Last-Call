# P2-14 approach vote integration

When the host authorizes a response with two or more officers, `MissionDirector` opens a 45-second `VoteManager` approach ballot. Every peer receives the same options and tally; the ballot appears as a clickable panel. The garage deploy door remains locked until the result is announced. A solo response selects silent approach immediately so the existing single-player flow stays usable.

The host validates ballots, resolves ties with the Breacher's vote and otherwise selects the documented default. Decoy cruiser appears only for a team of at least three or a Tech Operator. The chosen approach is replicated through `MissionDirector.selected_approach` and recorded as an `approach_selected` consequence event for mission scripts. Late joiners and reconnecting officers receive an open ballot; eligibility updates when a peer leaves.

Verified with 11 vote tests, 25 mission-loop tests, a two-peer ENet ballot test, and Godot's editor parse. The older `LoadoutManager` voting API belongs to an unused armory UI scene; the live Station 4 response path uses `VoteManager`.
