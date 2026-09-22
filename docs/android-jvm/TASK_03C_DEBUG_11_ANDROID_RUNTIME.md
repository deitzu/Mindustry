# TASK 03C-DEBUG-11 — Android Runtime Integration / Native Load Boundary

## Objective

Move from the CI-proven Android ARM64 native artifact boundary to the first Android/JVM runtime boundary without redesigning the backend.

## Scope

Investigation and minimal runtime-boundary probe only.

Production Android runtime, launcher, renderer, and native implementation were not modified.

## Baseline

- Branch: `ci/task-ci-01`
- Baseline commit: `4b67f60b6692cb70244de45750636cdd29862ad2`
- Arc: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- SDL: 2.32.8
- ABI: arm64-v8a
- NDK: 30.0.16248370
- Gradle: 9.3.1

## Current Runtime Path

Confirmed from source:

```
mindustry.desktop.DesktopLauncher
    -> new SdlApplication(...)
    -> SdlApplication.init()
    -> ArcNativesLoader.load()
    -> SharedLibraryLoader.load("arc")
    -> SDL.java static initialization
    -> SharedLibraryLoader.load("sdl-arc")
    -> SDL_Init(...)
```

The current Mindustry Android APK has a separate Android launcher, but the intended Android-JVM target does not use that APK-only architecture. Therefore the important target path remains the JVM entry point into the SDL backend.

## Investigation Findings

### Confirmed by source

### 1. JVM entry point

The normal desktop/JVM entry point is:

```
mindustry.desktop.DesktopLauncher
```

It constructs `SdlApplication` directly.

### 2. First native loading boundary

`SdlApplication.init()` calls:

```
ArcNativesLoader.load();
```

which calls:

```
new SharedLibraryLoader().load("arc");
```

The SDL Java wrapper then has a static initializer that calls:

```
new SharedLibraryLoader().load("sdl-arc");
```

Therefore `sdl-arc` is requested during class initialization before normal SDL calls are made.

### 3. Android library-name mapping

`SharedLibraryLoader.mapLibraryName()` has explicit Windows/Linux/macOS branches and otherwise returns the supplied logical name.

When `OS.isAndroid` is true:

```
mapLibraryName("arc")     -> "arc"
mapLibraryName("sdl-arc") -> "sdl-arc"
```

Then `SharedLibraryLoader.load()` uses:

```
System.loadLibrary(platformName)
```

for Android.

Thus Android's native loading mechanism expects the Android linker to resolve the logical `sdl-arc` library rather than extracting a resource from a JAR.

### 4. JAR extraction is not performed by the Android branch

`SharedLibraryLoader` contains JAR extraction methods, but its Android load path does not call them. The Android branch calls `System.loadLibrary()` directly.

Therefore the current loader does not directly load `libsdl-arc.so` from:

```
sdl-arc-natives-arm64-v8a.jar
```

No source evidence was found showing an Android-specific extraction hook for this SDL library in the current Mindustry JVM path.

### 5. SDL Android Java glue

SDL 2.32.8's Android native layer registers JNI methods against:

```
org/libsdl/app/SDLActivity
org/libsdl/app/SDLInputConnection
org/libsdl/app/SDLAudioManager
org/libsdl/app/SDLControllerManager
```

Its `JNI_OnLoad()` performs `RegisterNatives()` for those classes.

SDL's Android JNI setup also stores a JavaVM and the SDL activity class. The native layer later accesses the activity/context and Android surface through this JNI state.

Therefore an Android runtime using SDL 2.32.8 requires the corresponding Java-side SDL glue to be present and initialized before Android SDL functionality can operate.

### 6. SDLActivity responsibilities

The SDL 2.32.8 `org.libsdl.app.SDLActivity` implementation:

- loads SDL libraries
- verifies the C/Java SDL version
- calls `SDL.setupJNI()`
- calls `SDL.initialize()`
- creates the SDL surface
- forwards lifecycle/surface/input callbacks into native SDL

This proves that SDL Android initialization is more than a library load.

### 7. Existing Mindustry Android APK path

The existing `android/build.gradle` packages Arc Android natives into Android APK native libraries through:

```
Arc/natives/natives-android/libs
```

and includes the `backend-android` module.

That is useful historical/reference evidence, but it is not being treated as the intended Android-JVM runtime architecture for this project.

## Current Native Artifact

Previously CI-proven artifact:

```
/home/runner/work/Mindustry/Mindustry/../Arc/backends/backend-sdl/libs/android32/arm64-v8a/libsdl-arc.so
```

Package:

```
/home/runner/work/Mindustry/Mindustry/../Arc/backends/backend-sdl/libs/sdl-arc-natives-arm64-v8a.jar
```

JAR entry:

```
libsdl-arc.so
```

Previously verified:

- ELF64
- AArch64
- SONAME `libsdl-arc.so`
- `libGLESv3.so`
- `libGLESv1_CM.so`
- forbidden desktop/glibc dependencies absent
- JNI symbol surface present

These facts are inherited from DEBUG-10B and were not reopened.

## Minimal Runtime Probe

A non-invasive host-side probe was added to exercise the Java-side loader semantics without changing production runtime code.

Implementation commits:

- `5c5e21abee639040ab390459093676229f81b6eb`
- `224783ec28c2622e0edf9aacaff75243b712948b`

Files:

```
scripts/android-jvm/task-03c-runtime-loader-probe.sh
.github/workflows/ci.yml
```

The probe runs the already-built Mindustry JAR with Android-identifying Java properties and examines the actual `OS` detection and `SharedLibraryLoader.mapLibraryName()` behavior.

Important limitation: this is a host-side semantic probe. It does **not** run an Android JVM and does **not** invoke the Android linker.

## Probe Result

Continuous Build:

`35480439580`

Probe output:

```
Runtime os.name=Linux
Runtime os.arch=aarch64
Runtime sun.arch.data.model=64

OS.isAndroid=true
OS.isLinux=false
OS.isARM=true
OS.is64Bit=false

Mapped arc=arc
Mapped sdl-arc=sdl-arc

JAR libarcarm64.so=PRESENT
JAR libarc.so=ABSENT
JAR libsdl-arcarm64.so=ABSENT
JAR libsdl-arc.so=ABSENT

Loader resource for arc=ABSENT
Loader resource for sdl-arc=ABSENT

Loader boundary probe: PASS
```

The probe intentionally overrides the runtime identity to exercise the Android branch of the existing Java code. It does not claim that Linux can impersonate the Android linker.

## First Unverified Runtime Boundary

The first unverified boundary is:

```
Android JVM
    -> SharedLibraryLoader.load("sdl-arc")
    -> System.loadLibrary("sdl-arc")
    -> Android linker
```

Source inspection establishes the Java-side behavior, but no real Android JVM execution is available in this task to prove that `libsdl-arc.so` can be resolved and loaded in the intended runtime.

Therefore the actual runtime result is **Unknown**, not PASS.

## Expected Failure Classification

The next real runtime test must distinguish:

### B. Native library discovery failure

Expected symptoms would be an `UnsatisfiedLinkError` or Android linker failure if `libsdl-arc.so` is not available through the JVM's native library search/load mechanism.

### C. Android linker dependency failure

Relevant only after `libsdl-arc.so` itself is found.

### D. JNI linkage failure

Relevant after the library is loaded but the expected Java/JNI boundary is unavailable.

### E. SDL Android Java glue failure

Likely once SDL code actually reaches Android JNI calls such as `nativeSetupJNI` or surface handling.

These are not being claimed as observed runtime failures. They are the next classification points for an actual Android execution.

## CI / Build Verification

For commit `224783ec28c2622e0edf9aacaff75243b712948b`:

- Validate Gradle Wrapper: PASS
- Tests: PASS
- Continuous Build: PASS
- Android ARM64 SDL native probe: PASS
- Android ARM64 packaging: PASS
- Native artifact verification: PASS
- Unit tests: PASS
- `desktop:dist`: PASS
- `desktop/build/libs/Mindustry.jar`: verified
- Android JVM loader semantic probe: PASS

The successful native artifact and desktop regression results remain inherited from the same CI line and are not being treated as runtime proof.

## Files Changed in DEBUG-11

- `scripts/android-jvm/task-03c-runtime-loader-probe.sh`
- `.github/workflows/ci.yml`
- `docs/android-jvm/TASK_03C_DEBUG_11_ANDROID_RUNTIME.md`

No production backend or launcher Java source was modified.

## Acceptance Criteria

- [x] Runtime entry point identified.
- [x] Native load boundary identified.
- [x] Actual `sdl-arc` loading mechanism identified.
- [x] Smallest available loader-boundary probe established.
- [x] No speculative broad runtime rewrite.
- [x] Arc pin preserved.
- [x] Findings documented.
- [ ] Real Android JVM native load proven.
- [ ] Real Android JVM JNI boundary proven.
- [ ] Android SDL Java glue initialized.
- [ ] Android surface/window proven.
- [ ] EGL/GLES context proven.
- [ ] SDLGL operation proven.

## Evidence Classification

### Confirmed by source

- JVM entry point is `mindustry.desktop.DesktopLauncher`.
- `SdlApplication.init()` loads Arc natives before SDL initialization.
- `SDL.java` requests `sdl-arc` through `SharedLibraryLoader`.
- Android uses `System.loadLibrary()` in the current loader.
- Android SDL 2.32.8 uses `org.libsdl.app.*` JNI glue.

### Confirmed by build/CI

- Native Android ARM64 `libsdl-arc.so` builds and links.
- ABI/package/ELF/JNI/dependency verification passes.
- Tests pass.
- Desktop build and JAR verification pass.
- Android loader semantics probe passes.

### Confirmed by artifact inspection

- `sdl-arc-natives-arm64-v8a.jar` exists.
- JAR contains `libsdl-arc.so`.
- Native ELF metadata and dependencies were previously verified.

### Confirmed by runtime

- **None yet on a real Android JVM.**

### Inference

Because the current Android loader calls `System.loadLibrary("sdl-arc")` and does not extract JAR resources, an Android JVM runtime needs `libsdl-arc.so` to be exposed through its native-library loading boundary. The exact mechanism for the intended launcher remains to be proven.

## Known Limitations

- No real Android JVM/device execution was available.
- Mojo Launcher integration has not yet been executed with this Mindustry artifact.
- No Android `SDLActivity` replacement/integration has been implemented.
- No Android surface or EGL/GLES runtime behavior has been tested.

## Decision

**Do not self-fix the native loader yet.**

The source-level loading boundary is known, but there is no real Android runtime failure proving which side of that boundary must change.

The correct next step is an Android JVM execution harness that can produce an actual `System.loadLibrary("sdl-arc")` result and its exact exception/logcat output. Only then should extraction, native-path handling, or SDL Java glue be modified.

## Next Task

**TASK 03C-DEBUG-12 — Real Android JVM Execution Harness / Native Load Proof**

Establish the smallest reproducible Android JVM execution environment, preferably the intended Mojo JVM environment, and run the existing Mindustry JAR far enough to capture the first real native-load result.

Do not modify the backend until that runtime result is known.
