# P4-16 performance pass

## Changes

- Host AI perception and behavior tree updates share a configurable frame budget in `AITickBudget`. Two rotating cohorts spread work across physics frames. The default ceiling is 12 jobs or 3 ms from the first eligible AI job per frame; an ineligible cohort no longer starts the timer.
- Hostile visual rigs stop posing beyond 65 m and use a low polygon silhouette; the detailed rig returns within 55 m. AI, collisions, and replication continue at all distances.
- The four solid concrete perimeter walls at the station have conservative box occluders. Project occlusion culling is enabled.

## Reproduction and limits

Run `godot --headless --path . -s res://tools/perf/benchmark_ai.gd` for a CPU-only AI test range with 12 agents (90 warmup and 240 sampled physics frames). On the development machine, the initial scene measured 0.991 ms mean / 1.015 ms p95 physics time. After the initial pass, two runs measured 1.253 / 1.391 ms and 1.179 / 1.295 ms. After correcting the budget timer, two same-session runs measured 1.230 / 1.475 ms and 1.370 / 1.751 ms; the two preceding runs were 1.140 / 1.260 ms and 1.516 / 1.922 ms. This scene varies substantially between runs, so no CPU speedup is claimed. The budget is intended to limit spikes as the number of agents grows; it needs testing with larger live missions. Headless mode cannot assess LOD, GPU time, occlusion benefit, or 1% low FPS.

Before release, profile a rendered build at the station and each mission with 12 active hostiles. Use the Godot profiler and F3 network overlay to record average FPS, 1% low FPS, draw calls, frame time, and AI CPU time. Compare occlusion enabled/disabled in interior and outdoor views; if CPU occlusion cost exceeds its draw savings in open views, scope the setting to indoor levels. Check that the distant silhouettes and wall occlusion never hide visible actors or props.
