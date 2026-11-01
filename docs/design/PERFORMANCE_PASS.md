# P4-16 performance pass

## Changes

- Host AI perception and behavior tree updates share a configurable frame budget in `AITickBudget`. Two rotating cohorts spread work across physics frames. The default ceiling is 12 jobs or 3 ms from the first eligible AI job per frame; an ineligible cohort no longer starts the timer.
- Hostile visual rigs stop posing beyond 65 m and use a low polygon silhouette; the detailed rig returns within 55 m. AI, collisions, and replication continue at all distances.
- The four solid concrete perimeter walls at the station have conservative box occluders. Project occlusion culling is enabled.
- Rendered profiling found the 8192 shadow atlases and high SSAO/fog settings costly on integrated graphics. The High preset now uses 4096 shadow atlases, while Ultra retains 8192. Default shadow filtering, SSAO, and volumetric fog resolution are lighter. On first launch, Intel UHD/Iris/HD Graphics starts at Low with 50% 3D render scale; an existing saved video choice is preserved.

## Reproduction and limits

Run `godot --headless --path . -s res://tools/perf/benchmark_ai.gd` for a CPU-only AI test range with 12 agents (90 warmup and 240 sampled physics frames). On the development machine, the initial scene measured 0.991 ms mean / 1.015 ms p95 physics time. After the initial pass, two runs measured 1.253 / 1.391 ms and 1.179 / 1.295 ms. After correcting the budget timer, two same-session runs measured 1.230 / 1.475 ms and 1.370 / 1.751 ms; the two preceding runs were 1.140 / 1.260 ms and 1.516 / 1.922 ms. This scene varies substantially between runs, so no CPU speedup is claimed. The budget is intended to limit spikes as the number of agents grows; it needs testing with larger live missions. Headless mode cannot assess LOD, GPU time, occlusion benefit, or 1% low FPS.

Before release, profile a rendered build at the station and each mission with 12 active hostiles. Use the Godot profiler and F3 network overlay to record average FPS, 1% low FPS, draw calls, frame time, and AI CPU time. Compare occlusion enabled/disabled in interior and outdoor views; if CPU occlusion cost exceeds its draw savings in open views, scope the setting to indoor levels. Check that the distant silhouettes and wall occlusion never hide visible actors or props.

## Rendered D3D12 measurements (2026-11-01)

`tools/perf/benchmark_render.gd` loads a scene with a real camera, optionally adds hostiles, warms up 90 frames and samples 180 rendered frames with V-Sync off. Example: `godot --path . --windowed --gpu-index 1 -s res://tools/perf/benchmark_render.gd -- res://scenes/dispatch/operations_room.tscn 12 2 1.0` (scene, extra hostiles, quality index, render scale). The current PC's `user://settings.cfg` selected High/100%; the benchmark overrides only in memory.

| Device and station settings (1920×1080, 12 hostiles) | Mean frame | P95 | P99 |
| --- | ---: | ---: | ---: |
| Intel UHD, original High/100% | 90.95 ms | 96.43 ms | 98.31 ms |
| Intel UHD, lighter project settings, old High atlas | 75.99 ms | 79.08 ms | 85.87 ms |
| Intel UHD, final High/100% with 4096 atlas | 68.47 ms | 70.53 ms | 74.78 ms |
| Intel UHD, original Medium/75% | 58.59 ms | 62.12 ms | 62.92 ms |
| Intel UHD, original Low/50% | 36.62 ms | 38.49 ms | 40.53 ms |
| RTX 4060 Laptop, original High/100% (two runs) | 10.72 / 10.77 ms | 12.07 / 12.28 ms | 12.31 / 12.54 ms |
| RTX 4060 Laptop, final High/100% | 10.26 ms | 11.69 ms | 11.94 ms |

The Intel High comparison improved the sampled mean by about 25% on this machine; Low/50% reached about 27 FPS, still below a 30 FPS target. The warehouse raid with 15 hostiles at final High/100% on the RTX 4060 measured 6.02 ms mean / 7.98 ms P95. These are fixed-camera synthetic samples, not a full match or GPU profiler trace. A rendered playthrough is still needed to inspect shadow/fog quality, movement through each level, frame pacing, and 1% lows.

## Camera sweep follow-up (2026-11-01)

Append `sweep` to the benchmark command to sample four fixed positions in sequence and report frame time and draw calls per position. The camera uses the active player view after the player has spawned. At High/100%, 1920×1080, 12 hostiles on the RTX 4060 Laptop, the station averaged 11.32 ms across the four views. The corridor at `(20, 2, -5)` was the hotspot: 14.38 ms mean and about 7,822 draw calls. The other three views measured 8.37–11.35 ms and 136–2,012 draw calls. The warehouse raid sweep averaged 6.47 ms across its four positions. Each position gets about 45 rendered frames, so these numbers locate a hotspot but do not establish 1% low FPS.

The station interior contains roughly 1,985 mesh nodes. A trial that hid small meshes beyond 16 m reduced the corridor to about 7,012 draw calls and 13.81 ms, but also removed a visible wayfinding sign. A narrower trial still removed that sign and produced no reliable speedup. Neither culling trial was shipped. The remaining P4-16 work is to inspect station geometry/material batching and occlusion in the Godot GPU profiler, then verify any art change from multiple player views before applying it.
