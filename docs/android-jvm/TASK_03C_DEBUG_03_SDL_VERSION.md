# TASK 03C-Debug-03 — Fix SDL 2.32.8 Version Detection

## Status

**IMPLEMENTED — CI VALIDATION IN PROGRESS**

The SDL version parser in `scripts/android-jvm/task-03c-probe.sh` was corrected without changing the SDL build configuration or Android native implementation.

The parser was tested against the actual SDL 2.32.8 `SDL_version.h` structure and returns exactly `2.32.8`.

The normal Continuous Build was triggered by the implementation commit, but the run is still in progress.

## Context

TASK 03C previously reached SDL source acquisition after the deterministic Arc overlay was repaired.

The previous Continuous Build was:

```
Run: 35456522387
Commit: f87ad9e56840b23914b73ca0fa877b42894d745f
```

The Arc overlay was already confirmed by CI.

The probe then failed at SDL version validation:

```
SDL version mismatch: expected 2.32.8, got ..
```

No SDL CMake configuration or compilation had been reached.

## Root Cause

### Confirmed by source

The SDL 2.32.8 header defines the version using three preprocessor macros:

```
#define SDL_MAJOR_VERSION   2
#define SDL_MINOR_VERSION   32
#define SDL_PATCHLEVEL      8
```

The previous parser used:

```
awk -F" |[()]" ...
```

and expected the version value to occur at a fixed field position created by that custom separator expression.

That assumption was incorrect for the actual whitespace-separated preprocessor definitions. The resulting fields caused the parser to capture the wrong fields and produce:

```
..
```

instead of:

```
2.32.8
```

## Repair Method

The parser was replaced with a field-based AWK expression that matches the macro names and reads their value from field 3:

```
header_version="$(awk '/^#define SDL_MAJOR_VERSION[[:space:]]/ {major=$3} /^#define SDL_MINOR_VERSION[[:space:]]/ {minor=$3} /^#define SDL_PATCHLEVEL[[:space:]]/ {patch=$3} END {if(major == "" || minor == "" || patch == "") exit 1; print major "." minor "." patch}' "$SDL_ROOT/include/SDL_version.h")"
```

The parser now:

1. matches the three SDL version macros,
2. reads their numeric values from the value field,
3. fails if any required macro is missing,
4. constructs the version as `major.minor.patch`,
5. compares the result against `SDL_VERSION="2.32.8"`.

The existing version check was retained.

## Preserved Implementation

No native implementation changes were made.

The following remain unchanged:

- `SDLGL.java`
- `backends/backend-sdl/build.gradle`
- Arc overlay patch
- `.github/workflows/ci.yml`
- SDL version
- Android ABI
- Gradle configuration
- SDL CMake configuration

The probe continues to require the exact SDL version before CMake configuration.

## Scope Verification

The implementation change is limited to:

```
scripts/android-jvm/task-03c-probe.sh
```

The dedicated task report is:

```
docs/android-jvm/TASK_03C_DEBUG_03_SDL_VERSION.md
```

No previous task report was rewritten.

## Local Validation

### Shell syntax

**Not executed against a local checkout of the full repository.**

The required command is:

```
bash -n scripts/android-jvm/task-03c-probe.sh
```

The script change is syntactically valid by source inspection, but a successful local `bash -n` result is not claimed unless executed in the project checkout.

### Parser test

**PASS — Confirmed by direct parser test**

Using the actual SDL 2.32.8 macro structure:

```
#define SDL_MAJOR_VERSION   2
#define SDL_MINOR_VERSION   32
#define SDL_PATCHLEVEL      8
```

the replacement AWK expression produced exactly:

```
2.32.8
```

This verifies the parser logic only. It does not prove SDL configuration or compilation.

## Commit

Branch:

```
ci/task-ci-01
```

Implementation commit:

```
c7f14c41ccac86a536be8c30a9cc23a3faddd0b7
```

Commit message:

```
fix: correct SDL version detection in probe
```

`master` was not modified.

## CI

### Continuous Build

Current run:

```
Workflow: Continuous Build
Run ID: 35457240029
Commit: c7f14c41ccac86a536be8c30a9cc23a3faddd0b7
Status: in_progress
Conclusion: not yet available
```

Current job:

```
Test and build
```

At the time of this report, CI was still executing the Arc checkout stage:

```
Set up job                       PASS
Checkout triggering commit      PASS
Set up JDK 17                    PASS
Setup Gradle                     PASS
Clone and pin Arc                IN PROGRESS
Setup Android SDK                PENDING
Install Android native toolchain PENDING
Verify Android native toolchain  PENDING
Android ARM64 SDL native probe  PENDING
```

Therefore CI has **not yet reached SDL version validation**.

The prior run's SDL failure must not be carried forward as the result of this fix.

## Current Result

**Confirmed by source:** the parser now targets the actual SDL 2.32.8 header format.

**Confirmed by direct parser test:** the parser returns exactly `2.32.8`.

**Confirmed by Git:** implementation commit `c7f14c41ccac86a536be8c30a9cc23a3faddd0b7` exists on `ci/task-ci-01`.

**Confirmed by CI:** the new Continuous Build has been triggered.

**Unknown:** whether CI will pass SDL version validation and continue to CMake.

## Remaining Verification

CI must still prove:

1. pinned Arc verification,
2. deterministic Arc overlay,
3. SDL 2.32.8 acquisition,
4. `SDL source version: 2.32.8`,
5. SDL Android CMake configuration,
6. SDL2-static compilation,
7. jnigen task discovery,
8. jnigen generation,
9. Android backend native compilation,
10. AArch64 ELF generation and verification.

This task does not claim any of those downstream build results.

## Known Limitations

- The current CI run was still in progress when this report was created.
- A full local repository `bash -n` execution was not available in the execution environment.
- The direct parser test validates only version extraction, not the complete CI probe.
- No Android native compilation or runtime compatibility is claimed.

## Next Task

Continue the current CI run.

If SDL version validation passes but CMake or SDL2 compilation fails, create the next debug task from the exact failure output. Do not modify the Android native implementation preemptively.

If the CI run completes successfully through the SDL version check, record that evidence before proceeding to the next actual failing stage.

---

Status:
IMPLEMENTED — CI VALIDATION IN PROGRESS

Branch:
ci/task-ci-01

Baseline:
f87ad9e56840b23914b73ca0fa877b42894d745f

Commit:
c7f14c41ccac86a536be8c30a9cc23a3faddd0b7

Files changed:
scripts/android-jvm/task-03c-probe.sh
docs/android-jvm/TASK_03C_DEBUG_03_SDL_VERSION.md

Result:
SDL version parser repaired; direct parser test returns 2.32.8.

CI:
Continuous Build run 35457240029, in progress.

Build:
SDL CMake/build not yet reached.

Verification:
Actual SDL 2.32.8 header structure inspected; parser returns exactly 2.32.8.

Known limitations:
Full CI validation remains pending.

Next task:
Continue CI verification and debug only the next actual failure.
