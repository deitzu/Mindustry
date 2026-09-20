# TASK 03C-DEBUG-10B — Isolate/Fix Android jnigen Task Discovery Failure

## Status

**Complete.**

DEBUG-10B resolved the reproducible Gradle/Groovy failure encountered while the TASK 03C probe attempted to discover Android jnigen tasks dynamically.

The probe previously invoked:

```
./gradlew :backends:backend-sdl:tasks --all
```

and encountered:

```
BUG! exception in phase 'semantic analysis'
in source unit '_BuildScript_'
Cannot invoke "org.codehaus.groovy.control.SourceUnit.getErrorCollector()"
because "source" is null
```

The probe now uses the already-confirmed jnigen 3.1.2 task names directly:

```
jnigenBuildAndroid_arm64-v8a
jnigenPackageAndroid_arm64-v8a
```

The package-discovery correction from commit `2bd161c6f1e933fc1b385ef7a89a4ba7ab73c228` was preserved.

A separate Groovy scoping fix renamed the Android SDL environment variable in the deterministic Arc overlay from `sdlRoot` to `androidSdlRoot`.

## Branch

`ci/task-ci-01`

## Baseline

`2bd161c6f1e933fc1b385ef7a89a4ba7ab73c228`

## Result Commit

`932b34ece909155c775eaf62ed24a58a4a649432`

## Pinned Dependencies

- Arc: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- SDL: 2.32.8
- Android ABI: arm64-v8a
- Android NDK: 30.0.16248370
- Gradle: 9.3.1

## Scope

Only TASK 03C probe/verifier infrastructure and the deterministic Arc overlay were touched.

No Android runtime integration or renderer changes were made. In particular, no changes were made to:

- `SDL.java`
- `SDLGL.java` in DEBUG-10B
- `SdlGL20.java`
- `SdlGL30.java`
- `SdlApplication.java`
- `SdlGraphics.java`
- renderer code
- launchers
- SharedLibraryLoader
- OS handling
- unrelated Gradle modules
- Arc upstream history

## Failure and Reproduction

CI run `35479311348` reproduced the failure after SDL 2.32.8 static compilation succeeded.

The failing layer was Gradle/Groovy configuration while invoking the `jnigen` task from the probe. The Android native compiler had not yet failed in that run.

The full exception included:

```
DefaultScriptCompilationHandler.compileScript
GradleResolveVisitor.visitClass
java.lang.NullPointerException:
Cannot invoke "org.codehaus.groovy.control.SourceUnit.getErrorCollector()"
because "source" is null
```

This was therefore not treated as evidence of an Android native implementation failure.

## Investigation

### Confirmed by jnigen 3.1.2 source

The jnigen Gradle plugin creates Android tasks using the Android ABI value. For this project, the already-confirmed task names are:

```
jnigenBuildAllAndroid
jnigenBuildAndroid_arm64-v8a
jnigenPackageAllAndroid
jnigenPackageAndroid_arm64-v8a
```

Earlier CI output explicitly listed these tasks.

Dynamic task discovery was therefore unnecessary. The probe now uses the ABI-specific build and package tasks directly.

### Overlay scoping fix

The deterministic Arc overlay contained an Android environment variable named `sdlRoot` while the same build script also uses `sdlRoot` in another closure. The Android-specific variable was renamed to `androidSdlRoot`.

No native source or GLES implementation was changed by DEBUG-10B.

## Files Changed

- `scripts/android-jvm/task-03c-probe.sh`
- `ci/android-jvm/task03c-backend-sdl.patch`
- `docs/android-jvm/TASK_03C_DEBUG_10B_TASK_DISCOVERY.md`

The implementation result is commit `932b34ece909155c775eaf62ed24a58a4a649432`.

## Successful CI

Continuous Build:

`35479497497`

Result: **success**

Every required stage completed successfully:

- Android native toolchain setup: PASS
- Android native toolchain verification: PASS
- SDL 2.32.8 static build: PASS
- Arc pin verification and deterministic overlay application: PASS
- jnigen source generation: PASS
- Android ARM64 native compilation: PASS
- Android ARM64 packaging: PASS
- native artifact verification: PASS
- unit tests: PASS
- desktop build: PASS
- desktop JAR verification: PASS
- artifact uploads: PASS

Separate workflows for the same commit also reported successful Gradle-wrapper validation and tests.

## Actual jnigen Tasks Used

Confirmed by successful CI:

```
:backends:backend-sdl:jnigen
:backends:backend-sdl:jnigenBuildAndroid_arm64-v8a
:backends:backend-sdl:jnigenPackageAndroid_arm64-v8a
```

The task-list output also confirmed:

```
jnigenBuildAllAndroid
jnigenPackageAllAndroid
```

## Native Build Result

SDL static archive:

```
/home/runner/work/Mindustry/Mindustry/../SDL2-2.32.8/build/libSDL2.a
```

Android JNI shared library:

```
/home/runner/work/Mindustry/Mindustry/../Arc/backends/backend-sdl/libs/android32/arm64-v8a/libsdl-arc.so
```

## Android Package Result

Actual package:

```
/home/runner/work/Mindustry/Mindustry/../Arc/backends/backend-sdl/libs/sdl-arc-natives-arm64-v8a.jar
```

Verified JAR entry:

```
libsdl-arc.so
```

This matches the jnigen Android packaging implementation, which creates one ABI-specific JAR and inserts the generated `.so` directly into it.

## ELF Verification

Confirmed by the successful native probe:

```
ELF class=ELF64
ELF machine=AArch64
SONAME=libsdl-arc.so
```

Observed DT_NEEDED entries:

```
libm.so
liblog.so
libandroid.so
libdl.so
libGLESv3.so
libGLESv1_CM.so
libc.so
```

Required GLES dependencies:

- `libGLESv3.so`: PASS
- `libGLESv1_CM.so`: PASS

Forbidden dependency scan covered:

```
libGL.so.1
libSDL2-2.0.so.0
libc.so.6
ld-linux-aarch64.so.1
GLEW
```

Result:

```
Forbidden dependency scan: PASS
```

## JNI Verification

The generated native library contained:

```
JNI symbol count: 566
SDL JNI symbol count: 96
SDLGL JNI symbol count: 470
JNI symbol surface: PASS
```

Final native probe result:

```
Android native probe: PASS
```

## Artifact Uploads

Native probe artifact:

```
Android-SDL-native-probe-932b34ece909155c775eaf62ed24a58a4a649432
```

Artifact ID: `10595242514`

GitHub-reported digest:

`sha256:1e1c279fdb7fb97736a891b1b3ccd941f374b6355a48a0673f5044b71d8ac529`

Desktop artifact:

```
Mindustry-932b34ece909155c775eaf62ed24a58a4a649432
```

Artifact ID: `10595710654`

## Unit Tests

The Continuous Build run completed:

```
./gradlew tests:test --stacktrace
```

successfully.

The separate Tests workflow for the same commit also succeeded.

## Desktop Regression

The Continuous Build run completed:

```
./gradlew desktop:dist
```

successfully.

The expected JAR was verified at:

```
desktop/build/libs/Mindustry.jar
```

CI explicitly reported:

```
Verified desktop/build/libs/Mindustry.jar
```

## Arc Pin

The probe reported the same Arc revision before and after overlay application:

```
8eb00ffff0126d0576c67df46f99b8f6bccd96fe
```

The upstream Arc checkout was not committed or rewritten. The probe only applied the deterministic local overlay.

## Evidence Classification

### Confirmed by source

- jnigen 3.1.2 creates `jnigenBuildAndroid_arm64-v8a`.
- jnigen 3.1.2 creates `jnigenPackageAndroid_arm64-v8a`.
- Android packaging produces `sdl-arc-natives-arm64-v8a.jar`.
- Android packaging inserts the generated `libsdl-arc.so` into that JAR.

### Confirmed by CI/build

- SDL 2.32.8 static Android build succeeds.
- jnigen generation succeeds.
- Android ARM64 compilation/link succeeds.
- Android ARM64 packaging succeeds.
- Unit tests succeed.
- Desktop distribution succeeds.
- Desktop JAR exists at the expected path.

### Confirmed by artifact/probe inspection

- ELF64
- AArch64
- SONAME `libsdl-arc.so`
- required GLES DT_NEEDED entries
- JNI symbol surface
- forbidden dependency scan

### Inference

The successful transition from the failing `SourceUnit` path to direct confirmed-task execution, together with the scoping rename, supports identifying the previous failure as Gradle/Groovy probe/configuration infrastructure rather than a native Android compiler defect. No stronger claim about Gradle internals is made.

## Known Limitations

- Android runtime loading on a real Android device is not yet tested.
- EGL/GLES context creation and actual renderer execution on Android remain unverified.
- Device-specific GPU driver behavior remains unknown.
- This task proves the native artifact and packaging boundary, not full Android JVM runtime compatibility.

## Acceptance Criteria

- [x] Reproduce the task-discovery/configuration failure.
- [x] Remove fragile dynamic task discovery.
- [x] Use confirmed jnigen Android task names.
- [x] Preserve the package-discovery fix from `2bd161c6f1e933fc1b385ef7a89a4ba7ab73c228`.
- [x] Build Android ARM64 native library.
- [x] Package Android ARM64 native library.
- [x] Locate `sdl-arc-natives-arm64-v8a.jar`.
- [x] Verify `libsdl-arc.so`.
- [x] Verify ELF64/AArch64.
- [x] Verify SONAME.
- [x] Verify DT_NEEDED.
- [x] Verify required GLES libraries.
- [x] Verify JNI symbols.
- [x] Run unit tests.
- [x] Run `desktop:dist`.
- [x] Verify `desktop/build/libs/Mindustry.jar`.
- [x] Confirm Arc remains pinned.

## Next Task

**TASK 03C-DEBUG-11 — Android Runtime Integration / Native Load Boundary**

The native compilation, linkage, artifact inspection, and ABI-specific packaging boundaries are now CI-proven. The next task should inspect how the produced JNI package is consumed by the Android JVM runtime and establish the next reproducible runtime boundary.

No runtime implementation changes were made in DEBUG-10B.
