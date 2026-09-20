# Mindustry Android-JVM Patch Project — Context Backup

Snapshot updated: 2026-09-20
Purpose: mutable current-state recovery point for future sessions. Individual TASK/DEBUG reports remain immutable historical records.

## 1. Project Objective — AUDITED

Primary objective:

Run Mindustry as a Java/JVM application on a real Android ARM64 runtime.

Target:

- Android JVM
- arm64-v8a / AArch64
- Android/bionic ABI
- real Android-compatible native libraries
- generic Android JVM compatibility
- Mojo Launcher / MJLauncher is the first real runtime environment, not the definition of the architecture

The project is NOT trying to preserve desktop Linux ARM64/glibc compatibility in the Android branch.

The official Mindustry repository remains the reference for its normal desktop/Linux implementation. This fork is an Android-first engineering line.

Important terminology:

- Android uses bionic, not glibc.
- The target is Android/bionic-native ELF.
- Desktop Linux/glibc binaries are not acceptable Android runtime dependencies.

Not the target:

- desktop Linux ARM64/glibc compatibility
- APK-only execution as the JVM solution
- renamed incompatible Linux libraries
- fake .so.0 compatibility shims
- glibc binaries used as an Android workaround
- hardcoded Mojo-only hacks presented as generic Android support
- replacing the SDL backend with GL4ES/LTW/Zink without evidence

## 2. Repository / Branch Strategy

Repository:

- deitzu/Mindustry
- protected branch: master

Historical/debug branch:

- ci/task-ci-01
- preserves the earlier TASK 03C investigation chain

Active Android-first branch:

- android-jvm
- created from the latest ci/task-ci-01 state
- current HEAD: 7ad0c7741ce22ec61ecb1f68f2b5ad57801c1a75

Current HEAD commit:

- 7ad0c7741ce22ec61ecb1f68f2b5ad57801c1a75
- message: Document DEBUG-14 final CI success

Do not reset, rebase, or force-push as ordinary task operations.
Do not modify master.

Current branch strategy is documented in:

- docs/android-jvm/ANDROID_FIRST_BRANCH.md

## 3. Acceptance Policy

Primary acceptance target:

Android JVM + arm64-v8a + Android/bionic + real runtime compatibility.

Desktop Linux support is NOT an acceptance criterion for this branch.

Desktop build/regression checks may still be run when convenient, especially for shared-source safety, but a Linux-only incompatibility is not by itself a reason to block Android progress.

The existing Android APK is not the JVM solution. It may remain a secondary regression/reference target when practical, but Android-JVM compatibility is the primary acceptance target.

Do not spend project tasks preserving Linux behavior unless a later implementation explicitly requires a shared path or the preservation is nearly free.

Do not intentionally destroy unrelated desktop code merely for cleanup. Prefer Android-specific paths or isolated platform changes.

## 4. Core Architecture

Android:

backend-sdl
-> Android GLES
-> static SDL2
-> Android EGL/system APIs

Target native ABI:

Android/bionic
-> arm64-v8a / AArch64

Desktop:

backend-sdl
-> desktop OpenGL/GLEW
-> SDL2

Desktop behavior is reference/upstream behavior, not the Android branch's acceptance target.

Do not globally convert the desktop OpenGL/GLEW implementation into Android GLES.

## 5. Native Rules

Never use:

- libpthread.so.0
- libc.so.6
- ld-linux-aarch64.so.1
- libGL.so.1
- libSDL2-2.0.so.0
- desktop Linux ARM64 libraries
- fake compatibility .so.0 files
- library renaming as an ABI workaround

Native compatibility must be demonstrated through actual artifact inspection and real Android runtime evidence.

For native artifacts, verify where applicable:

- ELF class
- AArch64 machine
- Android/bionic compatibility
- program headers/interpreter
- DT_NEEDED
- SONAME
- JNI symbols
- forbidden dependency scan

## 6. Pinned Dependencies

Arc:

8eb00ffff0126d0576c67df46f99b8f6bccd96fe

SDL:

- version 2.32.8
- commit 98d1f3a45aae568ccd6ed5fec179330f47d4d356
- release ref release-2.32.8

Android CI toolchain:

- NDK 30.0.16248370
- Android API 36
- CMake 3.31.6

Do not silently change pinned revisions.

## 7. Completed Work

TASK 01 — Native Artifact Audit

Complete.

Established that available ARM64 Linux native libraries can still be incompatible with Android because they use glibc/Linux userspace dependencies.

TASK 02 — Native Build Feasibility

Complete.

Established the feasible Android SDL path:

Android backend-sdl
-> static SDL2
-> Android GLES
-> Android system libraries

Identified SDLGL.java as the main native GL compatibility boundary.

TASK 03A — Android CI Toolchain Bootstrap

Complete.

Established deterministic Android SDK/NDK tooling.

TASK 03B — Android backend-sdl audit/plan

Complete.

Established:

- current backend-sdl has no Android target
- current Linux path uses dynamic SDL2 and desktop OpenGL/libGL
- global GLEW handling conflicts with Android
- Android implementation should be platform-specific
- SDL 2.32.8 already contains Android video/GLES support
- static SDL2 is feasible

TASK 03C native/debug chain

Completed boundaries:

- Android ARM64 native build
- ELF/JNI/dependency verification
- Android OS detection on real JVM
- Android ARM64 architecture detection
- native library mapping
- native search-path diagnosis
- absolute-path native load isolation
- SDL Android Java glue source/package diagnosis

## 8. Important Runtime Evidence

Real Android environment:

- Mojo Launcher / MJLauncher
- Android ARM64
- Android API 31
- OpenJDK Runtime Environment (Android)
- Java VM vendor Oracle Corporation
- JVM 21.0.12-internal
- os.name = Linux
- os.arch = aarch64
- sun.arch.data.model = 64

DEBUG-12A proved:

- OS.isAndroid=true
- OS.isLinux=false
- OS.isARM=true
- OS.is64Bit=true
- library mapping for sdl-arc is correct

Do not interpret the Java exception text "target: Linux, 64-bit" as proof that OS.isLinux is true. os.name is still Linux on the Android JVM.

## 9. Native Discovery Boundary

Execute-JAR under Mojo does not automatically place a JAR-contained native resource into the JVM native search path.

Real runtime evidence showed:

System.loadLibrary("sdl-arc")
-> native search-path discovery failure

The embedded JAR resource existed, but the native file was absent from all relevant java.library.path entries.

No production SharedLibraryLoader change has been made.

This remains a later integration decision, not a reason to alter the historical diagnostic chain.

## 10. DEBUG-13A Absolute-Path Boundary

The real Android JVM extracted the actual Android native library from the JAR and called:

System.load(absolutePath)

Observed:

- file exists
- regular file
- readable
- non-zero size
- real ARM64 native artifact
- absolute load path entered

Then SDL Android JNI initialization reached Java glue resolution and failed on:

org/libsdl/app/SDLControllerManager

Precise meaning:

Confirmed:

- Android filesystem extraction
- absolute System.load() entry
- native initialization reached SDL Android Java class resolution
- missing SDLControllerManager class

Not proven at that stage:

- complete JNI registration
- complete native initialization
- SDL_Init
- Android surface/window
- EGL
- GLES runtime
- full Mindustry startup

## 11. DEBUG-14 — COMPLETE

Current report:

docs/android-jvm/TASK_03C_DEBUG_14_FINAL.md

DEBUG-14 CI/package scope is complete.

Final CI for commit b4433a1dc78bd4910724268645c1c06bf7ac08f1:

- Continuous Build: 35505910722 — PASS
- Tests: 35505910743 — PASS
- Gradle Wrapper validation: 35505910713 — PASS

Final artifact:

Android-JVM-android-jni-glue-load-probe-b4433a1dc78bd4910724268645c1c06bf7ac08f1

Artifact ID:

10603299911

Artifact SHA-256:

9641318b1c58be12e7b153267379937192f73ba4e29bf54b147a1d0853a9c8f7

SDL 2.32.8 source:

98d1f3a45aae568ccd6ed5fec179330f47d4d356

Direct Java JNI_OnLoad classes proven from SDL source:

- org/libsdl/app/SDLActivity
- org/libsdl/app/SDLInputConnection
- org/libsdl/app/SDLAudioManager
- org/libsdl/app/SDLControllerManager

Important source detail:

SDLInputConnection is a top-level class declared in SDLActivity.java at this SDL revision. There is no separate SDLInputConnection.java file.

Native SHA-256:

d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7

Embedded native SHA-256:

d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7

Therefore the diagnostic package embeds the same real native artifact.

DEBUG-14 proves:

- source selection
- four-class identification
- Java compilation
- deterministic packaging
- artifact integrity
- CI success

DEBUG-14 does NOT prove real Android runtime success with the four classes.

## 12. DEBUG-14 CI Failure History

The DEBUG-14 CI/package chain had multiple separate failures, preserved as historical evidence.

Relevant fixes included:

- SDL checkout validation/self-download
- SDL source path/version corrections
- script root detection
- class-list ordering assertion correction

The final green pipeline confirms the current package construction is reproducible in CI.

Do not rewrite earlier reports merely because later fixes succeeded.

## 13. Current Runtime Boundary

The current unclosed runtime boundary is:

real Android JVM
-> absolute System.load(absPath)
-> SDL Android JNI_OnLoad
-> four real SDL Java glue classes available
-> observe the next genuine runtime result

Do not preemptively add more SDL classes.

Do not claim complete JNI success until the real Android JVM proves it.

## 14. Immediate Next Task

TASK 03C-DEBUG-15 — Real Android Four-Class JNI Load Probe

Objective:

Run the final DEBUG-14 four-class diagnostic artifact on the real Mojo Android JVM and capture the earliest post-class-resolution boundary.

Expected test flow:

diagnostic JAR
-> real Mojo Android JVM
-> extract real libsdl-arc.so
-> System.load(absPath)
-> four SDL Java classes available
-> observe next boundary

Possible results:

- System.load() completes
- next missing Java class
- missing method/field
- JNI registration failure
- Android Context requirement
- Activity requirement
- surface/window requirement
- another native runtime/linker failure

STOP at the first genuine new boundary.

Do not solve future runtime layers in DEBUG-15.

## 15. Do Not Touch Yet

Unless new evidence requires it, do not modify:

- SharedLibraryLoader
- Mojo renderer hooks
- GL4ES/LTW/Zink integration
- full SDLActivity integration
- Android Activity lifecycle
- EGL/surface integration
- Mindustry renderer
- SdlApplication
- SdlGraphics
- ClientLauncher
- DesktopLauncher
- Arc pinned source
- Arc revision
- SDL version

The old Linux loader issue is a known discovery diagnosis. It is not the next runtime test.

## 16. Android-First Engineering Policy

For the active android-jvm branch:

1. Android/bionic compatibility is the primary target.
2. Linux/glibc compatibility is not an acceptance requirement.
3. Mojo is a runtime environment/test target, not the architecture definition.
4. Use real Android native libraries.
5. Preserve evidence and immutable history.
6. Prefer the smallest platform-specific change that crosses the next real boundary.
7. Do not infer runtime compatibility from CI.
8. Do not solve multiple future layers in one task.

## 17. Long-Term Roadmap

TASK 03C:

- Android ARM64 native build: COMPLETE
- artifact/ELF/JNI/dependency verification: COMPLETE
- Android runtime detection: COMPLETE
- native discovery diagnosis: COMPLETE
- absolute-path native-load isolation: COMPLETE
- SDL Android Java glue package: COMPLETE
- real four-class JNI load: NEXT
- complete JNI initialization: PENDING
- SDL_Init: PENDING
- Android Context/Activity: PENDING
- window/surface: PENDING
- EGL/GLES context: PENDING
- backend-sdl runtime initialization: PENDING
- Mindustry runtime initialization: PENDING

TASK 04:

Android-JVM entry point
- pending until required runtime boundaries are proven

TASK 05:

Runtime integration
- pending

TASK 06:

Final Android ARM64 validation
- pending

Desktop Linux remains upstream/reference behavior and is not an acceptance gate for the Android-first branch.

## 18. Documentation / History

Historical TASK/DEBUG reports remain immutable.

Current mutable context:

docs/android-jvm/PROJECT_CONTEXT_BACKUP_2026-09-20.md

Active strategy:

docs/android-jvm/ANDROID_FIRST_BRANCH.md

Latest historical report:

docs/android-jvm/TASK_03C_DEBUG_14_FINAL.md

PROJECT_HANDOFF.md is maintained on the separate audit branch:

audit/task-01-native-artifact

It is intentionally not expected on android-jvm.

## 19. Current Handoff

Status:

DEBUG-14 CI/package complete. Android-first strategy audited and retained. Current next boundary is the real Android four-class JNI load probe.

Branch:

android-jvm

Baseline for current completed DEBUG-14 package task:

b4433a1dc78bd4910724268645c1c06bf7ac08f1

Current branch HEAD:

7ad0c7741ce22ec61ecb1f68f2b5ad57801c1a75

Commit:

7ad0c7741ce22ec61ecb1f68f2b5ad57801c1a75

Pinned Arc:

8eb00ffff0126d0576c67df46f99b8f6bccd96fe

Pinned SDL:

2.32.8 / 98d1f3a45aae568ccd6ed5fec179330f47d4d356

Result:

Android-first branch strategy now explicitly treats Android JVM / arm64-v8a / Android-bionic as the acceptance target. Desktop Linux/glibc support is upstream/reference behavior and is not an acceptance gate. DEBUG-14 produced and verified the four-class SDL Android Java glue diagnostic package.

CI:

- 35505910722 — Continuous Build: PASS
- 35505910743 — Tests: PASS
- 35505910713 — Gradle Wrapper validation: PASS

Verification:

- Android ARM64 native build: PASS
- ELF/JNI/dependency checks: PASS
- DEBUG-14 four-class packaging: PASS
- artifact SHA integrity: PASS
- real Android four-class runtime: NOT YET VERIFIED

Known limitations:

- full JNI initialization unknown
- SDL_Init unknown
- Android context/activity/surface unknown
- EGL/GLES runtime unknown
- full Mindustry startup unknown
- loader integration remains pending
- compatibility with launchers other than Mojo remains unverified

Next task:

TASK 03C-DEBUG-15 — Real Android Four-Class JNI Load Probe
