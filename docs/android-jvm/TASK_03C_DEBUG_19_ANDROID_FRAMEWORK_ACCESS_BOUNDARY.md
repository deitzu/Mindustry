# TASK_03C_DEBUG_19 — Android Framework Access Boundary

## Status

COMPLETE — architectural boundary identified from real Android runtime evidence plus targeted source inspection of Mindustry, pinned SDL 2.32.8, and MojoLauncher `v3_openjdk`.

No Mindustry production code, Arc source, SDL source, or runtime workaround was changed.

## Branch

`android-jvm`

## Baseline

`b2018bb4541a020ebf74260ffbdc93364d8ca051`

The task prompt expected `e61228a3fef2e8854c56990fab094f87f71c83dc`, but the actual remote `android-jvm` branch had already advanced to `b2018bb4541a020ebf74260ffbdc93364d8ca051). The actual repository state was used.

## Result commit

Documentation-only commit for this report.

## Pinned dependencies

Arc:

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

SDL:

- version: `2.32.8`
- source commit: `98d1f3a45aae568ccd6ed5fec179330f47d4d356`

Mojo source inspected:

- repository: `MojoLauncher/MojoLauncher`
- branch: `v3_openjdk`
- source tree observed: `4ac5b23362ac2105e816f5fe9475379e53995ee5`
- exact installed Mojo binary/revision on the physical test device: UNKNOWN

## Objective

Determine where the Android framework boundary exists between the Android host application/runtime and the separately created OpenJDK JVM used to execute Mindustry, and identify the smallest legitimate path to real Android framework access.

## Scope

### In scope

- real Android framework visibility evidence;
- Mindustry launcher/source inspection;
- SDL Android Java dependency inspection;
- Mojo secondary-JVM startup inspection;
- JNI/classloader/native-hook boundary analysis;
- candidate architecture evaluation;
- smallest next implementation experiment.

### Out of scope

- production classloader workaround;
- Android framework stubs;
- bundling `android.jar`;
- SDL redesign;
- GLES/Zink/GL4ES work;
- Arc revision changes;
- direct modification of pinned Arc;
- production Mindustry runtime changes;
- modifying MojoLauncher as part of this task.

## Repository state verification

A local Mindustry Git checkout was not exposed in the execution environment, so the requested local commands could not be executed against a filesystem repository.

The remote repository state was instead verified through GitHub:

- branch `android-jvm` exists;
- HEAD before this task was `b2018bb4541a020ebf74260ffbdc93364d8ca051`;
- the task baseline contains the previously published framework visibility probe;
- no existing `DEBUG_19` framework-boundary report was present.

The pinned Arc revision remains the project-required value.

## Current Android runtime evidence

### Confirmed by Android runtime

The standalone framework visibility probe was executed in the real Mojo Android-JVM runtime.

Runtime:

- Device: Xiaomi M2004J19C
- Android API: 31
- ABI: arm64-v8a / AArch64
- JVM vendor: Oracle Corporation
- JVM: OpenJDK 64-Bit Server VM
- Java version: `1.8.0_512-internal`
- `os.name=Linux`
- `os.arch=aarch64`
- `sun.arch.data.model=64`
- `java.class.path=/data/user/0/git.artdeell.mjlaunch/cache/mod-installer-temp`
- `java.boot.class.path=null`

All inspected application-side classloaders were:

`sun.misc.Launcher$AppClassLoader`

System and context classloaders were identical.

Bootstrap lookup was:

`<bootstrap/null>`

All nine selected Android framework classes were `NOT_FOUND` through all three tested lookup paths:

```text
android.media.AudioDeviceCallback
android.media.AudioDeviceInfo
android.media.AudioManager
android.content.Context
android.app.Activity
android.os.Build
android.os.Environment
android.view.View
android.content.res.AssetManager
```

Every failure was a `ClassNotFoundException`.

This is stronger than the original single-class failure because the same result occurs across media, application/context, OS, UI, and asset framework namespaces.

The original Mindustry failure remains:

```text
java.lang.NoClassDefFoundError:
android/media/AudioDeviceCallback

Caused by:
java.lang.ClassNotFoundException:
android.media.AudioDeviceCallback
```

## Root cause

### A. Root cause

The current Mindustry execution is running inside a separately created OpenJDK JVM whose application classpath/classloader universe is not the Android ART framework runtime. Mojo explicitly creates this secondary JVM with its own VM initialization arguments and application classpath, then invokes Mindustry's main class through the secondary VM's own `JNIEnv`.

The inspected Mojo source provides no framework-class delegation from that secondary JVM into the host Android ART classloader.

Therefore the immediate Android framework failure is an **inter-runtime Java class visibility boundary**, not an ordinary Mindustry classloader search-path problem.

A Mindustry-side classloader cannot manufacture access to Android's actual framework implementations when those implementations belong to the host Android runtime and no supported bridge exposes them to the secondary VM.

This conclusion is an architectural inference from the combination of:

1. complete real-device failure of the selected Android framework class set;
2. explicit secondary-JVM creation;
3. explicit secondary-JVM classpath construction;
4. separate secondary `JNIEnv`;
5. absence of a framework delegation bridge in the examined Mojo JVM startup path.

## Evidence table

| Finding | Classification | Evidence |
|---|---|---|
| All 9 selected Android framework classes fail through SYSTEM, CONTEXT, and BOOTSTRAP lookup on the physical device. | Confirmed by Android runtime | Framework visibility probe output |
| System and context loaders are both `sun.misc.Launcher$AppClassLoader`. | Confirmed by Android runtime | Framework visibility probe output |
| `java.boot.class.path=null` on the tested runtime. | Confirmed by Android runtime | Framework visibility probe output |
| Mojo's JavaRunner constructs an explicit `-Djava.class.path=` from the game classpath entries. | Confirmed by source | MojoLauncher `JavaRunner.java` |
| Mojo starts the selected OpenJDK using `JNI_CreateJavaVM`. | Confirmed by source | MojoLauncher `jre_launcher.c` |
| Mojo receives a new `JNIEnv *vm_env` from `JNI_CreateJavaVM` and uses that environment to find and invoke the application's main class. | Confirmed by source | MojoLauncher `jre_launcher.c` |
| Mojo's `ClassLoader` hook replaces native library loading methods such as Java 8 `ClassLoader$NativeLibrary.load` / newer `NativeLibraries.load`. | Confirmed by source | MojoLauncher `native_library_hook.c` |
| The native library hook adjusts/preloads native libraries and does not implement Java framework class delegation. | Confirmed by source | MojoLauncher `native_library_hook.c` |
| Mojo retains an Android `Context` in `abort_wait.c` for exit handling. | Confirmed by source | MojoLauncher `abort_wait.c` |
| That retained Context is used with the host JVM's `JavaVM *` stored by `GetJavaVM`, not exposed as a Context object to the secondary OpenJDK VM. | Confirmed by source | MojoLauncher `abort_wait.c` |
| SDL Android Java code genuinely requires real Android framework APIs and Context/Activity semantics. | Confirmed by source | SDL 2.32.8 Android Java sources |
| The secondary OpenJDK VM has no demonstrated standard classloader path to ART's framework implementation classes. | Inference | Runtime matrix + Mojo source |
| A Mindustry-only classloader change is insufficient without an external bridge or actual framework class implementation supplied to the secondary VM. | Inference | Runtime matrix + Mojo VM boundary |
| The exact installed Mojo binary revision matches the currently inspected `v3_openjdk` source. | Unknown | Physical device build provenance not emitted by the probe |

## Architecture diagram

The evidence-supported architecture is:

```text
Android application / ART
        |
        | host JavaVM / host JNIEnv
        |
        +-----------------------------+
        |                             |
        | host Android APIs            | native launcher
        v                             v
Android Context / Activity       Mojo jre_launcher
                                      |
                                      | dlopen(libjvm.so)
                                      | dlsym(JNI_CreateJavaVM)
                                      v
                              Secondary OpenJDK JVM
                                      |
                                      | its own JNIEnv
                                      v
                              AppClassLoader
                                      |
                                      +-- Mindustry JAR/classes
                                      +-- normal JVM/JDK classes
                                      |
                                      +-- Android framework classes
                                              NOT_FOUND
                                              for tested loaders
```

The critical boundary is therefore:

```text
Host ART Android runtime
        X
Secondary OpenJDK classloader universe
```

The `X` is not a proven native-library failure. Native library loading is already handled by a separate Mojo mechanism.

## 1. Is Mindustry-side classloader manipulation sufficient?

No, not by itself.

### Confirmed by Android runtime

The secondary JVM cannot resolve any of the tested framework classes through:

- system classloader;
- context classloader;
- bootstrap lookup.

### Confirmed by source

Mindustry's Android-JVM launcher is ordinary application code. The current `AndroidJvmLauncher` initializes Arc/Mindustry services and constructs `SdlApplication`; it does not possess an Android ART classloader or a host Android `Context` object that belongs to the secondary VM.

The production SDL Java glue is likewise compiled as ordinary Java classes for the Android-JVM JAR.

### Inference

A custom Mindustry `ClassLoader` could only help if the underlying runtime supplied one of:

- framework class bytes that are valid and meaningful to the OpenJDK VM;
- a supported delegation mechanism into the host Android runtime;
- a native/service bridge that replaces framework object operations.

None of those are supplied by ordinary classloader manipulation.

Simply pointing a custom loader at another path does not make an ART framework class become a class belonging to the OpenJDK VM.

## 2. Does Mojo expose a supported bridge?

### Confirmed by source

The inspected `v3_openjdk` JVM startup path has these relevant pieces:

### `JavaRunner.java`

Mojo:

1. selects the JRE runtime home;
2. builds JVM arguments;
3. explicitly constructs `-Djava.class.path=` from application JAR paths;
4. transfers the arguments to native code;
5. calls `nativeLoadJVM(...)`.

The Java 8 Caciocavallo path can also construct an `-Xbootclasspath/p` option, but that is used for Caciocavallo AWT compatibility JARs, not Android framework implementation access.

### `jre_launcher.c`

Mojo:

1. loads `libjvm.so);
2. obtains `JNI_CreateJavaVM`;
3. supplies `JavaVMInitArgs`;
4. receives a new `JavaVM` and `JNIEnv *vm_env`;
5. optionally installs native library hooks;
6. converts application arguments;
7. calls `FindClass` and `GetStaticMethodID` through the secondary VM's `vm_env`;
8. invokes the application main method.

### `native_library_hook.c`

Mojo's classloader hook is specifically attached to native library loading:

- Java 8: `java/lang/ClassLoader$NativeLibrary`
- newer Java: `jdk/internal/loader/NativeLibraries`

The replacement methods call through to native-library loading and Android ELF-hinting logic.

This mechanism is therefore:

```text
ClassLoader hook
-> native library load
```

not:

```text
ClassLoader hook
-> Android ART Java framework delegation
```

### `abort_wait.c`

Mojo does have one explicit host-Android-object bridge:

```text
nativeSetupExit(Context context)
        |
        v
host JavaVM stored with GetJavaVM()
        |
        v
GlobalRef(Context)
        |
        v
ExitActivity.showExitMessage(Context, ...)
```

This is important because it proves that the launcher can retain/use Android objects on the **host ART VM**.

It does not expose that Context to the secondary OpenJDK VM.

### Conclusion

No supported Android framework Java bridge was found in the inspected Mojo JVM-startup/native-hook path.

The exact installed device binary may differ from the inspected source revision, so this conclusion is limited to the examined source revision plus the real-device runtime behavior.

## 3. Can Android framework classes be made available through a legitimate JVM mechanism?

The possibilities are:

### Bootclasspath provisioning

**Feasibility:** limited for actual Android framework implementations.

The standard JVM Invocation API allows startup options, including classpath-related options. Mojo already passes such options to `JNI_CreateJavaVM`. citeturn175128search0turn175128search1

However, Android framework implementation classes belong to Android's platform/ART boot-classpath environment rather than being ordinary application JAR classes. AOSP documents Android boot-classpath artifacts separately from ordinary secondary application dex/JAR loading. citeturn175128search3turn175128search7

The tested OpenJDK runtime reports `java.boot.class.path=null`, and all selected framework classes remain unresolved.

Using SDK `android.jar` as a runtime bootclasspath replacement is not a legitimate solution here: the project explicitly treats it as a compile-time API definition source, and SDK stubs are not the Android runtime implementation used by ART.

**Required layer:** Mojo/JVM startup, plus a real compatible framework implementation mechanism.

**Mindustry-only:** no.

**Object identity:** would not become valid Android ART object identity merely by supplying class definitions.

**Callbacks:** not solved.

### Custom classloader delegation

**Feasibility:** only with a real external bridge.

A secondary-JVM classloader cannot directly return an Android ART `Class` or `Context` as though it belonged to the OpenJDK VM.

**Required layer:** Mojo/native host bridge and secondary-VM bridge classes.

**Mindustry-only:** no.

**Object identity:** not preservable across the two VM object spaces by ordinary Java delegation.

**Callbacks:** require explicit forwarding.

### Native/JNI bridge

**Feasibility:** technically plausible and consistent with the observed launcher architecture.

The host Android side can retain a real host `Context` and invoke Android APIs using the host ART JNI environment. A secondary-JVM native call can then communicate with that host-side service and return primitive/data results to the OpenJDK VM.

The existing `abort_wait.c` pattern proves that Mojo can retain host Android objects and invoke host Android Java methods through a stored host `JavaVM *`. It does not yet prove a general-purpose secondary-to-host service bridge.

**Required layer:** Mojo native launcher plus a secondary-JVM-facing bridge API.

**Mindustry-only:** no.

**Object identity:** no, not for direct `Context`, `Activity`, `View`, etc. Those objects remain host-ART objects.

**Callbacks:** possible, but must be explicitly marshalled from host Android to secondary JVM as events/data.

### Generated Java facade over Android APIs

**Feasibility:** plausible only as the Java half of a native/host bridge.

A facade in the secondary JVM could expose familiar operations to SDL/Mindustry, but its methods would need to forward into Mojo/native code, which would then execute the actual Android API calls in host ART.

**Required layer:** Mojo-side host bridge plus secondary-JVM facade.

**Mindustry-only:** no, unless the bridge already exists.

**Object identity:** facade objects would be proxy/data objects, not ART framework objects.

**Callbacks:** explicit forwarding required.

### Launcher-side Java service bridge

**Feasibility:** plausible and arguably the cleanest architectural separation.

The host Android launcher already owns the real `Activity`/Context and Android lifecycle. A service bridge could expose only the Android operations needed by the secondary JVM and keep all actual framework interaction on the Android host side.

This is a design direction, not a completed implementation.

**Required layer:** MojoLauncher.

**Mindustry-only:** no.

**Object identity:** proxy/data semantics.

**Callbacks:** explicitly designed host-to-secondary event path.

### Arc-side framework bridge

**Feasibility:** Arc can define the abstraction consumed by SDL/backend code, but Arc cannot itself obtain an ART framework object that is invisible to the secondary VM.

An Arc-side change therefore becomes useful only after an external Android host bridge exists.

**Required layer:** Mojo bridge first, then possibly Arc abstraction.

**Mindustry-only:** no.

**Object identity:** same cross-VM limitation.

**Callbacks:** must still cross the host bridge.

## 4. Minimum Android API surface

The immediate `AudioDeviceCallback` failure is not an isolated symbol requirement.

### Confirmed by SDL 2.32.8 source

`SDLAudioManager` uses Android framework types including:

- `android.content.Context`
- `android.media.AudioDeviceCallback`
- `android.media.AudioDeviceInfo`
- `android.media.AudioManager`
- `android.media.AudioFormat`
- `android.media.AudioRecord`
- `android.media.AudioTrack`
- `android.media.MediaRecorder`
- `android.os.Build`
- `android.os.Process`
- `android.util.Log`

Its real audio path stores a Context, obtains `AudioManager` through `Context.getSystemService(...)`, creates/uses an `AudioDeviceCallback` on API 24+, queries device information, and registers/unregisters callbacks.

Therefore a real audio bridge needs more than class-resolution names. It needs access to an actual host Android Context and real Android audio service behavior.

### Confirmed by SDL 2.32.8 source

The broader `SDLActivity` implementation extends `android.app.Activity` and uses a significantly wider Android API surface, including:

- Context/Activity;
- View/ViewGroup;
- Surface and window APIs;
- input devices and key events;
- input-method APIs;
- resources/configuration;
- clipboard;
- sensor APIs;
- audio APIs;
- lifecycle callbacks;
- Android application/native-library paths.

The exact pinned SDL source also defines:

```text
SDL.setContext(Context)
SDL.getContext()
```

and the Android Activity setup stores the real Activity as SDL's Context.

### Runtime architecture implication

For the **current audio/JNI blocker**, a narrow host bridge could initially expose:

```text
host Android Context
    |
    +-- AudioManager acquisition
    +-- AudioDeviceInfo query
    +-- AudioDeviceCallback registration
    +-- callback event forwarding
```

For **full SDLActivity behavior**, the bridge must eventually cover UI/window/input/surface/lifecycle semantics. That is a much larger surface and should not be implemented as part of the current diagnostic task.

## Framework Java classes versus native libraries

This distinction is now clear.

### Native library path

Mojo has explicit native-library mechanisms:

```text
secondary JVM
  -> native ClassLoader hook
  -> Android-aware native library loading / ELF hinting
```

That mechanism is about finding/loading native ELF libraries.

### Framework Java path

The Android framework probe shows:

```text
secondary OpenJDK AppClassLoader
  -> Android framework Class.forName()
  -> NOT_FOUND
```

No corresponding framework delegation mechanism was found in the inspected Mojo JVM startup source.

Therefore:

```text
Native visibility != Android framework Java visibility
```

The existing success in extracting/loading `libsdl-arc.so` does not imply access to `android.media.*` or `android.app.*`.

## Answer to the central architectural question

The most defensible current architecture is:

```text
Android ART / Mojo host
        |
        | real Context / Activity / Android services
        v
Host-side Android bridge
        |
        | primitives / DTOs / events / explicit callbacks
        v
Secondary OpenJDK JVM
        |
        +-- Mindustry / Arc / SDL facade
        |
        +-- no direct ART framework object identity
```

A direct “make `android.*` visible to the OpenJDK ClassLoader” approach is not established as feasible from the evidence.

A bridge that keeps real Android framework calls on the host ART side is the path that matches the observed VM separation.

## Recommended next task

### TASK_03C_DEBUG_20 — Minimal Mojo Host-to-Secondary Android Bridge Probe

Do exactly one architecture experiment:

Create a **diagnostic-only Mojo-side bridge** that proves one real Android framework operation can be initiated from the secondary OpenJDK JVM and executed in the host Android runtime.

The smallest useful proof should:

1. retain/use the host Android `Context` on the host ART side;
2. expose one secondary-JVM-facing native entry point;
3. invoke a real Android framework operation through the host ART JNI environment;
4. return only primitive data to the secondary JVM;
5. separately test one host-side callback/event path if needed by the audio operation;
6. avoid changing Mindustry/SDL production code.

The experiment should stop after proving:

```text
secondary OpenJDK call
    -> native bridge
    -> host ART JNI
    -> real Android API
    -> primitive result/event
    -> secondary OpenJDK
```

Do not attempt to expose `android.content.Context` itself to the secondary JVM.

The purpose of this next task is to prove the bridge architecture before designing SDL integration.

## Evidence classification summary

### Confirmed by Android runtime

- All nine selected Android framework classes are unresolved in the tested secondary JVM.
- System and context classloaders are the same AppClassLoader.
- Bootstrap resolution also fails.
- The runtime has `java.boot.class.path=null`.
- The original Mindustry failure is `AudioDeviceCallback` ClassNotFoundException.

### Confirmed by source

- Mojo creates the secondary JVM with `JNI_CreateJavaVM`.
- Mojo explicitly constructs its application classpath.
- The secondary JVM has its own `JNIEnv *vm_env`.
- Mojo's ClassLoader hook is for native library loading.
- Mojo's host exit bridge retains a real Android Context in the host JVM.
- SDL Android Java code requires real Android framework APIs and Context/Activity semantics.
- SDL's audio path requires actual Android audio services and callback behavior.

### Inference

- The framework failure is caused by the boundary between the host Android ART runtime and the secondary OpenJDK JVM.
- A Mindustry-only classloader change cannot provide real ART framework access without an external bridge.
- The most coherent next architecture is host-side Android framework access with a secondary-JVM proxy/data bridge.

### Unknown

- Whether the installed device build exactly matches the inspected Mojo `v3_openjdk` source revision.
- Whether Mojo has an undocumented/framework bridge outside the examined JVM startup/native-hook path.
- Whether a general bridge would be sufficient for all SDLActivity/window/input/lifecycle requirements.
- Exact callback/threading design required to safely forward Android events to the secondary JVM.

## Source references

MojoLauncher:

- `JavaRunner.java`
  https://github.com/MojoLauncher/MojoLauncher/blob/v3_openjdk/app_pojavlauncher/src/main/java/net/kdt/pojavlaunch/utils/jre/JavaRunner.java
- `jre_launcher.c`
  https://github.com/MojoLauncher/MojoLauncher/blob/v3_openjdk/app_pojavlauncher/src/main/jni/jre_launcher/jre_launcher.c
- `native_library_hook.c`
  https://github.com/MojoLauncher/MojoLauncher/blob/v3_openjdk/app_pojavlauncher/src/main/jni/jre_launcher/native_library_hook.c
- `abort_wait.c`
  https://github.com/MojoLauncher/MojoLauncher/blob/v3_openjdk/app_pojavlauncher/src/main/jni/jre_launcher/abort_wait.c

SDL 2.32.8 pinned source:

- `SDL.java`
  https://github.com/libsdl-org/SDL/blob/98d1f3a45aae568ccd6ed5fec179330f47d4d356/android-project/app/src/main/java/org/libsdl/app/SDL.java
- `SDLActivity.java`
  https://github.com/libsdl-org/SDL/blob/98d1f3a45aae568ccd6ed5fec179330f47d4d356/android-project/app/src/main/java/org/libsdl/app/SDLActivity.java
- `SDLAudioManager.java`
  https://github.com/libsdl-org/SDL/blob/98d1f3a45aae568ccd6ed5fec179330f47d4d356/android-project/app/src/main/java/org/libsdl/app/SDLAudioManager.java

Android/OpenJDK runtime references:

- Oracle JNI Invocation API documents `JNI_CreateJavaVM` and VM startup options:
  https://docs.oracle.com/en/java/javase/17/docs/specs/jni/invocation.html
- AOSP ART documentation describes Android boot-classpath artifacts separately from secondary dex/JAR loading:
  https://android.googlesource.com/platform/art/+/android17-release/libartservice/service/README.md
- AOSP build configuration documents the platform boot JAR ordering:
  https://android.googlesource.com/platform/build/+/0d6adcb453e7c3f2b47da7367c2d1498a1ac892e/target/product/default_art_config.mk

## Known limitations

- No local Mindustry repository or ADB-connected device was available to rerun the probe during this analysis.
- The physical framework visibility result was supplied as current runtime evidence from the test device.
- Mojo source inspection targeted the current `v3_openjdk` branch and the JVM startup/native-hook path; the exact installed device binary revision remains unknown.
- No general “supported bridge” API was found in the inspected Mojo source, but absence outside that examined path is not mathematically proven.
- Cross-VM Android object identity and callback semantics require a concrete host-side bridge experiment.

## Handoff

Status:
COMPLETE — architectural boundary identified; no production fix implemented.

Branch:
`android-jvm`

Baseline:
`b2018bb4541a020ebf74260ffbdc93364d8ca051`

Commit:
Documentation-only result commit for this report.

Files changed:
- `docs/android-jvm/TASK_03C_DEBUG_19_ANDROID_FRAMEWORK_ACCESS_BOUNDARY.md`

Android runtime evidence:
All nine selected Android framework classes returned `NOT_FOUND` through SYSTEM, CONTEXT, and BOOTSTRAP on the real Mojo Android-JVM runtime. The tested runtime reports `java.version=1.8.0_512-internal`, `java.class.path=/data/user/0/git.artdeell.mjlaunch/cache/mod-installer-temp`, and `java.boot.class.path=null`.

Source evidence:
Mojo `JavaRunner.java` constructs the secondary JVM's application classpath; `jre_launcher.c` invokes `JNI_CreateJavaVM` and uses a new `JNIEnv *vm_env`; `native_library_hook.c` hooks native library loading rather than Android framework class delegation; `abort_wait.c` demonstrates a host-ART Context bridge used only for exit handling. SDL 2.32.8 source shows real Android Context/Activity/audio/window/input APIs are required.

Root cause:
The Android framework exists on the host Android/ART side, while Mindustry runs inside a separately created OpenJDK JVM with its own classloader universe. No supported framework-class delegation into that secondary VM was found in the examined Mojo startup/native-hook path.

Mindustry-only solution:
Insufficient. A Mindustry ClassLoader cannot directly turn an ART framework implementation or ART object into a class/object owned by the secondary OpenJDK VM.

Mojo-side requirement:
A host-side Android bridge is required for real framework access if the secondary JVM is retained. The bridge should keep actual framework operations on ART and expose proxy/data/event semantics to the secondary JVM.

Result:
The framework visibility problem is an inter-runtime boundary, not a normal JAR/classloader packaging issue. Native-library loading and framework Java visibility are separate mechanisms.

Known limitations:
Exact installed Mojo binary revision is unknown; only the tested runtime and inspected `v3_openjdk` source are claimed. Full SDLActivity/window/input/lifecycle bridge requirements remain unimplemented and unverified.

Next task:
TASK_03C_DEBUG_20 — Minimal Mojo Host-to-Secondary Android Bridge Probe. Prove one real host-ART Android API call, initiated by the secondary JVM and returned as primitive data/events, before touching Mindustry or SDL production integration.
