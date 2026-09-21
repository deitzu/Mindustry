# TASK-04-RUNTIME-01 — AndroidJvmLauncher Pre-SDL Files Initialization

Status: **BLOCKED — physical Android rerun required to close runtime acceptance**

## Task

Fix the first physical Android ARM64 JVM runtime failure where `Version.init()` reaches `Core.files.internal(...)` while `Core.files == null`.

The minimal launcher-side initialization was tested and implemented.

## Repository State

- Branch: `android-jvm`
- Baseline: `5e63c7094f258bce2dd05231ad4707864c5c8df1`
- Implementation commit: `8be6c427aba6d0947f46e2fe33127400fbaa0657`
- Report commit: pending
- Pinned Arc revision: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

## Scope

Production change:

- `desktop/src/mindustry/androidjvm/AndroidJvmLauncher.java`

No other production files were modified for this task.

## Evidence

### Confirmed by real Android runtime

The pre-fix physical Android ARM64 JVM execution reached:

```
mindustry.androidjvm.AndroidJvmLauncher.main
```

and failed first in:

```
java.lang.NullPointerException:
Cannot invoke "arc.Files.internal(String)"
because "arc.Core.files" is null

at mindustry.core.Version.init(Version.java:33)
at mindustry.androidjvm.AndroidJvmLauncher.main(AndroidJvmLauncher.java:30)
```

The crash handler then separately failed while accessing `Core.files.getLocalStoragePath()`. That was secondary to the first failure.

### Confirmed by source

Pinned Arc `SdlFiles` is:

```
public final class SdlFiles implements Files
```

and provides the normal `Files` implementation used by SDL.

Pinned Arc `SdlApplication` performs:

```
init();

Core.app = this;
Core.files = new SdlFiles();
Core.graphics = ...
```

Its constructor therefore assigns `Core.files` only after its native `init()` stage.

Mindustry `Version.init()` performs on Android:

```
Fi file = OS.isAndroid || OS.isIos
    ? Core.files.internal("version.properties")
    : ...
```

The Android JVM launcher invoked `Version.init()` before constructing `SdlApplication`, so the observed null dereference is explained directly by the initialization order.

### Confirmed by source

Launcher construction order before the fix:

1. `Version.init()`
2. `Vars.loadLogger()`
3. `Vars.loadFileLogger(...)`
4. `checkJavaVersion()`
5. `new SdlApplication(...)`

No earlier launcher code was found that requires a different `Core.*` service before `Version.init()`.

## Implementation

Applied the smallest Android-JVM-specific initialization before `Version.init()`:

```java
Core.files = new SdlFiles();
Version.init();
```

This reuses the same Arc backend `SdlFiles` implementation that `SdlApplication` assigns later.

No changes were made to:

- `Version.java`
- `SharedLibraryLoader`
- Arc source or revision
- Arc loader overlay
- backend-sdl source
- SDLGL/GLES/native code
- Android APK backend
- AndroidLauncher/ClientLauncher
- Mojo configuration
- CI architecture

## CI / Build

Continuous Build:

- Run: `35600488683`
- Commit: `8be6c427aba6d0947f46e2fe33127400fbaa0657`
- Overall result: **success**

Confirmed by CI/build:

- Android ARM64 SDL native probe: PASS
- Arc loader overlay: PASS
- patched Arc core rebuild: PASS
- backend-sdl loader refresh: PASS
- Android-JVM runtime dependency graph: PASS
- Android-JVM `desktop:dist`: PASS
- TASK-02C packaging verification: PASS
- TASK-02D probe package: PASS
- unit tests: PASS
- normal desktop JAR build: PASS
- real Android native load probe package: PASS
- absolute-path native load diagnostic: PASS
- SDL Android controller Java glue diagnostic: PASS
- Android JVM native loader boundary probe: PASS

CI produced the Android-JVM packaging artifact:

```
Mindustry-Android-JVM-packaging-8be6c427aba6d0947f46e2fe33127400fbaa0657
```

Artifact SHA-256:

```
7041a0b09d3c692e410ba0fd988fe8fd1d403ba6b91b985f13eeb4b1b5156fa2
```

### Artifact verification

Confirmed by artifact/CI inspection:

- expected Android-JVM packaging verification passed;
- packaged `arm64-v8a/libarc.so` remained:

```
ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338
```

- normal desktop build also completed successfully.

## Android JVM Runtime Verification

### Status: Unknown / not yet rerun after this fix

The physical Android ARM64 JVM test required by this task was not executed in the available environment after commit `8be6c427aba6d0947f46e2fe33127400fbaa0657`.

There is no Android device/Mojo execution interface available to this engineering session, so the following remain unconfirmed for the new artifact:

- whether `Version.init()` now completes on the physical Android JVM;
- the next runtime failure boundary after `Version.init()`;
- whether execution reaches `Vars.loadLogger()`, `Vars.loadFileLogger()`, `SdlApplication`, Arc native loading, JNI, EGL/GLES, or later Mindustry startup.

No claim of those runtime stages is made.

## Deepest Confirmed Boundary

Before this fix, the deepest physical runtime boundary was:

```
AndroidJvmLauncher.main
  -> Version.init()
  -> Core.files == null
  -> failure
```

After this fix, the deepest runtime boundary is **Unknown** until the updated JAR is executed on the physical Android ARM64 JVM.

## Known Limitations

The CI/build pipeline is green, but that does not substitute for the required physical Android rerun.

The task should remain open/blocked until the updated artifact is executed through the real Mojo Android ARM64 JVM path and the first post-fix runtime boundary is captured.

## Next Task

Run the `8be6c427aba6d0947f46e2fe33127400fbaa0657` Android-JVM JAR through the real physical Android ARM64 Mojo JVM with no runtime-property spoofing, capture stdout/stderr and logcat, and continue only at the first new runtime blocker.
