# Release Candidate — 911: The Last Call (P5-10)

Task: `P5-10` · Owner: `@mohamed` · Authority: LOCAL
Related: [`DAY_ONE_PATCH_PLAN.md`](DAY_ONE_PATCH_PLAN.md) · [`../community/DISCORD_AND_BUG_REPORTS.md`](../community/DISCORD_AND_BUG_REPORTS.md)

---

## 1. What "release candidate" means here

An RC is a **frozen, buildable, signed-off** snapshot — not "the latest main build". It is cut only when
every gate in §4 is green. If a gate is red, the build is a nightly and must not be uploaded to Steam.

An RC carries:

- a version from `project.godot` (`application/config/version`);
- the `rc` export feature tag, so the game can tell it is not a demo or a release build;
- a Windows and a Linux binary exported from the **same commit**;
- `release_manifest.json` and `SHA256SUMS` generated after the export;
- a GitHub release / artifact whose tag matches the version exactly.

Build identity is read at runtime by `core/build_info.gd` (`BuildInfo.version()`, `BuildInfo.channel()`).
The main-menu footer shows it, and every bug report attaches it.

## 2. Versioning and channels

Semantic versioning: `MAJOR.MINOR.PATCH` with an optional prerelease suffix.

| Change | Version move | Example |
|:---|:---|:---|
| Content drop / new shift | MINOR | `1.1.0` |
| Fixes only, same content | PATCH | `1.0.1` |
| Release candidate | prerelease of the target | `1.0.0-rc.1`, `1.0.0-rc.2` |
| Next Fest demo | separate demo version | `0.9.0-demo.1` |

`BuildInfo.channel()` returns:

| Channel | How it is detected | Use |
|:---|:---|:---|
| `demo` | export feature `demo` | Next Fest build; demo call set only |
| `rc` | export feature `rc` | release candidate |
| `release` | no special feature, not a debug build | public build |
| `dev` | `OS.is_debug_build()` | editor / debug export. Never ship. |

`docs/scripts/rc_manifest.py --check-version v1.0.0-rc.1` fails when the tag and
`application/config/version` disagree, so a wrong binary cannot be attached to a release by accident.

## 3. Building an RC

Export presets (in `export_presets.cfg`):

| Preset | Platform | Feature tag | Output |
|:---|:---|:---|:---|
| `Windows RC` | Windows Desktop | `rc` | `build/rc/windows/911-the-last-call-rc.exe` |
| `Linux RC` | Linux/X11 | `rc` | `build/rc/linux/911-the-last-call-rc.x86_64` |

Local build:

```bash
godot --headless --import
mkdir -p build/rc/windows build/rc/linux
godot --headless --export-release "Windows RC" build/rc/windows/911-the-last-call-rc.exe
godot --headless --export-release "Linux RC" build/rc/linux/911-the-last-call-rc.x86_64
python3 docs/scripts/rc_manifest.py --build-dir build/rc
```

The manifest records version, channel, commit, engine features, every file's size and SHA-256.
`SHA256SUMS` is written next to it for players and support.

CI: `.github/workflows/release.yml` runs on a `v*` tag (or manually). It:

1. validates progress files, localization tables and GDScript structure;
2. checks the tag against `application/config/version`;
3. exports both RC presets from the same commit;
4. writes `release_manifest.json` + `SHA256SUMS`;
5. uploads the artifact and, for a tag, publishes a GitHub release (prerelease when the tag contains `-rc.`).

**SteamPipe upload is deliberately manual.** Depot IDs and Steam credentials stay out of the repository.
The RC hand-off is the artifact + manifest; the release manager uploads that exact artifact to the
`beta` branch first (see the day-one plan).

## 4. RC gate checklist

Do not tag until every row is closed.

| Gate | Evidence | Owner | State |
|:---|:---|:---|:---|
| All GUT tests green on the RC commit | CI `test` job green | all | every RC |
| Call data validator clean | `godot --headless -s res://tools/validate_calls.gd` | @mohamed | every RC |
| Localization tables + GDScript checks clean | `validate_locales.py`, `check_gdscript.py` | @mohamed | every RC |
| P5-07 network matrix run and signed | filled `docs/qa/P5-07_QA_REGRESSION.md` | @mohamed | **testing — not closed** |
| P5-09 demo content selection final | demo export launches only demo calls | @mohamed | **progress — not closed** |
| Steam transport / invites / Cloud | P1-09, P5-01, P5-02 closed | @adnan | **not closed** |
| Steam Deck pass | P5-08 signed | @ali | open |
| Store page assets | P5-04, P5-05 approved | @ali | open |
| No open S0/S1 bugs | issue tracker query | @mohamed | every RC |
| Save/load across all 3 shifts | manual smoke (below) | @mohamed | every RC |
| All 3 endings reachable | manual + `EndingResolver` tests | @mohamed | every RC |
| Telemetry consent + crash dumps | privacy tab, `user://crash_dumps/` | @mohamed | every RC |
| Bug reporter produces a copyable report | pause menu → *Report a bug* | @mohamed | every RC |
| Discord invite configured | `BuildInfo.DISCORD_INVITE_URL` non-empty | @mohamed | before public RC |
| Arabic proofread by a native speaker | sign-off note on P5-06 | @mohamed | before public RC |
| Licences / credits complete | `docs/` credits + font OFL | @ali | before public RC |

> At the time this document was written, P5-07 is `testing`, P5-09 is `progress`, and the Steamworks
> tasks are not done. The packaging, manifest and bug-report flow are ready; the gates above still decide
> when an RC can actually be shipped.

## 5. Smoke test (30–45 minutes, fresh profile)

Run on a clean `user://` directory, once per platform.

1. Launch. Footer shows the expected version and `RC`.
2. Settings: switch to Arabic, confirm menus mirror RTL and text is readable; switch back.
3. Host a shift. Confirm the lobby shows the correct build and the address can be copied.
4. Join from a second machine. Claim different classes; start only when all are ready.
5. Play one full shift: answer calls, use the trace tool, buy gear, arrest, handle an anomaly.
6. Save, quit, relaunch, continue — meters, traits, flags and shift number survive.
7. Reach an ending in a debug/accelerated session. Confirm the correct ending screen and stats.
8. Trigger the pause menu → *Report a bug*. Write one line, copy, and confirm the report contains the
   build and no player name/IP. Open the GitHub form once.
9. Privacy: decline telemetry, restart, confirm the choice persisted. Opt in, force a script error, and
   confirm a dump appears under `user://crash_dumps/`.
10. Steam overlay / controller / Steam Deck pass (when Steamworks and P5-08 are available).
11. Exit cleanly; check no errors in the log and no crash dump from the session.

Record the result in the sign-off block, not just in chat.

## 6. Sign-off

| Role | Name | Checks | Date | Result |
|:---|:---|:---|:---|:---|
| Release manager | Mohamed | build, manifest, bug flow, smoke | | |
| Networking | Adnan | P5-07 matrix, transport, invites | | |
| UI / art / Deck | Ali | P5-08, store assets, UI polish | | |
| Content / QA | Mohamed | calls, endings, save/load | | |

A row is signed only with a build ID/commit and a result. "Looks fine" is not a sign-off.

## 7. Rollback

- Keep the previous public build on a Steam branch named `previous`.
- Never delete an RC artifact or its manifest; the checksum is the evidence of what shipped.
- If the RC is bad before launch: move the tag back only by publishing a **new** tag (`-rc.2`), never by
  force-pushing a tag players may have downloaded.
- If a bad build reaches `default`: promote `previous` back to `default` first, then fix forward on a
  hotfix branch (see the day-one plan).
