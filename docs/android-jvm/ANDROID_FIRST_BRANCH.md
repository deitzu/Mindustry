# Android-JVM Branch Strategy

Status: ACTIVE STRATEGY
Branch: android-jvm
Base: ci/task-ci-01
Target: Android JVM / arm64-v8a / Android-bionic

## 1. Purpose

This branch is the dedicated Android-first development line for the Mindustry Android-JVM Patch Project.

The objective is to make the Mindustry Java/JVM runtime operate on Android ARM64 with real Android-compatible native libraries.

The official Mindustry repository remains the reference for desktop/Linux support. This branch does not treat desktop Linux ARM64/glibc compatibility as an acceptance requirement.

## 2. Runtime Target

Primary target:

Android JVM
-> Mindustry JAR
-> Android-compatible Arc/backend stack
-> Android/bionic native libraries
-> arm64-v8a / AArch64

Current first runtime environment:
Mojo Launcher / MJLauncher

Mojo is a test/runtime environment, not the architecture definition. The implementation must avoid launcher-specific hacks unless a later task explicitly proves they are required.

## 3. Native ABI Rule

The native target is Android/bionic.

Bionic and glibc are different libc environments. This branch must not attempt to make Android execute desktop Linux/glibc binaries.

Forbidden approaches remain:

- glibc .so dependencies
- libpthread.so.0
- libc.so.6
- ld-linux-aarch64.so.1
- libGL.so.1
- libSDL2-2.0.so.0
- renaming incompatible Linux libraries
- fake .so.0 compatibility shims
- prebuilt desktop Linux ARM64 libraries
- Mojo-specific native hacks presented as general Android compatibility

A native artifact is accepted only when actual ELF inspection and runtime evidence support Android compatibility.

## 4. Graphics Architecture

Android:

backend-sdl
-> Android GLES
-> static SDL2
-> Android EGL/system APIs

Desktop OpenGL/GLEW is no longer an acceptance target for this branch.

Do not replace SDL with GL4ES, LTW, Zink, or another Mojo renderer merely because Mojo provides those components. Such components belong to Mojo's renderer infrastructure and are not automatically equivalent to SDL's Android video/GLES path.

## 5. Linux / Desktop Policy

Desktop Linux behavior is treated as upstream/reference behavior, not the target of this branch.

However, shared source must not be destroyed merely to remove Linux support. Prefer isolated Android implementations, platform branches, overlays, or dedicated Android paths where practical.

A desktop regression is therefore not automatically a blocker for Android work, but accidental destructive changes to unrelated desktop code remain out of scope.

The original experimental branch ci/task-ci-01 is preserved as historical/debugging work.

## 6. Branch Policy

master
- protected
- untouched

ci/task-ci-01
- historical/debug development line
- preserves the TASK 03C investigation history

android-jvm
- active Android-first implementation branch
- derived from the latest ci/task-ci-01 state
- future Android compatibility work belongs here

Do not reset, rebase, or force-push these branches as part of ordinary task work.

## 7. Evidence Policy

Every meaningful Android change must distinguish:

- Confirmed by source
- Confirmed by CI/build
- Confirmed by artifact inspection
- Confirmed by real Android runtime
- Inference
- Unknown

Build success is not runtime success.

A native library being AArch64 is not sufficient proof of Android compatibility.

## 8. Current Runtime Boundary

The native Android ARM64 SDL artifact is already proven buildable and packageable.

Real Android JVM testing has proven:

- Android detection
- ARM64 detection
- native library mapping
- JAR resource extraction
- absolute-path System.load() entry

The current runtime boundary is SDL Android Java glue / JNI_OnLoad-related initialization.

Current missing class:

org.libsdl.app.SDLControllerManager

This is the next debugging boundary. Do not skip ahead to full Mindustry startup.

## 9. Immediate Task

TASK 03C-DEBUG-14

Objective:

Determine and minimally package the real SDL 2.32.8 Android Java glue required for native initialization to proceed beyond the current missing class.

Stop at the next genuine runtime boundary.

Do not use fake SDL classes.

Do not implement full Activity/lifecycle/rendering integration until evidence reaches that layer.

## 10. Long-Term Sequence

DEBUG-14
-> SDL Android Java glue

DEBUG-15+
-> complete JNI initialization
-> SDL initialization
-> Android window/surface
-> EGL/GLES
-> input/lifecycle
-> Mindustry backend initialization
-> Android-JVM entry point
-> full runtime integration
-> final Android ARM64 validation

Each newly discovered failure gets its own focused task/report.

## 11. Documentation

Historical TASK/DEBUG reports remain immutable.

This file records the active branch strategy. It does not replace individual task reports or the current context backup.

Every meaningful task must leave a reproducible handoff containing:

Status:
Branch:
Baseline:
Commit:
Files changed:
Result:
CI:
Build:
Verification:
Known limitations:
Next task:
