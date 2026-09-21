# TASK-04-DEBUG-01 — Investigate Patched SharedLibraryLoader Packaging

## Status

**BLOCKED BY FIRST NEW FAILURE AFTER PACKAGING FIX**

The packaging cause has been identified and the smallest CI-side repair has been implemented: refresh the Arc `backend-sdl` JAR after the patched Arc core loader is rebuilt.

The repaired Android-JVM JAR was directly verified to contain the patched `SharedLibraryLoader.class`.

Continuous Build subsequently reached the existing `task-02d-build-arc-load-probe.sh` probe-package stage and failed there with exit code 1. No speculative fix was applied.

## Branch

`android-jvm`

## Baseline

`24a0008721e0519bb9755b94295637813fa2fd24`

## Implementation Commit

`cb580561475f1161d986f021f5e4ec34535e5316`

## Final Clean Commit

`2d2be25dc68fab989538f0541f6f4ad9124e4da1`

The final clean commit removes temporary DEBUG-01 instrumentation while retaining the actual packaging repair.

## Arc Revision

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

Confirmed in the relevant Continuous Build runs.

## Original Failure

Continuous Build run `35585254909` reported:

`Mindustry JAR does not contain patched SharedLibraryLoader.class`

The preceding command:

`./gradlew -PandroidJvm desktop:dist --rerun-tasks --stacktrace`

completed successfully.

## Investigation

### RuntimeClasspath evidence

Temporary CI instrumentation enumerated the actual `:desktop:runtimeClasspath` inputs used by `desktop:dist`.

Two inputs contained `arc/util/SharedLibraryLoader.class`:

| RuntimeClasspath order | Absolute path | Arc source | Loader SHA-256 | Patched |
|---|---|---|---|---|
| 9 | `/home/runner/work/Mindustry/Arc/backends/backend-sdl/build/libs/backend-sdl-1.0.jar` | Yes | `68370af470a5276d404371390393e5cb937e4d9545a13ddaaca9c92a74cf6c00` | **No** |
| 11 | `/home/runner/work/Mindustry/Arc/arc-core/build/libs/arc-core-1.0.jar` | Yes | `08b375d5edb93f000e49208a527e380c540a23eda9817db378d783cc8470d925` | **Yes** |

The desktop output directory:

`/home/runner/work/Mindustry/Mindustry/desktop/build/classes/java/main`

did not contain `arc/util/SharedLibraryLoader.class`.

### Bytecode evidence

The `backend-sdl-1.0.jar` copy lacked:

- `isAndroidRuntime`
- `androidResourcePath`

The `arc-core-1.0.jar` copy contained:

- `isAndroidRuntime`
- `androidResourcePath`
- absolute `System.load(...)`

### Source evidence for the duplicate

The pinned Arc `backends/backend-sdl/build.gradle` defines a `preJni` task which copies:

`$rootDir/arc-core/build/classes/java/main`

into:

`$rootDir/backends/backend-sdl/build/classes/java/main`

That deliberately embeds Arc core classes into the backend-sdl artifact.

## Root Cause

**Confirmed by source + CI/build + artifact inspection**

The patched loader was correctly produced by Arc `arc-core`, but `backend-sdl` had already copied an older Arc core class into its own JAR.

The relevant sequence was:

1. Android SDL native probe runs.
2. Arc backend-sdl `preJni` copies Arc core classes while the loader is still unpatched.
3. backend-sdl JAR contains the old `SharedLibraryLoader.class`.
4. CI applies the Android-JVM loader overlay later.
5. Arc `arc-core` is rebuilt with the patched class.
6. `:desktop:runtimeClasspath` therefore contains both copies.
7. `desktop:dist` expands runtime JARs with `zipTree`.
8. `duplicatesStrategy = DuplicatesStrategy.EXCLUDE` preserves the first encountered copy.
9. backend-sdl is runtimeClasspath input #9, while patched arc-core is #11, so the stale backend-sdl copy wins.

## Implementation

The smallest compatible repair was added to CI after:

- applying the Arc loader overlay;
- rebuilding patched Arc core.

The workflow now explicitly refreshes the generated backend-sdl artifact:

`./gradlew :backends:backend-sdl:preJni :backends:backend-sdl:jar --rerun-tasks --stacktrace --console=plain`

This causes backend-sdl's embedded Arc core classes to be copied from the patched Arc core output before the Mindustry packaging step.

No production source, Arc source, overlay patch, `desktop/build.gradle`, or runtime architecture was modified.

## Fix Verification

Continuous Build run:

`35587398481`

The refresh step passed.

After refresh, the two runtimeClasspath loader candidates both had SHA-256:

`08b375d5edb93f000e49208a527e380c540a23eda9817db378d783cc8470d925`

The final:

`desktop/build/libs/Mindustry.jar`

contained `arc/util/SharedLibraryLoader.class` with the same SHA-256:

`08b375d5edb93f000e49208a527e380c540a23eda9817db378d783cc8470d925`

The final JAR bytecode also contained:

- `isAndroidRuntime`
- `androidResourcePath`
- absolute `System.load(...)`

This directly proves the intended patched loader was selected for packaging.

## Build Results

Run `35587398481` successfully completed:

- Arc checkout at `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- Android native toolchain verification
- Android ARM64 SDL native probe
- Arc loader overlay
- patched Arc core rebuild
- backend-sdl refresh
- Android-JVM runtime dependency inspection
- Android-JVM `desktop:dist`
- `:core:compileJava`
- `:desktop:compileJava`

The task then reached:

`bash scripts/android-jvm/task-02d-build-arc-load-probe.sh desktop/build/libs/Mindustry.jar`

Its initial loader verification passed and the script entered:

`TASK 02D: verify Android JVM Arc native load probe package`

The script then exited with code 1.

No specific failing sub-check was printed in the available workflow log.

## First New Blocker

**Unknown / separate follow-up**

The original loader-packaging failure is resolved.

The current first failure is now inside the existing Android-JVM Arc native load probe package stage, after the patched loader is already present and verified in the Mindustry JAR.

Per the task stop condition, that second failure was not investigated or modified.

## Acceptance / Verification Matrix

| Item | Result |
|---|---|
| Duplicate loader candidates identified | **PASS** |
| Actual stale winner identified | **PASS** |
| Root cause confirmed from source/build/artifact evidence | **PASS** |
| Minimal packaging repair implemented | **PASS** |
| Patched loader present in final Mindustry JAR | **PASS** |
| Patched Android runtime methods present | **PASS** |
| `:core:compileJava` | **PASS** |
| `:desktop:compileJava` | **PASS** |
| Android-JVM `desktop:dist` | **PASS** |
| Normal `desktop:dist` after repair | **NOT REACHED** |
| Android-JVM final manifest freshly verified | **NOT REACHED** |
| Normal desktop manifest freshly verified | **NOT REACHED** |
| Arc SHA | **PASS** |
| Unrelated production modifications | **NONE** |

## Temporary Diagnostics

The temporary DEBUG-01 runtimeClasspath diagnostics were removed after the cause and repair were verified.

The final clean workflow retains only the actual backend-sdl refresh fix.

## Files Changed

Final clean state changes relevant to this task:

- `.github/workflows/ci.yml`
- `docs/android-jvm/TASK_04_DEBUG_01_ARC_LOADER_PACKAGING.md`

No production source file was changed.

## Known Limitations

- Continuous Build is not fully green because the existing `task-02d-build-arc-load-probe.sh` probe-package stage fails first after the packaging fix.
- Normal desktop packaging and final manifest verification were not reached.
- No Android runtime execution was performed.
- The exact internal check responsible for the probe-package exit code 1 remains unknown.

## Next Task

**TASK-04-DEBUG-02 — Diagnose the first post-packaging failure in `task-02d-build-arc-load-probe.sh`, beginning with the exact command/check that exits with status 1.**
