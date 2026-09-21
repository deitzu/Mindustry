# FIX_ANDROID_SDL_JAVA_GLUE

## Status

COMPLETE — Android-JVM SDL Java JNI glue packaging is implemented and verified by the full Continuous Build. Physical Android ARM64 runtime execution remains a separate next task.

## Objective

Package the minimum SDL 2.32.8 Android Java JNI glue required by the confirmed Android-JVM runtime failure:

`NoClassDefFoundError: org/libsdl/app/SDLControllerManager`

The glue must be packaged only with `-PandroidJvm`. Normal desktop packaging must remain unchanged.

## Baseline

Branch: `android-jvm`

Baseline commit: `707d4d2791c0fe95af01dfae4c1ef54f70d618d0`

Pinned Arc revision: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

SDL: `2.32.8`

SDL source commit: `98d1f3a45aae568ccd6ed5fec179330f47d4d356`

## Runtime blocker

### Confirmed by Android runtime

The previous real-device failure was:

```
java.lang.NoClassDefFoundError: org/libsdl/app/SDLControllerManager

Caused by: java.lang.ClassNotFoundException:
    org.libsdl.app.SDLControllerManager
```

The device had already passed Android SDL resource discovery and native file extraction, so this task targets Java SDL Android glue rather than the native `.so` discovery path.

## Source evidence

### Confirmed by source

SDL 2.32.8 directly requires these Android Java classes:

```
org/libsdl/app/SDLActivity.class
org/libsdl/app/SDLInputConnection.class
org/libsdl/app/SDLAudioManager.class
org/libsdl/app/SDLControllerManager.class
```

The identified package-private dependency closure is:

```
org/libsdl/app/SDLJoystickHandler.class
org/libsdl/app/SDLJoystickHandler_API16.class
org/libsdl/app/SDLJoystickHandler_API19.class
org/libsdl/app/SDLHapticHandler.class
org/libsdl/app/SDLHapticHandler_API26.class
```

No entire SDL Android project or APK is packaged.

## Implementation

### Confirmed by source/diff inspection

`desktop/build.gradle` registers an Android-JVM-only `compileAndroidJvmSdlJavaGlue` task during project configuration.

It:

- uses SDL 2.32.8 Android Java sources;
- compiles against the configured Android `android.jar`;
- validates the SDL source checkout and version;
- writes generated output under `desktop/build/generated/android-jvm/sdl-java-glue/classes`;
- packages only the exact nine SDL Android glue class files;
- remains inactive for normal desktop builds.

The Android-JVM artifact also contains:

```
arm64-v8a/libarc.so
arm64-v8a/libsdl-arc.so
```

## CI source provisioning

### Confirmed by CI/build

`.github/workflows/ci.yml` provisions a deterministic sibling checkout of SDL 2.32.8 at:

```
98d1f3a45aae568ccd6ed5fec179330f47d4d356
```

The checkout is validated against the SDL 2.32.8 version header before the production Java glue compilation.

## CI failures fixed during this task

### Gradle task registration

The initial implementation attempted to register the Java compilation task from inside `desktop:dist`. Gradle 9.3.1 rejected this configuration:

```
DefaultTaskContainer#register(String, Class, Action)
on task set cannot be executed in the current context.
```

The task registration was moved to normal project configuration and `dist` consumes its generated output directory.

### SDL checkout metadata

The next CI failure occurred because the existing SDL native probe used a release tarball while the Java glue compile path required Git metadata:

```
SDL source checkout is not a Git checkout:
  /home/runner/work/Mindustry/SDL2-2.32.8
```

CI was corrected to clone and pin the SDL Git commit explicitly.

### Gradle 9.3.1 `sourcepath` API

The next failure was:

```
Execution failed for task ':desktop:compileAndroidJvmSdlJavaGlue'.
> Java compilation initialization error
> Cannot specify -sourcepath or --source-path via CompileOptions.compilerArgs.
  Use the CompileOptions.sourcepath property instead.
```

The build now uses Gradle's `options.sourcepath` property.

### SDL glue verifier ordering

The Java compilation then succeeded, and the produced JAR contained all nine required classes, but the verifier compared an unsorted expected list against a sorted packaged list and failed.

The verifier was corrected to sort both sides with `LC_ALL=C sort`. This was a verifier false-negative, not a packaging defect.

## Final CI verification

### Confirmed by CI/build

Continuous Build:

- run: `35610180259`
- run number: `179`
- head: `bd2bc35c72ef458aeec79e6c99c3c01c6957ddcb`
- result: SUCCESS

The `Test and build` job passed all relevant stages, including:

- Android ARM64 SDL native probe;
- Arc loader overlay;
- patched Arc rebuild;
- backend-sdl JAR refresh;
- Android-JVM runtime dependency graph;
- Android-JVM artifact packaging;
- packaging verification;
- Android JVM native load probe package;
- unit tests;
- desktop JAR build;
- desktop JAR verification;
- artifact uploads.

The separate `Arc Android ARM64 native probe` job also passed.

## Artifact verification

### Confirmed by CI/build and artifact inspection

Android-JVM packaging verifier result:

```
TASK 02C Android-JVM packaging artifact verification: PASS
```

Final artifact:

```
ci-artifacts/task02c/Mindustry-android-jvm.jar
```

JAR SHA-256:

```
0f9cc9ef5b7e038411df31772bb544d376627c46d4d685abff58c6d14a75b14b
```

The verifier confirmed:

- `arm64-v8a/libarc.so` present;
- `arm64-v8a/libsdl-arc.so` present;
- desktop SDL native variants absent;
- exact nine SDL Android Java glue classes present;
- Android/JDK system packages `android/*`, `javax/*`, and `java/*` absent;
- packaged `libsdl-arc.so` exactly matches the pinned Arc Android ARM64 SDL package;
- packaged `libarc.so` matches the pinned Arc Android ARM64 artifact;
- packaged `libarc.so` is ELF64 AArch64 DYN with SONAME `libarc.so`;
- forbidden desktop/glibc dependency checks passed;
- JNI exported `Java_*` symbols: 83.

Final native hashes from the verifier:

```
libsdl-arc.so:
dd4bbd55562e79739d3db6ada038381b001b1979eb0be34b40e8cc079d2e4838

libarc.so:
ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338
```

The verifier uploaded packaging proof as:

```
Mindustry-Android-JVM-packaging-bd2bc35c72ef458aeec79e6c99c3c01c6957ddcb
```

## Desktop regression

### Confirmed by CI/build

`./gradlew desktop:dist` completed successfully.

The resulting desktop artifact was verified at:

```
desktop/build/libs/Mindustry.jar
```

The normal desktop build remained outside the Android-JVM-only SDL Java glue packaging path.

## Physical Android runtime

### Unknown / not executed

No ADB-connected Xiaomi M2004J19C is available in this engineering environment.

Target runtime remains:

- Xiaomi M2004J19C
- Android API 31
- arm64-v8a
- Mojo `justicia-20260910-[7e5e21b]-v3_openjdk`
- no property spoofing

Therefore this task does **not** claim that the real-device runtime has progressed beyond `SDLControllerManager`. That requires the final JAR to be executed on the actual Android JVM target.

## Commits

Implementation and verification commits:

- `051ea9deab4d3ed17b24e8762727bb96aec7aa5f` — package SDL Android Java JNI glue
- `ebd9e8dc06cf3fbea93595a16a760f7d410334ee` — add exact SDL Java glue verifier
- `35040d0e1f992935853aea4e79b6d23eb5f199d4` — correct verifier
- `29edfa8022b5d7e2e7eba0d6f4df60da44370c03` — register Java glue task during project configuration
- `d9ebb76278788c2a8f076b3093373c14d0daca13` — consume compiled output directory directly
- `9ddd3c5545e6d631fad33fd7c970bb7881f3e85e` — provision pinned SDL source in CI
- `d24df3499c3d4d1a46e77970c0c2340971bce43a` — document SDL Android Java glue packaging
- `fc867dda02ff4301142980240c300addce283651` — use Gradle sourcepath for SDL Java glue
- `bd2bc35c72ef458aeec79e6c99c3c01c6957ddcb` — make SDL glue verifier order-independent

No rebase, force-push, Arc upgrade, Mojo change, or master change was used.

## Known limitations

- Local Gradle execution was unavailable because the repository/toolchain was not mounted in this environment.
- Physical Android ARM64 runtime execution was not available.
- CI proves packaging and build correctness, not real-device runtime success.

## Next task

Run the final Android-JVM JAR on the real Android ARM64 Mojo runtime and capture the first new exception after the `SDLControllerManager` boundary.

## Handoff

Status:
COMPLETE

Branch:
`android-jvm`

Baseline:
`707d4d2791c0fe95af01dfae4c1ef54f70d618d0`

Commit:
`bd2bc35c72ef458aeec79e6c99c3c01c6957ddcb`

Files changed:
- `desktop/build.gradle`
- `scripts/android-jvm/task-02c-verify-packaging.sh`
- `.github/workflows/ci.yml`
- `docs/android-jvm/FIX_ANDROID_SDL_JAVA_GLUE.md`

Result:
The minimum SDL 2.32.8 Android Java JNI dependency closure is packaged only for Android-JVM builds. The final Android-JVM JAR passed native/resource/ELF/JNI verification, and the normal desktop JAR passed regression verification.

CI:
Continuous Build #179 (`35610180259`) — SUCCESS.
Arc Android ARM64 native probe — SUCCESS.

Build:
Android ARM64 SDL native probe — PASS.
Patched Arc rebuild — PASS.
Android-JVM packaging — PASS.
Unit tests — PASS.
Desktop JAR build — PASS.
Desktop JAR verification — PASS.
Runtime probe package — PASS.

Verification:
Final Android-JVM JAR contains the exact nine SDL Android glue classes and `arm64-v8a/libsdl-arc.so`; native hashes match pinned inputs; libarc ELF/JNI checks passed; desktop regression passed.

Known limitations:
Real Android ARM64 Mojo runtime has not been executed in this environment, so post-ControllerManager runtime behavior remains unknown.

Next task:
Execute the verified Android-JVM JAR on the real Android ARM64 Mojo runtime and stop at the first new blocker.
