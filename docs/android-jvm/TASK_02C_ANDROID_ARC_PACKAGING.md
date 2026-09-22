# TASK 02C — Integrate Verified Android ARM64 Arc libarc.so into Mindustry Android-JVM Native Packaging

## Status

**PASS**

## Objective

Integrate the pinned Arc Android native dependency into the Mindustry Android-JVM packaging path without starting Android runtime loading, changing SDL, changing the Android APK backend, or patching native ELF files.

The proven boundary is:

```
Pinned Arc
  -> natives-android
  -> arm64-v8a/libarc.so
  -> Mindustry desktop:dist with -PandroidJvm
  -> actual Mindustry Android-JVM JAR
  -> direct artifact verification
```

Runtime loading remains outside this task.

## Git State

- Branch: `android-jvm`
- Baseline: `83e925237bfaae0cc7c35b3b22853dcef817d87f`
- Final implementation commit: `64ea7aeecb9f740ab08d7fd7a98583638464e8c6`
- Intermediate integration commit: `2b7daaaa03fc43a6a3a5d2bc4bf340de2d287c39`
- CI checkout state: clean; `git status --short` produced no tracked/untracked changes in the verification step
- Protected `master`: not modified

The local analysis environment did not contain a usable Git checkout, so local working-tree state could not be independently captured outside CI.

## Arc

- Pinned Arc SHA: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- Arc included build: `../Arc`
- Arc Android native source/resource: `natives/natives-android/libs/arm64-v8a/libarc.so`
- Pinned Arc Android ARM64 libarc SHA256: `ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338`
- Existing pinned Arc Android artifact is the repository-supported resource exposed by Arc's `natives` resource source set.

TASK 02B separately proved that the same pinned Arc revision can generate Android ARM64 `libarc.so` through:

```
:arc-core:jnigenBuildAndroid_arm64-v8a
```

with Android NDK `30.0.16248370`.

## Packaging Analysis

### Current desktop Arc dependency

The actual Mindustry dependency owner is the root `build.gradle` `project(":desktop")` dependency block.

Normal desktop mode uses:

```groovy
implementation arcModule("natives:natives-desktop")
```

The desktop `dist` task packages the entire `runtimeClasspath` into `Mindustry.jar`.

### Android Arc dependency

The Android-JVM mode now selects:

```groovy
if(project.hasProperty("androidJvm")){
    implementation arcModule("natives:natives-android")
}else{
    implementation arcModule("natives:natives-desktop")
}
```

With the pinned local Arc included build, CI resolved this as:

```
com.github.Anuken:natives-android:8eb00ffff0
    -> project :Arc:natives:natives-android
```

The pinned Arc `natives/build.gradle` exposes `libs` as `sourceSets.main.resources`, so the Android resource is packaged into the JAR at:

```
arm64-v8a/libarc.so
```

### Selected packaging mechanism

The existing Mindustry `desktop:dist` JAR assembly is reused.

```
./gradlew -PandroidJvm desktop:dist --stacktrace
```

No new artifact architecture was introduced.

For Android-JVM builds, the `dist` task additionally excludes the other Arc Android ABIs:

```
armeabi-v7a/libarc.so
x86/libarc.so
x86_64/libarc.so
```

This leaves only the requested `arm64-v8a/libarc.so` in the Android-JVM artifact.

### Why this mechanism was chosen

It is the smallest change that:

1. preserves the existing desktop `natives-desktop` path;
2. selects the existing pinned Arc `natives-android` resource project only under an explicit Android-JVM build property;
3. reuses the existing JAR packaging task;
4. requires no generated binary checked into Git;
5. does not change runtime loading behavior.

## Implementation

Files changed for TASK 02C:

- `build.gradle`
- `desktop/build.gradle`
- `.github/workflows/ci.yml`
- `scripts/android-jvm/task-02c-verify-packaging.sh`
- `docs/android-jvm/TASK_02C_ANDROID_ARC_PACKAGING.md`

No generated native binary was committed.

The final implementation also strengthened the verifier so a packaging result containing any non-ARM64 Arc `libarc.so` entry fails.

### Historical intermediate result

The first implementation commit `2b7daaaa03fc43a6a3a5d2bc4bf340de2d287c39` correctly selected `natives-android`, but the existing JAR assembly initially packaged four Arc Android ABIs:

```
arm64-v8a/libarc.so
armeabi-v7a/libarc.so
x86/libarc.so
x86_64/libarc.so
```

No desktop `libarcarm64.so` was present.

This was treated as an incomplete 02C result rather than being declared success. Final commit `64ea7aeecb9f740ab08d7fd7a98583638464e8c6` added the Android-JVM-only ABI filter and corresponding verifier check.

## Build

### Targeted packaging command

```
./gradlew -PandroidJvm desktop:dist --stacktrace
```

Actual output artifact before publication:

```
desktop/build/libs/Mindustry.jar
```

CI copied the tested JAR to:

```
ci-artifacts/task02c/Mindustry-android-jvm.jar
```

### Targeted packaging result

**PASS**

The Android-JVM runtime dependency graph resolved `natives-android` and did not resolve `natives-desktop`.

### Full Mindustry smoke test

The same CI job then executed:

- unit tests
- normal desktop `desktop:dist`
- desktop JAR verification

All three completed successfully.

The existing workflow subsequently continued into pre-existing Android runtime probes. Those runtime steps are outside TASK 02C and are not used as evidence of runtime support.

## CI

Workflow: `Continuous Build`

Run: `35524401400`

Jobs:

- `Test and build`: `106113936300`
- `Arc Android ARM64 native probe`: `106113936387`

The Arc ARM64 native probe completed **successfully** on the final 02C commit.

The 02C-scoped steps in `Test and build`:

- Android-JVM dependency graph: **PASS**
- Android-JVM packaging build: **PASS**
- Android-JVM packaging artifact upload: **PASS**
- Unit tests: **PASS**
- Desktop JAR build: **PASS**
- Desktop JAR verification: **PASS**

The workflow remained active after those checks because the pre-existing runtime-probe sequence continued. Runtime results are intentionally excluded from the task verdict.

## Artifact

Published CI artifact:

```
Mindustry-Android-JVM-packaging-64ea7aeecb9f740ab08d7fd7a98583638464e8c6
```

GitHub artifact ID: `10609780056`

CI ZIP digest:

```
sha256:c93d68043d08bf9ec4b605a770ae2d0c468915335484e448748667ac597c9e09
```

Tested JAR:

```
/ci-artifacts/task02c/Mindustry-android-jvm.jar
```

JAR SHA256:

```
9b78f02e388d188c902023ed04cf900b53cb8c116253b64252d4b2e8e45c437c
```

Size: `87,591,316` bytes

### Arc entries

Final JAR contains exactly:

```
arm64-v8a/libarc.so
```

Final JAR does not contain:

```
armeabi-v7a/libarc.so
x86/libarc.so
x86_64/libarc.so
libarcarm64.so
```

### Packaged Arc provenance

Extracted packaged file:

```
arm64-v8a/libarc.so
```

SHA256:

```
ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338
```

This exactly matches the pinned Arc `natives-android` `arm64-v8a/libarc.so` resource.

## Android ARM64 selection mechanism

**Build-time selection is proven.**

```
-PandroidJvm
  -> desktop dependency switches to natives-android
  -> Arc natives resources expose arm64-v8a/libarc.so
  -> desktop:dist packages runtimeClasspath
  -> Android-JVM JAR contains arm64-v8a/libarc.so only
```

**Runtime loading selection is not proven.**

The current Arc runtime loader was not modified in TASK 02C. Runtime resource extraction/loading belongs to TASK 02D.

## ELF

Packaged `arm64-v8a/libarc.so` was extracted from the built JAR and inspected directly.

- ELF64: **YES**
- AArch64: **YES**
- DYN: **YES**
- SONAME: `libarc.so`

Direct `DT_NEEDED`:

```
libm.so
liblog.so
libOpenSLES.so
libc.so
libdl.so
```

Desktop/glibc dependencies:

```
libpthread.so.0
libdl.so.2
libm.so.6
libc.so.6
libstdc++.so.6
libgcc_s.so.1
ld-linux-aarch64.so.1
```

All absent from the packaged `libarc.so`.

GNU desktop ABI version requirements:

- `GLIBC_*`: absent
- `GLIBCXX_*`: absent
- `CXXABI_*`: absent
- `GCC_*`: absent

Version table contains Android-style `LIBC` requirements.

No ELF patching, renaming, or compatibility shim was used.

## JNI

Direct symbol-table inspection of the packaged `libarc.so` found:

**83 exported `Java_*` JNI symbols**

The count was obtained from the actual packaged ELF symbol table rather than inferred from the filename or copied source metadata.

## Regression

- Unit tests: **PASS**
- Desktop distribution/build: **PASS**
- Desktop JAR verification: **PASS**
- Existing Android APK path: **UNVERIFIED**

The Android APK Gradle configuration was inspected and left untouched. Its existing local-Arc `jniLibs` path remains separate from the Android-JVM dependency selector.

## Evidence

### Confirmed by source

- Mindustry root `build.gradle` owns the desktop Arc native dependency.
- Normal desktop mode uses `natives-desktop`.
- `-PandroidJvm` now switches only the desktop module's Arc native dependency to `natives-android`.
- Mindustry `desktop:dist` assembles runtimeClasspath into the JAR.
- Pinned Arc `natives/build.gradle` exposes `libs` as Java resources.
- Pinned Arc contains `natives-android/libs/arm64-v8a/libarc.so`.
- Android APK native resources are handled by the separate `android` module.

### Confirmed by CI/build

- Final commit `64ea7aeecb9f740ab08d7fd7a98583638464e8c6` built successfully through the 02C-scoped packaging path.
- `natives-android` appeared in Android-JVM runtimeClasspath and `natives-desktop` did not.
- Final Android-JVM packaging step passed.
- Unit tests passed.
- Desktop JAR build passed.
- Desktop JAR verification passed.
- Arc ARM64 native probe passed on the final commit.

### Confirmed by artifact inspection

- Final JAR contains exactly `arm64-v8a/libarc.so` for Arc native resources.
- `libarcarm64.so` is absent.
- Packaged `libarc.so` hash exactly matches the pinned Arc Android ARM64 prebuilt.
- Packaged `libarc.so` is ELF64/AArch64/DYN.
- SONAME is `libarc.so`.
- Direct DT_NEEDED is Android-compatible at the inspected boundary.
- Desktop/glibc dependency names are absent.
- GNU desktop ABI version requirements are absent.
- 83 exported JNI `Java_*` symbols are present.

### Inference

- The Android-JVM JAR now carries the intended Android ARM64 Arc native input and does not carry the Linux/glibc Arc binary.
- The artifact is an appropriate input for the next runtime-loading task.

### Unknown

- Whether Android JVM `System.loadLibrary` / `System.load` can load the packaged resource without further extraction/resource-path handling.
- Runtime JNI execution.
- SDL initialization.
- GLES context creation.
- Full Mindustry launch and gameplay on Android JVM.

## Scope Check

Not modified by TASK 02C:

- Arc source
- SDL
- `SDLGL.java`
- `SDL.java`
- `SharedLibraryLoader`
- `OS.isAndroid`
- `ClientLauncher`
- `DesktopLauncher`
- `AndroidLauncher`
- Mindustry renderer
- Android Activity/lifecycle

## Known Limitations

- Packaging is verified; Android runtime loading is not yet verified.
- The final packaged Arc binary is the pinned Arc Android prebuilt resource, not byte-identical to the separate TASK 02B generated NDK r30 artifact. Its exact hash and provenance were independently verified.
- Existing Android APK build execution was not required and was not run.
- The full CI workflow continued into pre-existing runtime probes after the 02C acceptance checks; those probes are outside the 02C verdict.

## Acceptance Criteria

- [x] Current branch state recorded
- [x] Arc SHA remains exactly `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- [x] Actual Mindustry packaging path inspected
- [x] Current desktop Arc native dependency identified
- [x] Android Arc native packaging mechanism identified
- [x] Minimal integration implemented
- [x] Android ARM64 `libarc.so` appears in relevant Mindustry artifact
- [x] Provenance traceable to pinned Arc
- [x] Packaged `libarc.so` ELF64
- [x] Packaged `libarc.so` AArch64
- [x] Packaged `libarc.so` DYN
- [x] SONAME inspected
- [x] DT_NEEDED inspected
- [x] Desktop/glibc dependencies absent
- [x] GNU desktop ABI version requirements absent
- [x] JNI symbol surface inspected
- [x] Targeted packaging build passes
- [x] Full Mindustry build smoke checks pass
- [x] Existing unit tests pass
- [x] Desktop distribution remains functional
- [x] Desktop JAR verification passes
- [x] No ELF patching/shim/rename used
- [x] No Arc source modified
- [x] No SDL/runtime integration introduced

## Result

**PASS**

TASK 02C proves the following boundary:

```
Pinned Arc
  -> Android native resource
  -> Mindustry Android-JVM packaging
  -> actual built JAR
  -> direct artifact integrity verification
```

It does not prove Android runtime loading.

## Next Task

**TASK 02D — Android JVM native loading of packaged libarc.so**
