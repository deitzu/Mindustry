# TASK 03C-DEBUG-18 — Minimal Haptic Prerequisites Runtime Experiment

## Status

INCOMPLETE — the DEBUG-18 diagnostic packaging change is committed, but this execution environment cannot directly retrieve the resulting GitHub Actions artifact or execute Mojo/MJLauncher on the Android device. Therefore artifact inspection and the real Android System.load() result are UNVERIFIED.

The task is not treated as a runtime PASS or FAIL without the device evidence.

## Branch

android-jvm

## Baseline

6d4733a686463a748a0d9988cae24f723e69b583

Remote branch comparison confirmed android-jvm was exactly at this commit before the DEBUG-18 implementation change.

Local working-tree status: UNVERIFIED. No local repository checkout is exposed in the current execution environment.

## Result commit

Implementation:
28becf4f3eaf4ef43d0520ef0c2b3bafa5fcc9da

Report:
pending at report creation

## Pinned dependencies

- Arc: 8eb00ffff0126d0576c67df46f99b8f6bccd96fe
- SDL: 2.32.8
- SDL commit: 98d1f3a45aae568ccd6ed5fec179330f47d4d356
- Target: Android JVM, arm64-v8a, AArch64, Android/bionic
- Runtime validation environment: Mojo Launcher / MJLauncher

## Objective

Validate whether:

- org/libsdl/app/SDLHapticHandler.class
- org/libsdl/app/SDLHapticHandler_API26.class

are sufficient to move the real Android JVM probe beyond the DEBUG-17 runtime boundary:

NoClassDefFoundError:
org/libsdl/app/SDLHapticHandler

This task does not test complete SDL Java glue, SDL_Init, Activity, Surface, EGL, GLES, or Mindustry startup.

## Scope

Changed only:

scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh

The DEBUG-16A classloader diagnostics were preserved. The diagnostic now additionally checks non-initializing visibility of:

- org.libsdl.app.SDLHapticHandler
- org.libsdl.app.SDLHapticHandler_API26

through the same system, probe, and context classloaders and resource lookups.

The native loading mechanism remains:

System.load(absolutePath)

No production runtime source, native binary, native compiler flags, loader behavior, library path, classloader setup, Mojo Launcher, or runtime arguments were changed.

## Source validation

Exact pinned source:

SDL 2.32.8, commit 98d1f3a45aae568ccd6ed5fec179330f47d4d356

Exact source location:

android-project/app/src/main/java/org/libsdl/app/SDLControllerManager.java

The build script now explicitly validates:

class SDLHapticHandler

and:

class SDLHapticHandler_API26 extends SDLHapticHandler

before compilation.

Both classes are declared in SDLControllerManager.java. No standalone source file was invented.

## Implementation

DEBUG-18 extends the DEBUG-17 payload by exactly two SDL classes:

- SDLHapticHandler
- SDLHapticHandler_API26

The script's SDL class list is now:

- SDLActivity
- SDLInputConnection
- SDLAudioManager
- SDLControllerManager
- SDLJoystickHandler
- SDLJoystickHandler_API16
- SDLJoystickHandler_API19
- SDLHapticHandler
- SDLHapticHandler_API26

The expected class-list comparison is updated accordingly.

An explicit verification rejects packaging of:

org/libsdl/app/SDLHapticHandler$SDLHaptic.class

No other new SDL class is intentionally staged.

## Classloader diagnostics

Existing DEBUG-16A joystick diagnostics remain intact, including:

- java.class.path
- probe CodeSource
- system classloader identity
- probe classloader identity
- thread context classloader identity
- Class.forName(..., false, loader)
- resource lookup
- resolved classloader
- resolved CodeSource

DEBUG-18 adds equivalent non-initializing checks for:

- SDLHapticHandler
- SDLHapticHandler_API26

The additional checks happen before System.load() and do not use direct static class references.

## Artifact verification

Expected native resource:

android-jvm-probe/native/arm64-v8a/libsdl-arc.so

Required native:

- size: 4,710,176 bytes
- SHA-256: d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7

Expected SDL class payload is exactly nine classes listed in the Java payload section, plus the existing probe helper.

Direct DEBUG-18 artifact inspection was not available because the current tooling does not expose a usable GitHub Actions run/artifact result for this pushed commit.

## Java payload

Exactly:

1. org/libsdl/app/SDLActivity.class
2. org/libsdl/app/SDLInputConnection.class
3. org/libsdl/app/SDLAudioManager.class
4. org/libsdl/app/SDLControllerManager.class
5. org/libsdl/app/SDLJoystickHandler.class
6. org/libsdl/app/SDLJoystickHandler_API16.class
7. org/libsdl/app/SDLJoystickHandler_API19.class
8. org/libsdl/app/SDLHapticHandler.class
9. org/libsdl/app/SDLHapticHandler_API26.class

Plus:

androidjvm/probe/AbsolutePathAndroidJniGlueLoadProbe.class

Explicitly absent by intended staging:

org/libsdl/app/SDLHapticHandler$SDLHaptic.class

## Native SHA

Required unchanged SHA-256:

d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7

No DEBUG-18 change touches the native source or native binary.

## Real Android runtime

UNVERIFIED.

The required Mojo/MJLauncher execution could not be performed from this environment.

The most recent available real Android evidence remains DEBUG-17:

NoClassDefFoundError:
org/libsdl/app/SDLHapticHandler

No DEBUG-18 log is being fabricated.

## System.load()

UNVERIFIED.

Expected diagnostic sequence remains:

ANDROID_JNI_GLUE_LOAD_BEGIN
-> System.load(absolutePath)
-> existing pass/fail marker

No new runtime result was available.

## First genuinely new boundary

UNVERIFIED.

No class beyond the DEBUG-17 SDLHapticHandler boundary can be truthfully named until the DEBUG-18 artifact is executed on the real Android JVM.

The nested SDLHapticHandler$SDLHaptic remains intentionally unadded.

## Static/runtime correlation

Static evidence from DEBUG-17A predicted for Android API 31:

SDLHapticHandler_API26
-> SDLHapticHandler

DEBUG-17 real Android evidence stopped at SDLHapticHandler.

DEBUG-18 therefore supplies exactly the two statically proven haptic inheritance prerequisites and no speculative nested helper.

The actual runtime result remains authoritative.

## Evidence classification

### Confirmed by source

- Exact SDL 2.32.8 revision is pinned and validated by the script.
- SDLHapticHandler_API26 extends SDLHapticHandler.
- The two classes are declared together in SDLControllerManager.java.
- DEBUG-18 validates those exact declarations before packaging.

### Confirmed by bytecode

Prior DEBUG-17A analysis confirmed the compiled SDLControllerManager.class API>=26 branch constructs SDLHapticHandler_API26 and the fallback constructs SDLHapticHandler.

DEBUG-18 does not modify that bytecode path.

### Confirmed by CI/build

The DEBUG-18 implementation commit exists and is a narrow modification of the existing diagnostic packaging script.

A successful DEBUG-18 GitHub Actions result was not retrievable through the available workflow tooling.

### Confirmed by artifact inspection

No DEBUG-18 artifact was directly inspectable in this environment.

The DEBUG-17 artifact remains the latest directly inspected diagnostic artifact.

### Confirmed by real Android runtime

DEBUG-17 established:

NoClassDefFoundError:
org/libsdl/app/SDLHapticHandler

No DEBUG-18 runtime result is available.

### Inference

- The nine-class SDL payload is exactly the requested DEBUG-18 payload.
- Adding only SDLHapticHandler and SDLHapticHandler_API26 is the smallest change justified by DEBUG-17A.
- The nested SDLHapticHandler$SDLHaptic should remain absent until runtime evidence requests it.

### Unknown

- Whether Android resolves both haptic classes successfully.
- Whether System.load() returns normally with the DEBUG-18 payload.
- Whether SDLHapticHandler$SDLHaptic is the next runtime boundary.
- Whether another Java/JNI/native boundary appears first.

## Acceptance criteria

- [x] exact SDL 2.32.8 revision preserved
- [x] API26 -> base relationship verified
- [x] only SDLHapticHandler + SDLHapticHandler_API26 added beyond DEBUG-17
- [x] SDLHapticHandler$SDLHaptic not intentionally added
- [x] no unrelated SDL classes added
- [x] native source/binary not modified
- [ ] native SHA directly verified inside DEBUG-18 artifact
- [ ] artifact directly inspected
- [x] classloader diagnostics preserved
- [ ] diagnostic build result confirmed
- [ ] real Android execution attempted
- [ ] first new boundary captured, or Android execution explicitly unavailable in this environment
- [x] no production workaround introduced
- [x] immutable DEBUG-18 report created

## Known limitations

The repository connector allows repository file writes and inspection but does not provide a general push-workflow-run listing/result path for the current commit. The container also has no local Mindustry checkout and no direct Mojo/MJLauncher Android runtime.

Because of those limits, this report does not claim CI artifact correctness or Android runtime success.

## Next task

Execute the DEBUG-18 artifact on the same real Android JVM/MJLauncher environment used for DEBUG-17.

Run only:

artifact
-> extract native
-> verify file/size/SHA
-> classloader diagnostics
-> System.load(absolutePath)

Stop at the first new boundary.

If the next boundary is SDLHapticHandler$SDLHaptic, that becomes the runtime-confirmed candidate for the next minimal experiment. Do not package it before that observation.
