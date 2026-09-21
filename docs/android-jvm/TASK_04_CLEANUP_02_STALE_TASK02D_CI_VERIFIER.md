# TASK-04-CLEANUP-02 — Retire Stale TASK-02D CI Verifier

## Status

**IN PROGRESS**

The obsolete TASK-02D VERIFY-02 packaged `SharedLibraryLoader` bytecode verification was removed from `.github/workflows/ci.yml`. Continuous Build is required to verify the complete workflow before closure.

## Branch

`android-jvm`

## Baseline

`8c4c1bc9df2660e3ec848de64c2f378296c4c070`

## Arc Revision

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

## Objective

Retire only the remaining obsolete TASK-02D VERIFY-02 packaging verifier from `.github/workflows/ci.yml`.

## Investigation

The current workflow was inspected before modification.

The obsolete verifier was identified inside:

`Package Android-JVM Arc native artifact`

The stale logic consisted of:

- the `TASK 02D: inspect packaged Arc loader class` diagnostic banner;
- `javap` against `arc.util.SharedLibraryLoader` from `desktop/build/libs/Mindustry.jar`;
- the generated `packaged-shared-library-loader.javap.txt` diagnostic output;
- the `isAndroidRuntime` and `androidResourcePath` grep checks that failed the Continuous Build.

The following adjacent Android-JVM steps were retained because they are still valid build/probe work:

- Android ARM64 SDL native probe;
- Android JVM Arc loader overlay;
- rebuilding patched Arc core;
- Android-JVM runtime dependency inspection;
- Android-JVM packaging verification script;
- Android JVM Arc native load probe package;
- real Android JVM native load probe;
- Android absolute-path native load diagnostic;
- SDL Android controller Java glue diagnostic;
- Android JVM native loader boundary probe.

No production source file was modified.

## Implementation

Removed only the stale packaged-loader verification commands from the `Package Android-JVM Arc native artifact` step.

The step still:

1. builds the Android-JVM JAR with `./gradlew -PandroidJvm desktop:dist --rerun-tasks --stacktrace`;
2. copies the JAR to the existing Android-JVM packaging artifact location;
3. runs `scripts/android-jvm/task-02c-verify-packaging.sh`.

No CI redesign was performed.

## Files Changed

- `.github/workflows/ci.yml`
- `docs/android-jvm/TASK_04_CLEANUP_02_STALE_TASK02D_CI_VERIFIER.md`

The implementation commit changes only `.github/workflows/ci.yml`, with 12 deletions and no additions.

## Acceptance Criteria

1. No stale TASK-02D VERIFY-02 packaging verifier remains in `ci.yml`.
2. Valid Android-JVM native probes remain.
3. `:core:compileJava` passes.
4. `:desktop:compileJava` passes.
5. Android-JVM `desktop:dist` passes.
6. Normal `desktop:dist` passes.
7. Android-JVM JAR manifest contains `Main-Class: mindustry.androidjvm.AndroidJvmLauncher`.
8. Normal desktop JAR manifest contains `Main-Class: mindustry.desktop.DesktopLauncher`.
9. Arc remains pinned to `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`.
10. No unrelated production-source modifications.

## CI

**PENDING**

Continuous Build must be evaluated on the final resulting commit.

## Build

**PENDING**

The previous TASK-04-CLEANUP-01 run established that the Android-JVM `desktop:dist` itself succeeds before the stale CI-side verifier fails. This task must confirm that the later workflow stages now complete.

## Verification

Source verification before CI:

- stale packaged `SharedLibraryLoader` bytecode checks are absent from the modified `ci.yml` section;
- the Android-JVM native probe steps remain present;
- the Arc overlay and pinned revision logic remain present.

Artifact and manifest verification: **PENDING CI**.

## Known Limitations

No Android runtime execution is part of this cleanup task.

If Continuous Build exposes a new genuine failure after the obsolete verifier is removed, that failure will be recorded as the first new blocker and no unrelated fix will be attempted in this task.

## Next Task

After a successful full Continuous Build, use the verified Android-JVM JAR for the real Android runtime reconnaissance path. Otherwise, create a focused debug task for the first genuine new failure.
