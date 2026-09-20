# TASK 03C-DEBUG-15 — Real Android Four-Class JNI Load Probe

## Status

COMPLETE — real Android runtime probe reached a new Java class-resolution boundary.

## Branch

**android-jvm**

## Baseline

**ad6ed8799b2d6cc471c349bd047a677a3dff82e9**

## Result

Documentation-only result commit created from this report.

## Pinned dependencies

Arc:

**8eb00ffff0126d0576c67df46f99b8f6bccd96fe**

SDL:

- version: **2.32.8**
- commit: **98d1f3a45aae568ccd6ed5fec179330f47d4d356**

## Objective

Run the completed DEBUG-14 four-class SDL Android Java glue diagnostic on the real Android JVM through Mojo Launcher and determine the earliest new native/JNI runtime boundary after providing the four Java classes directly registered by SDL 2.32.8 JNI_OnLoad.

The probe intentionally uses:

**System.load(absolutePath)**

and does not use:

**System.loadLibrary("sdl-arc")**.

## Artifact

Artifact:

**Android-JVM-android-jni-glue-load-probe-b4433a1dc78bd4910724268645c1c06bf7ac08f1**

GitHub Actions artifact ID:

**10603299911**

Artifact ZIP SHA-256:

**9641318b1c58be12e7b153267379937192f73ba4e29bf54b147a1d0853a9c8f7**

The inspected JAR contains exactly these four SDL Java classes:

- **org/libsdl/app/SDLActivity.class**
- **org/libsdl/app/SDLInputConnection.class**
- **org/libsdl/app/SDLAudioManager.class**
- **org/libsdl/app/SDLControllerManager.class**

and the real Android ARM64 native library:

**android-jvm-probe/native/arm64-v8a/libsdl-arc.so**

Embedded native SHA-256:

**d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7**

The embedded native SHA matches the DEBUG-14 source native artifact.

## Runtime environment

Real Android device previously used for DEBUG-12/12A/13/13A/14:

- Android API: 31
- architecture: ARM64 / AArch64
- JVM vendor: Oracle Corporation
- JVM version: **21.0.12-internal**
- os.name: **Linux**
- os.arch: **aarch64**
- sun.arch.data.model: **64**
- GPU: ARM Mali-G52
- launcher/runtime package observed in paths: **git.artdeell.mjlaunch**
- exact Mojo Launcher application version was not emitted by this probe log: Unknown

## Procedure

The final DEBUG-14 diagnostic JAR was executed through Mojo Launcher's Execute-JAR mechanism on the real Android JVM.

The probe:

1. located the embedded libsdl-arc.so;
2. extracted it to the Mojo cache filesystem;
3. checked existence, regular-file status, readability, and size;
4. computed the extracted SHA-256;
5. called System.load(absolutePath);
6. captured the first failure and complete Java cause chain.

No production code was modified before this first runtime result.

## Runtime result

### Resource and extraction boundary

Confirmed by real Android runtime:

**ANDROID_JNI_GLUE_FILE_EXISTS=true**

**ANDROID_JNI_GLUE_FILE_REGULAR=true**

**ANDROID_JNI_GLUE_FILE_READABLE=true**

**ANDROID_JNI_GLUE_FILE_SIZE=4710176**

**ANDROID_JNI_GLUE_SHA256=d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7**

Therefore the exact DEBUG-14 native artifact was successfully extracted and read by the Android JVM.

### Absolute native-load result

The probe reached:

**ANDROID_JNI_GLUE_LOAD_BEGIN**

and then failed with:

**ANDROID_JNI_GLUE_LOAD_ERROR.type=java.lang.NoClassDefFoundError**

**ANDROID_JNI_GLUE_LOAD_ERROR.message=org/libsdl/app/SDLJoystickHandler**

Cause chain:

**java.lang.NoClassDefFoundError: org/libsdl/app/SDLJoystickHandler**

caused by:

**java.lang.ClassNotFoundException: org.libsdl.app.SDLJoystickHandler**

Relevant stack boundary:

**java.lang.ClassLoader$NativeLibrary.load(Native Method)**

**java.lang.ClassLoader.loadLibrary0(Unknown Source)**

**java.lang.ClassLoader.loadLibrary(Unknown Source)**

**java.lang.Runtime.load0(Unknown Source)**

**java.lang.System.load(Unknown Source)**

**androidjvm.probe.AbsolutePathAndroidJniGlueLoadProbe.main(AbsolutePathAndroidJniGlueLoadProbe.java:123)**

There was no UnsatisfiedLinkError, linker dependency error, SIGSEGV, SIGABRT, EGL error, or Activity/window error in this probe.

## Boundary reached

**Earliest new boundary: Java class resolution during native-library loading/JNI initialization.**

The previous real-device boundary was the missing:

**org/libsdl/app/SDLControllerManager**

DEBUG-14 supplied that class.

The DEBUG-15 result moved past that previous missing-class boundary and exposed the next required class:

**org.libsdl.app.SDLJoystickHandler**

### Why this class is now the first blocker

Confirmed by SDL 2.32.8 source:

JNI_OnLoad calls registration for:

**org/libsdl/app/SDLControllerManager**

and the registration helper first calls JNI **FindClass** for the requested class.

Confirmed by artifact inspection:

SDLControllerManager.class contains a field with descriptor:

**Lorg/libsdl/app/SDLJoystickHandler;**

and its bytecode references:

- org/libsdl/app/SDLJoystickHandler
- org/libsdl/app/SDLJoystickHandler_API16
- org/libsdl/app/SDLJoystickHandler_API19
- org/libsdl/app/SDLHapticHandler
- org/libsdl/app/SDLHapticHandler_API26

Confirmed by SDL 2.32.8 source:

**SDLJoystickHandler** is a real top-level package-private class declared in **SDLControllerManager.java**; it is not a fabricated dependency.

**Inference:** the JVM is resolving the symbolic SDLJoystickHandler dependency while loading/verifying SDLControllerManager, which produces the observed NoClassDefFoundError. The log does not expose the exact JVM internal resolution instruction, so this internal mechanism is classified as inference rather than direct runtime proof.

## What DEBUG-15 proves

### Confirmed by artifact inspection

- The final DEBUG-14 artifact is intact.
- The artifact SHA-256 is 9641318b...
- The embedded native library is the expected real ARM64 Android artifact.
- The embedded native SHA matches d98174dd...
- The artifact contains the four intended direct JNI classes.

### Confirmed by real Android runtime

- The artifact can be consumed by Mojo's Execute-JAR environment.
- The embedded libsdl-arc.so can be extracted to an Android filesystem path.
- The extracted file is readable and has the expected SHA-256.
- System.load(absolutePath) reaches the Java native-library loading path.
- DEBUG-14's previously missing SDLControllerManager dependency is no longer the first reported missing class.
- The earliest newly observed failure is NoClassDefFoundError: org/libsdl/app/SDLJoystickHandler.
- The underlying cause reported by the JVM is ClassNotFoundException: org.libsdl.app.SDLJoystickHandler.

### Confirmed by source

- SDL 2.32.8 JNI_OnLoad registers four direct Java classes.
- The registration helper uses JNI FindClass.
- SDLJoystickHandler is defined in the real SDL source as a top-level package-private class in SDLControllerManager.java.

### Confirmed by CI/build

- DEBUG-14 four-class diagnostic packaging passed.
- The native artifact used by DEBUG-15 was produced and integrity-checked by CI.

### Inference

- The observed SDLJoystickHandler error is caused by JVM class resolution associated with SDLControllerManager during native library initialization.

### Unknown

- Whether supplying only SDLJoystickHandler.class is sufficient for the next load attempt.
- Whether the next boundary will be another Java class, Java method/field resolution, JNI registration, Android framework/context dependency, or another native/runtime boundary.
- Whether System.load(absolutePath) will eventually return successfully once all required transitive classes are available.

## Files changed

Only this historical report was added:

**docs/android-jvm/TASK_03C_DEBUG_15_REAL_ANDROID_JNI_LOAD.md**

No production Mindustry source was changed.

No Arc source was changed.

No SDL source was changed.

No loader, Mojo, renderer, Activity, EGL, or GLES integration was changed.

## CI

No new CI build was required.

The completed DEBUG-14 artifact was reused exactly as required by TASK 03C-DEBUG-15.

## Known limitations

- The exact Mojo Launcher application version was not emitted in the probe log.
- This task proves a real Android Java/native loading boundary, not full SDL initialization.
- No Activity, window, surface, EGL, GLES context, input runtime, audio runtime, or Mindustry startup has been proven.
- The internal JVM class-resolution sequence leading to SDLJoystickHandler is inferred from the observed exception plus bytecode/source evidence.

## Next task

Run the next smallest real-device diagnostic by adding only the real SDL 2.32.8 **SDLJoystickHandler.class** dependency to the probe package.

Do not add the API16/API19 joystick implementations or haptic classes preemptively. Let the Android JVM reveal the next dependency boundary.

## Handoff

Status:
COMPLETE

Branch:
android-jvm

Baseline:
ad6ed8799b2d6cc471c349bd047a677a3dff82e9

Commit:
Documentation-only result commit created from this report.

Files changed:
docs/android-jvm/TASK_03C_DEBUG_15_REAL_ANDROID_JNI_LOAD.md

Result:
Real Android DEBUG-14 four-class JNI-load probe progressed beyond the previously missing SDLControllerManager class and reached the next Java dependency boundary: org.libsdl.app.SDLJoystickHandler.

CI:
No new CI required; DEBUG-14 artifact reused.

Build:
No rebuild performed.

Verification:
Real Android extraction, file validation, SHA-256 verification, and System.load(absolutePath) execution confirmed. Failure was NoClassDefFoundError with underlying ClassNotFoundException for org.libsdl.app.SDLJoystickHandler.

Known limitations:
Only the first new Java class-resolution boundary is proven. Full JNI completion and SDL runtime initialization remain unverified.

Next task:
Add only the real SDL 2.32.8 SDLJoystickHandler.class dependency and repeat the real Android absolute-path load probe.
