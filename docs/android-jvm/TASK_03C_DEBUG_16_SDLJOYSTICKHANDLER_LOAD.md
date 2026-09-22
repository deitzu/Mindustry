# TASK 03C-DEBUG-16 — Add Only SDLJoystickHandler to Android JNI Load Probe

## Status

BLOCKED — diagnostic packaging and artifact verification completed; real Android Mojo execution could not be performed from the available environment.

## Branch

android-jvm

## Baseline

ad6ed8799b2d6cc471c349bd047a677a3dff82e9

## Result commit

95eedbccbcebf9db17e5b434052e60a1624f324d — diagnostic packaging change.

Documentation result commit: created after this report.

## Pinned dependencies

Arc:

8eb00ffff0126d0576c67df46f99b8f6bccd96fe

SDL:

- version: 2.32.8
- commit: 98d1f3a45aae568ccd6ed5fec179330f47d4d356

## Objective

Answer the narrow DEBUG-16 question:

Does supplying only org/libsdl/app/SDLJoystickHandler.class allow the Android JVM native-load probe to advance to the next runtime boundary?

The experiment keeps the same absolute-path loading flow:

System.load(absolutePath)

No production runtime integration was attempted.

## Scope

Changed only the existing diagnostic packaging mechanism to add the one source-derived class requested by DEBUG-16.

No changes were made to:

- libsdl-arc.so
- extraction mechanism
- System.load(absPath)
- classloader behavior
- Android runtime
- SharedLibraryLoader
- OS.java
- renderer code
- Activity/lifecycle code
- EGL/GLES code
- Mojo Launcher
- Arc production source
- SDL native source
- historical DEBUG-14/15 reports

## Source evidence

Confirmed by source:

SDL 2.32.8 defines SDLJoystickHandler as a real top-level package-private class in:

android-project/app/src/main/java/org/libsdl/app/SDLControllerManager.java

The class is declared in the same source file as SDLControllerManager.java. No standalone SDLJoystickHandler.java file is used by this revision.

## Implementation

The existing diagnostic helper:

scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh

was changed only to:

1. verify the SDLJoystickHandler class declaration exists in SDLControllerManager.java;
2. compile the same SDL 2.32.8 Android Java source set;
3. stage the existing DEBUG-14 four classes;
4. stage exactly one additional class: SDLJoystickHandler.class;
5. verify the resulting package contains the five SDL Java class files and the existing probe helper;
6. preserve the existing real libsdl-arc.so unchanged;
7. verify source and embedded native SHA-256 match.

No additional SDL classes were staged.

## CI/build evidence

GitHub Actions Continuous Build:

Run: 35508353977

Job: 106071836280

Conclusion: success

Relevant completed steps:

- Arc checkout/pin: PASS
- Android SDK/toolchain setup: PASS
- Android ARM64 SDL native probe: PASS
- Unit tests: PASS
- Desktop JAR build: PASS
- Desktop JAR verification: PASS
- Package real Android JVM native load probe: PASS
- Build Android absolute-path native load diagnostic: PASS
- Build SDL Android controller Java glue diagnostic: PASS
- Upload SDL Android controller Java glue diagnostic: PASS
- Android JVM loader-boundary probe: PASS

The CI loader-boundary step is still Linux-hosted and therefore is not real Android runtime evidence.

## Artifact verification

Artifact:

Android-JVM-android-jni-glue-load-probe-95eedbccbcebf9db17e5b434052e60a1624f324d

Artifact ID:

10603734726

Artifact ZIP SHA-256:

d2f2e46ee2bdeff39f062d6ee3f6d41c69231506b60d6d6e0cc10c54079f969f

Artifact JAR:

Mindustry-android-jvm-android-jni-glue-load-probe.jar

JAR SHA-256:

1b8f82d30f646fbb258aeacf4b7700ca7516c6a8f9b5398eb1e85af0732f4d80

Direct inspection showed these SDL Java classes and no additional org/libsdl/app class files:

- org/libsdl/app/SDLActivity.class
- org/libsdl/app/SDLInputConnection.class
- org/libsdl/app/SDLAudioManager.class
- org/libsdl/app/SDLControllerManager.class
- org/libsdl/app/SDLJoystickHandler.class

The probe helper is also present:

androidjvm/probe/AbsolutePathAndroidJniGlueLoadProbe.class

Native resource:

android-jvm-probe/native/arm64-v8a/libsdl-arc.so

Embedded native size:

4710176 bytes

Embedded native SHA-256:

d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7

This matches the required known-good native SHA exactly.

Direct inspection found no unexpected additional org/libsdl/app Java classes.

## Real Android runtime evidence

Not executed in this environment.

The available tool environment has no direct access to the real Android device or Mojo/MJLauncher process used for DEBUG-12/12A/13/13A/15.

Therefore the required real-device sequence:

diagnostic artifact
→ Mojo Launcher / MJLauncher
→ Android JVM
→ Execute JAR
→ extract native
→ SHA verification
→ System.load(absolutePath)

has not been observed for the DEBUG-16 artifact.

No Android runtime success or failure is claimed.

## Failure / boundary

No new DEBUG-16 runtime boundary was captured because the real-device execution step was blocked by device access.

The only runtime boundary currently established remains the DEBUG-15 result:

NoClassDefFoundError / ClassNotFoundException for org.libsdl.app.SDLJoystickHandler

That is historical DEBUG-15 evidence and is not a DEBUG-16 result.

## Evidence classification

### Confirmed by source

- SDLJoystickHandler is a real SDL 2.32.8 top-level package-private class.
- Its source location is SDLControllerManager.java.

### Confirmed by CI/build

- The DEBUG-16 packaging change builds successfully in Continuous Build run 35508353977.
- The Android ARM64 native probe, unit tests, desktop build, and diagnostic packaging all passed.

### Confirmed by artifact inspection

- Exactly the five intended org/libsdl/app class files are present.
- The probe helper is present.
- No additional org/libsdl/app class files are present.
- libsdl-arc.so is present at the expected resource path.
- Embedded native size is 4710176 bytes.
- Embedded native SHA-256 is d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7.

### Confirmed by real Android runtime

None for DEBUG-16.

### Inference

- The artifact is suitable for the intended one-class DEBUG-16 runtime experiment because it contains the same DEBUG-14/15 payload plus only SDLJoystickHandler.class and preserves the verified native binary.

### Unknown

- Whether SDLJoystickHandler.class is sufficient for System.load(absolutePath) to complete on the real Android JVM.
- The next runtime boundary after DEBUG-15.
- Whether the next boundary is another Java class/member, JNI registration, linker/runtime dependency, or another SDL initialization requirement.

## Files changed

Production/runtime source:

None.

Diagnostic:

scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh

Documentation:

docs/android-jvm/TASK_03C_DEBUG_16_SDLJOYSTICKHANDLER_LOAD.md

Historical reports were not modified.

## CI

New Continuous Build was required because the diagnostic packaging mechanism changed.

Continuous Build:

35508353977 — PASS

Gradle Wrapper validation:

35508353983 — PASS

## Acceptance criteria

- [x] Only SDLJoystickHandler.class was added beyond the DEBUG-14 Java set.
- [x] Native libsdl-arc.so remained unchanged.
- [x] Native SHA-256 matches d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7.
- [x] Artifact contents were directly inspected.
- [ ] Real Android runtime probe was executed.
- [x] No speculative SDL classes were added.
- [x] No production runtime workaround was introduced.
- [x] Immutable DEBUG-16 report was created.

## Known limitations

The task cannot be marked COMPLETE because the required real Android Mojo execution could not be performed by the available tool environment.

CI PASS is not treated as Android runtime evidence.

## Next task

Run the DEBUG-16 artifact on the same real Android JVM through Mojo/MJLauncher using the unchanged Execute-JAR probe.

Capture the complete log from:

PROBE_START

through either:

ANDROID_JNI_GLUE_LOAD_PASS / PROBE_END

or the first new:

ANDROID_JNI_GLUE_LOAD_FAIL

The result of that one run determines the next dependency boundary. Do not add any additional SDL class before seeing that runtime result.

## Handoff

Status:
BLOCKED

Branch:
android-jvm

Baseline:
ad6ed8799b2d6cc471c349bd047a677a3dff82e9

Commit:
95eedbccbcebf9db17e5b434052e60a1624f324d — diagnostic packaging

Files changed:
- scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh
- docs/android-jvm/TASK_03C_DEBUG_16_SDLJOYSTICKHANDLER_LOAD.md

Result:
DEBUG-16 diagnostic artifact successfully built and inspected with exactly one added SDL Java class. Real-device execution remains outstanding.

CI:
- 35508353977 — Continuous Build PASS
- 35508353983 — Gradle Wrapper validation PASS

Build:
DEBUG-16 diagnostic packaging PASS; native artifact unchanged.

Verification:
Five intended SDL Java classes present; no unexpected SDL Java classes; native SHA-256 unchanged and verified.

Known limitations:
No real Android DEBUG-16 runtime result available from the current environment.

Next task:
Execute the generated DEBUG-16 artifact through Mojo/MJLauncher on the real Android device and capture the first new boundary.
