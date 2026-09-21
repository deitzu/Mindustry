# TEST_ANDROID_FRAMEWORK_VISIBILITY

## Task

test(android-jvm): probe Android framework visibility

## Status

BLOCKED — deterministic probe implemented and host-validated, but this engineering environment has no ADB-connected Android device or Mojo runtime. The required physical Android visibility result therefore cannot be truthfully recorded here.

## Branch

`android-jvm`

## Baseline

`7ad0c7741ce22ec61ecb1f68f2b5ad57801c1a75`

This is the current remote `android-jvm` HEAD verified before this task.

## Commit

To be filled with the resulting focused commit.

## Objective

Determine why Android framework Java classes are not visible to the Java runtime when Mindustry is launched through the Android-JVM path on a real Android ARM64 device.

The probe is diagnostic only. It does not package `android.jar`, create framework stubs, initialize Android APIs, or modify Mindustry production code.

## Scope

### In scope

- deterministic Android framework Java visibility probe;
- JVM property capture;
- system/context/bootstrap classloader resolution tests;
- classloader hierarchy diagnostics;
- protection-domain/code-source reporting when available;
- host-side compilation/package verification;
- documentation of the physical-runtime limitation and current failure boundary.

### Out of scope

- Android framework compatibility fixes;
- `android.jar` runtime packaging;
- fake `android.*` classes;
- SDL changes;
- GLES/Zink/GL4ES work;
- production launcher/backend changes;
- Arc changes;
- CI configuration changes;
- renderer changes.

## Runtime

Target physical runtime:

- Device: Xiaomi M2004J19C
- Android API: 31
- ABI: arm64-v8a / AArch64
- Launcher/runtime: Mojo `justicia-20260910-[7e5e21b]-v3_openjdk`
- Working directory previously observed by the launcher:
  `/storage/emulated/0/Android/data/git.artdeell.mjlaunch/files/instances/mindustry`

The physical device is not connected to this engineering environment.

## Current failure

The active runtime failure supplied for this task is:

```text
[E] java.lang.ExceptionInInitializerError

Caused by:
arc.util.ArcRuntimeException:
Couldn't load shared library 'sdl-arc'
for target: Linux, 64-bit

Caused by:
java.lang.NoClassDefFoundError:
android/media/AudioDeviceCallback

Caused by:
java.lang.ClassNotFoundException:
android.media.AudioDeviceCallback
```

Earlier runtime stages have already been crossed: the Android ARM64 native resource was extracted and `System.load()` reached SDL Android Java/JNI initialization; `org/libsdl/app/SDLControllerManager` is no longer the missing class.

## Existing project context

The remote `android-jvm` branch already contains the historical SDL Java-glue packaging work. Its DEBUG-14 report records CI/package completion but explicitly leaves real-device Android framework visibility unverified.

The supplied `/mnt/data/PROJECT_HANDOFF.md` is from the separate historical `audit/task-01-native-artifact` branch and is not expected on `android-jvm`. The branch-local reports and actual remote Git state are therefore used for current-state context.

Pinned dependencies remain:

- Arc: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- SDL: `2.32.8`
- SDL source commit: `98d1f3a45aae568ccd6ed5fec179330f47d4d356`

No production workaround was added by this task.

## Probe implementation

New file:

`scripts/android-jvm/android-framework-visibility-probe.sh`

The script:

1. derives the repository root from the script's own location;
2. creates a temporary Java source file;
3. compiles the probe as Java 8 bytecode with `javac`;
4. packages only `androidjvm/probe/AndroidFrameworkVisibilityProbe.class` into a standalone JAR;
5. verifies that no `android/*`, `java/*`, or `javax/*` package is bundled;
6. prints the JAR path and SHA-256;
7. prints the exact `java -jar` form intended for the Android JVM runtime.

The probe itself resolves classes only by name with:

```java
Class.forName(className, false, classLoader)
```

No Android class is intentionally initialized.

## Classes tested

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

## Classloaders tested

For every class, the probe tests:

1. `ClassLoader.getSystemClassLoader()`
2. `Thread.currentThread().getContextClassLoader()`
3. bootstrap lookup through `Class.forName(className, false, null)`

It also records the probe classloader and parent hierarchy.

For successful resolutions, it records:

- resolved classloader class;
- resolved classloader value;
- `ProtectionDomain` code source when available;
- class resource URL when available;
- loader resource URL when available.

For failed resolutions, it records:

- attempted loader;
- `SUCCESS`, `NOT_FOUND`, or `ERROR`;
- exact exception type;
- exact exception message.

## JVM properties captured

Exactly the requested focused properties are printed:

```text
java.version
java.runtime.name
java.vm.vendor
java.vm.name
os.name
os.arch
sun.arch.data.model
java.class.path
java.boot.class.path
java.library.path
java.io.tmpdir
user.dir
```

No broad environment dump is performed.

## Build/test commands

A local Git checkout was not available in the execution environment. A shallow clone of the remote repository was attempted and failed because GitHub DNS/network access was unavailable. The remote branch/file state was therefore inspected through the GitHub repository interface.

Host-side probe validation performed:

```text
scripts/android-jvm/android-framework-visibility-probe.sh
```

The script successfully:

- compiled the probe;
- created the JAR;
- verified the JAR contents;
- produced a SHA-256.

The generated JAR was also executed with the container's Debian OpenJDK 21.0.11. That execution is **not Android evidence**.

Host artifact:

```text
Mindustry-android-jvm-framework-visibility-probe.jar
SHA-256:
01856e1fd73bf7f4eed3b11dfe2fb5e50c7c4984deb66d92e48574c4ae9e8064
```

The host negative control reported `NOT_FOUND` for the nine Android classes across SYSTEM, CONTEXT, and BOOTSTRAP. This validates the probe's failure-reporting path only.

## Actual Android output

**Not available in this engineering environment.**

There is no ADB binary/device connection exposed here, and no Mojo Android runtime session is available to execute the probe directly.

The only physical Android evidence currently available is the supplied Mindustry failure above, which proves at least this one class is unresolved:

```text
android.media.AudioDeviceCallback
```

The probe has not yet established whether the remaining eight classes are similarly unresolved, are visible through another loader, or fail for a different linkage reason.

## Evidence classification

### Confirmed by source

- The active Android-JVM path reaches SDL Android Java code.
- SDL Android Java code references Android framework APIs including `android.media.AudioDeviceCallback`, `AudioDeviceInfo`, `AudioManager`, `Context`, `Build`, and related APIs.
- The Android-JVM packaging task uses `android.jar` as a compile-time API-definition source for SDL Java glue rather than as a runtime framework.

### Confirmed by Android runtime

- The current Mindustry run fails while resolving `android.media.AudioDeviceCallback`.
- The exception chain contains `NoClassDefFoundError` followed by `ClassNotFoundException` for that class.
- Native SDL loading had already reached Java/JNI initialization before this failure.

### Confirmed by artifact/build validation

- The new probe packages only its own probe class and does not bundle Android framework classes.
- The probe JAR can be compiled and launched by a normal Java 21 host runtime.
- The probe records the requested JVM properties and classloader diagnostics.

### Inference

The current failure is consistent with the Android framework namespace not being exposed to the JVM lookup path used by SDL Java code. The exact mechanism is not yet proven.

Possible mechanisms remain:

- framework classes are absent from the tested classloader paths;
- Android framework classes exist behind a runtime-specific loader not reached by the tested loaders;
- bootclasspath/classloader integration is incomplete for this Android OpenJDK environment;
- the launcher exposes native Android functionality without exposing the framework Java API namespace to ordinary JVM class resolution.

### Unknown

- Whether any of the nine selected framework classes are visible on the real Android JVM.
- Whether Android framework classes are visible through bootstrap lookup, system loader, context loader, or another loader.
- Whether a special Android runtime bridge/classloader exists and is reachable from application code.
- Whether the missing-class result changes when the probe is launched independently versus inside the Mindustry JAR.

## Interpretation

The evidence does **not** justify the claim that Android framework classes are universally unavailable. It currently proves only one concrete missing class during SDL Java initialization.

The deterministic probe is the next measurement because it separates framework visibility from SDL's own class dependency chain.

The current production-layer conclusion should therefore remain:

```text
Current evidence:
SDL Android Java code is executing.
↓
Android framework class resolution fails for AudioDeviceCallback.
↓
Framework visibility mechanism is unknown.
↓
Run the dedicated probe on the same Mojo Android JVM.
```

No runtime workaround should be selected until the physical probe identifies the actual visibility boundary.

## Files changed

```text
scripts/android-jvm/android-framework-visibility-probe.sh
docs/android-jvm/TEST_ANDROID_FRAMEWORK_VISIBILITY.md
```

No production launcher/backend/Arc/SDL/GLES files were changed.

## Known limitations

- Physical Android ARM64 execution was not possible from this environment.
- The probe has therefore not yet satisfied the physical-device portion of the task's success criteria.
- Host OpenJDK results are deliberately not substituted for Android results.
- The existing Mindustry failure remains the only real-device framework-visibility evidence currently available.

## Next task

Run the generated probe JAR inside the same Mojo `justicia-20260910-[7e5e21b]-v3_openjdk` Android-JVM environment, capture the complete output, then compare the nine class results across SYSTEM, CONTEXT, and BOOTSTRAP.

After that output is available, the next production task should target only the demonstrated framework-visibility boundary. Do not add `android.jar` or framework stubs preemptively.

## Handoff

Status:
BLOCKED — probe implementation complete; physical Android runtime evidence unavailable in this environment.

Branch:
`android-jvm`

Baseline:
`7ad0c7741ce22ec61ecb1f68f2b5ad57801c1a75`

Commit:
To be filled with the resulting focused commit.

Files changed:
- `scripts/android-jvm/android-framework-visibility-probe.sh`
- `docs/android-jvm/TEST_ANDROID_FRAMEWORK_VISIBILITY.md`

Result:
A deterministic standalone probe now tests nine Android framework classes through the system classloader, context classloader, and bootstrap lookup, while recording focused JVM properties, classloader hierarchy, code source, and resource information. Host validation passed. The physical Android result remains unverified.

CI:
No workflow configuration was changed. CI execution of the new standalone probe is not a substitute for Android runtime evidence.

Build:
Host JAR compile/package: PASS. Host runtime sanity check: PASS as a probe-functionality check only, not Android validation.

Verification:
Probe JAR contains only the probe class; no `android/*`, `java/*`, or `javax/*` classes are bundled. Nine required framework classes are explicitly tested.

Known limitations:
No ADB-connected Xiaomi M2004J19C or Mojo runtime is available in this engineering environment, so the requested physical Android output cannot be claimed.

Next task:
Execute the generated probe JAR on the real Android ARM64 Mojo runtime and record all classloader-specific results before selecting any production fix.
