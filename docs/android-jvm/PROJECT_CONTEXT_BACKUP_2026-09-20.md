# Mindustry Android-JVM Patch Project — Context Backup

Snapshot updated: 2026-09-20
Purpose: current-state recovery point for future sessions. This file is a mutable context snapshot; individual TASK/DEBUG reports remain immutable historical records.

## 1. Project Objective

Run Mindustry's Java/JVM application through a real Android ARM64 runtime.

Target:
- Android JVM
- arm64-v8a / AArch64
- Android/bionic ABI
- real Android native compatibility
- Mojo Launcher is the current first runtime target, not the definition of the final architecture

Not the target:
- desktop Linux ARM64/glibc
- APK-only execution
- renamed incompatible Linux libraries
- fake .so.0 shims
- Mojo-specific native hacks as the final solution
- replacing the SDL backend with GL4ES/LTW/Zink without evidence

Repository:
- deitzu/Mindustry
- working branch: ci/task-ci-01
- protected branch: master
- current branch HEAD: a584a2564417e6c7c247e6a23ba8e2e905c9209d
- pinned Arc: 8eb00ffff0126d0576c67df46f99b8f6bccd96fe
- SDL: 2.32.8

## 2. Core Architecture Decision

Desktop:
backend-sdl -> GLEW -> desktop OpenGL -> SDL2

Android:
backend-sdl -> Android GLES -> static SDL2 -> Android system APIs

Primary native GL boundary:
- Arc/backends/backend-sdl/src/arc/backend/sdl/jni/SDLGL.java

Do not globally convert desktop OpenGL/GLEW to GLES.

Mojo's GL4ES/LTW/Zink renderer is tied to its LWJGL/Minecraft rendering path. It is not currently treated as the renderer for backend-sdl. SDL's Android build has its own Android EGL/GLES path.

## 3. Completed Work

TASK 01 — Native Artifact Audit
- Complete.
- Established that desktop Linux/AArch64 native naming is incompatible with the Android target.
- Established that Arc already contains real Android arm64-v8a native artifacts.

TASK 02 — Native Build Feasibility
- Complete.
- Established Android build feasibility for backend-sdl with static SDL2 and Android GLES.
- Established the minimal native GL boundary in SDLGL.java.

TASK 03C native implementation/debug chain
- Native Android ARM64 SDL build: COMPLETE.
- Android ELF/JNI/dependency verification: COMPLETE.
- Desktop regression: COMPLETE.
- DEBUG-11 runtime loader-boundary analysis: COMPLETE.
- DEBUG-12 real Android JVM execution: COMPLETE as a diagnostic task.
- DEBUG-12A Android JVM OS/architecture detection: COMPLETE as a runtime boundary.
- DEBUG-13 native library discovery investigation: COMPLETE as a discovery diagnosis.
- DEBUG-13A absolute-path native-load diagnostic: COMPLETE as an isolation experiment.

## 4. Native Artifact Evidence

Verified Android artifact:
- libsdl-arc.so
- ELF64
- AArch64
- Android/bionic-compatible
- SONAME: libsdl-arc.so
- JNI symbols present
- Android GLES/system dependencies present
- forbidden desktop/glibc dependencies absent

Known packaging:
- sdl-arc-natives-arm64-v8a.jar
  - libsdl-arc.so

Relevant CI evidence:
- DEBUG-10B 35479497497 PASS
- DEBUG-11 35480439580 PASS
- DEBUG-12 35486586424 PASS
- DEBUG-12A implementation 35490330638 PASS
- DEBUG-12A corrected overlay 35491902802 PASS
- DEBUG-12A Tests 35491902827 PASS
- DEBUG-12A Wrapper 35491902816 PASS
- DEBUG-13 diagnostic 35492978589 PASS
- DEBUG-13 Tests 35492978485 PASS
- DEBUG-13 Wrapper 35492978472 PASS
- latest absolute-load Tests 35494121983 PASS
- latest absolute-load Wrapper 35494122008 PASS

## 5. Current Arc Overlay State

Production-side repository mechanism:
- ci/android-jvm/task03c-backend-sdl.patch

Android runtime detection was extended from:
propNoNull("java.runtime.name").contains("Android Runtime")
to:
propNoNull("java.runtime.name").contains("Android")

Existing vendor checks for:
- The Android Project
remain preserved.

The legacy Android assignment:
- is64Bit = false;
was removed.

Therefore architecture-derived is64Bit remains authoritative.

SharedLibraryLoader.java was not changed.

Arc remains pinned exactly to:
- 8eb00ffff0126d0576c67df46f99b8f6bccd96fe

## 6. DEBUG-12 / DEBUG-12A Real Android Runtime Evidence

Real device:
- Mojo Launcher
- Android ARM64
- JVM: OpenJDK Runtime Environment (Android)
- JVM vendor: Oracle Corporation
- JVM version: 21.0.12-internal
- os.name: Linux
- os.arch: aarch64
- sun.arch.data.model: 64

Current real runtime reports:
- OS.isAndroid=true
- OS.isLinux=false
- OS.isARM=true
- OS.is64Bit=true

Library request:
- LIBRARY_REQUEST=sdl-arc
- LIBRARY_MAPPED_NAME=sdl-arc

Important:
- SharedLibraryLoader.mapLibraryName("sdl-arc") returns "sdl-arc" on Android.
- System.loadLibrary("sdl-arc") is then invoked.
- Do not interpret the exception text "target: Linux, 64-bit" as OS.isLinux=true; os.name remains Linux on the Android JVM.

## 7. DEBUG-13 Native Discovery Evidence

Mojo source investigation established:

Normal version/game launch:
native archive
-> Mojo native extraction
-> cache/natives/<version>
-> -Djava.library.path includes version-native-dir and Tools.NATIVE_LIB_DIR
-> JVM native loading

Execute JAR:
JAR
-> AWTActivity reads Main-Class
-> JavaRunner.startJvm(...)
-> no normal MoJsonDownloader/NativesExtractor/versionSpecificNativesDir pipeline

Mojo Tools.NATIVE_LIB_DIR is based on the Android application's nativeLibraryDir.

Real Execute-JAR runtime showed java.library.path entries including:
- /data/user/0/git.artdeell.mjlaunch/runtimes/Internal-21/lib
- /data/app/.../lib/arm64
- /data/user/0/git.artdeell.mjlaunch/runtimes/Internal-21/lib/server
- /data/user/0/git.artdeell.mjlaunch/runtimes/Internal-21/lib/jli

Diagnostic result:
- libsdl-arc.so absent from every listed java.library.path entry
- embedded JAR resource exists at:
  android-jvm-probe/native/arm64-v8a/libsdl-arc.so

Therefore:
System.loadLibrary("sdl-arc")
-> native search-path discovery failure

No production SharedLibraryLoader change has been made.

## 8. DEBUG-13A Absolute-Path Result

The diagnostic probe extracted the embedded Android native library to a real Android filesystem path.

Observed:
- absolute path under app cache
- file exists
- regular file
- readable
- size: 4,710,176 bytes
- SHA-256 observed: d98174dd... in the runtime diagnostic

Then:
System.load(absolutePath)

was attempted on the real Android JVM.

Result:
NoClassDefFoundError:
org/libsdl/app/SDLControllerManager

This is not the same as a normal missing-library or DT_NEEDED linker error.

Precise interpretation:
- JAR resource extraction to Android filesystem: PASS
- System.load(absolutePath) was entered: PASS
- native loading progressed into SDL Android JNI_OnLoad-related Java class resolution: CONFIRMED by runtime/source evidence
- org.libsdl.app.SDLControllerManager is missing: CONFIRMED by runtime
- complete JNI registration: NOT proven
- complete native linker initialization: NOT proven
- SDL_Init: NOT tested
- graphics: NOT tested

Do not overclaim that the entire native library load/link/JNI stage succeeded.

Historical diagnostic commit:
- 0b05554a41731801dd9a05afeede06a75d6b50d4

Latest branch HEAD:
- a584a2564417e6c7c247e6a23ba8e2e905c9209d
- message: Add Android absolute-path native load CI probe

Latest HEAD only adds CI build/upload wiring for the absolute-path diagnostic:
- Build Android absolute-path native load diagnostic
- Upload Android absolute-path native load diagnostic

No production loader change in that commit.

CI on latest HEAD:
- Tests 35494121983 PASS
- Gradle Wrapper Validation 35494122008 PASS
- Continuous Build result for latest HEAD is not yet recorded in this snapshot; do not assume it passed unless verified.

## 9. Current Runtime Boundary

Proven:

Android JVM startup
  PASS

Probe execution
  PASS

Android detection
  PASS

Linux exclusion
  PASS

ARM64 detection
  PASS

Logical mapping
  PASS

System.loadLibrary("sdl-arc")
  REACHED

Native search-path discovery through System.loadLibrary
  FAIL because libsdl-arc.so is absent from java.library.path

Independent absolute-path test:
JAR resource
  -> Android filesystem extraction
  -> System.load(absolutePath)
  -> SDL Android Java glue resolution
  -> FAIL: org.libsdl.app.SDLControllerManager missing

Current boundary:
SDL Android Java glue / JNI_OnLoad-related initialization

## 10. Current Task State

DEBUG-12A:
- Real Android OS detection boundary: PASS
- Real Android 64-bit detection boundary: PASS
- Historical report should remain immutable.

DEBUG-13:
- Native discovery diagnosis: PASS
- Execute JAR does not automatically place the JAR-contained native resource into java.library.path.
- Historical report should remain immutable.

DEBUG-13A:
- Absolute-path isolation experiment: COMPLETE
- The extracted native file reaches SDL Android Java glue class resolution.
- Failure: org.libsdl.app.SDLControllerManager missing.
- Historical report should remain immutable.

No production SDL Java glue integration has been applied yet.

## 11. Immediate Next Task

TASK 03C-DEBUG-14 — SDL Android Java Glue / JNI_OnLoad Dependency

Primary question:

What minimal SDL 2.32.8 Android Java glue must be present on the Android JVM classpath for the existing SDL native library's JNI_OnLoad-related initialization to proceed?

Investigation order:

1. Inspect SDL 2.32.8 Android Java glue source/classes.
2. Determine exactly which org.libsdl.app.* classes are referenced during JNI_OnLoad and immediate native initialization.
3. Identify the minimal class set required for the next runtime boundary.
4. Determine how those classes can be packaged into the Execute-JAR diagnostic runtime.
5. Create a minimal diagnostic artifact.
6. Run CI/build verification.
7. Test the fresh artifact on the same real Mojo Android JVM.
8. Stop at the first genuine new runtime failure.

Do not immediately implement full SDLActivity/surface/rendering/lifecycle integration.

Do not modify SharedLibraryLoader merely because of the earlier search-path issue.

## 12. Important DEBUG-14 Constraints

Do not:
- change the Arc pin
- use desktop SDL2
- use Linux/glibc libraries
- rename native libraries
- create compatibility shims
- replace SDL with GL4ES/LTW/Zink
- modify Mojo renderer hooks
- rewrite SharedLibraryLoader without evidence
- start full Mindustry runtime
- claim complete JNI success from a partial JNI_OnLoad trace

Current Android architecture remains:
backend-sdl
-> Android GLES
-> static SDL2
-> Android system APIs

## 13. Open Later Risks

Still unproven:
- complete JNI registration
- complete native initialization
- SDL_Init
- SDL Android Activity/context requirements
- SDL surface/window creation
- EGL context creation
- GLES runtime
- input/lifecycle integration
- full Mindustry startup
- compatibility with launchers other than Mojo

These are later boundaries.

## 14. Historical Reports

- docs/android-jvm/TASK_01_NATIVE_ARTIFACT_AUDIT.md
- docs/android-jvm/TASK_02_NATIVE_BUILD_FEASIBILITY.md
- docs/android-jvm/TASK_03C_DEBUG_02_ARC_PATCH.md
- docs/android-jvm/TASK_03C_DEBUG_03_SDL_VERSION.md
- docs/android-jvm/TASK_03C_DEBUG_08_GLES_EXT.md
- docs/android-jvm/TASK_03C_DEBUG_09_GLES_LINKAGE.md
- docs/android-jvm/TASK_03C_DEBUG_10B_TASK_DISCOVERY.md
- docs/android-jvm/TASK_03C_DEBUG_11_ANDROID_RUNTIME.md
- docs/android-jvm/TASK_03C_DEBUG_12_ANDROID_JVM_LOAD.md

DEBUG-12A/13/13A reports should be added as immutable historical reports when finalized.

PROJECT_HANDOFF.md is maintained on the separate audit branch:
- audit/task-01-native-artifact

It is intentionally not expected on ci/task-ci-01.

## 15. Long-Term Roadmap

TASK 03C:
- Android ARM64 SDL native build: COMPLETE
- artifact/ELF/JNI/dependency verification: COMPLETE
- real Android JVM execution: CONFIRMED
- Android runtime detection: COMPLETE
- native-library search-path diagnosis: COMPLETE
- absolute-path native load diagnostic: COMPLETE
- SDL Android Java glue diagnosis: NEXT
- complete JNI initialization: PENDING
- SDL_Init: PENDING
- SDL window: PENDING
- EGL/GLES context: PENDING
- rendering: PENDING

TASK 04:
- Android-JVM entry point
- pending until required TASK 03C runtime boundaries are proven

TASK 05:
- runtime integration
- pending

TASK 06:
- regression/final validation
- pending

## 16. Current Handoff

Status:
TASK 03C-DEBUG-13A complete as a diagnostic boundary. The next blocker is missing SDL Android Java glue class org.libsdl.app.SDLControllerManager during absolute-path native load.

Branch:
ci/task-ci-01

Baseline:
a584a2564417e6c7c247e6a23ba8e2e905c9209d

Commit:
a584a2564417e6c7c247e6a23ba8e2e905c9209d

Files changed in latest commit:
- .github/workflows/ci.yml

Pinned Arc:
8eb00ffff0126d0576c67df46f99b8f6bccd96fe

Result:
Real Android JVM correctly detects Android/ARM64. System.loadLibrary("sdl-arc") cannot discover the JAR-contained library through java.library.path. Direct System.load() of the extracted real Android native library reaches SDL Android Java glue resolution and currently fails because org.libsdl.app.SDLControllerManager is missing.

Next action:
Delegate TASK 03C-DEBUG-14 to the coder. Investigate and minimally package/probe the required SDL 2.32.8 Android Java glue, run CI/build verification, then test the fresh diagnostic artifact on the real Mojo Android JVM and stop at the next genuine runtime boundary.
