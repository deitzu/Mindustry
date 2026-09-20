# TASK 03C-DEBUG-17A — Static Haptic Branch Audit

## Status

COMPLETE — exact pinned SDL 2.32.8 source was verified and the API 31 haptic branch was determined. The minimum statically proven inheritance prerequisite set for that branch is SDLHapticHandler_API26 plus SDLHapticHandler. No diagnostic artifact, loader, native library, or production source was modified.

## Branch

android-jvm

## Baseline

98aa7f711bdef4690b3515d9bd3335fe0c2c7664

Remote branch inspection showed android-jvm is identical to this commit before this report was created.

Working-tree status before modification: UNVERIFIED. The available GitHub repository interface exposes the remote branch/ref but does not expose the local checkout's uncommitted working-tree state. No local project checkout was available in the execution environment.

## Result commit

Report-only commit:
pending at report creation

No implementation or artifact commit was made for DEBUG-17A.

## SDL source revision

SDL 2.32.8

Pinned commit:
98d1f3a45aae568ccd6ed5fec179330f47d4d356

Repository:
libsdl-org/SDL

Exact source location:
android-project/app/src/main/java/org/libsdl/app/SDLControllerManager.java

Source file blob observed at the pinned commit:
9d8b20b7bbf7c2750055472b59bb447d1080c6fe

## Source verification

Verification method:

1. Fetched SDLControllerManager.java directly from the SDL repository at ref 98d1f3a45aae568ccd6ed5fec179330f47d4d356.
2. Inspected the exact class declarations and haptic initialization code.
3. Cross-checked the same pinned source against the previously inspected DEBUG-16B source analysis.
4. Cross-checked the haptic branch against the compiled DEBUG-16A SDLControllerManager.class bytecode.

The source explicitly declares:

class SDLHapticHandler_API26 extends SDLHapticHandler

and SDLHapticHandler itself has no SDL-local superclass declaration, so its superclass is java.lang.Object.

The source also explicitly implements:

if (Build.VERSION.SDK_INT >= 26) {
    mHapticHandler = new SDLHapticHandler_API26();
} else {
    mHapticHandler = new SDLHapticHandler();
}

## Analysis method

Source analysis covered:

- SDLControllerManager.initialize()
- class declarations
- extends/implements relationships
- haptic fields
- constructors
- instance methods
- object creation
- field/method references
- Android API conditionals
- static initialization considerations
- reflection/dynamic loading
- JNI-relevant calls
- nested SDL-local class references

Bytecode analysis used the compiled DEBUG-16A SDLControllerManager.class with:

- javap -c -p
- javap -verbose

The DEBUG-16A artifact did not package SDLHapticHandler.class or SDLHapticHandler_API26.class, so their own compiled class files were not available for direct javap inspection in this audit. Their source definitions were inspected from the exact pinned revision.

This is sufficient to establish the branch and inheritance relationship from source, while keeping unavailable bytecode evidence explicitly marked as unavailable.

## Analysis roots

Primary root:

org.libsdl.app.SDLControllerManager

Haptic path:

SDLControllerManager.initialize()
    -> SDLHapticHandler_API26   [API >= 26]
        -> SDLHapticHandler

Fallback path:

SDLControllerManager.initialize()
    -> SDLHapticHandler       [API < 26]

Nested/static local reference inside the base handler:

SDLHapticHandler
    -> SDLHapticHandler$SDLHaptic

Additional local calls:

SDLHapticHandler
    -> SDLControllerManager
    -> SDL

## API 31 branch determination

Android API level under the project runtime:

31

Exact source condition:

Build.VERSION.SDK_INT >= 26

Selected haptic class on API 31:

org.libsdl.app.SDLHapticHandler_API26

Therefore the API 31 runtime selects:

SDLControllerManager
    -> SDLHapticHandler_API26
    -> SDLHapticHandler

### Branch table

| Runtime condition | Selected class/path | Evidence | Runtime confirmed |
|---|---|---|---|
| API >= 26 | SDLHapticHandler_API26 -> SDLHapticHandler | exact pinned source; prior javap of SDLControllerManager.initialize() | API31 selection not separately instrumented |
| API < 26 | SDLHapticHandler | exact pinned source; prior javap of SDLControllerManager.initialize() | no |

The API 31 row is explicit because 31 satisfies the exact >=26 test.

## Haptic inheritance chain

Confirmed relationship:

SDLHapticHandler_API26
    extends SDLHapticHandler

SDLHapticHandler
    extends java.lang.Object

No other SDL-local superclass was found for SDLHapticHandler.

## Minimum statically proven inheritance prerequisite set

DECISION: Option B

Minimal haptic prerequisite set:

1. org/libsdl/app/SDLHapticHandler.class
2. org/libsdl/app/SDLHapticHandler_API26.class

Reason:

- API 31 satisfies SDLControllerManager's exact API >= 26 condition.
- That branch explicitly constructs SDLHapticHandler_API26.
- SDLHapticHandler_API26 directly extends SDLHapticHandler.
- Therefore both class definitions are required to satisfy the selected branch's inheritance/class-definition relationship.
- No SDL-local superclass of SDLHapticHandler exists.

This is a minimal statically proven inheritance prerequisite set, not a complete static haptic dependency closure.

## SDL-local dependencies

### SDLControllerManager -> SDLHapticHandler

Reference type:
HARD_STATIC_REFERENCE

Also an:
INHERITANCE_PREREQUISITE for the selected API26 class path

Evidence:
- field descriptor mHapticHandler
- new SDLHapticHandler_API26() / new SDLHapticHandler()
- method calls through mHapticHandler

### SDLControllerManager -> SDLHapticHandler_API26

Reference type:
HARD_STATIC_REFERENCE

Conditional:
yes

API condition:
Build.VERSION.SDK_INT >= 26

Evidence:
- exact source branch
- compiled DEBUG-16A bytecode shows new SDLHapticHandler_API26() at the >=26 branch

### SDLHapticHandler_API26 -> SDLHapticHandler

Reference type:
INHERITANCE_PREREQUISITE

Conditional:
no, once API26 class is selected

Evidence:
exact pinned source declaration:
class SDLHapticHandler_API26 extends SDLHapticHandler

### SDLHapticHandler -> SDLHapticHandler$SDLHaptic

Reference type:
HARD_STATIC_REFERENCE

Evidence:
- nested static class declaration
- field type ArrayList<SDLHaptic>
- new SDLHaptic() in pollHapticDevices()
- getHaptic() return type

This nested class is not a superclass prerequisite. It is an additional statically referenced local class whose execution requirement depends on the haptic polling/usage path and JVM class-linking behavior.

### SDLHapticHandler -> SDLControllerManager

Reference type:
HARD_STATIC_REFERENCE

Evidence:
- nativeAddHaptic(...)
- nativeRemoveHaptic(...)

This class is already an analysis root and therefore is not an additional missing payload candidate for this task.

### SDLHapticHandler -> SDL

Reference type:
HARD_STATIC_REFERENCE

Evidence:
- SDL.getContext().getSystemService(...)

SDL is already outside the new haptic prerequisite decision and is not a newly discovered candidate payload class.

## Additional Android/framework dependencies

These are not SDL-local payload classes:

SDLHapticHandler_API26 references:

- android.os.VibrationEffect
- android.util.Log
- java.lang.Math

SDLHapticHandler references:

- android.hardware/input-related Android classes through InputDevice
- android.os.Vibrator
- android.content.Context
- java.util.ArrayList
- SDL/Android context APIs

These are framework/JVM dependencies, not additional SDL-local inheritance prerequisites.

## Conditional dependencies

### SDLControllerManager joystick branch

The existing controller initialization also contains:

API >= 19
    -> SDLJoystickHandler_API19
else
    -> SDLJoystickHandler_API16

This is outside the haptic prerequisite decision but remains part of the surrounding controller initialization.

### SDLControllerManager haptic branch

API >= 26
    -> SDLHapticHandler_API26
else
    -> SDLHapticHandler

This is the condition that controls the haptic class selected on API 31.

No separate API31-specific SDL haptic class exists in the inspected source.

## Reflective / dynamic dependencies

No reflective or dynamically generated SDL-local class loading was identified in the haptic classes inspected.

The SDL.java ReLinker dynamic loading path exists elsewhere in SDL and is not part of the haptic branch audit.

## JNI dependencies

SDLHapticHandler directly invokes native methods declared by SDLControllerManager:

- SDLControllerManager.nativeAddHaptic(...)
- SDLControllerManager.nativeRemoveHaptic(...)

These are JNI method invocations through an already-established SDLControllerManager root.

No new SDL Java class name loaded through JNI was identified in the haptic branch itself.

The native JNI registration-root analysis from earlier tasks remains separate from this haptic branch audit.

## Runtime cross-check

DEBUG-17 real Android evidence established:

NoClassDefFoundError:
org/libsdl/app/SDLHapticHandler

This is:

RUNTIME_CONFIRMED

as the current runtime failure boundary.

The runtime result does not by itself prove whether API26 or another branch is selected. The exact source/bytecode analysis independently establishes that Android API 31 selects SDLHapticHandler_API26.

Therefore:

- runtime confirms SDLHapticHandler is currently demanded/encountered
- static source confirms API31 selects SDLHapticHandler_API26
- static source confirms API26 extends SDLHapticHandler

There is no contradiction between the runtime boundary and the static branch analysis.

## Bytecode cross-check

The previously compiled DEBUG-16A SDLControllerManager.class contains this exact structure:

- load mHapticHandler
- compare Build.VERSION.SDK_INT with 26
- API >= 26 branch:
  new org/libsdl/app/SDLHapticHandler_API26
  invokespecial SDLHapticHandler_API26.<init>
  putstatic mHapticHandler
- API < 26 branch:
  new org/libsdl/app/SDLHapticHandler
  invokespecial SDLHapticHandler.<init>
  putstatic mHapticHandler

The constant pool also contains:

- SDLHapticHandler_API26
- SDLHapticHandler
- mHapticHandler:Lorg/libsdl/app/SDLHapticHandler

Direct bytecode for the two haptic class files themselves was not available in the inspected DEBUG-16A artifact.

## Evidence classification

### Confirmed by source

- Exact SDL 2.32.8 revision.
- API >= 26 haptic branch.
- API 31 therefore selects SDLHapticHandler_API26.
- SDLHapticHandler_API26 extends SDLHapticHandler.
- SDLHapticHandler has no SDL-local superclass.
- SDLHapticHandler contains nested SDLHapticHandler$SDLHaptic.
- SDLHapticHandler calls SDLControllerManager native haptic methods.
- SDLHapticHandler accesses SDL.getContext().
- API26 haptic implementation uses Android VibrationEffect/Vibrator APIs.

### Confirmed by bytecode

- DEBUG-16A SDLControllerManager.class contains the >=26 conditional branch.
- API >=26 branch executes new SDLHapticHandler_API26().
- Fallback branch executes new SDLHapticHandler().
- mHapticHandler is typed as SDLHapticHandler.

Direct bytecode inspection of SDLHapticHandler_API26.class and SDLHapticHandler.class was not possible because those class files were not present in DEBUG-16A.

### Confirmed by CI/build

Not required for this analysis-only task.

No DEBUG-17A build was performed.

### Confirmed by artifact inspection

The existing DEBUG-16A artifact was inspected to obtain the compiled SDLControllerManager.class used for bytecode cross-checking.

No artifact was modified.

### Confirmed by real Android runtime

- DEBUG-17 reached NoClassDefFoundError for org.libsdl.app.SDLHapticHandler.
- SDLHapticHandler is therefore a runtime-confirmed current boundary.

API31 selecting API26 is not separately runtime-instrumented here; that point is source/bytecode confirmed.

### Inference

- The minimum statically proven inheritance prerequisite set for the API31 haptic branch is {SDLHapticHandler_API26, SDLHapticHandler}.
- SDLHapticHandler$SDLHaptic is an additional static local dependency, but it is not part of the inheritance prerequisite pair.
- SDL, SDLControllerManager, and Android framework classes are not newly justified by this branch as additional standalone payload candidates.

### Unknown

- Whether a real Android JVM will immediately require SDLHapticHandler$SDLHaptic after API26/base classes are supplied.
- Whether loading/linking/verification of API26 or base HapticHandler triggers any additional class resolution before System.load() can complete.
- Whether any runtime-specific classloader/JNI behavior adds requirements not visible in this static audit.
- Whether the full haptic polling/run path works on Android API31.

## False-positive risks

Static references may exist in methods that are not executed.

In particular:

- SDLHapticHandler$SDLHaptic is referenced by haptic polling and getHaptic logic, but the current native-load boundary does not prove that its class will be resolved immediately.
- Android framework references do not imply missing bundled classes because those classes are supplied by the Android runtime.
- A bytecode constant-pool reference does not by itself establish immediate runtime loading.

STATIC REFERENCE != IMMEDIATE RUNTIME REQUIREMENT

## False-negative risks

Static analysis may miss:

- dynamic class loading
- reflection
- JNI class lookup outside the inspected Java code
- class initialization side effects
- classloader-specific resolution behavior
- runtime feature-gated code
- native callbacks that trigger Java classes

The haptic class files themselves were not directly bytecode-inspected in this task because the existing DEBUG-16A artifact intentionally did not contain them.

## Known limitations

This task is source/bytecode audit only.

No DEBUG-18 artifact was created.

No SDL class was added to any diagnostic artifact.

No production source, native library, loader, classloader setup, or runtime behavior was changed.

The local checkout's working-tree status could not be inspected because no local repository checkout was available to the tool environment.

## Minimum-prerequisite decision

Option B:

Minimal haptic prerequisite set:

SDLHapticHandler
SDLHapticHandler_API26

This decision is based on the exact pinned source branch plus the compiled SDLControllerManager bytecode.

It is not based merely on the fact that SDLHapticHandler was the runtime failure string.

## Recommendation for DEBUG-18

The evidence-backed next diagnostic payload should begin with exactly:

- org/libsdl/app/SDLHapticHandler.class
- org/libsdl/app/SDLHapticHandler_API26.class

plus the already established DEBUG-17 payload.

Do not add SDLHapticHandler$SDLHaptic or unrelated SDL classes solely from this static audit unless a subsequent runtime result demonstrates that they are the next required boundary.

DEBUG-18 should remain a runtime validation experiment, not a generalized SDL Java dependency expansion.

## Acceptance criteria

- [x] exact SDL 2.32.8 commit verified
- [x] SDLControllerManager haptic initialization inspected
- [x] API 31 branch determined from exact source/bytecode
- [x] SDLHapticHandler_API26 relationship verified
- [x] SDLHapticHandler inheritance/dependencies analyzed
- [x] SDLHapticHandler_API26 dependencies analyzed
- [x] SDL-local dependencies classified
- [x] conditional dependencies classified
- [x] reflective/JNI references considered
- [x] runtime-confirmed SDLHapticHandler kept separate from static predictions
- [x] minimum prerequisite-set decision made
- [x] no diagnostic artifact changes made
- [x] no production source changes made
- [x] immutable DEBUG-17A report created

## Handoff

Status: COMPLETE

Branch: android-jvm

Baseline: 98aa7f711bdef4690b3515d9bd3335fe0c2c7664

Result: exact pinned SDL source plus available compiled controller bytecode establish the API31 haptic branch and minimum inheritance prerequisite set.

CI: not required

Build: not performed

Verification: source revision, branch condition, inheritance chain, static local references, and DEBUG-17 runtime boundary cross-checked.

Known limitations: direct bytecode for SDLHapticHandler_API26 and SDLHapticHandler was unavailable in the existing DEBUG-16A artifact; real Android execution is intentionally not repeated.

Next task: DEBUG-18 should validate the minimal haptic prerequisite set on the real Android JVM and stop at the first new runtime boundary.
