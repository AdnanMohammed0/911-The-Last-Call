# Sanity system — P3-03

Sanity is host-owned on each `Player` and replicated by the existing `HostSync`. `ClassData` sets the initial maximum and drain multiplier: Tech 100/1.0, Profiler 80/1.3, Breacher 100/0.9, Medic 130/0.7. `SanitySystem.band_for` uses percentage of that maximum: Steady ≥70%, Uneasy 40–69%, Panicked 15–39%, Broken <15%.

Call `Player.apply_sanity_damage(amount, source)` or `SanitySystem.damage(peer_id, amount, source)` on the host. `Player.restore_sanity(amount)` and `SanitySystem.restore` clamp restoration to the class maximum. PTSD doubles gunfire drain, Nyctophobia doubles explicit darkness drain, Hardened reduces all drain by 15%. Reaching zero applies the PTSD trait once. A downed teammate costs 10 sanity, a nearby bleed-out costs 15, and securing a mission restores 10.

The host checks `light_zones` four times per second. Areas named `Dark…` or also assigned to `darkness_zones` drain 0.5 sanity per second without the flashlight. Other lit areas restore 0.3 per second. Unmarked world space is neutral; map authors should mark genuinely dark areas rather than making an entire night map drain continuously. Both box and sphere collision shapes work even when the Area3D has no collision mask.

The local player's replicated sanity drives the `Panic` audio bus with a smoothed low-pass from 20 kHz at full sanity to 800 Hz at zero and reverb wet from 0 to 0.22. `SFX` routes through Panic. Phone, voice, and music remain clear. Panicked/Broken bands occasionally emit local phantom footstep/ring events using the existing hallucination signal. The bodycam visual effect now uses sanity percentage, so Medic's 130 maximum behaves correctly.

Verified headless with `test_sanity_system.gd`. A live two-player check should verify that only each owner's local audio changes and the host's sanity state reaches both peers.
