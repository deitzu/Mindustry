# TASK 03C-DEBUG-12 — Real Android JVM Native Load Proof

## Status

Blocked at Android runtime OS classification before the `sdl-arc` native linker boundary.

## Branch

`ci/task-ci-01`

## Baseline

- Mindustry branch: `ci/task-ci-01`
- Arc revision: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- SDL: 2.32.8
- ABI: arm64-v8a
- Probe package commit: `76201b7cbc9a7587fca22aa45a966b0f5d29c358`
- CI run: `35486586424`

## Objective

Exercise the first real Android/JVM native boundary:

```
Android ARM64 device
  -> Mojo Launcher Execute JAR
  -> Android JVM
  -> Mindustry.jar
  -> SharedLibraryLoader.load("sdl-arc")
  -> System.loadLibrary(...)
  -> Android native loader
```

The task does not attempt full Mindustry startup.

## Scope

- Real Android ARM64 execution through Mojo Launcher.
- No production loader changes before real evidence.
- No Arc revision change.
- No native ABI workaround.
- Stop at the first confirmed blocker.

## Device / Runtime

Observed directly from the real device launch:

- Launcher: justicia-20260910-[7e5e21b]-v3_openjdk
- Build type: gplay
- Device: Xiaomi M2004J19C
- ABI: arm64
- Android API: 31
- Android graphics device: ARM Mali-G52
- Runtime: OpenJDK Runtime Environment (Android)
- JVM vendor: Oracle Corporation
- JVM version: 21.0.12-internal
- `os.name`: Linux
- `os.arch`: aarch64
- `sun.arch.data.model`: 64

## Procedure

1. CI produced `Mindustry-android-jvm-load-probe.jar` with probe class and actual arm64-v8a `libsdl-arc.so` embedded as a JAR resource.
2. Existing JAR was replaced in the Mojo Launcher version environment.
3. The JAR was launched through Mojo Launcher's **Execute a JAR** path.
4. No host-simulation `-Dos.*` overrides were used.
5. The process output and crash log were captured from the real Android device.

## Result

### Confirmed

The intended probe executed:

```
PROBE_START
```

The JVM was real Android:

```
Runtime.java.runtime.name=OpenJDK Runtime Environment (Android)
Runtime.java.vm.vendor=Oracle Corporation
Runtime.os.name=Linux
Runtime.os.arch=aarch64
Runtime.sun.arch.data.model=64
```

The probe reached the native load call:

```
LIBRARY_REQUEST=sdl-arc
LIBRARY_MAPPED_NAME=libsdl-arcarm64.so
LIBRARY_LOAD_BEGIN
```

The load failed before JNI and SDL initialization:

```
LIBRARY_LOAD_FAIL
LIBRARY_LOAD_ERROR.message=Couldn't load shared library 'libsdl-arcarm64.so' for target: Linux, 64-bit
LIBRARY_LOAD_ERROR.cause[1].message=Unable to read file for extraction: libsdl-arcarm64.so
```

The embedded resource was present:

```
Probe.embeddedNativeResource=jar:file:/data/data/git.artdeell.mjlaunch/cache/mod-installer-temp!/android-jvm-probe/native/arm64-v8a/libsdl-arc.so
```

### Failure classification

**Layer A/B: Android runtime classification + native discovery naming**

The Android JVM identifies itself with:

```
java.runtime.name=OpenJDK Runtime Environment (Android)
java.vm.vendor=Oracle Corporation
```

but the pinned Arc `OS.java` Android detection only recognizes:

- `java.runtime.name` containing `Android Runtime`
- `java.vm.vendor` containing `The Android Project`
- `java.vendor` containing `The Android Project`

Therefore the runtime was classified as:

```
OS.isAndroid=false
OS.isLinux=true
OS.isARM=true
OS.is64Bit=true
```

That classification caused `SharedLibraryLoader.mapLibraryName("sdl-arc")` to produce:

```
libsdl-arcarm64.so
```

instead of the Android logical library name used by `System.loadLibrary`.

The actual package contains:

```
libsdl-arc.so
```

and the probe intentionally does not extract the JAR resource itself.

## Relevant source evidence

Pinned Arc `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`:

### `arc-core/src/arc/util/OS.java`

Android detection is based on the legacy strings:

```java
propNoNull("java.runtime.name").contains("Android Runtime")
propNoNull("java.vm.vendor").contains("The Android Project")
propNoNull("java.vendor").contains("The Android Project")
```

### `arc-core/src/arc/util/SharedLibraryLoader.java`

The loader uses:

```java
String platformName = mapLibraryName(libraryName);
if(isAndroid)
    System.loadLibrary(platformName);
else
    loadFile(platformName);
```

The same source maps Linux ARM64 to:

```
lib + libraryName + arm + 64 + .so
```

which produced `libsdl-arcarm64.so` under the observed misclassification.

## Why this is not an Android linker failure

The Android linker was not reached for `sdl-arc` in this probe.

The failure occurred inside Arc's resource lookup path because the requested name was:

```
libsdl-arcarm64.so
```

and the probe JAR contains:

```
android-jvm-probe/native/arm64-v8a/libsdl-arc.so
```

Therefore there is currently no evidence for or against DT_NEEDED resolution of `libsdl-arc.so` on the Android device from this run.

## Previous runtime observation

A separate launch through the Mojo version/game path reached Mindustry's normal desktop launcher and failed earlier on:

```
libarcarm64.so: dlopen failed: library "libpthread.so.0" not found
```

That failure is consistent with the same Android runtime being misclassified as Linux and is not used as the primary DEBUG-12 acceptance result.

## Files changed

No production runtime/native files were modified in response to this device failure.

This report is the only change for DEBUG-12.

## CI / Build Evidence

CI run `35486586424` completed successfully.

Relevant steps:

- Android ARM64 SDL native probe: PASS
- Unit tests: PASS
- Desktop JAR build: PASS
- Desktop JAR verification: PASS
- Real Android JVM probe packaging: PASS
- Host loader-boundary probe: PASS
- Android JVM probe artifact upload: PASS

Probe JAR SHA-256:

```
ec3eb3b8838f1fa1e300a3ea93a519c04f26694784f092f684f6cb41ee98c223
```

## Acceptance criteria

- [x] Real Android ARM64 execution performed.
- [x] Mojo Launcher environment confirmed.
- [x] Android JVM confirmed.
- [x] Existing Mindustry JAR/probe reached actual native load call.
- [x] System native-loading path was exercised through Arc `SharedLibraryLoader`.
- [x] Exact failure captured.
- [x] Earliest blocking layer identified.
- [x] No speculative production rewrite performed.
- [x] Arc pin preserved.
- [ ] `sdl-arc` successfully loaded on Android.
- [ ] JNI smoke call executed.
- [ ] SDL_Init executed.

## Next task

**TASK 03C-DEBUG-12A — Android JVM Runtime Detection**

Investigate the smallest compatible change needed for Arc's Android detection to recognize the actual Mojo Android JVM runtime:

```
java.runtime.name=OpenJDK Runtime Environment (Android)
java.vm.vendor=Oracle Corporation
```

Acceptance for 12A should first prove:

```
OS.isAndroid=true
OS.isLinux=false
```

under the real Mojo Android JVM, then re-run the same probe without changing native artifacts.

Do not address SDL Android Java glue, linker dependencies, or graphics until the `sdl-arc` native load boundary passes.

## Handoff

Status:
Blocked at Android runtime OS classification / native discovery naming.

Branch:
`ci/task-ci-01`

Baseline:
Arc `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`, SDL 2.32.8, arm64-v8a.

Commit:
`76201b7cbc9a7587fca22aa45a966b0f5d29c358`

Files changed:
`docs/android-jvm/TASK_03C_DEBUG_12_ANDROID_JVM_LOAD.md`

Result:
Real Android Execute-JAR probe reached `SharedLibraryLoader.load("sdl-arc")`, but Arc classified the Android JVM as Linux and requested `libsdl-arcarm64.so`.

CI:
`35486586424` PASS.

Build:
Android ARM64 native artifact, desktop JAR, and probe package all PASS.

Verification:
Real device output confirms Android JVM properties, probe execution, embedded native resource, exact load failure, and failure before JNI/SDL.

Known limitations:
No successful `sdl-arc` load, JNI call, SDL_Init, linker dependency, or graphics evidence yet.

Next task:
TASK 03C-DEBUG-12A — Android JVM Runtime Detection.
