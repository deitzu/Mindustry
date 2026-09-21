# TASK-04 — Android JVM Full Mindustry Runtime Reconnaissance

## Status
COMPLETE

Reconnaissance is complete as a failure map. The current android-jvm branch does not produce a current runnable Mindustry JAR because the earliest build boundary is a Java compile failure in :core:compileJava. No current full Android runtime success is claimed.

## Branch
android-jvm

Current head after recon instrumentation: 73498edc34adf59541941a12718e99ceecc3dddf

## Baseline
64ea7aeecb9f740ab08d7fd7a98583638464e8c6

## Arc Revision
8eb00ffff0126d0576c67df46f99b8f6bccd96fe

## Objective
Establish the current real Android-JVM runtime/build boundary without implementing another runtime fix. Distinguish source presence, CI/build evidence, native artifact evidence, historical Android runtime evidence, and unknown layers.

## Current Artifact
Current desktop/build/libs/Mindustry.jar: NOT PRODUCED.

Confirmed by CI/build: Continuous Build run 35575508517, job 106256344790, failed while packaging the Android-JVM build because :core:compileJava failed first. The current JAR therefore cannot be audited as a current integrated artifact.

## Source State
- AndroidJvmLauncher.java exists under core/src/mindustry/androidjvm/. Confirmed by source.
- desktop/build.gradle selects AndroidJvmLauncher when androidJvm is present. Confirmed by source.
- Patched Arc SharedLibraryLoader overlay exists in ci/android-jvm/task02d-arc-shared-library-loader.patch. Confirmed by source.
- Android ARM64 Arc native build exists and passed CI. Confirmed by CI/build.
- Android ARM64 SDL native build/package exists and passed CI. Confirmed by CI/build and artifact inspection.
- Normal desktop runtimeClasspath packaging remains from runtimeClasspathContents(). The old SharedLibraryLoader exclusion/reinjection workaround is absent. Confirmed by source.

## JAR Contents
Current Mindustry.jar is absent, so current Main-Class, AndroidJvmLauncher.class, SharedLibraryLoader.class, arm64-v8a/libarc.so, SDL native entries, and accidental desktop-native entries are UNKNOWN.

Historical DEBUG-14 diagnostic packaging is separate evidence: it packaged the four direct SDL JNI_OnLoad Java classes and the real libsdl-arc.so. It is not the current Mindustry.jar.

## Native Artifact Inventory
### Android Arc libarc.so
Confirmed by artifact inspection from run 35575508517, job 106256344579, artifact 10626849961.
SHA-256: 501e5a8da6c4486cff62834bff14dbeea4202a048119e5fe33e245523519aaa0
ELF64, AArch64, DYN, SONAME libarc.so, JNI symbol count 0.
DT_NEEDED: libm.so, liblog.so, libOpenSLES.so, libc.so, libdl.so.
No forbidden desktop/glibc dependency names were observed in the inspected dynamic section.

### Android SDL libsdl-arc.so
Confirmed by artifact inspection from run 35575508517, job 106256344790, artifact 10627687122.
SHA-256: d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7
ELF64, AArch64, DYN, SONAME libsdl-arc.so, JNI_OnLoad present.
Prior CI verification reported 566 JNI-related symbols, including 96 SDL JNI symbols and 470 SDLGL JNI symbols.
DT_NEEDED: libm.so, liblog.so, libandroid.so, libdl.so, libGLESv3.so, libGLESv1_CM.so, libc.so.
No forbidden desktop/glibc dependency names were observed in the inspected dynamic section.

These native artifacts are Android ARM64 candidates by CI/ELF inspection. This does not prove complete runtime initialization.

## Runtime Startup Chain
Expected chain from current source and project context:
Android JVM -> Main-Class -> AndroidJvmLauncher -> SdlApplication/SdlConfig -> patched Arc SharedLibraryLoader -> Android ARM64 native resource -> libsdl-arc.so -> SDL Android JNI initialization -> SDL_Init -> Android window/surface -> EGL/GLES -> ClientLauncher -> filesystem/assets -> input -> audio.

Stage map:
- Android JVM environment: previously observed on real Android. Confirmed by Android runtime.
- AndroidJvmLauncher source: present. Confirmed by source.
- Current AndroidJvmLauncher compilation: broken. Confirmed by CI/build.
- Current Main-Class in Mindustry.jar: UNKNOWN because no current JAR.
- Patched SharedLibraryLoader in source: present. Confirmed by source.
- Patched SharedLibraryLoader in current Mindustry.jar: UNKNOWN.
- Android Arc native build: PASS. Confirmed by CI/build and artifact inspection.
- Android SDL native build/package: PASS. Confirmed by CI/build and artifact inspection.
- Absolute-path native load: previously reached on real Android. Confirmed by prior Android runtime evidence.
- SDL Android Java class resolution: previously reached on real Android. Confirmed by prior Android runtime evidence.
- Four direct SDL JNI_OnLoad classes: packaged by DEBUG-14. Confirmed by CI/build and artifact inspection.
- Post-DEBUG-14 four-class Android runtime: UNKNOWN.
- Complete JNI registration, SDL_Init, Context/Activity, surface, EGL/GLES, ClientLauncher, filesystem/assets, input, audio, and full Mindustry startup: UNKNOWN.

## Actual Runtime Evidence
Real Android environment previously used: Mojo Launcher/MJLauncher, Android ARM64, Android API 31, OpenJDK Runtime Environment (Android), Oracle Corporation VM, JVM 21.0.12-internal, os.name Linux, os.arch aarch64, sun.arch.data.model 64.
Prior real-runtime checks: OS.isAndroid=true, OS.isLinux=false, OS.isARM=true, OS.is64Bit=true.

Prior DEBUG-13A real-runtime boundary:
embedded Android native resource -> extraction -> System.load(absolutePath) -> SDL Android JNI initialization -> missing org/libsdl/app/SDLControllerManager.

Confirmed by Android runtime via prior task record: absolute native load was entered; extracted file existed, was regular, readable, non-zero; SDL Java class resolution was reached.

Not proven by that run: complete JNI registration, SDL_Init, Android window/surface, EGL/GLES, or full Mindustry startup.

DEBUG-14 later packaged these four direct JNI_OnLoad classes: SDLActivity, SDLInputConnection, SDLAudioManager, SDLControllerManager. Its real-device four-class runtime remained unverified.

## Latest Crash / Log Evidence
Raw current Android runtime log after DEBUG-14: UNKNOWN. No current raw device log/crash file is present in the current repository state.
Prior runtime failure is preserved only as a task-recorded result, not as the raw device log: SDLControllerManager class resolution.
Current CI failure is directly logged in run 35575508517/job 106256344790. First meaningful compiler error: core/src/mindustry/androidjvm/AndroidJvmLauncher.java:4: error: package arc.backend.sdl does not exist.

## Missing Components
- Current integrated Mindustry.jar: missing because :core:compileJava fails.
- Current integrated JAR contents: unknown because no current JAR exists.
- Current post-DEBUG-14 Android runtime result: unknown.
- Complete JNI/SDL/Context/window/EGL/GLES/filesystem/input/audio/full-startup behavior: unknown.

## Broken Components
### AndroidJvmLauncher compile-time module boundary
Confirmed by source + CI/build.
AndroidJvmLauncher.java is part of the :core source set but imports arc.backend.sdl.*. The desktop project explicitly declares arcModule(backends:backend-sdl), while the core project dependency block does not.
CI then fails at :core:compileJava with the first meaningful error: package arc.backend.sdl does not exist. Later SdlApplication, SdlConfig, and related symbol errors are secondary consequences.

### Native stack
Not classified as currently broken. The Android Arc and SDL native artifacts pass the available CI/ELF checks, and prior Android testing reached absolute native loading. There is no newer real-device linker/JNI failure in the current evidence.

## Unknown Components
- Current Main-Class and current Mindustry.jar contents.
- Current integrated Arc loader bytecode/resource packaging.
- Current integrated SDL native packaging.
- Post-DEBUG-14 four-class real Android result.
- Complete JNI registration and all later SDL/Mindustry runtime layers.
- Raw post-DEBUG-14 Android crash/log.

## First Failure Boundary
Current complete Android-JVM build path fails first at the Java build layer:
AndroidJvmLauncher.java -> :core:compileJava -> FAIL: package arc.backend.sdl does not exist.

This occurs before current JAR creation, current JAR inspection, current native extraction from that JAR, and current Android runtime execution.

The last observed real Android runtime boundary remains SDL Android Java glue, where DEBUG-13A reached missing SDLControllerManager before DEBUG-14 packaged the required four classes.

## Root Cause
Current first blocker is confirmed by source + CI/build: AndroidJvmLauncher is compiled inside :core but directly imports Arc backend-sdl APIs that are not on the :core compile classpath. The desktop project has that dependency; the core project does not.

Runtime root cause after DEBUG-14 is UNKNOWN because the real Android four-class probe was not rerun in the available evidence.

## Changes Made
No production runtime source was modified for TASK-04.
Recon-only change added: .github/workflows/android-jvm-task04-runtime-recon.yml.
No changes were made to AndroidJvmLauncher.java, ClientLauncher, DesktopLauncher, SDLGL.java, renderer, AndroidLauncher, Arc revision, or SDL revision.

## CI Runs
- 35575508517 / job 106256344790: current Android-JVM build attempted; FAIL at :core:compileJava.
- 35575508517 / job 106256344579: Android Arc ARM64 native probe; PASS.
- 35575508517 / job 106256344790: Android SDL ARM64 native probe step; PASS before later Java compile failure.
- 35578976603 / job 106267182465: current PR test pipeline; was still in progress when captured and was not used for the root-cause conclusion.
- TASK-04 temporary workflow introduced at commit 73498edc34adf59541941a12718e99ceecc3dddf; its push-triggered run ID is not exposed by the available GitHub connector.

## Artifact IDs
- 10626849961 — Arc Android ARM64 native probe.
- 10627687122 — Android SDL native probe.
- 10603299911 — historical DEBUG-14 Android SDL JNI glue diagnostic package.

## Verification
Source: AndroidJvmLauncher exists; current backend/module dependency structure identified; normal runtimeClasspath packaging path retained.
CI/build: current native probes pass; current Mindustry Android-JVM build fails at :core:compileJava.
Artifact inspection: Arc and SDL Android ARM64 ELF/JNI/dependency evidence pass.
Android runtime: prior absolute native load and SDL class-resolution boundary confirmed; post-DEBUG-14 four-class runtime unknown.

## Known Limitations
- No current integrated Mindustry.jar exists.
- Raw historical Android runtime log is not present in the current repository, only its task-recorded result.
- No actual Android ARM64 JVM execution is available through the provided tool environment.
- GitHub connector does not expose the push-triggered TASK-04 workflow run ID.
- CI Linux execution is not an Android runtime substitute.
- Previous temporary TASK-02D diagnostics remain part of current branch history/state and should be cleaned in a separate focused task.

## Recommended Next Task
TASK-04-BUILD-01 — Resolve the AndroidJvmLauncher compile-time module boundary.

Scope: make the current AndroidJvmLauncher compile in its actual project/module context; address only the missing arc.backend.sdl compile dependency/classpath boundary; first rerun :core:compileJava; then rerun current desktop:dist.

Do not modify SharedLibraryLoader, SDL native architecture, GLES path, ClientLauncher, Android APK path, or runtime behavior in that next task.

After the build blocker is cleared, return to the real Android four-class runtime probe and stop at the next genuine runtime boundary.