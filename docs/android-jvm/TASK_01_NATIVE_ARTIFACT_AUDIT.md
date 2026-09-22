# Task 01 - Native Artifact Audit

Status: COMPLETE (audit only)
Date: 2026-09-19
Mindustry base: master @ 4ef2a6d81e2732de16d73d233d3182ec7f0dc63d
Arc dependency: 8eb00ffff0126d0576c67df46f99b8f6bccd96fe

## Scope

Audit the native loading/build path for the Android-JVM target before making architectural changes.

## Confirmed source-level path

Desktop entry point:

DesktopLauncher -> SdlApplication -> ArcNativesLoader.load()
  -> SharedLibraryLoader.load("arc")

Then the SDL class is initialized:

SDL static initializer
  -> SharedLibraryLoader.load("sdl-arc")

## Finding 1: Arc native selection

Mindustry's desktop module depends on Arc's desktop native module:

- arcModule("natives:natives-desktop")
- arcModule("backends:backend-sdl")

Mindustry pins Arc to 8eb00ffff0.

At Arc 8eb00ffff0126d0576c67df46f99b8f6bccd96fe, the desktop native package contains:

- libarc64.so
- libarcarm64.so
- libarc64.dylib
- libarcarm64.dylib
- arc64.dll

The Android native package is separate and contains ABI directories, including:

- natives/natives-android/libs/arm64-v8a/libarc.so

Arc's SharedLibraryLoader selects native names from OS flags. On a JVM that reports itself as Linux/aarch64 and is not recognized as Android, "arc" maps to libarcarm64.so and uses extraction + System.load().

Therefore, an Android-hosted JVM can select the desktop Linux ARM64 Arc native instead of the Android libarc.so.

The uploaded native-archive audit independently identified libarcarm64.so as an AArch64 Linux/glibc binary, with dependencies including glibc-style .so.0 libraries.

## Finding 2: SDL backend has no Linux ARM64 target

Arc backend-sdl defines Linux native generation only with:

addLinux(x64, x86)

There is no addLinux(... ARM) rule in backend-sdl at this commit.

Its Linux resources contain:

- libs/linux64/libSDL2.so
- libs/linux64/libsdl-arc64.so

There is no corresponding libsdl-arcarm64.so resource in this backend.

SharedLibraryLoader would request libsdl-arcarm64.so on Linux ARM64, so this is a direct platform/resource mismatch.

## Finding 3: SDL2 is dynamically linked on Linux

backend-sdl's Linux build obtains SDL linker arguments from:

sdl2-config --libs

and appends:

-Wl,-Bdynamic -lGL

The Linux SDL.java initializer also explicitly attempts to load the bundled libSDL2.so before loading sdl-arc.

The uploaded native archive reports the SDL2 library SONAME as:

libSDL2-2.0.so.0

and reports libsdl-arc64.so as depending on:

- libSDL2-2.0.so.0
- libGL.so.1
- libc.so.6

This confirms the current Linux SDL path assumes a desktop Linux graphics/runtime stack.

## Finding 4: Android-native Arc support already exists

Arc does have a genuine Android ARM64 native artifact:

natives/natives-android/libs/arm64-v8a/libarc.so

Arc's arc-core native build also contains a dedicated addAndroid() target using Android-specific native libraries and OpenSLES support.

Therefore, the project does not need a new ARM64 Arc native from scratch merely to obtain an Android-compatible Arc library.

## Likely first native failure

The source-level initialization order makes the first native load:

ArcNativesLoader.load("arc")

For a Linux/aarch64 JVM that is not recognized as Android, this selects the desktop libarcarm64.so first.

The next independent problem is the SDL backend: no Linux ARM64 sdl-arc native is shipped/built by backend-sdl at this commit.

This means there are at least two distinct native compatibility problems. Fixing only the visible .so.0 error is not sufficient.

## DT_NEEDED / symbol-level limits

The uploaded project evidence establishes the relevant DT_NEEDED entries listed above.

The exact complete DT_NEEDED graph and the exact symbol-to-library references were not re-extracted from the binary blobs through GitHub in this session because the connector exposes binary blobs as UTF-8-only content.

Therefore this audit does not claim a complete symbol-level dependency graph beyond the archive evidence already recorded in the project notes.

## Static-linking conclusion

The current Linux backend-sdl build does not statically link SDL2; it explicitly uses dynamic linking on Linux.

Windows uses SDL static linker arguments, but that does not establish Android feasibility.

Whether SDL can/should be statically linked for an Android-JVM target is deferred to Task 02.

## Task 01 conclusion

The Android-JVM failure is not just a missing file rename problem.

The current source/build configuration has a platform-selection mismatch:

Android-native Arc exists, but the desktop JVM loader can select the Linux/glibc libarcarm64.so.

Separately, backend-sdl has no Linux ARM64 native artifact at all and is built around desktop OpenGL/SDL assumptions.

No source-code implementation change was made in Task 01.

Next task: TASK 02 - Native Build Feasibility.
