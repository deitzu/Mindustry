# FIX_ANDROID_SDL_JAVA_GLUE

## Status

BLOCKED — production CI is not complete and physical Android ARM64 execution is unavailable in this environment.

## Objective

Package the minimum SDL 2.32.8 Android Java JNI glue required by the confirmed Android-JVM runtime failure:

`NoClassDefFoundError: org/libsdl/app/SDLControllerManager`

The glue must be packaged only with `-PandroidJvm`. Normal desktop packaging must remain unchanged.

## Baseline

Branch: `android-jvm`

Baseline commit: `707d4d2791c0fe95af01dfae4c1ef54f70d618d0`

Pinned Arc revision: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

SDL: `2.32.8`

SDL source commit: `98d1f3a45aae568ccd6ed5fec179330f47d4d356`

## Runtime blocker

### Confirmed by Android runtime

The previous real-device failure was:

```
java.lang.NoClassDefFoundError: org/libsdl/app/SDLControllerManager

Caused by: java.lang.ClassNotFoundException:
    org.libsdl.app.SDLControllerManager
```

The device had already passed Android SDL resource discovery and native file extraction, so this task targets Java SDL Android glue rather than the native `.so` path.

## Source evidence

### Confirmed by source

SDL 2.32.8 directly exposes these JNI classes:

```
org/libsdl/app/SDLActivity.class
org/libsdl/app/SDLInputConnection.class
org/libsdl/app/SDLAudioManager.class
org/libsdl/app/SDLControllerManager.class
```

The relevant package-private dependency closure identified from the actual SDL sources is:

```
org/libsdl/app/SDLJoystickHandler.class
org/libsdl/app/SDLJoystickHandler_API16.class
org/libsdl/app/SDLJoystickHandler_API19.class
org/libsdl/app/SDLHapticHandler.class
org/libsdl/app/SDLHapticHandler_API26.class
```

No entire SDL Android project or APK is packaged.

## Implementation

### Confirmed by source/diff inspection

`desktop/build.gradle` now registers an Android-JVM-only `compileAndroidJvmSdlJavaGlue` task during project configuration.

It:

- uses SDL 2.32.8 Android Java sources;
- compiles against the configured Android `android.jar`;
- validates the SDL source checkout is the pinned revision;
- writes generated output under `desktop/build/generated/android-jvm/sdl-java-glue/classes`;
- packages only the exact nine SDL Android glue class files;
- remains inactive for normal desktop builds.

The existing Android resources remain:

```
arm64-v8a/libarc.so
arm64-v8a/libsdl-arc.so
```

### Packaging verifier

`scripts/android-jvm/task-02c-verify-packaging.sh` now inspects the actual JAR and requires the exact nine-class SDL Java set.

It also rejects bundled:

```
android/*
javax/*
java/*
```

and retains the existing Android ARM64 native/ELF verification.

## CI corrections

### Confirmed by CI/build

The first implementation failed because Gradle 9.3.1 rejected registering a task from inside `desktop:dist`:

```
DefaultTaskContainer#register(String, Class, Action)
on task set cannot be executed in the current context.
```

The compile task was moved to project configuration and `dist` now consumes its output directory.

A subsequent CI run passed the Android-JVM dependency graph.

The next failure was concrete and unrelated to the Java source itself:

```
Execution failed for task ':desktop:compileAndroidJvmSdlJavaGlue'.
> SDL source checkout is not a Git checkout:
  /home/runner/work/Mindustry/SDL2-2.32.8
```

The existing SDL native probe extracted SDL from a release tarball, while the production task required Git metadata.

### Fix

`.github/workflows/ci.yml` now creates a deterministic sibling SDL checkout before the existing native probe:

```
98d1f3a45aae568ccd6ed5fec179330f47d4d356
```

and verifies the SDL header reports version `2.32.8`.

## Current CI

Continuous Build:

- run: `35608783963`
- run number: `176`
- head: `9ddd3c5545e6d631fad33fd7c970bb7881f3e85e`
- status observed: `in_progress`

At the latest observation, the build had passed:

- Android ARM64 SDL native probe;
- pinned Arc verification;
- Android JVM Arc loader overlay.

The previous dependency-graph failure was eliminated. The final production packaging result from the current run has not yet been inspected.

## Artifact verification

### Unknown

Still pending from the fixed production run:

- `arm64-v8a/libarc.so` in final JAR;
- `arm64-v8a/libsdl-arc.so` in final JAR;
- exact nine SDL Java classes in final JAR;
- absence of Android SDL glue from the normal desktop JAR;
- final artifact hashes.

The verifier itself now checks the exact class set against the actual JAR.

## Physical Android runtime

### Unknown

No ADB-connected Xiaomi M2004J19C is available in this engineering environment.

Required target:

- Xiaomi M2004J19C
- Android API 31
- arm64-v8a
- Mojo `justicia-20260910-[7e5e21b]-v3_openjdk`
- no property spoofing

Therefore removal of `SDLControllerManager` from the real-device exception chain has not been claimed.

## Commits

Implementation commits:

- `051ea9deab4d3ed17b24e8762727bb96aec7aa5f` — package SDL Android Java JNI glue
- `ebd9e8dc06cf3fbea93595a16a760f7d410334ee` — add exact SDL Java glue verifier
- `35040d0e1f992935853aea4e79b6d23eb5f199d4` — correct verifier
- `29edfa8022b5d7e2e7eba0d6f4df60da44370c03` — register Java glue task during project configuration
- `d9ebb76278788c2a8f076b3093373c14d0daca13` — consume compiled output directory directly
- `9ddd3c5545e6d631fad33fd7c970bb7881f3e85e` — provision pinned SDL source in CI

No rebase, force-push, Arc upgrade, Mojo change, or master change was used.

## Known limitations

- Local Gradle execution was unavailable because this environment has no mounted repository/toolchain.
- Current CI has not yet produced a final fixed-artifact inspection result.
- Physical Android runtime execution is unavailable here.

## Next task

Complete the fixed CI run, inspect the actual Android-JVM and normal desktop JARs, then execute the final Android-JVM JAR on the real device.

The next runtime task must stop at the first new exception after the `SDLControllerManager` boundary.

## Handoff

Status:
BLOCKED

Branch:
`android-jvm`

Baseline:
`707d4d2791c0fe95af01dfae4c1ef54f70d618d0`

Commit:
`9ddd3c5545e6d631fad33fd7c970bb7881f3e85e` plus this documentation commit

Files changed:
- `desktop/build.gradle`
- `scripts/android-jvm/task-02c-verify-packaging.sh`
- `.github/workflows/ci.yml`
- `docs/android-jvm/FIX_ANDROID_SDL_JAVA_GLUE.md`

Result:
The Android SDL Java JNI glue packaging path is implemented and the exact nine-class verifier is in place. CI source provisioning now supplies the pinned SDL 2.32.8 Git checkout required by the production compile task.

CI:
`35608783963` — in progress at report creation.

Build:
Android ARM64 SDL native probe and patched Arc rebuild stages passed. Final Android-JVM packaging result is pending.

Verification:
SDL source closure confirmed; production verifier checks the exact nine-class set; final artifact inspection pending.

Known limitations:
No physical Android ARM64 runtime is available from this environment.

Next task:
Inspect the final CI artifact and run the fixed JAR on the real Android ARM64 Mojo runtime; stop at the first new blocker.
