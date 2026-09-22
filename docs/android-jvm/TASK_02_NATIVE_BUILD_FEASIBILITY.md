# TASK 02 - Native Build Feasibility

Status: COMPLETE (analysis only)
Date: 2026-09-19
Mindustry: deitzu/Mindustry @ master 4ef2a6d81e2732de16d73d233d3182ec7f0dc63d
Arc: 8eb00ffff0126d0576c67df46f99b8f6bccd96fe

1. Arc Core Native Feasibility

The existing Arc Android native path is reusable for an Android-hosted JVM.

Arc has a dedicated Android native package with:

- natives/natives-android/libs/arm64-v8a/libarc.so
- natives/natives-freetype-android/libs/arm64-v8a/libarc-freetype.so

The Arc native build uses a dedicated addAndroid() configuration in arc-core/build.gradle. That target links Android-specific libraries (-llog and -lOpenSLES), selects the Android OpenSLES backend, and requests APP_STL := c++_static.

Therefore libarc.so is the intended Android arm64-v8a output, not the Linux/aarch64 libarcarm64.so. The build provenance is clear. The GitHub connector cannot decode binary blobs as UTF-8, so the exact DT_NEEDED entries of libarc.so were not independently re-read with readelf in this session. The conclusion about its Android target is based on the dedicated Android build target and arm64-v8a packaging.

This is important because Android ARM64 compatibility is an ABI/runtime property, not merely the CPU architecture. The Android NDK explicitly treats AArch64 as arm64-v8a.

The existing SharedLibraryLoader already has an Android path: when OS.isAndroid is true, it uses System.loadLibrary() instead of extracting a desktop library. On Android, the mapped library name is left as the undecorated name, so loading "arc" resolves to the normal Android libarc.so form.

For an Android-hosted JVM, an Android-native libarc.so is usable in principle, provided the JVM runs in the Android process and its native loading mechanism uses the Android linker/JNI ABI. Android's System.load() accepts an absolute file path, while System.loadLibrary() resolves an undecorated name through the runtime's native-library search mechanism.

Therefore:

- Reusing libarc.so: feasible.
- Reusing libarc-freetype.so: feasible.
- Copying/extracting the libraries before loading: possible when the host JVM cannot expose them through its normal native-library path.
- System.load(): suitable for an explicitly located extracted file.
- System.loadLibrary(): suitable when the library is in a location visible to the JVM/class-loader native-library search path.
- Current SharedLibraryLoader: already has the necessary Android-side loading primitive, but the runtime classification problem remains and must be handled later without globally forcing OS.isAndroid.

No SharedLibraryLoader changes are made in TASK 02.

2. SDL Native Feasibility

The current backend-sdl can be adapted to an Android ARM64 native target, but it cannot be used unchanged.

The strongest evidence is the contrast between its current build and Arc's other Android targets.

Current backend-sdl build:

- explicitly defines Linux native generation with addLinux(x64, x86)
- has no addLinux(... ARM) target
- downloads/compiles GLEW
- compiles SDL JNI against GL/glew.h
- calls glewInit()
- links Linux with sdl2-config --libs and -Wl,-Bdynamic -lGL
- ships Linux resources under libs/linux64

The SDL JNI bridge is therefore tightly coupled to desktop OpenGL in its current form.

SDL.java itself wraps SDL window/context functions, but SdlApplication explicitly requests desktop OpenGL profile values (core/compatibility), and the Java wrapper does not expose the ES profile constant currently. SdlGraphics constructs GLVersion using ApplicationType.desktop.

SDLGL.java is more directly coupled: it defines GLEW_STATIC, includes GL/glew.h, calls glewInit(), and exposes the GL20/GL30 surface through GLEW-backed native functions.

SdlGL20 and SdlGL30 are comparatively thin Java forwarding layers. They do not contain the desktop-native ABI themselves; they forward into SDLGL. This means the existing Arc graphics abstraction can remain conceptually intact, while the native GL bridge needs an Android/GLES implementation.

Android SDL compilation itself is technically supported. SDL's Android documentation describes arm64-v8a builds and its Android OpenGL ES/EGL path. SDL can also be built as a static library. The problem is that the current Arc backend-sdl Gradle configuration does not invoke an Android target and its native bridge is written for desktop OpenGL/GLEW.

The required native-direction changes would therefore be:

- add a dedicated Android jnigen target rather than pretending Linux ARM is Android
- compile SDL2 with the Android NDK
- use Android GLES/EGL rather than libGL
- remove GLEW from the Android variant
- replace the GLEW-dependent function initialization/extension path with GLES-compatible calls or explicit function lookup where required
- link SDL2 statically into the JNI library when practical
- account for SDL's Android Java/platform glue during later runtime integration

This is native/backend adaptation, but not evidence for rewriting Mindustry's renderer.

3. Audio/Other Native Feasibility

Arc's existing audio native path is reusable.

arc-core/build.gradle already contains addAndroid():

- OpenSLES backend sources are selected
- -llog and -lOpenSLES are linked
- APP_STL := c++_static is requested

The same arc-core native library therefore already contains an Android-specific SoLoud configuration. The high-level Arc Audio Java class simply initializes SoLoud and does not introduce a separate platform-specific audio backend.

This means no new audio implementation is justified for the JVM-on-Android native stack at this stage.

OpenSL ES is deprecated by current Android NDK documentation, with AAudio/Oboe recommended for new development, but OpenSL ES remains a supported Android native API. Therefore deprecation is a maintenance concern, not the blocker for this feasibility task.

FreeType is also already separated correctly. Arc has:

- natives/natives-freetype-android/libs/arm64-v8a/libarc-freetype.so

and its FreeType build invokes addAndroid(). The existing Mindustry Android Gradle build already knows how to package the Android Arc and FreeType native directories as jniLibs.

For the JVM target, these Android-native artifacts must be made available to the JVM's native-library search/loading mechanism, but their native compilation does not need to be recreated.

4. Native Loading Feasibility

The evidence supports a hybrid strategy.

Existing Android-native artifacts can be reused for Arc core and FreeType. The SDL backend requires a separate Android ARM64 native build because no Android SDL artifact exists in backend-sdl at the pinned Arc commit.

So the practical architecture is:

- Arc core: reuse existing Android libarc.so
- FreeType: reuse existing Android libarc-freetype.so
- SDL backend: build an Android arm64-v8a variant specifically for the JVM target
- JVM runtime: load the Android-native libraries from locations accessible to the host JVM

This is not equivalent to making Linux ARM64 binaries work on Android.

A pure reuse strategy is insufficient because backend-sdl has no Android native artifact.

A pure new-package strategy would unnecessarily rebuild functionality that Arc already provides for Android.

A full renderer/backend rewrite is not yet required by the native evidence.

A compatibility-shim strategy for glibc/Linux .so.0 libraries is not justified. It would preserve the wrong ABI assumption instead of producing Android-native binaries.

5. Static Linking Feasibility

Static-linking SDL2 into the Android JNI library is technically feasible.

SDL's official Android build documentation describes Android-native builds and the CMake project exposes static SDL targets. Static linking is also already used elsewhere in Arc's Android native configuration through APP_STL := c++_static.

The desired Android-native dependency shape is therefore realistic:

JNI shared library
  -> statically linked SDL2
  -> Android NDK/system APIs
  -> GLES/EGL
  -> Android/bionic runtime

instead of:

JNI shared library
  -> libSDL2-2.0.so.0
  -> libGL.so.1
  -> glibc/libc.so.6

Static SDL2 would eliminate the desktop SDL2 SONAME dependency from the JNI library. Building against Android GLES/EGL instead of desktop OpenGL would eliminate the need for libGL.so.1.

Static linking does not remove every runtime dependency. The resulting Android shared library can still depend on Android system libraries such as liblog and graphics/audio system APIs. Those are expected Android dependencies rather than Linux/glibc desktop dependencies.

The C++ runtime requires deliberate treatment. Arc's existing Android native build already chooses c++_static for its SoLoud target, which is evidence that this project already uses the static C++ runtime pattern for Android-native output.

No static-linking implementation was performed in TASK 02.

6. Architecture Options

Option 1: Rebuild existing native libraries for Android

Files/components:
- Arc native build targets
- Android native packaging directories

Native changes:
- Android NDK targets and Android-specific linker flags

Java changes:
- Native loading/packaging integration only

Major blocker:
- backend-sdl still needs an Android-capable GLES JNI implementation

Risk:
- Moderate; preserves existing module boundaries but requires native build work.

Option 2: Add an Android target to backend-sdl

Files/components:
- Arc backends/backend-sdl/build.gradle
- backend-sdl JNI sources
- Android SDL source/build inputs

Native changes:
- add Android jnigen target
- Android SDL build
- remove Linux libGL/GLEW assumptions
- optionally static-link SDL2

Java changes:
- later adjustment of SDL application/graphics platform type and context setup

Major blocker:
- current SDLGL implementation is GLEW/OpenGL based, and SDL Android also has Java/platform glue requirements.

Risk:
- Moderate to high; keeps the SDL backend architecture but adds a platform-specific native path.

Option 3: Create a separate Android-JVM backend

Files/components:
- new backend module
- Android/JVM integration code
- native packaging

Native changes:
- can reuse libarc.so and libarc-freetype.so
- may reuse or independently package SDL2 Android native code

Java changes:
- new Application/Graphics/Input integration for the JVM runtime

Major blocker:
- the host JVM must provide an Android window/surface/lifecycle integration model without relying on a specific launcher implementation.

Risk:
- High; isolates desktop assumptions but expands Java-side integration.

Option 4: Patch Mindustry Java to avoid SDL

Files/components:
- Mindustry desktop/JVM entry path
- potentially core startup code

Native changes:
- possibly none for SDL if another backend is used

Java changes:
- substantial backend/application integration

Major blocker:
- graphics, input, windowing, audio, and lifecycle must all be supplied by another backend.

Risk:
- High; scope expands beyond the native dependency issue.

Option 5: Keep desktop-native libraries and provide compatibility shims

Files/components:
- native loader
- shim libraries
- Android packaging

Native changes:
- emulate Linux/glibc or desktop library interfaces

Java changes:
- loader/path handling

Major blocker:
- the existing binaries target the wrong operating-system ABI and desktop OpenGL/SDL stack.

Risk:
- Very high; likely to produce a fragile compatibility layer and does not solve the underlying Android-native requirement.

7. Minimum Required Changes

For the smallest technically valid native implementation, the modification boundary is:

Arc:
- backends/backend-sdl/build.gradle
- backends/backend-sdl/src/arc/backend/sdl/jni/SDL.java
- backends/backend-sdl/src/arc/backend/sdl/jni/SDLGL.java
- Android SDL2 source/build inputs used by the new Android target
- potentially backends/backend-sdl/src/arc/backend/sdl/SdlApplication.java and SdlGraphics.java for Android context/profile/type behavior after the native build works

Reuse without modification:
- arc-core Android native build/output
- natives/natives-android/libs/arm64-v8a/libarc.so
- natives/natives-freetype-android/libs/arm64-v8a/libarc-freetype.so
- arc-core/build.gradle Android SoLoud configuration

Mindustry integration boundary:
- build.gradle / JVM-target packaging configuration will eventually need to expose the Android-native artifacts to the JVM runtime.
- desktop/build.gradle should not be repurposed into an Android build; desktop packaging must remain unchanged.
- the eventual Android-JVM entry point belongs in a separate runtime/backend area, not in AndroidLauncher and not by modifying ClientLauncher.

The current Mindustry build consumes Arc externally through the pinned arcHash, so backend-sdl native changes belong to the Arc source/build boundary rather than to a random Mindustry Java patch.

No files from these modification boundaries were changed in TASK 02.

8. Recommended Next Implementation Task

TASK 03 - Build a minimal Android arm64-v8a backend-sdl native probe: add an Android jnigen target, compile the JNI bridge against Android SDL2/GLES without GLEW/libGL, and statically link SDL2 where the build allows it. Do not integrate it into Mindustry or change the JVM loader yet.
