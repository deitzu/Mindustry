# TASK 03C-DEBUG-16B — Static SDL Android Java Dependency Analysis

## Status
COMPLETE — exact pinned SDL 2.32.8 source was analyzed with source inspection plus bytecode inspection of the five packaged DEBUG-16A classes. No diagnostic artifact or production code was changed.

## Branch
android-jvm

## Baseline
29c93910d5fd4149c0b9ec0bf3e69e0ea52f024d

## Result commit
Documentation-only commit for this report.

## SDL source revision
SDL 2.32.8 commit: 98d1f3a45aae568ccd6ed5fec179330f47d4d356
Source location: android-project/app/src/main/java/org/libsdl/app/
Inspected files: SDL.java, SDLActivity.java, SDLAudioManager.java, SDLControllerManager.java, SDLSurface.java, HIDDevice.java, HIDDeviceManager.java, HIDDeviceBLESteamController.java, HIDDeviceUSB.java

## Analysis method
1. Verified the exact SDL source revision by fetching the Android Java sources at commit 98d1f3a45aae568ccd6ed5fec179330f47d4d356.
2. Inspected source class declarations, inheritance, field types, object creation, method calls, SDK/API branches, reflection, dynamic class loading, and JNI-facing native method declarations.
3. Unpacked the DEBUG-16A diagnostic JAR and inspected the five packaged SDL class files with javap -verbose and javap -c -p.
4. Filtered Android/java/javax framework references from the SDL-local dependency closure.
5. Cross-checked static candidates against DEBUG-15/16/16A real Android evidence without upgrading static references to runtime requirements.

## Analysis roots
JNI registration roots:
- org.libsdl.app.SDLActivity
- org.libsdl.app.SDLInputConnection
- org.libsdl.app.SDLAudioManager
- org.libsdl.app.SDLControllerManager

Runtime-observed chain:
- org.libsdl.app.SDLJoystickHandler
- org.libsdl.app.SDLJoystickHandler_API19

## Dependency graph
Native JNI_OnLoad
  -> SDLActivity
  -> SDLInputConnection
  -> SDLAudioManager
  -> SDLControllerManager

SDL
  -> SDLActivity
  -> SDLAudioManager
  -> SDLControllerManager

SDLControllerManager
  -> SDLJoystickHandler
  -> SDLJoystickHandler_API19 [API >= 19]
      -> SDLJoystickHandler_API16
          -> SDLJoystickHandler
  -> SDLJoystickHandler_API16 [API < 19]
  -> SDLHapticHandler_API26 [API >= 26]
      -> SDLHapticHandler
  -> SDLHapticHandler [API < 26]

SDLJoystickHandler_API16
  -> SDLJoystickHandler_API16$SDLJoystick
  -> SDLJoystickHandler_API16$RangeComparator
  -> SDLControllerManager

SDLHapticHandler
  -> SDLHapticHandler$SDLHaptic

SDLActivity
  -> SDLSurface
  -> SDLClipboardHandler
  -> HIDDeviceManager
  -> SDLGenericMotionListener_API12
  -> SDLGenericMotionListener_API24 [API >= 24 and < 26]
  -> SDLGenericMotionListener_API26 [API >= 26]
  -> SDLInputConnection
  -> SDLControllerManager
  -> SDLMain
  -> DummyEdit
  -> SDLActivity nested/generated classes

SDLInputConnection
  -> SDL
  -> SDLActivity

SDLGenericMotionListener_API24
  -> SDLGenericMotionListener_API12
SDLGenericMotionListener_API26
  -> SDLGenericMotionListener_API24
SDLSurface
  -> SDLActivity
  -> SDLGenericMotionListener_API12

HIDDeviceManager
  -> HIDDevice
  -> HIDDeviceUSB
  -> HIDDeviceBLESteamController
HIDDeviceUSB
  -> HIDDeviceUSB$InputThread
HIDDeviceBLESteamController
  -> HIDDeviceBLESteamController$GattOperation
      -> HIDDeviceBLESteamController$GattOperation$Operation

SDLAudioManager
  -> SDLAudioManager$1

## Required dependency table
| Source | Target | Reference type | Conditional | Runtime confirmed | Evidence |
|---|---|---|---|---|---|
| native JNI_OnLoad | SDLActivity | JNI_STRING_REFERENCE / RegisterNatives | no | yes, historical | SDL_android.c JNI_OnLoad |
| native JNI_OnLoad | SDLInputConnection | JNI_STRING_REFERENCE / RegisterNatives | no | yes, historical | SDL_android.c JNI_OnLoad |
| native JNI_OnLoad | SDLAudioManager | JNI_STRING_REFERENCE / RegisterNatives | no | yes, historical | SDL_android.c JNI_OnLoad |
| native JNI_OnLoad | SDLControllerManager | JNI_STRING_REFERENCE / RegisterNatives | no | yes, historical | SDL_android.c JNI_OnLoad |
| SDL | SDLActivity | METHOD_REFERENCE | no | no | SDL.java setupJNI/initialize |
| SDL | SDLAudioManager | METHOD_REFERENCE | no | no | SDL.java setupJNI/initialize |
| SDL | SDLControllerManager | METHOD_REFERENCE | no | no | SDL.java setupJNI/initialize |
| SDLActivity | SDLSurface | FIELD_REFERENCE / OBJECT_CREATION | later Activity path | no | SDLActivity field/createSDLSurface |
| SDLActivity | SDLClipboardHandler | FIELD_REFERENCE / OBJECT_CREATION | later Activity path | no | SDLActivity field/onCreate |
| SDLActivity | HIDDeviceManager | FIELD_REFERENCE / METHOD_REFERENCE | later Activity path | no | SDLActivity field/onCreate |
| SDLActivity | SDLGenericMotionListener_API12 | FIELD_REFERENCE / OBJECT_CREATION | no / API branch | no | SDLActivity.getMotionListener |
| SDLActivity | SDLGenericMotionListener_API24 | OBJECT_CREATION | API >= 24 | no | SDLActivity.getMotionListener |
| SDLActivity | SDLGenericMotionListener_API26 | OBJECT_CREATION | API >= 26 | no | SDLActivity.getMotionListener |
| SDLActivity | SDLInputConnection | OBJECT_CREATION | later input path | no | DummyEdit.onCreateInputConnection |
| SDLInputConnection | SDL | METHOD_REFERENCE | no | no | SDL.getContext() |
| SDLInputConnection | SDLActivity | METHOD_REFERENCE | later input path | no | SDLActivity.onNativeSoftReturnKey |
| SDLControllerManager | SDLJoystickHandler | FIELD_REFERENCE / METHOD_REFERENCE | no | yes | DEBUG-15/16 plus bytecode |
| SDLControllerManager | SDLJoystickHandler_API19 | OBJECT_CREATION | API >= 19 | yes | DEBUG-16A + javap |
| SDLControllerManager | SDLJoystickHandler_API16 | OBJECT_CREATION / SUPERCLASS | API < 19 / superclass chain | no | source |
| SDLJoystickHandler_API19 | SDLJoystickHandler_API16 | SUPERCLASS_REFERENCE | no | no | source declaration |
| SDLJoystickHandler_API16 | SDLJoystickHandler | SUPERCLASS_REFERENCE | no | yes | source + runtime |
| SDLJoystickHandler_API16 | SDLJoystickHandler_API16$SDLJoystick | NESTED_CLASS_REFERENCE | no | no | source |
| SDLJoystickHandler_API16 | SDLJoystickHandler_API16$RangeComparator | NESTED_CLASS_REFERENCE / OBJECT_CREATION | no | no | source |
| SDLControllerManager | SDLHapticHandler | FIELD_REFERENCE / OBJECT_CREATION | API-dependent | no | source + bytecode |
| SDLControllerManager | SDLHapticHandler_API26 | OBJECT_CREATION | API >= 26 | no | source + bytecode |
| SDLHapticHandler_API26 | SDLHapticHandler | SUPERCLASS_REFERENCE | no | no | source |
| SDLGenericMotionListener_API12 | SDLControllerManager | METHOD_REFERENCE | event-source dependent | no | source |
| SDLGenericMotionListener_API12 | SDLActivity | METHOD_REFERENCE | event-source dependent | no | source |
| SDLSurface | SDLActivity | METHOD/FIELD_REFERENCE | Surface path | no | source |
| HIDDeviceManager | HIDDevice | FIELD_REFERENCE | later HID path | no | source |
| HIDDeviceManager | HIDDeviceUSB | OBJECT_CREATION | USB HID path | no | source |
| HIDDeviceManager | HIDDeviceBLESteamController | FIELD_REFERENCE / OBJECT_CREATION | Bluetooth HID path | no | source |
| SDLAudioManager | SDLAudioManager$1 | NESTED/ANONYMOUS_CLASS_REFERENCE | API >= 24 | no | source + bytecode |

## Runtime cross-check
DEBUG-15: SDLJoystickHandler was the first new missing class.
DEBUG-16: SDLJoystickHandler was packaged without changing the native library.
DEBUG-16A: the class was visible through the measured Java loaders/resource lookup, then the unchanged System.load path reported NoClassDefFoundError for org/libsdl/app/SDLJoystickHandler_API19.

Therefore:
- SDLJoystickHandler = RUNTIME_CONFIRMED
- SDLJoystickHandler_API19 = RUNTIME_CONFIRMED as the next class requested by the Android runtime
- all other static candidates remain RUNTIME_UNCONFIRMED

## Bytecode findings
Direct javap inspection of the packaged DEBUG-16A classes confirmed:
- SDLActivity constant-pool references to HIDDeviceManager, SDL, SDLAudioManager, SDLControllerManager, SDLInputConnection, SDLClipboardHandler, SDLSurface, SDLGenericMotionListener_API12/API24/API26, SDLMain, and nested/generated SDLActivity classes.
- SDLInputConnection references to SDL.getContext() and SDLActivity.onNativeSoftReturnKey().
- SDLAudioManager references only its own anonymous SDLAudioManager$1 class within the SDL-local set.
- SDLControllerManager contains field references to SDLJoystickHandler and SDLHapticHandler and constructor invocations for SDLJoystickHandler_API19, SDLJoystickHandler_API16, SDLHapticHandler_API26, and SDLHapticHandler.
- SDLControllerManager.initialize() bytecode explicitly branches on Build.VERSION.SDK_INT and executes new SDLJoystickHandler_API19() for API >= 19.
- SDLJoystickHandler itself has no additional SDL-local superclass/dependency; it extends java.lang.Object.

## Reflective / dynamic / JNI references
SDL.java dynamically loads optional ReLinker classes through Context.getClassLoader().loadClass(...):
- com.getkeepsafe.relinker.ReLinker
- com.getkeepsafe.relinker.ReLinker$LoadListener
- android.content.Context
- java.lang.String
Those are not SDL-local dependencies. The code falls back to System.loadLibrary when the reflective ReLinker path fails.

SDLSurface uses reflection for getButtonState on the runtime event object. This is an Android API lookup, not an SDL-local class dependency.

HIDDeviceManager contains the string org.libsdl.app.USB_PERMISSION, but this is a broadcast action string, not a Java class dependency.

Native SDL JNI_OnLoad contains the four JNI registration class strings. Those are JNI_STRING_REFERENCE relationships, separate from ordinary Java source references.

## Classification
### Runtime-confirmed
- SDLControllerManager
- SDLJoystickHandler
- SDLJoystickHandler_API19

### Static hard references
- SDLControllerManager -> SDLJoystickHandler
- SDLControllerManager -> SDLJoystickHandler_API16
- SDLControllerManager -> SDLJoystickHandler_API19
- SDLControllerManager -> SDLHapticHandler
- SDLControllerManager -> SDLHapticHandler_API26
- SDLJoystickHandler_API19 -> SDLJoystickHandler_API16
- SDLJoystickHandler_API16 -> SDLJoystickHandler
- SDLActivity -> SDLSurface / SDLClipboardHandler / HIDDeviceManager / SDLInputConnection
- SDLInputConnection -> SDL / SDLActivity
- SDLSurface -> SDLActivity
- HIDDeviceManager -> HIDDevice / HIDDeviceUSB / HIDDeviceBLESteamController

### Conditional references
- SDLControllerManager joystick selection: API >= 19 -> API19, otherwise API16.
- SDLControllerManager haptic selection: API >= 26 -> API26, otherwise base haptic handler.
- SDLActivity motion selection: API >= 26 -> API26, API >= 24 -> API24, otherwise API12.
- SDLAudioManager audio device callback creation: API >= 24.

### Reflective / dynamic
- ReLinker loading in SDL.java.
- SDLSurface getButtonState reflective lookup.

### JNI-specific
- native JNI_OnLoad -> four Java registration roots.

## Confirmed by source
- Exact SDL 2.32.8 revision and Android Java source locations.
- SDLControllerManager -> SDLJoystickHandler/API16/API19.
- SDLJoystickHandler_API19 -> API16 -> SDLJoystickHandler.
- Haptic and generic-motion class hierarchies.
- SDLActivity Surface, input, HID, clipboard, and motion references.
- SDL.java ReLinker dynamic loading path.

## Confirmed by bytecode
- The five packaged DEBUG-16A classes contain the SDL-local constant-pool references described above.
- SDLControllerManager bytecode contains new SDLJoystickHandler_API19() behind the API >= 19 test.
- SDLJoystickHandler bytecode has no additional SDL-local dependency.

## Confirmed by real Android runtime
- SDLControllerManager was reached as an earlier JNI boundary.
- SDLJoystickHandler was requested by the Android runtime.
- SDLJoystickHandler_API19 was the next missing class reported by DEBUG-16A.

## Static prediction
The strongest static candidates for the currently observed controller branch are:
SDLJoystickHandler_API19 -> SDLJoystickHandler_API16 -> SDLJoystickHandler

API16 additionally references its own nested joystick helpers and SDLControllerManager.
The haptic branch is a separate API-dependent candidate:
SDLHapticHandler_API26 -> SDLHapticHandler -> SDLHapticHandler$SDLHaptic

The broader Activity closure includes Surface, generic motion, clipboard, HID, input, and nested Activity classes. These are later/lifecycle candidates, not runtime-proven native-load dependencies.

## False-positive risks
Static references can be present in methods that are never executed, in unused fields, in dead branches, or in compiler-generated classes. SDK-version branches can make many static references conditional.

STATICALLY REFERENCED != RUNTIME-PROVEN

## False-negative risks
Static analysis can miss or understate reflection, dynamically constructed class names, JNI FindClass strings outside the inspected Java files, native callbacks, runtime-generated classes, class-initialization effects, and classloader-specific behavior.

## Known limitations
- Bytecode inspection covered the five SDL class files present in the DEBUG-16A artifact. Candidate class files intentionally not packaged, including SDLJoystickHandler_API19, were source-analyzed.
- The graph represents static reachability, not execution.
- Native/JNI classloader visibility is a runtime question and cannot be established by this static analysis.
- No new Android runtime test was performed for DEBUG-16B.

## Diagnostic / production scope
No diagnostic artifact expansion.
No native payload changes.
No System.load() changes.
No classloader changes.
No production Mindustry source changes.
No Arc source changes.
No SDL source changes.

## Acceptance criteria
- [x] exact SDL 2.32.8 pinned revision verified
- [x] known JNI roots analyzed
- [x] SDLJoystickHandler analyzed
- [x] SDLJoystickHandler_API19 analyzed
- [x] transitive SDL Java references identified where statically discoverable
- [x] reference types classified
- [x] conditional references distinguished
- [x] reflective/JNI references distinguished
- [x] Android framework classes separated from SDL-local dependencies
- [x] runtime-confirmed evidence separated from static predictions
- [x] dependency graph produced
- [x] dependency table produced
- [x] limitations documented
- [x] immutable DEBUG-16B report created
- [x] no diagnostic artifact expansion performed
- [x] no production source modified

## Recommended next experiment
Do not assign a new task ID or package anything solely because of this static graph.
The strongest candidate remains SDLJoystickHandler_API19 because DEBUG-16A already observed it as the next missing class, and the exact pinned source/bytecode independently predicts the API >= 19 path.
Use the real Android result as the authority for the next minimal payload decision.

## Handoff
Status: COMPLETE
Branch: android-jvm
Baseline: 29c93910d5fd4149c0b9ec0bf3e69e0ea52f024d
Commit: documentation-only report commit
Files changed: docs/android-jvm/TASK_03C_DEBUG_16B_STATIC_SDL_DEPENDENCY_ANALYSIS.md
Result: source and bytecode analysis completed against SDL 2.32.8 commit 98d1f3a45aae568ccd6ed5fec179330f47d4d356.
CI: no task-specific build required; no artifact changes.
Build: no production or diagnostic rebuild.
Verification: exact pinned sources inspected; DEBUG-16A packaged bytecode inspected with javap; runtime evidence cross-checked.
Known limitations: static analysis does not establish runtime necessity.
Next task: use DEBUG-16A runtime evidence plus this graph to design the smallest next probe; do not add any dependency based only on static prediction.