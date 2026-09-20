# TASK 03C-DEBUG-09 — Android GLES3 Linkage Compatibility

## Status

**Complete.** The Android ARM64 GLES3 linkage issue is fixed. The native probe now builds and links the JNI shared library successfully. No new native linker failure appeared, so DEBUG-09 stops at the accepted native feasibility boundary.

The overall Continuous Build workflow is **failure** because a later `tests:test` step configures the locally cloned Arc backend without `SDL2_ANDROID_ROOT`. This occurs after the native probe has already passed and is outside the DEBUG-09 GLES linkage scope.

## Branch

`ci/task-ci-01`

## Baseline

`42cea81b673a394e2d26adb22b361036fcc42846`

## Result Commit

`eb73cf6a2fe3c98ac0780f754e26515546ea6d40`

## Pinned Dependencies

- Arc: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- SDL: 2.32.8
- jnigen: 3.1.2
- Android ABI: arm64-v8a
- Android minimum API target: 21
- Android NDK: 30.0.16248370

## Original Linker Failure

Before this task, the Android JNI object compiled successfully but the shared-library link failed with undefined GLES3 symbols, beginning with:

```
ld.lld: error: undefined symbol: glReadBuffer
ld.lld: error: undefined symbol: glDrawRangeElements
ld.lld: error: undefined symbol: glTexImage3D
```

The failure set also included:

- `glTexSubImage3D`
- `glCopyTexSubImage3D`
- `glGenQueries`
- `glDeleteQueries`
- `glIsQuery`
- `glBeginQuery`
- `glEndQuery`
- `glGetQueryiv`
- `glGetQueryObjectuiv`
- `glUnmapBuffer`
- `glDrawBuffers`
- `glUniformMatrix2x3fv`
- `glUniformMatrix3x2fv`
- `glUniformMatrix2x4fv`
- `glUniformMatrix4x2fv`
- `glUniformMatrix3x4fv`
- `glUniformMatrix4x3fv`

## Investigation

### Confirmed by CI/toolchain

The CI native environment used:

```
ANDROID_NDK_HOME=/usr/local/lib/android/sdk/ndk/30.0.16248370
ANDROID_NDK_VERSION=30.0.16248370
```

The generated Android target was then linked with `-lGLESv3`.

The resulting native probe produced:

```
/home/runner/work/Mindustry/Mindustry/../Arc/backends/backend-sdl/libs/android32/arm64-v8a/libsdl-arc.so
```

This proves the configured NDK/toolchain provided the required GLESv3 linkage for this target.

### Root-cause reasoning

The previous Android target exposed GLES3 declarations through:

```
#include <GLES3/gl3.h>
#include <GLES2/gl2ext.h>
```

but its generated Android linker configuration used `-lGLESv2` for the JNI shared library.

The before/after build evidence establishes the practical mismatch:

```
GLES3 source calls + -lGLESv2
        -> undefined GLES3 linker symbols

GLES3 source calls + -lGLESv3
        -> native link succeeds
```

The exact linkage change therefore addresses the observed failure layer.

## Implementation

Only the Android library entry in the existing deterministic Arc overlay was changed:

Before:

```groovy
"-lGLESv2"
```

After:

```groovy
"-lGLESv3"
```

The existing:

```groovy
"-lGLESv1_CM"
```

was preserved.

No `SDLGL.java` changes were made in DEBUG-09.

The permanent project modification remains in:

```
ci/android-jvm/task03c-backend-sdl.patch
```

The patch was updated through the existing overlay mechanism; upstream Arc was not modified or committed.

## Generated Android.mk Evidence

CI inspected the generated:

```
Arc/backends/backend-sdl/build/jnigen/target/android32/Android.mk
```

The actual linker configuration was:

```
LOCAL_LDLIBS := ".../SDL2-2.32.8/build" "-lSDL2" "-llog" "-landroid" "-ldl" "-lGLESv3" "-lGLESv1_CM"
```

This is **confirmed by generated artifact/log**.

## CI

Continuous Build:

`35477585128`

Native probe stage:

- Android NDK/toolchain setup: passed
- Arc pin verification: passed
- deterministic overlay application: passed
- SDL 2.32.8 setup: passed
- `jnigenBuildAllAndroid`: passed
- Android ARM64 JNI shared-library link: passed
- generated Android.mk inspection: passed
- ELF/native compatibility probe: passed
- artifact upload: passed

The native probe artifact was uploaded successfully as:

```
Android-SDL-native-probe-eb73cf6a2fe3c98ac0780f754e26515546ea6d40
```

Artifact ID: `10594961972`

## Build Result

**Confirmed by CI/build:** the previous GLES3 linker failures are gone.

The build reached:

```
[arm64-v8a] Compile++      : sdl-arc <= arc_backend_sdl_jni_SDLGL.cpp
[arm64-v8a] SharedLibrary  : libsdl-arc.so
[arm64-v8a] Install        : libsdl-arc.so => /home/runner/work/Mindustry/Arc/backends/backend-sdl/libs/android32/arm64-v8a/libsdl-arc.so
BUILD SUCCESSFUL in 3s
```

No new native linker error followed this stage.

## Artifact Verification

The produced JNI shared library was inspected by the existing probe and reported:

```
ELF class=ELF64
ELF machine=AArch64
SONAME=libsdl-arc.so
libm.so
liblog.so
libandroid.so
libdl.so
libGLESv3.so
libGLESv1_CM.so
libc.so
JNI symbol count: 566
Forbidden dependency scan: PASS
Android native probe: PASS
```

### Evidence classification

**Confirmed by source**
- Android target contains `-lGLESv3`.
- `-lGLESv1_CM` remains.
- Desktop Linux/Windows/macOS library configuration was not changed by the DEBUG-09 implementation commit.

**Confirmed by CI/build**
- Arc remained pinned to `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`.
- Android.mk contains `-lGLESv3`.
- `SDLGL.cpp` compiles.
- The previous GLES3 undefined-symbol linker failures disappear.
- `libsdl-arc.so` links and installs for arm64-v8a.
- Native artifact verification passes.

**Confirmed by generated artifact**
- Final JNI library is ELF64/AArch64.
- Final dynamic dependency set contains `libGLESv3.so`.
- Forbidden dependency scan passes.

**Inferred**
- The original GLES3 linker failure was caused by the Arc Android target using the GLES2 library while directly referencing GLES3 entry points. The build delta strongly supports this explanation.

**Unknown**
- Runtime loading/execution under Android JVM has not been tested.
- Actual device-side GLES driver behavior has not been tested.

## Desktop Preservation

The DEBUG-09 implementation commit changes only:

```
ci/android-jvm/task03c-backend-sdl.patch
```

and only changes the Android library entry inside the overlay.

Desktop build verification is not available from Continuous Build `35477585128` because the workflow stopped in the later unit-test step before `desktop:dist`.

The later failure was:

```
SDL2_ANDROID_ROOT is required for the Android SDL probe
```

during `tests:test` project configuration. This is not a GLES linker failure and was not modified in DEBUG-09.

## Known Limitations

- The overall Continuous Build remains red because of the later `tests:test` environment/configuration failure.
- Desktop `desktop:dist` was therefore skipped in this run.
- Runtime Android loading and execution remain unverified.
- No claim is made yet about actual device-side GLES capability beyond the native linkage probe.

## Next Task

**TASK 03C-DEBUG-10 — Android Native Artifact / Linkage Follow-up**

The GLES3 native linkage barrier is cleared. The next task should inspect the remaining native feasibility boundary, starting with the generated ARM64 artifact and its JNI/native integration requirements. Do not alter runtime code until the native artifact boundary is fully verified.
