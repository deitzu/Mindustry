# TASK-04-RUNTIME-03 — Package Android SDL JNI Resource

Status: **BLOCKED — physical Android ARM64 rerun required**

## Task

Package the existing pinned Arc/backend-sdl Android ARM64 JNI library into the Android-JVM production Mindustry JAR at the exact resource path required by the Android JVM loader:

`arm64-v8a/libsdl-arc.so`

Keep the existing Android Arc resource `arm64-v8a/libarc.so` unchanged and preserve normal desktop packaging.

## Repository State

- Branch: `android-jvm`
- Baseline: `9d3752ec87cccd5d3a659d46c0d101697c12fa15`
- Result commit: `fa0e6e12a8de43829be0ebf62b65bd372f242623`
- Pinned Arc revision: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- Previous implementation commit: `8be6c427aba6d0947f46e2fe33127400fbaa0657`

## Runtime Blocker

### Confirmed by real Android runtime

The first new physical Android ARM64 Mojo JVM failure after TASK-04-RUNTIME-01 was:

```
java.lang.ExceptionInInitializerError
    at arc.backend.sdl.SdlApplication.init(SdlApplication.java:116)
    at arc.backend.sdl.SdlApplication.<init>(SdlApplication.java:39)
    at mindustry.androidjvm.AndroidJvmLauncher.main(AndroidJvmLauncher.java:37)

Caused by: arc.util.ArcRuntimeException:
    Couldn't load shared library 'sdl-arc' for target: Linux, 64-bit

Caused by: arc.util.ArcRuntimeException:
    Unable to read file for extraction: arm64-v8a/libsdl-arc.so
```

This established that the previous `Core.files == null` boundary was passed and that SDL initialization was the next real runtime boundary.

The missing resource is the first blocker addressed by this task.

## Source / Build Evidence

### Confirmed by source

Pinned Arc `SdlApplication` calls its native `init()` before assigning `Core.files`; its SDL initialization loads the `sdl-arc` native library.

The Android-JVM Arc loader overlay maps the Android resource for `sdl-arc` to:

`arm64-v8a/libsdl-arc.so`

### Confirmed by CI/build

TASK-03C on pinned Arc revision produced the actual Android ARM64 SDL native package:

```
../Arc/backends/backend-sdl/libs/sdl-arc-natives-arm64-v8a.jar
```

The package entry is exactly:

```
libsdl-arc.so
```

The produced Android native ELF was confirmed as ELF64/AArch64 with SONAME `libsdl-arc.so`.

The relevant native library was built by the established tasks:

```
jnigenBuildAndroid_arm64-v8a
jnigenPackageAndroid_arm64-v8a
```

No new native build architecture was introduced.

## Implementation

### Confirmed by source/diff inspection

Production packaging change is limited to the Android-JVM branch of `desktop:dist`.

The build now resolves the sibling Arc checkout using `rootDir.parent` and requires:

```
Arc/backends/backend-sdl/libs/sdl-arc-natives-arm64-v8a.jar
```

Before producing the Android-JVM JAR, it verifies that this package exists and contains exactly one `libsdl-arc.so` entry.

The existing package is then copied into the Mindustry JAR under:

```
arm64-v8a/libsdl-arc.so
```

The change remains conditional on `-PandroidJvm`.

Existing Android Arc filtering remains intact:

```
arm64-v8a/libarc.so
```

Desktop builds do not execute the Android SDL packaging block.

### Packaging verifier

`scripts/android-jvm/task-02c-verify-packaging.sh` now verifies:

- `arm64-v8a/libarc.so` exists;
- `arm64-v8a/libsdl-arc.so` exists;
- the SDL resource has no other architecture-specific `libsdl-arc.so` entries;
- desktop SDL variants such as `libsdl-arcarm64.so` and `libSDL2-2.0.so.0` are absent;
- the packaged `libsdl-arc.so` SHA-256 matches the `libsdl-arc.so` extracted from the exact pinned Arc Android ARM64 SDL native package.

This directly verifies that the production resource is byte-identical to the actual package produced by the pinned build.

## CI

Continuous Build:

- Run: `35603499578`
- Commit: `fa0e6e12a8de43829be0ebf62b65bd372f242623`
- Result: **SUCCESS**

Confirmed CI steps:

- Android ARM64 SDL native probe: PASS
- Arc revision verification: PASS
- Arc Android JVM loader overlay: PASS
- patched Arc core rebuild: PASS
- backend-sdl refresh: PASS
- Android-JVM runtime dependency graph: PASS
- Android-JVM `desktop:dist`: PASS
- TASK-02C packaging verification: PASS
- TASK-02D probe package: PASS
- unit tests: PASS
- normal desktop JAR build: PASS
- desktop JAR verification: PASS
- subsequent native/JNI diagnostic packages: PASS
- Android JVM loader-boundary probe: PASS

### CI packaging evidence

The Android-JVM packaging artifact contained:

```
arm64-v8a/libarc.so
arm64-v8a/libsdl-arc.so
```

Android-JVM packaged JAR SHA-256:

```
99c94aa9dfb1a5e8f7ef322fd49013284cb6d0ccea7f98f729cbe3ce04f204f2
```

Actual pinned Arc Android ARM64 SDL package `libsdl-arc.so` SHA-256:

```
d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7
```

Packaged Android-JVM `libsdl-arc.so` SHA-256:

```
d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7
```

The hashes match exactly.

The existing Android Arc library remained:

```
ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338
```

## Artifact Inspection

### Confirmed by artifact inspection

The downloaded Android-JVM packaging artifact was inspected directly.

Its production JAR contains exactly these Android Arc/SDL native resources:

```
arm64-v8a/libarc.so
arm64-v8a/libsdl-arc.so
```

The Android-JVM manifest remains:

```
Main-Class: mindustry.androidjvm.AndroidJvmLauncher
```

The normal desktop artifact was also inspected directly.

Its manifest remains:

```
Main-Class: mindustry.desktop.DesktopLauncher
```

The normal desktop JAR contains desktop-native resources such as `libarcarm64.so` and `libsdl-arcarm64.dylib`, but does **not** contain the Android-only `arm64-v8a/libsdl-arc.so` resource.

This confirms the Android SDL packaging block is conditional and does not leak the Android resource into the normal desktop JAR.

## Physical Android Runtime Verification

### Unknown / not executed in this environment

The required post-fix physical runtime test was not performed from this engineering environment.

Target runtime:

- Xiaomi M2004J19C
- API 31
- arm64
- Mojo Android ARM64 JVM
- no runtime-property spoofing

Therefore the following are still **Unknown**:

- whether the updated production JAR now passes the `arm64-v8a/libsdl-arc.so` extraction boundary on the physical device;
- whether SDL native loading succeeds;
- the next real runtime failure after SDL resource discovery;
- whether execution reaches JNI, SDL initialization completion, EGL/GLES, or later Mindustry startup.

No runtime success beyond the supplied pre-fix evidence is claimed.

## Deepest Confirmed Boundary

Before this task, real Android runtime reached:

```
AndroidJvmLauncher.main
  -> SdlApplication.<init>
  -> SdlApplication.init
  -> SharedLibraryLoader("sdl-arc")
  -> missing arm64-v8a/libsdl-arc.so
```

After this task, the updated artifact has the required resource, but the new physical runtime boundary remains **Unknown** until the artifact is executed on the target device.

## Files Changed

- `desktop/build.gradle`
- `scripts/android-jvm/task-02c-verify-packaging.sh`
- `docs/android-jvm/TASK_04_RUNTIME_03_ANDROID_SDL_PACKAGING.md`

No Android launcher, Arc source, loader overlay, SDLGL, GLES, or native source architecture was changed.

## Known Limitations

The packaging fix and CI verification are complete.

The task is not fully closed because physical Android ARM64 execution of the updated production JAR was not available in this environment.

The prior CI loader-boundary diagnostic still intentionally uses its existing host-property simulation for that diagnostic only; this task did not alter it, and it is not evidence of physical Android runtime behavior.

## Next Task

Run the updated Android-JVM production artifact from commit `fa0e6e12a8de43829be0ebf62b65bd372f242623` on the real Xiaomi M2004J19C / API 31 / arm64 Mojo JVM with no property spoofing.

Capture:

- complete stdout/stderr;
- relevant logcat;
- process exit status;
- the first complete exception;
- the first native/linker failure, if any.

Stop at the first new runtime blocker after `arm64-v8a/libsdl-arc.so` is found.
