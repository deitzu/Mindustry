# Mindustry Android-JVM Patch Project — Context Backup

Snapshot date: 2026-09-20
Purpose: preserve the complete engineering state needed to continue the project in a future session without re-discovering established facts.

## 1. Project Objective

Primary goal:

Run the desktop Mindustry JAR through a Java/JVM runtime hosted on real Android ARM64.

Target:
- Android JVM
- arm64-v8a / AArch64
- Android/bionic ABI
- real Android native libraries
- Mojo Launcher is the current first runtime target, not the definition of the architecture

Explicitly not the target:
- desktop Linux ARM64/glibc
- APK-only execution
- Linux libraries renamed as Android libraries
- fake .so.0 compatibility shims
- Mojo-specific native hacks as the final solution
- replacing the backend with GL4ES/LTW/Zink merely because a launcher supports them

Repository:
- deitzu/Mindustry

Working branch:
- ci/task-ci-01

Protected branch:
- master

Current branch HEAD:
- 89e58ae622850460cfcca09763360eb9c4b858e8

Pinned Arc revision:
- 8eb00ffff0126d0576c67df46f99b8f6bccd96fe

SDL:
- 2.32.8

## 2. Core Architecture Decision

Desired desktop path:

backend-sdl
  -> GLEW
  -> desktop OpenGL
  -> SDL2

Desired Android path:

backend-sdl
  -> Android GLES
  -> static SDL2
  -> Android system APIs

Primary native GL boundary:
- Arc/backends/backend-sdl/src/arc/backend/sdl/jni/SDLGL.java

The Android implementation must be platform-specific. Do not globally replace desktop OpenGL/GLEW with GLES.

Mojo's GL4ES/LTW/Zink renderer infrastructure is primarily tied to its LWJGL/Minecraft rendering path. It is not currently treated as the renderer for the SDL backend. SDL has its own Android EGL/GLES path.

## 3. Completed Task History

### TASK 01 — Native Artifact Audit
Status: complete

Key established facts:
- Arc Linux/AArch64 naming can produce desktop-style libarcarm64.so.
- Arc already contains Android arm64-v8a libarc.so.
- Existing Linux SDL is desktop-oriented and incompatible with the Android target.
- This is a real ABI/platform mismatch, not a .so.0 naming problem.

### TASK 02 — Native Build Feasibility
Status: complete

Established:
- Arc already has Android native patterns using addAndroid().
- Arc already uses c++_static in an Android native configuration.
- Android FreeType native artifacts already exist.
- backend-sdl itself has no existing Android target.
- SDL2 2.32.8 has an Android implementation and a static target.
- SDLGL.java is the smallest practical native OpenGL compatibility boundary.

### TASK 03C — Android ARM64 SDL Native Probe
Status: implementation/verification phase completed through runtime-loader boundary

Important completed substeps:
- 03A Android CI toolchain bootstrap
- 03B exact pinned Arc backend-sdl Android audit/plan
- 03C Android ARM64 SDL native probe
- DEBUG-01 through DEBUG-10B
- DEBUG-11 Android runtime loader-boundary analysis
- DEBUG-12 real Android JVM native-load proof
- DEBUG-12A Android JVM runtime detection implementation is currently in progress at device verification stage

## 4. Native Build Evidence

Android native artifact was successfully built and verified.

Known verified properties from completed native probe:
- ELF64
- AArch64
- Android-compatible native artifact
- SONAME: libsdl-arc.so
- JNI symbols present
- Android system/GLES dependencies verified
- forbidden desktop/glibc dependencies absent
- desktop build passed

Known artifact structure:
- Arc/backends/backend-sdl/libs/android32/arm64-v8a/libsdl-arc.so
- Arc/backends/backend-sdl/libs/sdl-arc-natives-arm64-v8a.jar
  - libsdl-arc.so

DEBUG-10B CI:
- run 35479497497
- result: success
- head: 932b34ece909155c775eaf62ed24a58a4a649432

DEBUG-11 CI:
- run 35480439580
- result: success
- head: 224783ec28c2622e0edf9aacaff75243b712948b

DEBUG-12 packaging/build CI:
- run 35486586424
- result: success
- head: 76201b7cbc9a7587fca22aa45a966b0f5d29c358

## 5. Current Production Overlay

Current implementation commit:
- 89e58ae622850460cfcca09763360eb9c4b858e8

Current changed production-side repository file:
- ci/android-jvm/task03c-backend-sdl.patch

The current Arc overlay extends Android detection in OS.java from:

propNoNull("java.runtime.name").contains("Android Runtime")

to:

propNoNull("java.runtime.name").contains("Android")

The existing vendor checks for "The Android Project" remain.

SharedLibraryLoader.java was not modified.

Arc remains pinned to:
- 8eb00ffff0126d0576c67df46f99b8f6bccd96fe

## 6. DEBUG-12 Real Android Evidence

Real Android ARM64 execution was performed through Mojo Launcher.

Runtime evidence:
- java.runtime.name = OpenJDK Runtime Environment (Android)
- java.vm.vendor = Oracle Corporation
- java.version = 21.0.12-internal
- os.name = Linux
- os.arch = aarch64
- sun.arch.data.model = 64

Before DEBUG-12A:
- OS.isAndroid = false
- OS.isLinux = true
- OS.isARM = true
- OS.is64Bit = true

The misclassification caused:
- libsdl-arcarm64.so to be requested
- actual embedded resource was libsdl-arc.so
- failure occurred before Android linker/JNI/SDL

Historical report:
- docs/android-jvm/TASK_03C_DEBUG_12_ANDROID_JVM_LOAD.md

Historical report commit:
- d407ea48a746a07dd6db6df212ae023a93290b0c

Do not rewrite that historical report.

## 7. DEBUG-12A Current Evidence

After the runtime-name patch, the same real Mojo Android JVM probe now reports:

- OS.isAndroid = true
- OS.isLinux = false
- OS.isARM = true
- OS.is64Bit = false

It also reports:
- LIBRARY_MAPPED_NAME = sdl-arc

This proves the first Android classification bug is fixed.

However, Arc OS.java currently contains a legacy Android block that explicitly assigns:
- is64Bit = false

The runtime itself reports:
- os.arch = aarch64
- sun.arch.data.model = 64

Therefore the current immediate culprit is the Android-specific overwrite of is64Bit.

Expected minimal next source change:
- preserve the existing architecture-derived is64Bit value
- remove the legacy Android assignment that forces is64Bit=false
- do not hardcode is64Bit=true

Expected result on the current device:
- OS.isAndroid = true
- OS.isLinux = false
- OS.isARM = true
- OS.is64Bit = true
- mapLibraryName("sdl-arc") = "sdl-arc"

Important source detail:
SharedLibraryLoader.mapLibraryName() returns the logical library name unchanged for Android because Android does not enter its Windows/Linux/macOS branches.

Therefore the correct progression is:

aarch64
  -> is64Bit=true
  -> Android detection
  -> isAndroid=true
  -> isLinux=false
  -> mapLibraryName("sdl-arc") == "sdl-arc"
  -> System.loadLibrary("sdl-arc")
  -> Android linker

Do not describe mapLibraryName() itself as producing "libsdl-arc.so". That filename is resolved by the native loading mechanism.

## 8. Current DEBUG-12A CI

Implementation commit:
- 89e58ae622850460cfcca09763360eb9c4b858e8

CI:
- run 35490330638
- result: success
- head: 89e58ae622850460cfcca09763360eb9c4b858e8

Verified by CI:
- Arc pin preserved
- overlay applied
- Android ARM64 native probe passes
- JNI verification passes
- forbidden dependency scan passes
- desktop:dist passes
- desktop/build/libs/Mindustry.jar verified
- Android JVM load probe packaging passes
- host loader-boundary probe passes

CI does NOT prove the latest real Android runtime behavior. The device must be rerun.

## 9. Current Blocking Chain

Current state:

Android JVM startup
  PASS

Probe execution
  PASS

Real Android runtime detection
  PASS for isAndroid/isLinux after 12A patch

ARM detection
  PASS

64-bit detection
  BLOCKED by legacy Android override

Native library mapping
  PASS at logical name level

System.loadLibrary("sdl-arc")
  NOT REACHED successfully yet

Android linker
  NOT YET PROVEN for this post-12A state

JNI
  NOT YET PROVEN in this post-12A state

SDL_Init
  NOT YET PROVEN

EGL/GLES
  NOT YET PROVEN

Full Mindustry startup
  NOT YET PROVEN

## 10. Next Engineering Action

Next action remains inside TASK 03C-DEBUG-12A.

Coder should:
1. inspect exact pinned Arc OS.java;
2. preserve architecture-derived is64Bit;
3. remove only the Android legacy override that forces is64Bit=false;
4. update the deterministic Arc overlay;
5. run CI/build;
6. run desktop regression;
7. build a fresh real Android probe artifact;
8. run it through Mojo without -Dos.* overrides;
9. capture:
   - OS.isAndroid
   - OS.isLinux
   - OS.isARM
   - OS.is64Bit
   - LIBRARY_MAPPED_NAME
   - native load result

STOP at the first new runtime failure.

Do not fix native extraction, JNI, SDL Java glue, EGL, GLES, or graphics in the same task unless the new evidence shows the failure is actually in that layer.

## 11. Expected Next Boundary

If 12A succeeds, the likely next boundary becomes:

System.loadLibrary("sdl-arc")
  -> Android linker / native library discovery

At that point:
- inspect the actual java.library.path
- inspect Mojo's native extraction/location mechanism
- determine whether sdl-arc is actually discoverable by the Android JVM
- capture the exact Android linker error if any

Do not assume the error in advance.

## 12. SDL / Android Runtime Risks Still Open

Known later risks:
- Mojo/SDL Android Java glue compatibility
- SDLActivity-equivalent requirements
- Activity/context availability
- surface acquisition
- window creation
- EGL context creation
- GLES runtime compatibility
- desktop-oriented SdlApplication behavior
- desktop-oriented SdlGraphics behavior
- input/lifecycle integration
- final Mindustry runtime integration

These are later tasks unless an earlier runtime failure forces entry into them.

## 13. Files / Scope Boundaries

Production Arc overlay:
- ci/android-jvm/task03c-backend-sdl.patch

Important historical reports:
- docs/android-jvm/TASK_01_NATIVE_ARTIFACT_AUDIT.md
- docs/android-jvm/TASK_02_NATIVE_BUILD_FEASIBILITY.md
- docs/android-jvm/TASK_03C_DEBUG_02_ARC_PATCH.md
- docs/android-jvm/TASK_03C_DEBUG_03_SDL_VERSION.md
- docs/android-jvm/TASK_03C_DEBUG_08_GLES_EXT.md
- docs/android-jvm/TASK_03C_DEBUG_09_GLES_LINKAGE.md
- docs/android-jvm/TASK_03C_DEBUG_10B_TASK_DISCOVERY.md
- docs/android-jvm/TASK_03C_DEBUG_11_ANDROID_RUNTIME.md
- docs/android-jvm/TASK_03C_DEBUG_12_ANDROID_JVM_LOAD.md

Do not rewrite historical reports because later tasks discover new issues.

Current task report for DEBUG-12A should be created only after its acceptance boundary has actually been tested.

## 14. Handoff / Documentation Branch

PROJECT_HANDOFF.md exists on the separate audit branch:
- audit/task-01-native-artifact

It is not expected to exist on ci/task-ci-01.

The current CI branch uses task-specific historical reports.

## 15. Engineering Rules

Always:
- inspect source before guessing
- use exact pinned Arc revision
- use deterministic overlays
- capture exact failure output
- fix the earliest real failing layer
- verify with real build/runtime evidence
- preserve desktop support
- document meaningful debug/fix work

Never:
- use fake Linux-to-Android library shims
- rename incompatible desktop libraries
- hide linker/runtime failures
- claim Android compatibility from host simulation
- change unrelated runtime layers in response to hypothetical failures
- change the Arc pin silently
- rewrite old task reports

## 16. Final Long-Term Roadmap

TASK 03C — Native Android ARM64 SDL feasibility
  ├─ native build proof                 COMPLETE
  ├─ artifact/ELF/JNI proof            COMPLETE
  ├─ loader-boundary analysis          COMPLETE
  ├─ real Android JVM execution        COMPLETE
  ├─ Android runtime detection         IN PROGRESS
  ├─ native library load               PENDING
  ├─ JNI execution                     PENDING
  ├─ SDL_Init                           PENDING
  ├─ SDL window                         PENDING
  ├─ EGL/GLES context                   PENDING
  └─ runtime rendering                  PENDING

TASK 04 — Android-JVM entry point
  Pending until TASK 03C runtime boundaries are proven.

TASK 05 — Runtime integration
  Pending.

TASK 06 — Regression / final validation
  Pending.

## 17. Current Handoff

Status:
TASK 03C-DEBUG-12A in progress; Android classification is fixed, legacy is64Bit override is the immediate blocker.

Branch:
ci/task-ci-01

Baseline:
d407ea48a746a07dd6db6df212ae023a93290b0c

Current implementation commit:
89e58ae622850460cfcca09763360eb9c4b858e8

Pinned Arc:
8eb00ffff0126d0576c67df46f99b8f6bccd96fe

Current change:
ci/android-jvm/task03c-backend-sdl.patch

Result:
Real Mojo Android JVM is now correctly recognized as Android, but Arc forces is64Bit=false inside the Android classification block.

Next task action:
Remove only the legacy is64Bit=false Android override, verify CI/desktop, rerun the real Mojo probe, and stop at the next genuine runtime boundary.
