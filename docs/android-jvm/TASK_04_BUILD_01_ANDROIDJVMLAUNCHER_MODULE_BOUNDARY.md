# TASK-04-BUILD-01 — AndroidJvmLauncher Module Boundary

## Status

**PASS**

The AndroidJvmLauncher module-boundary blocker is resolved and the result is verified by a dedicated GitHub Actions workflow.

## Branch

`android-jvm`

## Baseline

`64ea7aeecb9f740ab08d7fd7a98583638464e8c6`

## Arc Revision

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

The workflow used for the final verification cloned and checked out this exact Arc revision before applying the existing deterministic loader overlay.

## Problem

The previous Android-JVM source location was:

`core/src/mindustry/androidjvm/AndroidJvmLauncher.java`

The class imports Arc `backend-sdl` APIs, including `arc.backend.sdl.*`.

The `:core` project does not declare Arc `backends:backend-sdl`; the `:desktop` project already declares it.

The earlier current-state CI failure was:

` :core:compileJava -> AndroidJvmLauncher.java:4 -> error: package arc.backend.sdl does not exist `

This was the first confirmed blocker in TASK-04 runtime reconnaissance.

## Investigation

### Confirmed by source

The root `build.gradle` dependency structure is:

`:core`

- Arc `arc-core`
- Arc extensions such as `flabel`, `freetype`, `g3d`, `fx`, and `arcnet`
- no `backends:backend-sdl`

`:desktop`

- `project(":core")`
- Arc `extensions:profiling`
- Arc `extensions:discord`
- Arc native/file-dialog dependencies
- Arc `backends:backend-sdl`

The desktop module therefore already has the compile-time dependency required by AndroidJvmLauncher.

### Confirmed by source

`desktop/build.gradle` already dynamically selects:

`mindustry.androidjvm.AndroidJvmLauncher`

when `androidJvm` is present, otherwise:

`mindustry.desktop.DesktopLauncher`.

No Main-Class redesign was required.

### Confirmed by source and CI

The launcher source can live in `:desktop` while retaining:

`package mindustry.androidjvm;`

No runtime behavior change was required by the move.

## Implementation

The launcher was moved from:

`core/src/mindustry/androidjvm/AndroidJvmLauncher.java`

to:

`desktop/src/mindustry/androidjvm/AndroidJvmLauncher.java`

The package declaration remained exactly:

`package mindustry.androidjvm;`

The stale TASK-02D diagnostic property:

`androidJvm=true`

was also removed from `gradle.properties`, so normal Gradle verification could select `DesktopLauncher` without a permanent Android-JVM override.

No `backend-sdl` dependency was added to `:core`.

After CI exposed missing imports that had been hidden by the original compilation boundary, only the imports required to compile the moved source in `:desktop` were added:

- `arc.Files.*`
- `arc.struct.*`
- `arc.util.Log.*`
- `mindustry.desktop.ErrorDialog`
- `mindustry.gen.*`
- `mindustry.net.Net.*`
- `mindustry.mod.Mods.*`
- `mindustry.type.*`
- `mindustry.ui.dialogs.*`

The final two unresolved symbols were verified from source locations:

- `ErrorDialog` is in `mindustry.desktop.ErrorDialog`.
- `NetProvider` is provided through `mindustry.net.Net.*`.

No launcher logic was rewritten.

## Build Evidence

### Final dedicated verification workflow

Workflow:

`.github/workflows/task04-build-01.yml`

Final run:

`35580411393`

Job:

`106271739313`

Result:

**PASS**

The workflow completed all verification steps successfully.

### Core compilation

Command:

`./gradlew :core:compileJava --stacktrace --console=plain`

Result:

**BUILD SUCCESSFUL**

This is the key acceptance point: `:core:compileJava` now succeeds without any `backend-sdl` dependency being added to `:core`.

### Desktop compilation

Command:

`./gradlew :desktop:compileJava --stacktrace --console=plain`

Result:

**BUILD SUCCESSFUL**

### Android-JVM JAR

Command:

`./gradlew -PandroidJvm desktop:dist --rerun-tasks --stacktrace --console=plain`

Result:

**BUILD SUCCESSFUL**

CI reported:

`BUILD SUCCESSFUL in 1m 13s`

## JAR Verification

The generated artifact was:

`desktop/build/libs/Mindustry.jar`

The workflow directly inspected the JAR manifest and archive entries.

### Android-JVM manifest

Confirmed by artifact inspection:

`Main-Class: mindustry.androidjvm.AndroidJvmLauncher`

The following entry was also confirmed present:

`mindustry/androidjvm/AndroidJvmLauncher.class`

Therefore:

**Android-JVM Main-Class + launcher class: PASS**

### Normal desktop manifest

After the Android-JVM JAR check, the workflow ran:

`./gradlew desktop:dist --rerun-tasks --stacktrace --console=plain`

Result:

**BUILD SUCCESSFUL**

CI reported:

`BUILD SUCCESSFUL in 48s`

The final desktop manifest was:

`Main-Class: mindustry.desktop.DesktopLauncher`

The following entry was also confirmed:

`mindustry/desktop/DesktopLauncher.class`

Therefore:

**Desktop Main-Class + launcher class: PASS**

## Desktop Regression

**Confirmed by CI/build**

Normal desktop packaging remains intact.

Verified:

- normal `desktop:dist` succeeds;
- normal manifest selects `mindustry.desktop.DesktopLauncher`;
- normal desktop launcher class is present.

No Android-JVM setting remains forced in `gradle.properties`.

## Changes Made

Production source changes:

1. Move:
   `core/src/mindustry/androidjvm/AndroidJvmLauncher.java`
   -> `desktop/src/mindustry/androidjvm/AndroidJvmLauncher.java`

2. Add only compile-required imports to the moved launcher.

3. Remove the temporary `androidJvm=true` property from `gradle.properties`.

CI-only diagnostic file:

`.github/workflows/task04-build-01.yml`

was used to execute the required verification and is removed after evidence capture.

Documentation:

`docs/android-jvm/TASK_04_BUILD_01_ANDROIDJVMLAUNCHER_MODULE_BOUNDARY.md`

## Commit History

Focused implementation began with:

`d4f8519f2f51ef8fd27c3cd5e07d6fa838c5abb7`

Message:

`fix(android-jvm): move AndroidJvmLauncher to desktop module`

CI then exposed missing imports in the moved source. Those were fixed incrementally in:

- `2e92dc74dc950161efd70b3ab93139e3ebe3b93b`
- `01b1decb2f079499ed1da8b9dc3642157353c623`

This incremental history is preserved because CI failures were real evidence and the branch is not rebased or rewritten.

## Result

**Confirmed by CI/build**

The compile-time module boundary is resolved.

The final state satisfies the task's intended structure:

`core`

contains shared game/client logic and does **not** depend on `backend-sdl` solely for AndroidJvmLauncher.

`desktop`

contains AndroidJvmLauncher and already provides:

`project(":core")`

plus:

`arcModule("backends:backend-sdl")`

The Android-JVM entry point remains:

`mindustry.androidjvm.AndroidJvmLauncher`

and the normal desktop entry point remains:

`mindustry.desktop.DesktopLauncher`.

## Known Limitations

- This task verifies Java/module compilation and JAR entry-point packaging only.
- It does not prove Android runtime execution.
- It does not prove native loading, JNI initialization, SDL_Init, EGL/GLES, filesystem, input, audio, or full Mindustry startup.
- The generic Continuous Build had an independent Arc GitHub API 403 during one earlier run; the dedicated task workflow cloned the exact pinned Arc revision directly and completed successfully. This did not become a source/build blocker for the final verification.
- Temporary verification PRs from earlier CI experimentation remain historical project state and were not merged into `master`.

## Next Task

Return to the Android-JVM runtime reconnaissance path.

The next focused runtime task should rerun the real Android JVM test at the last known runtime boundary after DEBUG-14:

`real Android JVM`

-> four SDL Android JNI_OnLoad Java classes

-> observe the next genuine result.

Do not preemptively redesign SDL, GLES, SharedLibraryLoader, or the Android APK backend before obtaining that runtime evidence.
