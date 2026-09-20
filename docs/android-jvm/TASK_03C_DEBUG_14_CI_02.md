# TASK 03C-DEBUG-14-CI-02 — Fix SDL checkout validation failure

## Status

INCOMPLETE — fix applied; CI verification pending.

## Branch

`android-jvm`

## Baseline

`66a9dca4dc73e4d5ba0fe1b4e7d088fa0cec598f`

Pinned Arc revision:

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

SDL:

`2.32.8`

SDL source commit:

`98d1f3a45aae568ccd6ed5fec179330f47d4d356`

## Result

`b437e1ab30cbee5908702abfad1323a9d7742d5e`

Commit message:

`Fix DEBUG-14 SDL checkout validation`

## Files changed

- `scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh`
- this report

No Arc upstream files, production Mindustry runtime files, `OS.java`, `SharedLibraryLoader`, or `SDLGL.java` were modified.

## Failure

Historical failing workflow:

Run `35505065349`

Job `106063365531`

Step:

`Build SDL Android controller Java glue diagnostic`

Observed log:

- Arc verification succeeded.
- The script did not execute its SDL clone branch.
- The next command, `git -C "$SDL_ROOT" rev-parse HEAD`, failed with:
  `fatal: not a git repository (or any of the parent directories): .git`

The same run had already passed:

- Android ARM64 SDL native probe
- unit tests
- `desktop:dist`
- desktop JAR verification
- real Android JVM native-load probe packaging
- absolute-path native-load diagnostic packaging

## Root Cause

The helper used the presence of the SDL version header as the condition for deciding whether SDL had already been obtained.

That condition was too weak. An SDL source tree can exist with the expected header while not being a Git checkout with `.git` metadata. The subsequent unconditional `git -C "$SDL_ROOT" rev-parse HEAD` therefore failed.

The CI evidence establishes this sequence because the SDL clone message was absent, while the immediate next Git command failed.

The exact producer of the non-Git SDL source tree is not established by this run. The native build stage also uses SDL source, so an earlier task may have populated the sibling path, but that causal attribution is not proven here.

## Fix

Changed the SDL acquisition guard from a header-only check to a Git-checkout check:

```bash
if ! git -C "$SDL_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  rm -rf "$SDL_ROOT"
  git clone --no-tags --depth=1 --branch "release-$SDL_VERSION" https://github.com/libsdl-org/SDL "$SDL_ROOT"
fi
```

This ensures the helper obtains a fresh authoritative SDL Git checkout whenever the sibling path is missing or is not a valid Git repository.

Also corrected the SDL version-header parser to use the already-defined authoritative path:

```
$SDL_VERSION_HEADER
```

which points to:

```
$SDL_ROOT/include/SDL_version.h
```

This removes the stale `include/SDL2/SDL_version.h` path from the parser.

## CI

- Run `35497969143` — earlier failure on redundant Arc Git query.
- Run `35504194009` — Arc filesystem/Git diagnostic; established Arc state immediately before the earlier failure.
- Run `35505038814` — failed after the Arc-query fix because SDL checkout validation was still too weak.
- Run `35505065349` — reproduced the SDL checkout validation failure on commit `66a9dca...`.
- A new CI run is expected from result commit `b437e1ab30cbee5908702abfad1323a9d7742d5e`; final verification is pending.

## Build

Confirmed by the failing run before DEBUG-14 stopped execution:

- Arc checkout and exact pin: PASS
- Android SDK/NDK setup: PASS
- Android native toolchain verification: PASS
- Android ARM64 SDL native build: PASS
- unit tests: PASS
- `desktop:dist`: PASS
- desktop JAR verification: PASS
- real Android JVM native-load probe packaging: PASS
- absolute-load native-load diagnostic packaging: PASS

DEBUG-14 SDL Java glue packaging was not reached successfully.

## Verification

### Confirmed by source

- The helper expects SDL 2.32.8 at sibling path `../SDL2-2.32.8`.
- SDL version header is `include/SDL_version.h` at the pinned SDL source tree.
- The diagnostic packages only the four direct JNI_OnLoad classes:
  - `SDLActivity.class`
  - `SDLInputConnection.class`
  - `SDLAudioManager.class`
  - `SDLControllerManager.class`

### Confirmed by CI/build

- The failure occurs specifically at the SDL Git revision lookup after Arc verification.
- The run reached that point with all preceding required build stages green.

### Confirmed by artifact inspection

- Earlier stages produced and verified the real ARM64 `libsdl-arc.so` and diagnostic packages.
- Final DEBUG-14 glue artifact for the new fix is pending.

### Inference

- The sibling SDL tree was likely populated by an earlier build step without Git metadata. This is plausible but not proven by the current evidence.

### Unknown

- Which earlier process created the non-Git SDL tree in the failing job.
- Whether the fixed guard is the only remaining CI issue in DEBUG-14.

## Known limitations

- New CI verification has not yet been observed.
- Full Android runtime behavior of the four SDL Java classes remains untested.
- This task remains a CI packaging/debug task and does not change the production native loader.

## Next task

Verify the CI run triggered by `b437e1ab30cbee5908702abfad1323a9d7742d5e`.

If the DEBUG-14 packaging step passes, inspect the artifact contents and verify the exact four Java classes plus the unchanged real `libsdl-arc.so`. If another failure occurs, create a new debug report from the exact failure rather than rewriting this history.

## Handoff

Status:
INCOMPLETE — CI verification pending

Branch:
`android-jvm`

Baseline:
`66a9dca4dc73e4d5ba0fe1b4e7d088fa0cec598f`

Commit:
`b437e1ab30cbee5908702abfad1323a9d7742d5e`

Files changed:
`scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh`
`docs/android-jvm/TASK_03C_DEBUG_14_CI_02.md`

Result:
SDL checkout validation now requires a valid Git checkout and the SDL header parser uses the correct `include/SDL_version.h` path.

CI:
New verification run pending after `b437e1ab...`.

Build:
All pre-DEBUG-14 stages were green in the failing run; DEBUG-14 packaging remained blocked by SDL checkout validation.

Verification:
Root cause confirmed at the SDL Git lookup. Fix applied. Final packaging verification pending.

Known limitations:
Exact producer of the non-Git SDL source tree remains unknown.

Next task:
Verify the new CI run and inspect the DEBUG-14 artifact if packaging passes.
