# TASK 03C-DEBUG-16A — Classloader Visibility Instrumentation

## Status

COMPLETE — diagnostic instrumentation was implemented, built, and artifact-inspected successfully. Real Android runtime execution is UNVERIFIED because no Android/Mojo device is accessible from this environment.

## Branch

android-jvm

## Baseline

ad6ed8799b2d6cc471c349bd047a677a3dff82e9

## Result commit

615bd7f1358d271501d55eb0a122412d02b6aa83 — classloader visibility instrumentation.

Documentation result commit:
created by this report commit.

## Pinned dependencies

Arc:

8eb00ffff0126d0576c67df46f99b8f6bccd96fe

SDL:

- version: 2.32.8
- commit: 98d1f3a45aae568ccd6ed5fec179330f47d4d356

## Objective

Determine whether the DEBUG-16 contradiction is caused by Java application-classpath visibility, a difference between Java classloader visibility and native/JNI class resolution, an artifact mismatch, or another concrete loader/package issue.

The instrumentation intentionally does not add any SDL dependency and does not change:

- System.load(absolutePath)
- native extraction
- java.library.path
- LD_LIBRARY_PATH
- native payload
- Mojo Launcher
- production runtime code

## Hypotheses

### Hypothesis A

The class is present in the inspected artifact but not visible to the Java application classpath actually used by Mojo.

### Hypothesis B

The class is visible to the application Java classloader but not visible through the class-resolution context used by native/JNI loading.

### Hypothesis C

The artifact inspected by the project is not the same artifact/JAR executed on Android.

### Hypothesis D

Another concrete classpath, loader, package, or runtime issue exists.

This task does not select among these hypotheses without runtime measurements.

## Files changed

Production/runtime source:

None.

Diagnostic:

scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh

Documentation:

docs/android-jvm/TASK_03C_DEBUG_16A_CLASSLOADER_VISIBILITY.md

Historical DEBUG-14, DEBUG-15, and DEBUG-16 reports were not modified.

## Diagnostic implementation

The existing inline probe class:

androidjvm/probe/AbsolutePathAndroidJniGlueLoadProbe.java

was instrumented immediately before the unchanged:

System.load(target.getAbsolutePath());

The diagnostics log:

- java.class.path
- probe class ProtectionDomain / CodeSource when available
- system classloader concrete class
- probe classloader concrete class
- thread context classloader concrete class
- Class.forName("org.libsdl.app.SDLJoystickHandler", false, loader) for each relevant loader
- success/failure and exception type/message for each Class.forName call
- resource lookup for org/libsdl/app/SDLJoystickHandler.class through each relevant loader
- resolved classloader and code source when a visibility test succeeds

The visibility test uses initialize=false, so it does not intentionally initialize SDLJoystickHandler.

The source contains no direct SDLJoystickHandler.class reference before these tests.

The existing native load path remains unchanged and still performs:

System.load(target.getAbsolutePath());

The existing failure logging remains unchanged.

## Required logging implemented

The probe now emits:

ANDROID_JNI_CLASS_VISIBILITY_BEGIN

ANDROID_JNI_CLASS_JAVA_CLASS_PATH=...

ANDROID_JNI_CLASS_CODE_SOURCE=...

ANDROID_JNI_CLASS_SYSTEM_LOADER_CLASS=...
ANDROID_JNI_CLASS_SYSTEM_VISIBLE=true/false
ANDROID_JNI_CLASS_SYSTEM_ERROR.type=...
ANDROID_JNI_CLASS_SYSTEM_ERROR.message=...
ANDROID_JNI_CLASS_SYSTEM_RESOURCE=...

ANDROID_JNI_CLASS_PROBE_LOADER_CLASS=...
ANDROID_JNI_CLASS_PROBE_VISIBLE=true/false
ANDROID_JNI_CLASS_PROBE_ERROR.type=...
ANDROID_JNI_CLASS_PROBE_ERROR.message=...
ANDROID_JNI_CLASS_PROBE_RESOURCE=...

ANDROID_JNI_CLASS_CONTEXT_LOADER_CLASS=...
ANDROID_JNI_CLASS_CONTEXT_VISIBLE=true/false
ANDROID_JNI_CLASS_CONTEXT_ERROR.type=...
ANDROID_JNI_CLASS_CONTEXT_ERROR.message=...
ANDROID_JNI_CLASS_CONTEXT_RESOURCE=...

ANDROID_JNI_CLASS_RESOURCE_SYSTEM=...
ANDROID_JNI_CLASS_RESOURCE_PROBE=...
ANDROID_JNI_CLASS_RESOURCE_CONTEXT=...

ANDROID_JNI_CLASS_VISIBILITY_END

The final native operation remains:

ANDROID_JNI_GLUE_LOAD_BEGIN
→ System.load(absolutePath)
→ existing pass/fail logging

## Artifact payload

The DEBUG-16 five-class payload is preserved exactly.

SDL Java classes:

- org/libsdl/app/SDLActivity.class
- org/libsdl/app/SDLInputConnection.class
- org/libsdl/app/SDLAudioManager.class
- org/libsdl/app/SDLControllerManager.class
- org/libsdl/app/SDLJoystickHandler.class

No additional SDL Java classes were added.

The native resource remains:

android-jvm-probe/native/arm64-v8a/libsdl-arc.so

## Artifact verification

Continuous Build produced:

Artifact:

Android-JVM-android-jni-glue-load-probe-615bd7f1358d271501d55eb0a122412d02b6aa83

Artifact ID:

10603804467

Artifact SHA-256:

6cdc6cba82e3facca13bf912cc202616c3327904b7ee1538b75de9549f476fbb

Directly inspected JAR:

Mindustry-android-jvm-android-jni-glue-load-probe.jar

JAR SHA-256:

7f25c6de373cdb7f9e90d52ed1e32415105dd067f5409bfd3f7798173b8fb979

Direct inspection found exactly five org/libsdl/app class files:

org/libsdl/app/SDLActivity.class
org/libsdl/app/SDLAudioManager.class
org/libsdl/app/SDLControllerManager.class
org/libsdl/app/SDLInputConnection.class
org/libsdl/app/SDLJoystickHandler.class

No other org/libsdl/app class files were present.

The probe helper remained present.

Native resource:

android-jvm-probe/native/arm64-v8a/libsdl-arc.so

Native size:

4710176 bytes

Native SHA-256:

d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7

The native SHA matches the known-good DEBUG-16/DEBUG-15 value exactly.

## CI/build

Continuous Build:

35509296103 — PASS

Tests:

35509296054 — PASS

Gradle Wrapper validation:

35509296121 — PASS

Continuous Build specifically passed:

- Android ARM64 SDL native probe
- unit tests
- desktop JAR build and verification
- real Android JVM load probe packaging
- absolute-path load diagnostic packaging
- DEBUG-16A classloader-instrumented diagnostic packaging
- artifact upload

The GitHub-hosted loader probe remains Linux-hosted and is not Android runtime evidence.

## Real Android runtime evidence

UNVERIFIED.

No Android device or Mojo/MJLauncher process is accessible from this execution environment.

Therefore no new DEBUG-16A runtime visibility matrix is claimed.

In particular, this report does not claim:

- System loader visibility
- Probe loader visibility
- Context loader visibility
- resource visibility on Android
- equivalence of inspected and executed artifact
- JNI/native classloader visibility

Those require execution of the new instrumented JAR on the real Android JVM.

## Visibility matrix

Because the real Android execution has not been performed:

| Loader | Loader class | SDLJoystickHandler visible | Resource visible | Notes |
|---|---|---|---|---|
| System | UNVERIFIED | UNVERIFIED | UNVERIFIED | Requires real Android execution |
| Probe | UNVERIFIED | UNVERIFIED | UNVERIFIED | Requires real Android execution |
| Context | UNVERIFIED | UNVERIFIED | UNVERIFIED | Requires real Android execution |

Executed artifact/code source:

UNVERIFIED on Android.

Built artifact:

Android-JVM-android-jni-glue-load-probe-615bd7f1358d271501d55eb0a122412d02b6aa83

## Evidence classification

### Confirmed by source

- SDLJoystickHandler is a real SDL 2.32.8 top-level package-private class declared in SDLControllerManager.java.
- The diagnostic source now invokes Class.forName with initialize=false for the string class name.
- The diagnostic does not directly reference SDLJoystickHandler.class before the visibility test.
- The existing System.load(absolutePath) operation remains unchanged.

### Confirmed by CI/build

- The instrumented probe compiles successfully.
- Continuous Build 35509296103 passes.
- Tests 35509296054 passes.
- Gradle Wrapper validation 35509296121 passes.
- The DEBUG-16A artifact was produced and uploaded successfully.

### Confirmed by artifact inspection

- The five-class DEBUG-16 SDL Java payload remains intact.
- No additional SDL Java classes were introduced.
- The probe helper is present.
- libsdl-arc.so remains present.
- Native size is 4710176 bytes.
- Native SHA-256 remains d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7.
- The DEBUG-16A diagnostic instrumentation is present in the packaged probe.

### Confirmed by real Android runtime

None for DEBUG-16A yet.

### Inference

- The instrumented artifact is suitable for separating normal Java loader visibility from the subsequent native/JNI resolution failure because it observes the same class before the unchanged System.load(absolutePath) operation.

### Unknown

- Whether System, Probe, and Context classloaders can see SDLJoystickHandler on the actual Android runtime.
- Whether their resource lookups find SDLJoystickHandler.class.
- Whether the JAR code source observed by Android matches the newly built artifact.
- Whether JNI/native resolution uses the same loader/context as the Java visibility checks.
- Whether System.load() changes behavior after these diagnostics.

## Interpretation

No final explanation of the DEBUG-16 contradiction is possible yet from CI alone.

The artifact contradiction itself is resolved only at the artifact layer:

**Confirmed by artifact inspection:** SDLJoystickHandler.class is physically present in the JAR.

The next distinction is intentionally left to Android runtime evidence:

**Java loader visibility**
vs.
**native/JNI class-resolution visibility**

This task therefore does not declare Hypothesis A, B, C, or D as proven.

## Acceptance criteria

- [x] Existing DEBUG-16 five-class payload preserved.
- [x] No additional SDL classes added.
- [x] Native libsdl-arc.so unchanged.
- [x] Native SHA remains identical.
- [x] Classloader diagnostics compile.
- [x] Runtime classpath/code-source diagnostics compile.
- [x] System/probe/context loader visibility checks implemented.
- [x] Resource visibility checks implemented.
- [x] Class.forName uses initialize=false.
- [x] Existing System.load(absPath) path remains unchanged.
- [x] Artifact contents inspected directly.
- [x] Immutable DEBUG-16A report created.
- [ ] Real Android runtime execution and visibility matrix captured.

## Known limitations

- Real Android/Mojo runtime data is unavailable in this environment.
- CI proves compilation, packaging, payload integrity, and instrumentation presence, but not Android classloader behavior.
- The contradiction between normal Java class visibility and JNI/native resolution remains unresolved until the instrumented JAR is run on the Android device.

## Next task

Execute the DEBUG-16A artifact through the same Mojo/MJLauncher Execute-JAR path on the real Android device.

Capture from:

PROBE_START

through:

ANDROID_JNI_CLASS_VISIBILITY_BEGIN
...
ANDROID_JNI_CLASS_VISIBILITY_END
ANDROID_JNI_GLUE_LOAD_BEGIN
...

Then use the resulting visibility matrix to distinguish application-classpath visibility from the native/JNI resolution boundary.

Do not add another SDL class before that result.

Do not declare DEBUG-17 unless the new Android evidence identifies a concrete next boundary.

## Handoff

Status:
COMPLETE

Branch:
android-jvm

Baseline:
ad6ed8799b2d6cc471c349bd047a677a3dff82e9

Commit:
615bd7f1358d271501d55eb0a122412d02b6aa83 — instrumentation
Documentation result commit: created by this report.

Files changed:
- scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh
- docs/android-jvm/TASK_03C_DEBUG_16A_CLASSLOADER_VISIBILITY.md

Result:
DEBUG-16A instrumentation successfully built and artifact-inspected. The five-class SDL payload and native binary were preserved unchanged. The probe now measures Java classpath, code source, system/probe/context classloaders, Class.forName initialize=false visibility, and class-resource visibility before the unchanged System.load(absolutePath).

CI:
- 35509296103 — Continuous Build PASS
- 35509296054 — Tests PASS
- 35509296121 — Gradle Wrapper validation PASS

Build:
DEBUG-16A diagnostic packaging PASS.

Verification:
Exactly five SDL Java classes present; no additional SDL classes; native SHA-256 unchanged.

Known limitations:
Real Android runtime visibility is UNVERIFIED.

Next task:
Run the new DEBUG-16A artifact on the real Android JVM through Mojo and capture the complete classloader visibility matrix plus the unchanged System.load result.
