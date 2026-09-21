# TASK 02D DEBUG-01 — Gradle Packaging of Patched Arc Loader

## Status

**IN PROGRESS**

## Objective

Debug the TASK 02D failure where the patched Arc `arc.util.SharedLibraryLoader.class` is produced successfully but is absent from the final Mindustry Android-JVM JAR.

The failure boundary is JAR packaging. Android native loading has not been reached.

## Git State

- Branch: `android-jvm`
- Baseline: `2848b4a82af2e3adf548522062dc697c99665967`
- Result commit: `2f4580dbc944ed0d49b9149c38f1ac70cb6150dd`
- Protected `master`: not modified
- Arc pinned revision: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

## Original Failure

Continuous Build:

- Run: `35550778785`
- Job: `106184998096`
- Failing step: `Package Android-JVM Arc native artifact`

The step successfully completed:

```
./gradlew -PandroidJvm desktop:dist --rerun-tasks --stacktrace
```

Then failed during packaged-class verification:

```
Error: class not found: arc.util.SharedLibraryLoader
```

The Android JVM native-load probe did not execute.

## Evidence

### Confirmed by CI/build

Before packaging, the workflow applied the deterministic Arc loader overlay and verified the Arc SHA remained pinned.

The workflow then executed:

```
./gradlew :Arc:arc-core:classes --rerun-tasks --stacktrace --console=plain
```

and verified:

```
../Arc/arc-core/build/classes/java/main/arc/util/SharedLibraryLoader.class
```

The same later `desktop:dist` invocation rebuilt the local Arc project, including:

- `:Arc:arc-core:compileJava`
- `:Arc:arc-core:classes`
- `:Arc:arc-core:jar`

and completed successfully.

The Android-JVM runtime dependency graph also resolved:

```
com.github.Anuken:arc-core:8eb00ffff0 -> project :Arc:arc-core
com.github.Anuken:natives-android:8eb00ffff0 -> project :Arc:natives:natives-android
```

### Confirmed by source

The parent TASK 02C `desktop:dist` path assembled `configurations.runtimeClasspath` directly and successfully packaged the build.

Pinned Arc `arc-core/build.gradle` packages its compiled class output through its normal Java JAR task.

### Inference

The TASK 02D packaging customization introduced an unnecessary duplicate path:

1. exclude `arc/util/SharedLibraryLoader.class` from runtimeClasspath contents;
2. attempt to inject the class separately from `../Arc/arc-core/build/classes/java/main`.

The class is already produced by the patched Arc `arc-core` JAR that participates in the composite-build dependency graph. Therefore the explicit exclusion was removing the natural packaging source, while the external directory injection was not resulting in the expected JAR entry.

The exact Gradle internal reason why that secondary `from(...)` source did not contribute the class remains **Unknown**.

## Fix

Commit `2f4580dbc944ed0d49b9149c38f1ac70cb6150dd` removes the Android-JVM-specific exclusion/injection block from `desktop/build.gradle`.

The JAR task now uses the normal runtimeClasspath assembly for all builds:

```groovy
from{
    runtimeClasspathContents()
}
```

The existing Android-JVM ABI exclusions for non-arm64 Arc native libraries remain unchanged.

No generated class files or binaries were committed.

## Scope Check

Changed:

- `desktop/build.gradle`

Not changed:

- Arc source in Git
- Arc pinned SHA
- SDL
- renderer
- Android Activity/lifecycle
- Android APK backend
- native ELF files
- `master`

## Verification Status

Current code change is committed.

The new commit has not yet been verified by a completed CI run in this environment. Local clean-build reproduction is unavailable because the runtime environment cannot reach GitHub.

Therefore TASK 02D remains **IN PROGRESS**.

## Next

Run/inspect CI for commit `2f4580dbc944ed0d49b9149c38f1ac70cb6150dd`.

Acceptance sequence:

1. patched Arc loader compiles;
2. `desktop:dist` succeeds;
3. `Mindustry.jar` contains `arc/util/SharedLibraryLoader.class`;
4. packaged class contains Android resource-loading logic;
5. existing Android ARM64 Arc resource remains present;
6. only then execute the Android JVM native-load probe.

Do not classify native loading or JNI initialization from the previous failed run.
