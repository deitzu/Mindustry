# TASK 03C-DEBUG-17 — SDLJoystickHandler API19/API16 Minimal Inheritance Chain

## Status

INCOMPLETE — the DEBUG-17 packaging change is committed, but this execution environment did not expose a usable GitHub Actions run result or the real Mojo/MJLauncher Android runtime. Therefore the diagnostic artifact and real Android System.load result are not verified here.

A runtime failure is not being inferred; runtime execution is simply unverified.

## Branch

android-jvm

## Baseline

5bacaefe82b097bf4e9f10fe19062cbbe98d5d10

This was the actual branch HEAD immediately before the DEBUG-17 change.

## Result commit

Implementation commit:
a69c834228c45b468eaf6713641b20f54d549d5e

Report commit:
pending at creation of this report

## Pinned dependencies

- Arc revision: 8eb00ffff0126d0576c67df46f99b8f6bccd96fe
- SDL version: 2.32.8
- SDL commit: 98d1f3a45aae568ccd6ed5fec179330f47d4d356
- Android target: arm64-v8a / AArch64 / Android-bionic
- Android runtime target: real Android JVM under Mojo/MJLauncher

## Objective

Validate the minimal statically proven controller inheritance prerequisites by adding only:

- org/libsdl/app/SDLJoystickHandler_API16.class
- org/libsdl/app/SDLJoystickHandler_API19.class

The objective is to observe the first genuinely new Android runtime boundary after the already-observed SDLJoystickHandler -> SDLJoystickHandler_API19 failure.

This task does not establish complete SDL Java glue compatibility, Activity support, haptics, EGL/GLES, or Mindustry startup.

## Scope

Changed only:

scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh

The probe implementation, native resource, extraction path, absolute System.load() mechanism, classloader diagnostics, runtime arguments, and production source were not changed.

Historical reports DEBUG-14, DEBUG-15, DEBUG-16, and DEBUG-16A/16B were not rewritten.

## Source validation

Exact source revision:

SDL 2.32.8, commit 98d1f3a45aae568ccd6ed5fec179330f47d4d356

Exact source location:

android-project/app/src/main/java/org/libsdl/app/SDLControllerManager.java

The exact pinned source declares:

class SDLJoystickHandler_API16 extends SDLJoystickHandler

and:

class SDLJoystickHandler_API19 extends SDLJoystickHandler_API16

The same source file also shows SDLControllerManager.initialize() selecting SDLJoystickHandler_API19 when Build.VERSION.SDK_INT >= 19.

No standalone SDLJoystickHandler_API16.java or SDLJoystickHandler_API19.java file was assumed.

## Implementation

The existing DEBUG-16A packaging mechanism was changed only enough to stage:

1. SDLActivity.class
2. SDLInputConnection.class
3. SDLAudioManager.class
4. SDLControllerManager.class
5. SDLJoystickHandler.class
6. SDLJoystickHandler_API16.class
7. SDLJoystickHandler_API19.class

The script now explicitly checks the two inheritance declarations in SDLControllerManager.java before compilation.

The expected packaged org/libsdl/app/*.class list was expanded from five entries to exactly these seven entries.

No other SDL classes were added.

The native input remains the same libsdl-arc.so path.

## Artifact verification

Expected artifact name:

Android-JVM-android-jni-glue-load-probe-a69c834228c45b468eaf6713641b20f54d549d5e

Expected native resource:

android-jvm-probe/native/arm64-v8a/libsdl-arc.so

Expected native SHA-256:

d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7

Direct artifact inspection was not completed for DEBUG-17 because the CI-produced artifact was not retrievable from the available GitHub tooling in this execution environment.

## Java payload

Required seven SDL classes only:

- org/libsdl/app/SDLActivity.class
- org/libsdl/app/SDLInputConnection.class
- org/libsdl/app/SDLAudioManager.class
- org/libsdl/app/SDLControllerManager.class
- org/libsdl/app/SDLJoystickHandler.class
- org/libsdl/app/SDLJoystickHandler_API16.class
- org/libsdl/app/SDLJoystickHandler_API19.class

Plus the existing probe helper.

No additional org/libsdl/app class is intentionally staged by the DEBUG-17 script.

## Native SHA

Required unchanged SHA-256:

d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7

No native source, compiler flags, or native binary was modified by DEBUG-17.

## Real Android runtime evidence

No DEBUG-17 Mojo/MJLauncher execution was available in this environment.

DEBUG-16A already established the preceding facts:

- SDLJoystickHandler was visible through the tested Java loaders/resource lookup.
- System.load(absolutePath) then reported NoClassDefFoundError for org.libsdl.app.SDLJoystickHandler_API19.

DEBUG-17 has not produced a new Android runtime log beyond those earlier observations.

## First genuinely new boundary

UNVERIFIED.

The next boundary is intentionally not guessed from the static graph. The Android runtime must execute the DEBUG-17 artifact and reveal the first new boundary.

Potential static candidates outside this task, including haptic handlers, are not promoted to runtime findings here.

## Static/runtime correlation

Confirmed historical correlation:

SDLJoystickHandler_API19 -> SDLJoystickHandler_API16 -> SDLJoystickHandler is the minimal statically proven inheritance chain for the API >= 19 joystick path.

DEBUG-16A runtime had already requested SDLJoystickHandler_API19 after SDLJoystickHandler was made visible.

DEBUG-17 prepares exactly the two missing inheritance prerequisites, but without the real Android result this correlation has not yet been extended through successful runtime resolution.

## Evidence classification

### Confirmed by source

- Exact SDL 2.32.8 commit: 98d1f3a45aae568ccd6ed5fec179330f47d4d356.
- SDLJoystickHandler_API16 extends SDLJoystickHandler.
- SDLJoystickHandler_API19 extends SDLJoystickHandler_API16.
- SDLControllerManager.initialize() selects API19 for Android API >= 19.

### Confirmed by bytecode

- Prior DEBUG-16B bytecode analysis confirmed SDLControllerManager contains the API >= 19 constructor path for SDLJoystickHandler_API19 and the API16 alternative.
- New DEBUG-17 API16/API19 class bytecode was not produced or inspected in this environment.

### Confirmed by CI/build

- DEBUG-17 implementation commit exists and the branch diff is limited to scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh.
- No successful DEBUG-17 CI build result was retrievable through the available workflow tooling.

### Confirmed by artifact inspection

- No DEBUG-17 artifact was directly inspectable in this environment.
- DEBUG-16A remains the last directly inspected artifact.

### Confirmed by real Android runtime

- Prior DEBUG-16A evidence established SDLJoystickHandler visibility and then reached the missing SDLJoystickHandler_API19 boundary.
- No DEBUG-17 runtime result is available.

### Inference

- Adding API16 and API19 is the minimum payload change justified by the observed API19 failure plus the pinned-source inheritance chain.
- It is not proven that this pair will be the final controller-side prerequisite set for native loading.

### Unknown

- Whether DEBUG-17 System.load() returns normally.
- The first genuinely new runtime boundary after API16/API19 are present.
- Whether class initialization exposes another Java dependency before any later SDL subsystem.
- The final CI artifact SHA/name produced by a successful DEBUG-17 workflow run.

## Acceptance criteria

- [x] exact pinned SDL 2.32.8 source revision verified
- [x] SDLJoystickHandler_API19 source relationship verified
- [x] SDLJoystickHandler_API16 source relationship verified
- [x] only API19 + API16 added beyond the DEBUG-16A payload in the diagnostic script
- [x] no speculative SDL classes added
- [x] native build/source path was not changed
- [x] classloader diagnostics preserved unchanged
- [x] no production runtime workaround introduced
- [ ] native libsdl-arc.so artifact directly verified for DEBUG-17
- [ ] native SHA directly verified inside the DEBUG-17 artifact
- [ ] diagnostic build success confirmed by CI
- [ ] real Android runtime test attempted
- [ ] first genuinely new runtime boundary captured, or runtime limitation recorded as the blocking condition
- [x] immutable DEBUG-17 report created

## Known limitations

The available GitHub connector can read and write repository files but does not expose a general list-push-workflow-runs operation for the current branch. The container also has no usable network/DNS path to GitHub, so the CI result could not be independently fetched locally.

The same environment has no Mojo/MJLauncher Android runtime access. Consequently, the central runtime experiment cannot be truthfully marked PASS or FAIL here.

No production compatibility conclusion should be drawn from the incomplete verification.

## Next task

Run the DEBUG-17 artifact on the same real Android JVM/Mojo environment used for DEBUG-16A and stop at the first new boundary after API16/API19 are present.

The next artifact expansion, if any, must be based on that runtime result rather than on the broader static dependency graph.
