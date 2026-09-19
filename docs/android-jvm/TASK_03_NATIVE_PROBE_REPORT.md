# TASK 03 - Android ARM64 backend-sdl Native Probe

## Task Status

**BLOCKED**

Task 03 could not be implemented or experimentally verified in the current environment. The available evidence establishes the architectural direction, but the required Android native build and runtime validation cannot be performed here.

## Baseline

- Repository: `deitzu/Mindustry`
- Working branch: `audit/task-01-native-artifact`
- Expected pre-task HEAD: `25d61c8785ab14fc379eb60217e1c56e9c4f9a68`
- Actual branch HEAD observed: `739d6c138f149cee8bd96f57159bacf2cbd77e05`
- Actual HEAD parent: `25d61c8785ab14fc379eb60217e1c56e9c4f9a68`
- Pinned Arc revision: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

The actual branch HEAD is a documentation-only commit whose parent is the expected baseline. No production-code divergence was identified.

## Files Changed

The Task 03 implementation changed no production source files.

This report is the only file added by this Task 03 result commit.

## Build

Android arm64-v8a build: **UNVERIFIED**

Artifact path: **none**

The current environment does not expose an Android NDK toolchain or Android SDK/runtime. Environment inspection found:

- `git`: available
- `clang`: available
- `adb`: unavailable
- `ndk-build`: unavailable
- `aarch64-linux-android*-clang`: unavailable
- `ANDROID_NDK_HOME`: unset
- `ANDROID_NDK_ROOT`: unset
- `ANDROID_HOME`: unset

A local checkout of the repository was also not present, so local `git status`, `git branch --show-current`, and `git rev-parse HEAD` could not be performed. The remote branch state was inspected directly through GitHub.

## Artifact

- architecture: **UNVERIFIED**
- format: **UNVERIFIED**
- SONAME: **UNVERIFIED**

No Task 03 Android shared object was produced.

## Native Dependencies

- `libSDL2-2.0.so.0`: **UNVERIFIED**
- `libGL.so.1`: **UNVERIFIED**
- `GLEW`: **UNVERIFIED**
- glibc/Linux desktop dependencies: **UNVERIFIED**

These dependencies cannot be classified from a Task 03 artifact because no artifact was produced.

## Runtime Load

Android JVM load test: **UNVERIFIED**

No Android runtime, Android-hosted JVM, or Android device/emulator was available for a native loading test.

## Evidence Classification

### Confirmed by source

1. The Mindustry repository does not contain `backends/backend-sdl/`, `arc-core/`, or `natives/`. Those components belong to the pinned Arc dependency.
2. In Arc revision `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`, `backends/backend-sdl/build.gradle` defines desktop native targets and does not define an Android native target.
3. The Linux SDL build obtains SDL2 linker flags through `sdl2-config` and explicitly adds `-Wl,-Bdynamic -lGL`.
4. `SDLGL.java` defines `GLEW_STATIC`, includes `GL/glew.h`, and invokes `glewInit()`.
5. `SDL.java` contains Linux-specific loading logic for `libSDL2.so`.
6. `SdlGraphics.java` initializes the GLEW-backed native bridge and reports `ApplicationType.desktop`.
7. Arc already provides an Android-native `addAndroid()` configuration for its core native library and uses Android-specific libraries plus `c++_static`.
8. Arc's Android backend demonstrates an existing GLES/EGL path through `AndroidGraphics` and `AndroidGL20`.
9. Mindustry uses Arc through the pinned `arcHash`, and local Arc sources are only used when a sibling local Arc checkout is available.

### Confirmed by build

None.

### Confirmed by artifact inspection

None.

### Confirmed by runtime test

None.

### Inference

The smallest technically aligned implementation remains a dedicated Android ARM64 backend-sdl path that:

- builds SDL2 for Android `arm64-v8a`
- uses Android GLES/EGL instead of desktop OpenGL
- removes the GLEW dependency from the Android variant
- statically links SDL2 where practical
- preserves the existing desktop backend
- produces an Android/bionic JNI shared library

This follows the completed Task 01 and Task 02 analysis and has not been experimentally proven in this environment.

### Unknown

- Whether the current jnigen version and build environment can successfully express the required Android backend-sdl target without additional tooling changes.
- Whether SDL2 2.32.8 can be statically integrated into the exact Arc JNI bridge with the current source layout without additional Android-specific SDL platform glue.
- The final DT_NEEDED set of a produced Android backend-sdl library.
- Whether that library can be loaded successfully by the intended Android-hosted JVM.

## Remaining Blockers

1. **Writable source boundary:** the requested backend-sdl implementation files are part of the pinned Arc dependency, not `deitzu/Mindustry`. The connected GitHub account has read access to `Anuken/Arc` but does not have write access to that repository, and no writable `deitzu/Arc` fork is available through the connected account.
2. **Android native toolchain:** no Android NDK or Android SDK is installed or exposed in the current environment.
3. **Runtime validation environment:** no Android device/emulator or Android-hosted JVM is available for the required native load test.
4. **ELF artifact:** because no Android shared object was built, architecture, SONAME, DT_NEEDED, and dependency requirements cannot be validated.

## Scope Check

The following were **NOT modified**:

- `SharedLibraryLoader`
- `OS.isAndroid`
- `ArcNativesLoader`
- `ClientLauncher`
- `DesktopLauncher`
- Mindustry renderer
- final JVM runtime integration
- Android Activity/lifecycle integration
- final packaging
- `SdlApplication.java`
- `SdlGraphics.java`
- production Arc backend-sdl source

No reset, rebase, force push, or unrelated modification was performed.

## Definition of Done

- [ ] Android arm64-v8a artifact produced
- [ ] Android/bionic target confirmed
- [ ] GLES/EGL used instead of desktop libGL
- [ ] GLEW eliminated
- [ ] dynamic desktop SDL2 eliminated
- [ ] Linux/glibc dependencies eliminated
- [ ] artifact inspected
- [ ] Android JVM/native load test passed

**Result: BLOCKED.**

This report records the Task 03 result without claiming success that was not experimentally demonstrated.
