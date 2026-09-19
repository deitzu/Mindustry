# TASK 03C-Debug-02 — Repair Deterministic Arc Overlay Patch

## Status

**IMPLEMENTED — CI OVERLAY VALIDATED; FULL TASK 03C BUILD NOT YET VALIDATED**

The malformed deterministic Arc overlay patch was rebuilt against the exact pinned Arc revision and committed on `ci/task-ci-01`.

GitHub Actions subsequently confirmed that the repaired overlay passed the probe's `git apply --check`, `git apply`, and `git diff --check` stages and allowed execution to continue into SDL acquisition/version verification.

The broader TASK 03C native build was not reached because the same CI run later failed while parsing the SDL version.

## Context

TASK 03C uses a deterministic temporary patch to overlay the Android SDL implementation onto the pinned Arc checkout:

```
Arc revision:
8eb00ffff0126d0576c67df46f99b8f6bccd96fe
```

The previous CI execution failed during:

```
git -C "$ARC_DIR" apply --check "$PATCH_FILE"
```

with:

```
error: corrupt patch at .../ci/android-jvm/task03c-backend-sdl.patch:22
```

No SDL configuration or jnigen build was reached in that failed execution.

## Root Cause

Two patch-format problems were established by inspection against the actual pinned Arc source.

### 1. Invalid unified-diff hunk metadata

The previous patch contained hunk headers whose declared old/new line counts did not match the actual hunk bodies.

This made the patch structurally invalid as a unified diff and caused `git apply --check` to report the patch as corrupt.

### 2. Incorrect source blob metadata

The previous modified-file headers used placeholder metadata such as:

```
index 2deda3b..0000000 100644
index 8db6a4d..0000000 100644
```

The actual pinned Arc source blobs were verified as:

```
backends/backend-sdl/build.gradle
2deda3bb5d51501ef946d95dad2c2b8e23af29be

backends/backend-sdl/src/arc/backend/sdl/jni/SDLGL.java
cc95b47ca5b46f6a1c25dd575d9d6600c4f5c813
```

The patch was therefore rebuilt from the exact pinned source instead of manually adjusting the old patch's line numbers.

## Repair Method

The deterministic overlay mechanism was retained.

The patch was regenerated as a standard unified diff targeting the exact existing Arc files at revision `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`.

The repaired patch contains exactly two file sections:

```
backends/backend-sdl/build.gradle
backends/backend-sdl/src/arc/backend/sdl/jni/SDLGL.java
```

The repaired patch contains valid hunk metadata and no placeholder `0000000` modified-file blob metadata.

The repair did not intentionally redesign the Android implementation or replace the deterministic patch mechanism.

## Preserved Implementation

The patch continues to represent the TASK 03C Android backend changes.

### backend-sdl/build.gradle

Preserved changes include:

- GLEW restricted to non-Android targets.
- Android ARM64 jnigen target.
- `SDL2_ANDROID_ROOT` based SDL source/build paths.
- SDL2 Android include paths.
- SDL2 static library linkage.
- Android `log`, `android`, `dl`, `GLESv2`, and `GLESv1_CM` linkage.
- `APP_STL := c++_static`.
- Existing desktop target configuration remains present.

### SDLGL.java

Preserved changes include:

- Android GLES3/GLES2 headers.
- Desktop GLEW branch preservation.
- Android initialization without `glewInit()`.
- Direct Android GLES framebuffer calls.
- Desktop GLEW framebuffer fallback behavior.
- Existing JNI method signatures.
- Android handling for `glProgramParameteri`.

No runtime integration was performed by this task.

## Scope Verification

Production/runtime files outside the deterministic Arc overlay were not intentionally changed by this task.

The overlay targets only:

```
backends/backend-sdl/build.gradle
backends/backend-sdl/src/arc/backend/sdl/jni/SDLGL.java
```

No changes were made to:

- `SDL.java`
- `SdlGL20.java`
- `SdlGL30.java`
- `SdlApplication.java`
- `SdlGraphics.java`
- `SharedLibraryLoader`
- `OS.java`
- launchers
- Mindustry renderer
- Android Activity/lifecycle
- Arc revision
- SDL version
- Android ABI

`master` was not targeted.

## Local Validation

A clean local Arc checkout was not available in the execution environment, so the exact requested local sequence could not be executed there:

```
git -C ../Arc apply --check ci/android-jvm/task03c-backend-sdl.patch
git -C ../Arc apply ci/android-jvm/task03c-backend-sdl.patch
git -C ../Arc diff --check
git -C ../Arc diff --stat
git -C ../Arc diff
```

Therefore these are recorded as **NOT LOCALLY VERIFIED**.

The patch structure was statically inspected before commit, including unified-diff sections, hunk headers, and hunk line counts.

## Commit

Branch:

```
ci/task-ci-01
```

Baseline for DEBUG-02:

```
49a55cd7d5a226696f397bc720d0c3d8c8a3d0ec
```

The rebuilt patch content was introduced during the repair commit sequence, with the branch tip finalized at:

```
f87ad9e56840b23914b73ca0fa877b42894d745f
```

Commit message:

```
fix: repair Arc SDL probe overlay patch
```

A preceding intermediate commit in the repair sequence was:

```
2b29618bef9cccd1851273dac3f2007a073be35b
```

The final branch tip is the commit referenced as the known DEBUG-02 result.

## CI

### Continuous Build

Workflow:

```
Continuous Build
```

Run ID:

```
35456522387
```

Commit:

```
f87ad9e56840b23914b73ca0fa877b42894d745f
```

Final status:

```
completed
```

Final conclusion:

```
failure
```

The job reached the Android SDL probe.

Relevant successful stages:

- Android SDK setup
- Android NDK installation
- Android native toolchain verification
- pinned Arc revision verification
- deterministic Arc overlay application

The CI log shows the repaired patch applied successfully and the Arc working tree contained only the two intended modified files at that point:

```
 M backends/backend-sdl/build.gradle
 M backends/backend-sdl/src/arc/backend/sdl/jni/SDLGL.java
```

The probe then continued to SDL acquisition/version verification.

## Current Result

**Confirmed by CI:** the corrupt-patch failure was removed.

The same CI execution reached:

```
== TASK 03C: obtain SDL 2.32.8 ==
```

and then failed with:

```
SDL version mismatch: expected 2.32.8, got ..
```

This failure is downstream of the Arc overlay stage.

Therefore:

- Arc overlay repair: **CI-confirmed**
- SDL configure: **not reached**
- SDL2-static build: **not reached**
- jnigen task discovery: **not reached**
- jnigen generation: **not reached**
- Android native compilation: **not reached**
- ELF verification: **not reached**
- runtime validation: **not performed**

The SDL version parsing failure belongs to the next debugging boundary and is not treated as evidence that the repaired Arc patch failed.

## Remaining Verification

Still unverified for TASK 03C as a whole:

1. SDL 2.32.8 configuration for Android `arm64-v8a`.
2. SDL2-static build.
3. Actual Android jnigen task discovery.
4. jnigen source generation.
5. Android native backend compilation.
6. AArch64 JNI `.so` generation.
7. ELF header/program/dynamic dependency verification.
8. JNI symbol verification.
9. Desktop regression build.
10. Runtime loading on Android JVM.

## Known Limitations

- No clean local pinned Arc checkout was available for executing the complete requested local Git validation sequence.
- CI validated the overlay application and `diff --check` path, but did not complete the native build.
- The latest CI blocker is the SDL header-version extraction producing `..` instead of `2.32.8`.
- No claim of Android runtime compatibility is made.

## Next Task

**Next task: TASK 03C-Debug-03 — repair the SDL 2.32.8 version verification step.**

Use the exact CI failure as the starting evidence. Do not redesign the Android native implementation or the Arc overlay unless a later failure demonstrates an implementation-level problem.

---

Status:
IMPLEMENTED — CI overlay validated; TASK 03C native build still blocked

Branch:
ci/task-ci-01

Baseline:
49a55cd7d5a226696f397bc720d0c3d8c8a3d0ec

Commit:
f87ad9e56840b23914b73ca0fa877b42894d745f

Files changed:
docs/android-jvm/TASK_03C_DEBUG_02_ARC_PATCH.md

Result:
Repaired deterministic Arc overlay patch; CI confirmed the overlay stage succeeded and advanced to SDL version verification.

CI:
Continuous Build run 35456522387 — failure after overlay, at SDL version verification.

Build:
SDL/jnigen/native build not reached.

Verification:
Patch structure statically audited; CI confirmed apply --check, application, and diff --check stages by progressing past the overlay.

Known limitations:
Full local Arc Git validation was unavailable; native build remains unverified.

Next task:
TASK 03C-Debug-03 — repair SDL 2.32.8 version verification.
