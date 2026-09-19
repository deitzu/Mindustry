# Mindustry Android-JVM Patch Project - Session Handoff

## Project

Goal: run Mindustry through a Java/JVM runtime hosted on Android ARM64.

This target is explicitly:
- Android JVM on arm64-v8a
- Android/bionic ABI
- not Linux ARM64
- not desktop Linux
- not a normal Android APK
- not Mojo-specific at the native layer

Repository:
- deitzu/Mindustry
- default branch: master
- working branch: audit/task-01-native-artifact

Pinned Arc revision used by Mindustry:
- 8eb00ffff0126d0576c67df46f99b8f6bccd96fe

## Completed Tasks

### TASK 01 - Native Artifact Audit

Commit:
- 73bc87569599976b5dc96929ac55e83f3ff9a7b4

Report:
- docs/android-jvm/TASK_01_NATIVE_ARTIFACT_AUDIT.md

Key findings:
1. Arc's SharedLibraryLoader maps Linux+aarch64 JVM to libarcarm64.so, which is a desktop Linux/glibc native.
2. Arc already contains a real Android native:
   natives/natives-android/libs/arm64-v8a/libarc.so
3. backend-sdl has no Linux ARM target and no libsdl-arcarm64.so.
4. Linux SDL backend uses dynamic SDL2 and desktop OpenGL/libGL assumptions.
5. Therefore the original Android-JVM failure is a platform ABI mismatch, not simply a missing .so.0 file.

### TASK 02 - Native Build Feasibility

Commit:
- 25d61c8785ab14fc379eb60217e1c56e9c4f9a68

Report:
- docs/android-jvm/TASK_02_NATIVE_BUILD_FEASIBILITY.md

Key findings:
1. Existing Android Arc native can be reused:
   - natives/natives-android/libs/arm64-v8a/libarc.so
2. Existing Android FreeType native can be reused:
   - natives/natives-freetype-android/libs/arm64-v8a/libarc-freetype.so
3. Arc core already has addAndroid() native configuration:
   - -llog
   - -lOpenSLES
   - APP_STL := c++_static
4. FreeType build already has addAndroid().
5. backend-sdl cannot be reused unchanged:
   - addLinux(x64, x86) only
   - SDLGL.java includes GLEW
   - SDLGL.java calls glewInit()
   - Linux build links libGL
6. SDL2 itself can technically be built for Android ARM64 and can be statically linked, but the current Arc SDL JNI bridge must gain an Android/GLES path.
7. A hybrid native architecture is supported by the evidence:
   - reuse Android Arc native
   - reuse Android FreeType native
   - create Android ARM64 SDL native path for the JVM backend
8. No production source code was modified in TASK 02.

## Current Branch State

Branch:
audit/task-01-native-artifact

HEAD:
25d61c8785ab14fc379eb60217e1c56e9c4f9a68

The branch currently contains only the two audit reports.

## Important Source Evidence

Arc:
- arc-core/build.gradle
  - has addAndroid() for SoLoud
  - uses OpenSLES
  - uses c++_static
- arc-core/src/arc/util/SharedLibraryLoader.java
  - Android path uses System.loadLibrary()
  - Linux ARM64 path maps to libarcarm64.so
- arc-core/src/arc/util/OS.java
  - Android detection is separate from Linux
  - do NOT globally patch OS.isAndroid
- arc-core/src/arc/util/ArcNativesLoader.java
  - loads "arc"

Android backend:
- backends/backend-android/src/arc/backend/android/AndroidApplication.java
  - reports ApplicationType.android
  - loads Arc natives through ArcNativesLoader
- backends/backend-android/src/arc/backend/android/AndroidGraphics.java
  - uses Android EGL/GLSurfaceView
  - creates AndroidGL20/AndroidGL30
- backends/backend-android/src/arc/backend/android/AndroidGL20.java
  - calls android.opengl.GLES20 directly
- Android backend therefore demonstrates that Arc graphics abstraction already has a GLES implementation.

SDL backend:
- backends/backend-sdl/build.gradle
  - Linux only: addLinux(x64, x86)
  - GLEW fetched/built
  - Linux links sdl2-config + -lGL
- backends/backend-sdl/src/arc/backend/sdl/jni/SDLGL.java
  - #define GLEW_STATIC
  - #include "GL/glew.h"
  - glewInit()
- backends/backend-sdl/src/arc/backend/sdl/SdlGL20.java
  - thin forwarding wrapper into SDLGL
- backends/backend-sdl/src/arc/backend/sdl/SdlGL30.java
  - thin forwarding wrapper into SDLGL
- backends/backend-sdl/src/arc/backend/sdl/SdlApplication.java
  - creates SDL OpenGL context
  - reports ApplicationType.desktop
- backends/backend-sdl/src/arc/backend/sdl/SdlGraphics.java
  - uses ApplicationType.desktop
  - initializes SDLGL/GLEW

Android native artifacts at Arc commit:
- natives/natives-android/libs/arm64-v8a/libarc.so
- natives/natives-freetype-android/libs/arm64-v8a/libarc-freetype.so

Desktop native artifacts include:
- natives/natives-desktop/libs/libarcarm64.so
- backend-sdl/libs/linux64/libsdl-arc64.so
- backend-sdl/libs/linux64/libSDL2.so

## Constraints From Mandor

Do NOT:
- implement final solution during TASK 02
- modify SharedLibraryLoader yet
- rewrite SDLGL.java yet
- modify ClientLauncher
- modify DesktopLauncher
- patch OS.isAndroid globally
- treat Linux ARM64 as Android
- treat Android JVM as Android APK
- use Linux/glibc binaries as Android target
- create fake .so.0 shims
- make Mojo-specific detection
- rewrite the renderer

## Next Task

TASK 03 - Build a minimal Android arm64-v8a backend-sdl native probe.

Required scope:
1. Add an Android target to backend-sdl jnigen/build configuration.
2. Build SDL2 for Android arm64-v8a.
3. Build the JNI bridge against Android GLES/EGL instead of desktop GLEW/libGL.
4. Prefer static-linking SDL2 into the JNI library if technically possible.
5. Produce a minimal native artifact suitable for an Android JVM.
6. Do NOT integrate the artifact into Mindustry yet.
7. Do NOT change SharedLibraryLoader yet.
8. Do NOT change ClientLauncher/DesktopLauncher.
9. Any temporary probe must be clearly temporary and must not become production code.

Primary question for TASK 03:
Can Arc backend-sdl produce a loadable Android arm64-v8a JNI library without libSDL2-2.0.so.0, libGL.so.1, or GLEW?

## Known Caveat

The GitHub connector available in the analysis session exposes binary blobs through a UTF-8-oriented path, so full ELF symbol/DT_NEEDED extraction could not be independently rerun directly from GitHub binary blobs. Existing artifact evidence in TASK 01/02 should be treated as the current binary evidence.

## Handoff Rule

The next agent should read:
1. this file
2. TASK_01_NATIVE_ARTIFACT_AUDIT.md
3. TASK_02_NATIVE_BUILD_FEASIBILITY.md

Then continue from TASK 03. Do not restart the investigation from zero.
