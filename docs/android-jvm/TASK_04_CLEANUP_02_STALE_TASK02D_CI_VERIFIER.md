# TASK-04-CLEANUP-02 — Retire Stale TASK-02D CI Verifier

## Status

**BLOCKED BY FIRST NEW FAILURE**

The obsolete TASK-02D VERIFY-02 packaged `SharedLibraryLoader` bytecode verifier was successfully removed from `.github/workflows/ci.yml`.

Continuous Build then passed the previous failure point and exposed the next genuine failure in the existing Android-JVM Arc native load probe. Per the task stop condition, no unrelated fix was attempted.

## Branch

`android-jvm`

## Baseline

`8c4c1bc9df2660e3ec848de64c2f378296c4c070`

## Implementation Commit

`ec873c1f1e61d8181c000b1f8d278c1dca82900a`

Message:

`chore(android-jvm): retire stale TASK-02D CI verifier`

## Report Commit

`991f19b9bedd74fcc854e8a236d88c411cec1207`

## Arc Revision

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

Confirmed by the Continuous Build checkout. The pinned Arc revision was unchanged.

## Exact Stale Verifier Removed

The obsolete block was inside the existing step:

`Package Android-JVM Arc native artifact`

Removed:

- `TASK 02D: inspect packaged Arc loader class` diagnostic output;
- `javap -classpath desktop/build/libs/Mindustry.jar -c -p arc.util.SharedLibraryLoader`;
- output file `ci-artifacts/task02d/packaged-shared-library-loader.javap.txt`;
- the `isAndroidRuntime` packaged-bytecode check;
- the `androidResourcePath` packaged-bytecode check;
- the associated failure messages for those checks.

Retained in the same step:

- Android-JVM `desktop:dist`;
- `Mindustry-android-jvm.jar` packaging copy;
- `scripts/android-jvm/task-02c-verify-packaging.sh`.

## Valid Android-JVM Probes Preserved

The workflow still contains the existing valid probe/build stages, including:

- Android ARM64 SDL native probe;
- deterministic Arc loader overlay;
- patched Arc core rebuild;
- Android-JVM runtime dependency inspection;
- Android-JVM Arc native load probe package;
- real Android JVM native load probe;
- Android absolute-path native load diagnostic;
- SDL Android controller Java glue diagnostic;
- Android JVM native loader boundary probe.

The obsolete packaged-bytecode verifier markers are absent from the current `ci.yml`.

## Scope Verification

The implementation commit changes only:

`.github/workflows/ci.yml`

with **0 additions / 12 deletions**.

No production source file was modified.

The following were not modified:

- `AndroidJvmLauncher`
- `SharedLibraryLoader.java`
- Arc overlay patch
- Arc revision
- `desktop/build.gradle`
- `build.gradle`
- `SDLGL.java`
- backend-sdl source
- GLES/native source
- native linker configuration
- Android APK backend
- launcher behavior

## Continuous Build

Workflow:

`.github/workflows/ci.yml`

Workflow name:

`Continuous Build`

Run:

`35585254909`

Main job:

`106286981227` — `Test and build`

Parallel native probe job:

`106286981080` — `Arc Android ARM64 native probe`

### Result

- Arc Android ARM64 native probe: **PASS**
- Main `Test and build`: **FAIL**
- Previous stale TASK-02D verifier: **removed and no longer the failure point**
- First new failure: `Build Android JVM Arc native load probe package`

Exact failing command:

`bash scripts/android-jvm/task-02d-build-arc-load-probe.sh desktop/build/libs/Mindustry.jar`

Exact failure:

`Mindustry JAR does not contain patched SharedLibraryLoader.class`

The job exited with code 1 immediately after this failure.

## Build Results

The Continuous Build progressed through the following successfully before the stop condition:

- Arc checkout at the required pinned revision;
- Android toolchain installation and verification;
- Android ARM64 SDL native probe;
- Arc loader overlay application;
- patched Arc core rebuild;
- Android-JVM runtime dependency inspection;
- Android-JVM `desktop:dist`.

The Android-JVM `desktop:dist` invocation completed successfully before the first new failure.

The stale verifier failure from TASK-04-CLEANUP-01 no longer occurs.

## Acceptance Matrix

| Acceptance | Result | Evidence |
|---|---|---|
| No stale TASK-02D VERIFY-02 packaging verifier remains in `ci.yml` | **PASS** | Source inspection: old diagnostic, packaged `javap`, output, and grep checks absent |
| Valid Android-JVM native probes remain | **PASS** | Existing probe steps remain in `ci.yml` |
| `:core:compileJava` passes | **PASS** | Completed successfully in Continuous Build before failure |
| `:desktop:compileJava` passes | **PASS** | Completed successfully in Continuous Build before failure |
| `./gradlew -PandroidJvm desktop:dist --rerun-tasks` passes | **PASS** | Completed successfully before first new failure |
| Normal `./gradlew desktop:dist --rerun-tasks` passes | **NOT REACHED** | Workflow stopped at first new failure |
| Android-JVM JAR Main-Class = `mindustry.androidjvm.AndroidJvmLauncher` | **NOT FRESHLY VERIFIED** | Workflow stopped before a fresh manifest check |
| Normal desktop JAR Main-Class = `mindustry.desktop.DesktopLauncher` | **NOT REACHED** | Workflow stopped before normal desktop packaging |
| Arc SHA = `8eb00ffff0126d0576c67df46f99b8f6bccd96fe` | **PASS** | CI cloned/checked out exact pinned revision |
| No unrelated production-source modifications | **PASS** | Implementation commit contains only `.github/workflows/ci.yml` |

## Result

**Cleanup objective: PASS. Full acceptance: BLOCKED.**

The obsolete CI-side TASK-02D VERIFY-02 packaged-loader verifier has been retired without changing valid Android-JVM probes or production code.

The next failure is a different existing probe:

`task-02d-build-arc-load-probe.sh`

It reports that the produced Mindustry JAR does not contain the patched Arc `SharedLibraryLoader.class`.

This is the first genuine post-cleanup failure, so the task stops here as required.

## Known Limitations

- Full Continuous Build is not green.
- Normal desktop packaging and both final JAR manifest checks were not reached.
- No Android runtime execution was performed.
- The new failure requires a separate focused investigation; it was not modified as part of this cleanup task.

## Next Task

**TASK-04-DEBUG-01 — Investigate why the Android-JVM JAR produced by `desktop:dist` does not contain the patched Arc `SharedLibraryLoader.class`, starting from the actual dependency/package inputs.**
