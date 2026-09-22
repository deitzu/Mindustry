# TASK 03C-DEBUG-14 — SDL Android Java Glue / JNI_OnLoad Dependency

## Status

IN PROGRESS — diagnostic harness is blocked by CI script failures; no production runtime change was made.

## Branch

`ci/task-ci-01`

## Baseline

Pinned Arc revision:

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

SDL target investigated:

- SDL version: `2.32.8`
- SDL ref: `release-2.32.8`
- SDL commit: `98d1f3a45aae568ccd6ed5fec179330f47d4d356`

## Objective

Determine the minimum SDL 2.32.8 Android Java glue required for the existing absolute-path `System.load()` probe to progress beyond the observed missing `org.libsdl.app.SDLControllerManager` class.

Specifically:

- inspect SDL 2.32.8 Android Java sources;
- confirm the Java classes directly registered by SDL `JNI_OnLoad`;
- distinguish immediate JNI-load requirements from later Activity/window/input/audio/lifecycle requirements;
- package only real SDL source-derived Java classes for the diagnostic;
- do not modify production Mindustry runtime loading or introduce fake Java stubs.

This task remains within native/JNI feasibility work. The project documentation explicitly keeps Activity/lifecycle and broader runtime integration outside this probe boundary. fileciteturn295file7L1-L20

## Scope

In scope:

- CI diagnostic helper under `scripts/android-jvm/`;
- exact SDL 2.32.8 Android Java source inspection;
- diagnostic JAR packaging;
- real `libsdl-arc.so` reuse;
- CI verification.

Out of scope:

- production loader changes;
- Android Activity integration;
- renderer rewrites;
- replacing existing Android launcher;
- modifying pinned Arc source directly.

The project documentation requires preserving desktop behavior and keeping Android Activity/lifecycle work separate from the native probe. fileciteturn295file8L1-L35

## Source Findings

### SDL Android Java tree

At SDL `release-2.32.8`, the Android package contains:

- `SDLActivity.java`
- `SDL.java`
- `SDLAudioManager.java`
- `SDLControllerManager.java`
- `SDLSurface.java`
- HID device helper classes

There is no standalone `SDLInputConnection.java` file at this tag.

`SDLInputConnection` is declared as a top-level class inside `SDLActivity.java`.

### JNI_OnLoad

SDL 2.32.8 `src/core/android/SDL_android.c` registers exactly four Java classes from `JNI_OnLoad`:

1. `org/libsdl/app/SDLActivity`
2. `org/libsdl/app/SDLInputConnection`
3. `org/libsdl/app/SDLAudioManager`
4. `org/libsdl/app/SDLControllerManager`

The second class therefore has a separate JNI registration entry even though its Java source is physically inside `SDLActivity.java`.

### Existing real-device boundary

The preceding absolute-path Android JVM probe successfully extracted the real native library and reached JNI initialization. The observed failure was:

`java.lang.NoClassDefFoundError: org/libsdl/app/SDLControllerManager`

This establishes `SDLControllerManager` as the first *observed* missing Java class on the real Android path.

It does not yet establish that the four directly registered classes are sufficient for complete SDL runtime operation.

## Implementation / Attempt History

### Attempt 1 — narrow controller-only packaging

Commit:

`d1d26c5a90e0f8b30d735301aa2b7f4f9b226497`

The first diagnostic packaged only the controller-side Java glue. This was recognized as too narrow because native `JNI_OnLoad` registers four direct classes, not only `SDLControllerManager`.

Result:

- superseded by the broader four-class probe;
- no production runtime change.

### Attempt 2 — four direct JNI_OnLoad classes

Commit:

`559d465fe68efac47ca043ed967cb2d4dbc64cf5`

Workflow update:

`17c5f429780b8e44cbb3fad75d59e7dca001d757`

The probe was expanded to package the four Java classes directly registered from `JNI_OnLoad`.

### Attempt 3 — independent SDL source acquisition

Commit:

`f4748eba99461d572d9c351adb5f3437c9039f96`

The diagnostic was changed to obtain SDL independently rather than relying on a sibling checkout left by an earlier step.

CI still failed because the extracted archive directory did not match the assumed `../SDL2-2.32.8` layout.

### Attempt 4 — pinned SDL git checkout and corrected source assumptions

Commit:

`3143bec1587ecf5a7abf67b3f20cd1ab8670a45e`

Changes:

- SDL checkout switched to a pinned source revision;
- SDL commit verification was added;
- the script attempted to include `SDLInputConnection.java` as a separate source.

The last assumption was incorrect for SDL 2.32.8. Source inspection later confirmed `SDLInputConnection` is declared inside `SDLActivity.java`.

### Attempt 5 — correct SDL release tag and source list

Commit:

`6d8db43db263938957f062cf63e4aef3620c7e26`

Changes:

- checkout ref changed to `release-2.32.8`;
- standalone `SDLInputConnection.java` source requirement removed;
- `SDLInputConnection.class` remains a required packaged output, generated from `SDLActivity.java`.

CI then progressed past source checkout but failed on the next path assumption.

### Attempt 6 — correct raw SDL source header path

Commit:

`3037f44c55b8e743fd1d2c4771b3f3a285ade949`

Changes:

- source checkout validation changed from `include/SDL2/SDL_version.h` to the actual SDL source path `include/SDL_version.h`.

CI then progressed further but failed before the SDL diagnostic itself because the script assumed it was launched from a Git working tree.

### Attempt 7 — current cwd-independent root discovery

Commit:

`36ddb9f63b8509e64b5faea1f8640023181de098`

Changes:

- repository root is now derived from the script location using `BASH_SOURCE[0]`;
- removes the runtime dependency on the caller's current working directory.

This is the current result commit and has not yet been validated by a new CI run at the time of this report.

## CI Evidence

### Consecutive failure 1

Run:

`35496568136`

Commit:

`3143bec1587ecf5a7abf67b3f20cd1ab8670a45e`

Failure:

`fatal: Remote branch 2.32.8 not found in upstream origin`

Classification:

**Confirmed by CI/build — diagnostic harness/source checkout failure.**

Not a native/JNI runtime failure.

Earlier steps still passed, including:

- Arc checkout/pin;
- Android SDK/NDK setup;
- Android ARM64 native probe;
- unit tests;
- desktop JAR;
- absolute-path native load diagnostic.

### Consecutive failure 2

Run:

`35497126543`

Commit:

`6d8db43db263938957f062cf63e4aef3620c7e26`

Failure:

`SDL headers not found after checkout: .../SDL2-2.32.8`

Classification:

**Confirmed by CI/build — SDL source layout assumption.**

The checkout itself succeeded; the script incorrectly expected the generated/install-style `include/SDL2/` layout instead of the raw source `include/` layout.

### Consecutive failure 3

Run:

`35497584619`

Commit:

`3037f44c55b8e743fd1d2c4771b3f3a285ade949`

Failure:

`fatal: not a git repository (or any of the parent directories): .git`

This occurred immediately when the helper evaluated:

`git rev-parse --show-toplevel`

Classification:

**Confirmed by CI/build — helper working-directory assumption.**

No JNI probe execution occurred after this failure.

## What Was and Was Not Proven

### Confirmed by source

- SDL 2.32.8 has Android Java glue.
- `SDLInputConnection` is inside `SDLActivity.java`.
- `JNI_OnLoad` directly registers four Java classes.
- The four-class package definition is therefore source-grounded rather than fabricated.

### Confirmed by CI/build

- Arc remains pinned to the required revision during the relevant runs.
- The Android ARM64 native probe continues to pass.
- The desktop build continues to pass.
- The absolute-path native probe package continues to build successfully.
- The current DEBUG-14 helper has not yet completed its Java-glue packaging step.

### Confirmed by real Android runtime

- The real native library can be extracted to an absolute filesystem path.
- `System.load(absPath)` reaches the native/JNI load boundary.
- `SDLControllerManager` was the first observed missing Java class.

### Unknown

- Whether packaging only the four `JNI_OnLoad` classes is sufficient for `System.load(absPath)` to return normally on the real Android JVM.
- The next missing Java dependency, if any.
- Whether successful JNI library loading is enough to proceed to the later SDL Activity/context/window boundary.

The project documentation explicitly treats actual Android runtime loadability as a separate verification stage from native build feasibility. fileciteturn295file10L1-L20

## Result

DEBUG-14 is **not complete**.

The three consecutive CI failures were all in the diagnostic harness and were progressively narrowed:

`wrong SDL acquisition`
→ `wrong SDL source layout`
→ `wrong CI working-directory assumption`

None of these failures invalidates the underlying JNI hypothesis.

No production loader, Mindustry launcher, renderer, or pinned Arc source was changed as part of these fixes.

## Known Limitations

- CI has not yet produced the final four-class diagnostic artifact from commit `36ddb9f...`.
- Real-device verification of the four-class package is therefore still pending.
- The report does not claim complete SDL runtime compatibility.

## Acceptance Criteria

- [x] Exact SDL 2.32.8 source revision identified.
- [x] Four direct JNI_OnLoad Java classes identified from SDL source.
- [x] `SDLInputConnection` source placement verified.
- [x] Real Android missing-class boundary documented.
- [x] CI failures preserved with exact run/commit evidence.
- [ ] Diagnostic JAR packaging passes in CI.
- [ ] Real Android probe progresses beyond `SDLControllerManager`.
- [ ] Next missing dependency, if any, is captured from real runtime output.
- [ ] No production runtime integration introduced.

## Next Task

Run CI for commit:

`36ddb9f63b8509e64b5faea1f8640023181de098`

If the helper packages successfully, run the resulting diagnostic JAR on the real Android JVM and record the earliest next boundary.

Do not add further Java classes preemptively. Let the actual Android exception determine the next dependency.

## Handoff

Status:
IN PROGRESS — CI harness fixed but not yet verified

Branch:
`ci/task-ci-01`

Baseline:
Pinned Arc `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

Commit:
`36ddb9f63b8509e64b5faea1f8640023181de098`

Files changed:
- `scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh`
- this report

Result:
Three consecutive CI failures were diagnosed as helper/source-layout/working-directory issues. No production Android runtime code changed.

CI:
- `35496568136` — failed: SDL git branch `2.32.8`
- `35497126543` — failed: SDL source header path
- `35497584619` — failed: helper cwd / Git root detection

Build:
- Android ARM64 native probe: PASS on affected runs
- unit tests: PASS on affected runs
- desktop JAR: PASS on affected runs
- absolute-load probe package: PASS on affected runs
- DEBUG-14 Java-glue package: not yet passed in CI

Verification:
- SDL 2.32.8 Java/JNI source structure inspected
- `SDLInputConnection` confirmed inside `SDLActivity.java`
- JNI_OnLoad four-class registration confirmed
- real Android first missing class: `org/libsdl/app/SDLControllerManager`

Known limitations:
Four-class runtime sufficiency remains unverified.

Next task:
CI verification of `36ddb9f...`, followed by the real Android four-class JNI load probe.
