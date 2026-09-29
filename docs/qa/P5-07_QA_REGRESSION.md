# P5-07 — Full QA regression: networking matrix

> Owner: `mohamed` · Status: harness ready, matrix **not yet executed** · Relates to: `docs/design/ARCHITECTURE.md` §4 (networking), `NetManager`, `LagCompensation`, `NetDebug`.

## 1. What this is, and what it is not

The matrix exercises a real session: **2, 3 and 4 total players** (host included — `NetManager.MAX_PEERS` is 4), under **normal, high-latency and lossy** conditions. It has to be run by a person on real machines. Nothing in this repository can fabricate those results, and a checklist that claims to have passed without a run is worse than no checklist.

So P5-07 is split honestly:

| Part | How | Status |
| :--- | :--- | :--- |
| Limits, parsing and bounds the matrix rests on | `tests/test_net_matrix.gd` (GUT, runs in CI) | automated |
| The 2/3/4 × condition matrix | Manual run, this document | **not run** |

A green CI run means the guard rails are intact. It does **not** mean the game survives four players on a bad connection.

## 2. Run the automated part

```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_net_matrix.gd -gexit
```

If a test here fails, the numbers in §4 change too — fix the constant and update the table, don't just re-run.

## 3. Environment for the manual run

- **Players:** 2, then 3, then 4. Four separate machines is ideal; one host + three clients on one LAN is acceptable, and the host must be specified in every row.
- **Builds:** all peers on the same commit and the same `PROTOCOL_VERSION`.
- **Overlay:** press **F3** in every instance. It is the evidence for RTT, jitter and packet loss per peer (`NetDebug.build_report()`), and the only way to tell "laggy" from "desynced".
- **Latency / loss injection:** Godot has no built-in network simulator, so use the OS:
  - Linux: `sudo tc qdisc add dev <iface> root netem delay 150ms loss 5%` (remove with `tc qdisc del dev <iface> root`).
  - Windows: use a tool such as Clumsy (free, per-process).
  - Apply it to the **clients**, not the host, unless the row says otherwise.

Record the command actually used next to the result. "High latency" without a number is not a result.

## 4. The matrix

Every row is one session. Run top to bottom; a row only counts once the previous one is clean.

| # | Players | Condition | Injected on | Expected | Result |
| :- | :--- | :--- | :--- | :--- | :--- |
| 1 | 2 | baseline (LAN) | — | Roster shows 2, all ready, shift starts, both see each other move | ☐ |
| 2 | 3 | baseline | — | Roster shows 3, shift starts, all see each other move | ☐ |
| 3 | 4 | baseline | — | Roster shows 4, shift starts, all see each other move. A 5th join is refused, not silently dropped | ☐ |
| 4 | 2 | 150 ms / 0 % | client | Movement stays smooth; F3 RTT ≈ 300 ms round trip; no rubber-banding beyond interpolation | ☐ |
| 5 | 3 | 150 ms / 0 % | clients | As row 4, plus voice is still intelligible | ☐ |
| 6 | 4 | 150 ms / 0 % | clients | As row 5 under full lobby; no client times out | ☐ |
| 7 | 2 | 300 ms / 0 % | client | At the `MAX_REWIND_MSEC` ceiling: no player is snapped backwards on their own screen | ☐ |
| 8 | 3 | 80 ms / 5 % | clients | Occasional loss is absorbed; roster never desyncs | ☐ |
| 9 | 4 | 80 ms / 5 % | clients | As row 8; F3 loss column tracks the injected rate within a few percent | ☐ |
| 10 | 4 | 150 ms / 10 % | clients | Worst case ships-ready: no crash, no permanent desync, `NetDebug` violations stay bounded | ☐ |

### Session-edge rows (run once each, at 4 players)

| # | Scenario | Expected | Result |
| :- | :--- | :--- | :--- |
| E1 | Client force-quits mid-shift | Peer leaves the roster within `PEER_TIMEOUT_MAX_MS`; host does not stall | ☐ |
| E2 | Host force-quits mid-shift | Clients leave to menu with a reason, not a hang | ☐ |
| E3 | Client rejoins a dropped session | Rejoin via the saved token puts it back in its slot (`get_reserved_slot_count()` drains) | ☐ |
| E4 | Mismatched `PROTOCOL_VERSION` | Second build is rejected with a clear message, no partial desync | ☐ |
| E5 | Two players pick the same class | Second pick is refused; `is_class_taken()` holds | ☐ |
| E6 | Host starts with a player unready or classless | Start stays disabled (`can_start()` false) | ☐ |

## 5. After the run

1. Fill every ☐ with **PASS**, **FAIL** or an observation — not a tick alone.
2. Attach or paste the `NetDebug.build_report()` text for the worst two rows (10 and E1).
3. A FAIL becomes a bug with the row number in the title, e.g. `net(4p, 10% loss): client 3 desyncs on rejoin`.
4. Only then does P5-07 move to `done`. Until a run exists, it stays `testing`.

## 6. Known soft spots (watch these first)

- **Voice under loss** (rows 5–10): voice rides channel 2; loss there degrades audio before it affects gameplay, so judge them separately.
- **Rejoin after timeout** (E3): the token path is the most complex part of `NetManager` and the least exercised.
- **Class race** (E5): two players confirming the same class on the same frame is the realistic failure, not a slow second pick.
- **Host migration** is **not** implemented; E2 covers leaving cleanly, not recovering the shift.

## 7. Sign-off

| Field | Value |
| :--- | :--- |
| Build / commit | |
| Date | |
| Tester(s) | |
| Machines / OS | |
| Injection commands used | |
| Rows passed / total | / 16 |
