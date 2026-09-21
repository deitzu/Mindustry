# FIX_ANDROID_SDL_JAVA_GLUE

## Status

BLOCKED pending complete CI verification and physical Android ARM64 rerun.

The implementation is committed on branch `android-jvm`. The known Android runtime blocker being addressed is:

`NoClassDefFoundError: org/libsdl/app/SDLControllerManager`

The current execution environment has no mounted Mindustry repository, no network access for a local clone, and no ADB-connected Android device, so a physical Mojo runtime rerun cannot be performed here.

## Objective

Package the minimum SDL 2.32.8 Android Java JNI glue required by the Android-JVM `libsdl-arc.so` runtime, only when `-PandroidJvm` is active.

## Scope

Production packaging: `desktop/build.gradle`

Packaging verification: `scripts/android-jvm/task-02c-verify-packaging.sh`

This report documents the implementation and verification boundary. No upstream Arc source was modified or committed.

## Baseline

Branch: `android-jvm`

Baseline commit: `707d4d2791c0fe95af01dfae4c1ef54f70d618d0`

Pinned Arc revision: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

SDL source: 2.32.8. The existing Android native probe obtains the `SDL2-2.32.8` release source used by this build.

## Current runtime failure

Confirmed by Android runtime before this task:

```
java.lang.NoClassDefFoundError: org/libsdl/app/SDLControllerManager
Caused by: java.lang.ClassNotFoundException:
    org.libsdl.app.SDLControllerManager
```

Earlier boundaries were already proven:

- `arm64-v8a/libsdl-arc.so` resource discovery: PASS
- native extraction: PASS
- `System.load()` reached: PASS
- failure occurred at Java SDL Android glue resolution

## Source evidence

Confirmed from the SDL 2.32.8 Android Java source and existing repository diagnostic:

Direct JNI glue classes:

```
org/libsdl/app/SDLActivity.class
org/libsdl/app/SDLInputConnection.class
org/libsdl/app/SDLAudioManager.class
org/libsdl/app/SDLControllerManager.class
```

Required package-private helper classes from the same SDL sources:

```
org/libsdl/app/SDLJoystickHandler.class
org/libsdl/app/SDLJoystickHandler_API16.class
org/libsdl/app/SDLJoystickHandler_API19.class
org/libsdl/app/SDLHapticHandler.class
org/libsdl/app/SDLHapticHandler_API26.class
```

The two helper source groups are defined by SDL source layout rather than copied or reimplemented in Mindustry.

## Implementation

`desktop/build.gradle` now creates a dedicated `compileAndroidJvmSdlJavaGlue` JavaCompile task only under `-PandroidJvm`.

The task:

1. compiles only:
   - `SDLActivity.java`
   - `SDLAudioManager.java`
   - `SDLControllerManager.java`
2. uses the configured Android `android.jar`
3. uses the SDL source path for Java source closure
4. writes generated classes to:
   `desktop/build/generated/android-jvm/sdl-java-glue/classes`
5. packages only the exact nine required class files into the JAR
6. validates SDL 2.32.8 from `include/SDL_version.h`

The normal desktop build path does not create or package this Android Java task.

A first implementation attempted to register the JavaCompile task from inside the `dist` task configuration. CI with Gradle 9.3.1 rejected that with:

```
DefaultTaskContainer#register(String, Class, Action)
on task set cannot be executed in the current context.
```

The task was moved to project configuration and the JAR now consumes its output directory directly.

A second CI failure showed that the SDL acquisition path is a release tarball, not a Git checkout. The invalid `.git`/Git-SHA check was therefore replaced by a concrete SDL 2.32.8 header-version check.

## Verifier

`scripts/android-jvm/task-02c-verify-packaging.sh` now inspects the actual final JAR and requires the exact nine-class SDL Android glue set.

It also fails when `android/`, `javax/`, or `java/` classes are bundled.

Existing native verification remains in place for:

```
arm64-v8a/libarc.so
arm64-v8a/libsdl-arc.so
```

The verifier does not trust source-directory presence as proof.

## Build / CI evidence

Continuous Build run 168 reached the Android-JVM dependency stage successfully after:

- Arc checkout at the pinned revision
- Android SDK/NDK verification
- Android ARM64 SDL native probe
- deterministic Arc loader overlay
- patched Arc core rebuild
- backend-sdl rebuild

Run 168 then failed during project configuration because the JavaCompile task was registered inside `dist`. That failure was fixed.

Continuous Build run 170 then passed the Android-JVM runtime dependency graph stage and failed at the SDL Java compilation task because the Gradle task incorrectly required a Git checkout for a release tarball. That failure was fixed.

A new Continuous Build run was triggered for commit `848a9639d6bce8614b1c34f6dfb005fed2ed6975` and was still in progress at report creation.

Local required Gradle commands were not run because this execution environment has no mounted repository/toolchain. CI is therefore the authoritative reproducible build evidence available in this session.

## Final JAR inspection

Confirmed by source-level packaging configuration and verifier content:

- exact nine SDL Android Java classes are specified
- native Android resources remain part of the Android-JVM path
- no SDL APK/project is packaged
- Android Java glue is gated by `-PandroidJvm`

A completed CI artifact inspection is still required before marking this task complete.

## Desktop regression

The Android glue is guarded by `project.hasProperty("androidJvm")` and is outside the normal desktop packaging path.

A completed clean desktop artifact inspection is still required to verify that:

`org/libsdl/app/SDLControllerManager.class`

and:

`arm64-v8a/libsdl-arc.so`

are absent from the normal desktop JAR.

## Physical Android result

Not executed in this environment.

The real target remains:

- Xiaomi M2004J19C
- Android API 31
- arm64
- Mojo Launcher `justicia-20260910-[7e5e21b]-v3_openjdk`

No property spoofing or Mojo modifications were used.

## Boundary / next blocker

The intended success boundary for this task is removal of:

`NoClassDefFoundError: org/libsdl/app/SDLControllerManager`

No claim is made yet about JNI registration, SDL initialization, EGL/GLES, window creation, or renderer startup.

After the new artifact is built and installed on the physical device, stop at the first new runtime exception and make that exception the next task.

## Known limitations

- Physical Android runtime verification is unavailable in the current execution environment.
- The latest Continuous Build for the current result commit had not completed when this report was created.
- Final downloaded JAR entry inspection from the latest run is pending.

## Result commits

Implementation/history commits in this task include:

- `051ea9deab4d3ed17b24e8762727bb96aec7aa5f` — package SDL Java glue
- `ebd9e8dc06cf3fbea93595a16a760f7d410334ee` — add SDL glue verifier
- `35040d0e1f992935853aea4e79b6d23eb5f199d4` — correct verifier
- `29edfa8022b5d7e2e7eba0d6f4df60da44370c03` — register Java glue task during configuration
- `bee78639070a3cf13fb613a32a7a55ac392688fa` — move task registration outside `dist`
- `d9ebb76278788c2a8f076b3093373c14d0daca13` — consume compiled output directory directly
- `848a9639d6bce8614b1c34f6dfb005fed2ed6975` — validate SDL source release version

## Next task

Rerun/complete Continuous Build for `848a9639d6bce8614b1c34f6dfb005fed2ed6975`, inspect the produced Android-JVM JAR and clean desktop JAR, then perform the physical Mojo Android ARM64 runtime test and stop at the first new runtime boundary.
