# TASK 03C-DEBUG-14-CI-01 — Fix SDL Android Glue Probe CI Failure

## Status

INCOMPLETE — fix applied and CI verification is currently in progress.

## Branch

`android-jvm`

## Baseline

`1edfc38866aedbf7635c96cfc4b00ab592dd7ac2`

This was the diagnostic commit that established the actual filesystem state immediately before the failing late Arc Git query.

Pinned Arc revision:

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

SDL:

`2.32.8`

SDL source commit:

`98d1f3a45aae568ccd6ed5fec179330f47d4d356`

## Result

`614cdcd6081c0d494ca60e53819ec7e80c2a5db0`

Commit message:

`Fix DEBUG-14 Arc repository-state check`

## Files changed

- `scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh`
- this report

No Arc upstream files, SDL source files, SharedLibraryLoader, OS.java, SDLGL.java, or production Mindustry runtime files were modified.

## Failure

Historical failing workflow:

Run `35497969143`

Job `106044423912`

Step:

`Build SDL Android controller Java glue diagnostic`

Observed terminal error:

`fatal: not a git repository (or any of the parent directories): .git`

Exit code:

`128`

## Root Cause

The diagnostic instrumentation in commit `1edfc388...` proved the following immediately before the failure:

- `ROOT=/home/runner/work/Mindustry/Mindustry`
- `ARC_DIR=/home/runner/work/Mindustry/Mindustry/../Arc`
- `ARC_DIR` exists and is a directory.
- `build.gradle`, `gradle.properties`, and `settings.gradle` exist in Arc.
- `ARC_DIR/.git` exists and is a directory.
- `.git/HEAD` exists.
- `.git/config` exists.
- `git -C "$ARC_DIR" rev-parse --show-toplevel` succeeds and returns `/home/runner/work/Mindustry/Arc`.
- `git -C "$ARC_DIR" rev-parse HEAD` succeeds and returns the exact pinned Arc revision `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`.

Immediately after those successful checks, the script executed the same `git -C "$ARC_DIR" rev-parse HEAD` a third time and it failed.

Therefore the failing condition was **not**:

- an incorrect Arc path;
- a missing `../Arc` directory;
- missing `.git` metadata;
- a malformed/missing HEAD;
- a malformed/missing Git config;
- an incorrect Arc revision.

The proven failure mechanism is that the helper performed a redundant late Git revalidation after the Arc repository had already been successfully established and verified. The second/third identical Git invocation was not providing new information and proved unreliable in this CI step.

The exact external mechanism that caused that immediately repeated third invocation to return “not a git repository” is **unknown**. The available CI evidence does not show a filesystem mutation or other causal state transition between the successful and failed invocations.

## Fix

The smallest robust change was made in `scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh`:

1. Keep explicit validation that Arc exists, has Git metadata, and contains expected Arc files.
2. Execute exactly one late-stage `git -C "$ARC_DIR" rev-parse HEAD`.
3. Capture that result directly into `actual_arc`.
4. Compare it with the authoritative pinned revision.
5. Do not execute a second redundant `rev-parse HEAD`.

This preserves an explicit Arc SHA check without depending on the problematic duplicate Git query.

The existing CI workflow remains responsible for the authoritative Arc checkout and exact SHA verification before any build steps.

## CI

Previous failure evidence:

- Run `35497969143` — failed at DEBUG-14 controller-glue diagnostic because of the late duplicate Git query.
- Run `35504194009` — diagnostic commit `1edfc388...`; filesystem inspection proved Arc and its Git metadata were healthy before the failing third query.

Current verification:

- Run `35505038814`
- Head commit: `614cdcd6081c0d494ca60e53819ec7e80c2a5db0`
- Job: Test and build
- Current state at report creation: **in progress**
- The final DEBUG-14 packaging result is therefore not yet proven.

## Build

Historically confirmed before this fix on the same task chain:

- Arc checkout and exact pin: PASS
- Android SDK/NDK setup: PASS
- Android native toolchain verification: PASS
- Android ARM64 SDL native build: PASS
- Android native package generation: PASS
- unit tests: PASS
- `desktop:dist`: PASS
- desktop JAR verification: PASS
- real Android JVM native-load probe packaging: PASS
- absolute-path native-load diagnostic packaging: PASS

The current run has not yet reached the final DEBUG-14 packaging result at report creation.

## Verification

### Confirmed by source

- Mindustry uses the sibling `../Arc` checkout when local Arc is present.
- The DEBUG-14 helper obtains SDL 2.32.8 independently.
- SDL 2.32.8 direct JNI_OnLoad classes remain unchanged by this CI fix.

### Confirmed by CI/build

- The failing run reached the DEBUG-14 helper only after the Arc checkout had been verified.
- The diagnostic commit proved the Arc directory and Git metadata were healthy.
- The fix commit contains only the controller-glue probe script change plus this report.

### Confirmed by artifact inspection

- Prior CI runs verified the real `libsdl-arc.so` ARM64 artifact and its packaging checks.
- Final artifact verification for `614cdcd...` is pending.

### Confirmed by real Android runtime

- Earlier DEBUG-13A real-device probing reached `System.load(absPath)` and reported the first missing SDL Java dependency as `org/libsdl/app/SDLControllerManager`.

### Inference

- The late duplicate Git query is unnecessary because the workflow already establishes and verifies the Arc revision.

### Unknown

- The precise transient cause for the third identical Git query returning “not a git repository” after two successful queries remains unknown.

## Known limitations

- Current CI run `35505038814` is still in progress.
- DEBUG-14 controller-glue packaging success is not yet established.
- No conclusion is made about full SDL Android runtime compatibility.
- This task intentionally stops at the CI packaging boundary.

## Next task

After run `35505038814` completes:

- If DEBUG-14 packaging passes, inspect the produced diagnostic JAR and verify the four intended SDL Java classes plus unchanged `libsdl-arc.so`.
- If the packaging step fails, create a new debug task/report based on the actual failure.

Do not begin the real Android four-class runtime probe as part of this task until CI packaging itself is verified.

## Handoff

Status:
INCOMPLETE — CI verification in progress

Branch:
`android-jvm`

Baseline:
`1edfc38866aedbf7635c96cfc4b00ab592dd7ac2`

Commit:
`614cdcd6081c0d494ca60e53819ec7e80c2a5db0`

Files changed:
`scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh`
`docs/android-jvm/TASK_03C_DEBUG_14_CI_01.md`

Result:
Removed the redundant third Arc Git query after proving the Arc directory and Git metadata were valid immediately before the failure.

CI:
- `35497969143` — failure: duplicate late Arc Git query.
- `35504194009` — diagnostic: Arc filesystem/Git state confirmed healthy, third identical query failed.
- `35505038814` — current verification run, in progress.

Build:
Prior Android ARM64/native, unit-test, desktop, and diagnostic packaging stages were green before the DEBUG-14 step.

Verification:
Root cause narrowed to the redundant late Git revalidation. Current fix awaits CI completion.

Known limitations:
Exact transient mechanism behind the third Git invocation remains unknown.

Next task:
Verify run `35505038814`; then inspect the DEBUG-14 artifact only if packaging passes.
