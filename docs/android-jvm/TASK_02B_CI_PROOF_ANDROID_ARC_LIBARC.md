# TASK 02B — CI Proof of Android ARM64 Arc libarc.so

## Status

**PASS**

## Objective

Prove with a clean GitHub Actions runner that pinned Arc revision
`8eb00ffff0126d0576c67df46f99b8f6bccd96fe` can build a genuine Android/bionic
AArch64 `libarc.so` for `arm64-v8a` through Arc's real Gradle/jnigen path.

## Git State

- Branch: `android-jvm`
- CI probe commit: `1eb6463e34c8c48e5beeb6981cc2f0ef4f0fe9e5`
- Arc revision: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- Protected `master`: untouched
- Arc source: unmodified
- SDL source/runtime: unmodified for this task

Local worktree status was not available in the analysis environment. CI checkout and Arc SHA were directly verified by the probe.

## CI

- Workflow: `Continuous Build`
- Run: `35521685200`
- Probe job: `106106740626`
- Probe job conclusion: success
- Arc native probe step: success
- Artifact upload step: success
- CI artifact ID: `10609135911`
- Artifact digest: `sha256:bc2352b736a1ee67d9b9730c68e91ff72147b2d0bb52cd98c4bbd72c3a193934`

## Toolchain

- OS: Ubuntu 24.04 runner
- JDK: 17
- Gradle: 9.3.1
- Android SDK: runner Android SDK
- Android API environment: 36
- NDK: `30.0.16248370`
- AArch64 compiler: `/usr/local/lib/android/sdk/ndk/30.0.16248370/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++`
- Compiler target: `aarch64-unknown-linux-android21`
- Native build driver: `/usr/local/lib/android/sdk/ndk/30.0.16248370/ndk-build`

The actual native build command recorded by CI was:

```
/usr/local/lib/android/sdk/ndk/30.0.16248370/ndk-build -j4 \
  NDK_PROJECT_PATH=/home/runner/work/Mindustry/Arc/arc-core/build/jnigen/target/android32 \
  NDK_APPLICATION_MK=/home/runner/work/Mindustry/Arc/arc-core/build/jnigen/target/android32/Application.mk \
  APP_BUILD_SCRIPT=/home/runner/work/Mindustry/Arc/arc-core/build/jnigen/target/android32/Android.mk \
  NDK_OUT=/home/runner/work/Mindustry/Arc/arc-core/build/jnigen/target/android32 \
  NDK_LIBS_OUT=/home/runner/work/Mindustry/Arc/arc-core/build/natives/android32
```

CI then reported:

```
[arm64-v8a] SharedLibrary  : libarc.so
[arm64-v8a] Install        : libarc.so => .../arc-core/build/natives/android32/arm64-v8a/libarc.so
```

## Arc Build Structure

The pinned Arc `arc-core/build.gradle` defines:

- `sharedLibName = "arc"`
- `libsDir = "build/natives"`
- common C/C++ source selection
- Linux-specific miniaudio source and Linux libraries
- a separate `addAndroid()` target
- Android libraries `-llog` and `-lOpenSLES`
- Android OpenSLES source selection
- `APP_STL := c++_static`

The build also wires `preJni` into jnigen tasks.

## Gradle Task Discovery

Actual command executed:

```
./gradlew :arc-core:tasks --all --console=plain
```

Gradle reported the following relevant Android tasks:

- `jnigenBuildAllAndroid`
- `jnigenBuildAndroid_arm64-v8a`
- `jnigenBuildAndroid_armeabi-v7a`
- `jnigenBuildAndroid_x86`
- `jnigenBuildAndroid_x86_64`
- `jnigenPackageAllAndroid`
- `jnigenPackageAndroid_arm64-v8a`
- `jnigenPackageAndroid_armeabi-v7a`
- `jnigenPackageAndroid_x86`
- `jnigenPackageAndroid_x86_64`

Selected real build task:

```
:arc-core:jnigenBuildAndroid_arm64-v8a
```

The Gradle dry-run showed the actual prerequisite chain:

```
:arc-core:compileJava
:arc-core:processResources
:arc-core:classes
:arc-core:copyUnsafeStuff
:arc-core:preJni
:arc-core:jnigen
:arc-core:jnigenBuildAndroid_arm64-v8a
```

The package task was also discovered but was not required to prove native build feasibility.

## Generated Artifact

Two generated `libarc.so` paths were found under the current Arc build output:

```
/home/runner/work/Mindustry/Arc/arc-core/build/jnigen/target/android32/local/arm64-v8a/libarc.so
/home/runner/work/Mindustry/Arc/arc-core/build/natives/android32/arm64-v8a/libarc.so
```

The probe selected and independently audited:

- Path: `arc-core/build/jnigen/target/android32/local/arm64-v8a/libarc.so`
- Filename: `libarc.so`
- Size: `2,532,584` bytes
- SHA256: `501e5a8da6c4486cff62834bff14dbeea4202a048119e5fe33e245523519aaa0`
- Build ID: `cedc62ed86021bd542505ac80ec5b50108446bfb`

The artifact was copied from the current CI build output into the uploaded probe artifact. It was not copied from the repository's prebuilt Android library.

## ELF Verification

### Header

Confirmed by direct `llvm-readelf` / local ELF inspection:

- Class: `ELF64`
- Machine: `AArch64`
- Endianness: little endian
- OS/ABI: `UNIX - System V`
- Type: `DYN (Shared object file)`

The binary also contains a `.note.android.ident` note identifying Android NDK `r30` revision `16248370`.

The local `file` inspection describes it as:

```
ELF 64-bit LSB shared object, ARM aarch64,
dynamically linked, for Android 21,
built by NDK r30 (16248370)
```

No `PT_INTERP` desktop loader segment is present.

## SONAME

Actual `DT_SONAME`:

```
libarc.so
```

The SONAME was read from the ELF and not inferred from the filename.

## DT_NEEDED

Exact direct dependencies:

```
libm.so
liblog.so
libOpenSLES.so
libc.so
libdl.so
```

No desktop dependencies from TASK 01 are present:

- `libpthread.so.0`: absent
- `libdl.so.2`: absent
- `libstdc++.so.6`: absent
- `libm.so.6`: absent
- `libgcc_s.so.1`: absent
- `libc.so.6`: absent
- `ld-linux-aarch64.so.1`: absent

RPATH/RUNPATH: none reported.

## Symbol / Version Verification

The generated ELF has Android-style version requirements:

- `libm.so` -> `LIBC`
- `libc.so` -> `LIBC`
- `libdl.so` -> `LIBC`

No desktop version requirements were found for:

- `GLIBC_*`
- `GLIBCXX_*`
- `CXXABI_*`
- `GCC_[0-9]*`

Relevant undefined symbols include Android libc-versioned pthread/math/system calls, for example:

- `pthread_create@LIBC`
- `pthread_join@LIBC`
- `pthread_mutex_lock@LIBC`
- `malloc@LIBC`
- `free@LIBC`
- `clock_gettime@LIBC`
- `pow@LIBC`
- `cos@LIBC`
- `dl_iterate_phdr@LIBC`

The generated symbol surface also contains `__android_log_print`.

## JNI Verification

Independent inspection of the generated artifact found **166 `Java_*` symbols**.

Examples include:

```
Java_arc_audio_Soloud_backendSamplerate
Java_arc_audio_Soloud_filterFade
Java_arc_audio_Soloud_idValid
Java_arc_audio_Soloud_sourcePlay__JFFFZ
Java_arc_graphics_Pixmap_loadJni
Java_arc_graphics_Pixmap_createJni
Java_arc_util_Buffers_freeMemory
```

The CI helper's first diagnostic count reported `0` because its grep expression did not match the `readelf -Ws` output format. This was a diagnostic regex defect only. Independent artifact inspection establishes the actual JNI surface as 166 symbols.

## Existing Arc Android Prebuilt Comparison

Existing pinned-tree artifact:

```
../Arc/natives/natives-android/libs/arm64-v8a/libarc.so
```

Properties:

- Size: `753,520` bytes
- SHA256: `ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338`
- Build ID: `f8c7c8f50e772f9af71ecf856cdf75f26f318288`
- ELF64
- AArch64
- Type: `DYN`
- Android 21
- NDK r27d (`13750724`)
- SONAME: `libarc.so`

Its direct dependencies are identical to the newly generated artifact:

```
libm.so
liblog.so
libOpenSLES.so
libc.so
libdl.so
```

It also has Android-style `LIBC` version requirements and no desktop GNU/glibc version contract.

The generated and prebuilt binaries are **different binaries**:

- different SHA256
- different Build ID
- different size
- generated artifact is unstripped with debug information
- prebuilt artifact is stripped

Conclusion: **different but both independently Android-compatible at the inspected direct ELF dependency layer.**

## TASK 01 Comparison

TASK 01 desktop artifact:

```
libarcarm64.so
├── libpthread.so.0
├── libdl.so.2
├── libstdc++.so.6
├── libm.so.6
├── libgcc_s.so.1
├── libc.so.6
└── ld-linux-aarch64.so.1
```

TASK 02B generated Android artifact:

```
libarc.so
├── libm.so
├── liblog.so
├── libOpenSLES.so
├── libc.so
└── libdl.so
```

The ABI boundary has therefore changed from the TASK 01 GNU/Linux/glibc contract to an Android/bionic-targeted artifact produced by the Android NDK.

## Acceptance Criteria

- [x] Arc revision exactly verified
- [x] Correct Arc included-build Gradle root identified
- [x] Exact Android native Gradle task discovered from Gradle
- [x] Required task dependencies identified
- [x] Android NDK toolchain verified
- [x] Real arm64-v8a Android build executed
- [x] Generated libarc.so located
- [x] Artifact provenance established
- [x] SHA256 recorded
- [x] ELF64 confirmed
- [x] AArch64 confirmed
- [x] Android-targeted artifact supported by evidence
- [x] SONAME recorded
- [x] DT_NEEDED recorded
- [x] Linux/glibc dependencies absent
- [x] Desktop glibc symbol-version requirements absent
- [x] JNI symbol surface inspected
- [x] Existing Android libarc.so compared
- [x] No patchelf/shim/rename workaround used
- [x] No SDL/runtime changes made

## Desktop Regression

- Unit tests: **UNVERIFIED at report time**; the existing `Test and build` job was still running while the native probe completed.
- Desktop build: **UNVERIFIED at report time**.
- Desktop JAR verification: **UNVERIFIED at report time**.

The Android native probe was implemented as a separate CI job, so it did not disable or replace the existing desktop pipeline.

## Evidence Classification

### Confirmed by source

- Pinned Arc `arc-core` defines the Android native target.
- The Android target uses `-llog`, `-lOpenSLES`, Android-specific native source, and `APP_STL := c++_static`.
- `sharedLibName` is `arc`.
- jnigen prerequisites include `preJni` and `jnigen`.

### Confirmed by CI/build

- Arc revision is exactly `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`.
- NDK `30.0.16248370` is installed and verified.
- Real task `:arc-core:jnigenBuildAndroid_arm64-v8a` was discovered and executed.
- `ndk-build` was used.
- The native build reported `[arm64-v8a] SharedLibrary : libarc.so`.
- The resulting artifact was uploaded from the current build.

### Confirmed by artifact inspection

- Generated binary is ELF64 AArch64 DYN.
- Android identity note is present.
- SONAME is `libarc.so`.
- Direct DT_NEEDED contains only Android-style dependencies.
- Desktop/glibc dependency names are absent.
- Desktop GNU ABI version requirements are absent.
- 166 JNI `Java_*` symbols are present.
- Existing Arc Android prebuilt is independently Android-compatible at the inspected direct dependency layer.

### Inference

- The generated artifact is a viable native input for a later Mindustry Android-JVM packaging step because it is produced by Arc's Android arm64-v8a target and passes the native ELF/dependency checks. Actual Mindustry runtime loading remains untested.

### Unknown

- Full Android runtime loadability.
- Runtime behavior on MojoLauncher/MJLauncher or other Android JVM implementations.
- Full transitive compatibility of every Android system library beyond the direct DT_NEEDED boundary.

## Result

**PASS**

The pinned Arc revision can reproducibly produce a genuine Android ARM64 `libarc.so` through its real Gradle/jnigen build path. The generated artifact is directly verified as Android-targeted and does not carry the desktop Linux/glibc dependency contract from TASK 01.

This proves **native build/artifact feasibility only**. It does not prove Android-JVM runtime integration.

## Known Limitations

- The generated artifact was not runtime-loaded in this task.
- The existing Android prebuilt and generated artifact differ in toolchain version, size, Build ID, and stripping state, so binary identity is not expected.
- The current helper's JNI count diagnostic needs a regex correction for future probe quality; the artifact itself was independently inspected and found to contain 166 JNI symbols.
- Desktop unit/build verification was still in progress at report creation time.

## Next Task

**TASK 02C — Integrate the verified Android ARM64 Arc `libarc.so` into Mindustry's Android-JVM native packaging path without starting SDL/runtime integration.**
