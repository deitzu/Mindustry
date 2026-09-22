# TASK-02D DEBUG-02 — Arc SharedLibraryLoader Packaging Regression

## Status

**INCONCLUSIVE**

The root cause is identified precisely from the Gradle project-directory semantics and the failing CI dependency graph, but the temporary diagnostic CI run did not reach the packaging stage before this report was finalized. Direct physical inspection of the resolved Arc JAR path and Jar task input visitation is therefore not available from a completed run.

## Branch

**android-jvm**

## Baseline

**64ea7aeecb9f740ab08d7fd7a98583638464e8c6**

The baseline is the last proven stable baseline specified for this task. Commit `a648693ea7` was not treated as stable.

## Arc Revision

**8eb00ffff0126d0576c67df46f99b8f6bccd96fe**

The Arc SHA was verified in the failing CI run after applying the loader overlay.

## Objective

Identify the exact boundary at which the patched `arc/util/SharedLibraryLoader.class` is lost between the patched Arc source/build output and `desktop/build/libs/Mindustry.jar`, without implementing a production workaround.

## Symptom

The patched Arc class is produced successfully during the Android-JVM build, and `:desktop:dist` succeeds, but the resulting `desktop/build/libs/Mindustry.jar` does not contain:

`arc/util/SharedLibraryLoader.class`

The failing CI verification was:

```
./gradlew -PandroidJvm desktop:dist --rerun-tasks --stacktrace
javap -classpath desktop/build/libs/Mindustry.jar -c -p arc.util.SharedLibraryLoader
```

The JAR task completed successfully, followed by:

```
Error: class not found: arc.util.SharedLibraryLoader
```

## Investigation

### Initial repository state

The required local commands were attempted in the provided runtime:

```
git status --short
git branch --show-current
git rev-parse HEAD
git log --oneline -5
```

The provided runtime does not contain the Git repository, so Git returned:

```
fatal: not a git repository (or any of the parent directories): .git
```

No local user work was reset, discarded, rebased, or force-pushed.

The GitHub branch `android-jvm` was then inspected directly. Its pre-diagnostic head was:

`a648693ea7a045676fcfa582613587440f1f5675`

### Failing CI build

CI run **35550778785**, job **106184998096**, executed the deterministic Arc overlay and verified the Arc SHA remained:

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

The build then ran:

```
./gradlew :Arc:arc-core:classes --rerun-tasks --stacktrace --console=plain
```

and explicitly checked:

```
../Arc/arc-core/build/classes/java/main/arc/util/SharedLibraryLoader.class
```

The check succeeded. `javap` also confirmed the patched loader contains the Android-JVM-specific methods/strings.

The same build subsequently executed:

```
:Arc:arc-core:compileJava
:Arc:arc-core:classes
:Arc:arc-core:jar
```

all successfully.

### Composite-build dependency resolution

The CI dependency report for `:desktop:runtimeClasspath` contained:

```
com.github.Anuken:arc-core:8eb00ffff0 -> project :Arc:arc-core
```

and similarly resolved Arc native modules to local `:Arc` projects.

This establishes that the Android-JVM runtime classpath was using the included local Arc composite build, not a Maven/JitPack artifact.

`settings.gradle` includes:

```
includeBuild("../Arc")
```

from the Mindustry root project when the sibling Arc checkout exists. The root project's `build.gradle` also selects local Arc coordinates when that checkout exists.

### Packaging change that introduced the regression

The failing TASK-02D packaging commit changed `desktop/build.gradle` from the normal runtime-classpath assembly to:

```
from{
    runtimeClasspathContents()
}{
    exclude("arc/util/SharedLibraryLoader.class")
}
from("../Arc/arc-core/build/classes/java/main"){
    include("arc/util/SharedLibraryLoader.class")
}
```

while retaining:

```
duplicatesStrategy = DuplicatesStrategy.EXCLUDE
```

The previous normal packaging path did not perform this exclusion/injection pair.

### Exact path error

This is the decisive boundary.

`desktop/build.gradle` is evaluated for the Gradle project `:desktop`. Gradle documents that relative file paths are resolved relative to the **current project directory**, not the root project directory. citeturn793975search0turn793975search1

The `:desktop` project directory is the Mindustry `desktop/` directory, because `settings.gradle` includes `desktop` as a normal child project.

Therefore this expression in `desktop/build.gradle`:

```
../Arc/arc-core/build/classes/java/main
```

resolves to:

```
<workspace>/Mindustry/desktop/../Arc/arc-core/build/classes/java/main
```

which is:

```
<workspace>/Mindustry/Arc/arc-core/build/classes/java/main
```

The actual Arc checkout used by CI is the **sibling** directory:

```
<workspace>/Arc/arc-core/build/classes/java/main
```

as shown by the successful CI loader check using:

```
$GITHUB_WORKSPACE/../Arc/arc-core/build/classes/java/main
```

So the explicit second `from(...)` source in the failing TASK-02D block points at the wrong filesystem location and cannot contribute the patched class.

At the same time, the first `from(runtimeClasspathContents())` source explicitly excludes `arc/util/SharedLibraryLoader.class`.

The result is deterministic:

```
local Arc project output
        |
        +--> runtimeClasspath -> valid Arc project output
        |                       |
        |                       +--> SharedLibraryLoader.class
        |                       +--> EXCLUDED by TASK-02D packaging block
        |
        +--> explicit ../Arc/... injection
                                |
                                +--> resolves under :desktop project directory
                                +--> <Mindustry>/Arc/...
                                +--> not the sibling <workspace>/Arc/...
                                +--> contributes no loader class
```

The class is therefore absent from the packaging source before successful Jar creation can include it.

### Temporary diagnostic instrumentation

A temporary diagnostic-only commit was created:

`f9e9b31e91bbdaed0ab55fba9841723eda0464d4`

It added instrumentation to:

- print resolved `:desktop:runtimeClasspath` files and whether they contain `SharedLibraryLoader.class`;
- inspect `../Arc/arc-core/build/libs/arc-core*.jar`;
- print the resolved `file("../Arc/...")` absolute path;
- reproduce the old TASK-02D exclusion/injection packaging with both `EXCLUDE` and `INCLUDE`;
- print `:desktop:dist` source entries containing `SharedLibraryLoader.class`.

The resulting CI run was **35565397536**. At the time this report was finalized, the build had not reached the packaging step, so its downloadable job log was not available. This instrumentation was removed again before the final debug commit.

## Evidence Chain

### Source

**Confirmed by source**

`ci/android-jvm/task02d-arc-shared-library-loader.patch` modifies `arc/util/SharedLibraryLoader.java` to add Android-JVM runtime detection and ARM64 resource loading.

### Compile output

**Confirmed by CI/build**

The patched class was explicitly checked at:

```
../Arc/arc-core/build/classes/java/main/arc/util/SharedLibraryLoader.class
```

and the check passed after `:Arc:arc-core:classes`.

### Arc JAR

**Partially confirmed**

`:Arc:arc-core:jar` completed successfully after the patched class was compiled.

A completed CI artifact containing the physical `arc-core*.jar` was not published by the failing run, so a direct `jar tf`/ZIP-entry inspection of that exact generated JAR is **UNKNOWN**.

### runtimeClasspath

**Confirmed by CI/build**

The runtime dependency graph resolved:

```
com.github.Anuken:arc-core:8eb00ffff0 -> project :Arc:arc-core
```

This confirms composite-build/project resolution rather than a stale Maven/JitPack Arc artifact.

The exact physical file path selected for the resolved `:Arc:arc-core` runtime artifact was not emitted by the completed failing run, so that physical path is **UNKNOWN**.

### Jar task inputs

**Root cause boundary identified; direct input visitation is UNKNOWN**

The failing packaging block excludes the loader class from the runtimeClasspath source and then references a path that resolves incorrectly from `:desktop`.

The temporary `source.visit` diagnostic intended to print the exact Jar inputs did not complete in CI before this report was finalized.

### Final JAR

**Confirmed by CI/build**

`:desktop:dist` succeeded, but:

```
javap -classpath desktop/build/libs/Mindustry.jar -c -p arc.util.SharedLibraryLoader
```

failed with:

```
Error: class not found: arc.util.SharedLibraryLoader
```

This directly proves the final JAR lacked the class.

## Root Cause

**The TASK-02D packaging block excludes `arc/util/SharedLibraryLoader.class` from the valid composite-build `:Arc:arc-core` runtimeClasspath input, then attempts to re-add it from `../Arc/arc-core/build/classes/java/main`; because that relative path is evaluated from the `:desktop` project directory, it resolves to `<workspace>/Mindustry/Arc/... ` instead of the actual sibling Arc checkout `<workspace>/Arc/...`, so the replacement source contributes no class and the final Mindustry JAR contains no `SharedLibraryLoader.class`.**

## Rejected Hypotheses

### Stale or cached Arc Maven artifact

**Disproven.**

CI dependency resolution showed:

```
com.github.Anuken:arc-core:8eb00ffff0 -> project :Arc:arc-core
```

so the runtime dependency was substituted by the local included Arc project.

### Arc compile failure

**Disproven.**

The patched Arc loader class existed in the expected Arc compile output and `:Arc:arc-core:compileJava`, `:Arc:arc-core:classes`, and `:Arc:arc-core:jar` all completed successfully.

### Composite-build substitution selecting the wrong module

**Disproven as the primary failure.**

Composite substitution selected the intended local `:Arc:arc-core` project. The defect was introduced after that resolution by the TASK-02D exclusion/injection packaging customization.

### `DuplicatesStrategy.EXCLUDE` as the primary cause

**Disproven as the standalone cause.**

The class was deliberately excluded from the runtimeClasspath source before duplicate handling could preserve it. The second source then pointed to the wrong filesystem location. `DuplicatesStrategy.EXCLUDE` was therefore not the reason the valid class disappeared; the exclusion plus invalid replacement path was.

### Class disappearing inside Gradle Jar assembly after being present in its inputs

**Not established.**

The available completed CI run proves the class is absent from the final JAR and identifies the invalid replacement source, but a completed direct Jar-input visitation trace was not available.

## Changes Made

### Production files changed

**None in the final state.**

### Diagnostic files changed

A temporary diagnostic block was added to:

`desktop/build.gradle`

in commit:

`f9e9b31e91bbdaed0ab55fba9841723eda0464d4`

The block was removed before the final debug commit.

### Temporary files used

No temporary production artifacts or manual class-copying files were created.

## Verification

- Patched `SharedLibraryLoader.class` compilation: **PASS** in CI run 35550778785.
- Patched Arc loader bytecode inspection: **PASS** in CI run 35550778785.
- Arc `arc-core` JAR task: **PASS** in CI run 35550778785.
- `:desktop:runtimeClasspath` Arc resolution: **PASS**, resolved to `:Arc:arc-core`.
- Final `Mindustry.jar` loader presence: **FAIL**, class not found by `javap`.
- Direct physical inspection of generated `arc-core*.jar`: **UNKNOWN**.
- Direct completed Jar-input visitation trace: **UNKNOWN**.

## Known Limitations

The provided runtime has no local Mindustry Git checkout, so the required pre-change Git commands could not inspect local working-tree dirtiness.

The temporary diagnostic CI run 35565397536 had not reached the packaging stage when this report was finalized. Therefore the exact physical `:desktop:runtimeClasspath` file path and the live Jar input enumeration were not captured from that diagnostic run.

These gaps do not change the identified path-resolution root cause, which is established by the `:desktop` project location, the relative path in the failing packaging block, the actual sibling Arc checkout path used by CI, and the confirmed local composite dependency resolution.

## Recommended Minimal Fix

Do not reintroduce the TASK-02D exclusion/injection block.

The smallest production change indicated by the evidence is to retain the normal runtimeClasspath assembly already restored by commit:

`2f4580dbc944ed0d49b9149c38f1ac70cb6150dd`

That path consumes the locally substituted `:Arc:arc-core` output without excluding `SharedLibraryLoader.class`.

No manual class copying or arbitrary filesystem injection is justified.

## Next Task

Run a clean CI verification of the restored normal packaging path, specifically:

1. `:Arc:arc-core:classes` with the loader overlay.
2. `:Arc:arc-core:jar` and direct `jar tf` verification of `SharedLibraryLoader.class`.
3. `:desktop:runtimeClasspath` physical artifact inspection.
4. `:desktop:dist`.
5. Direct inspection of `desktop/build/libs/Mindustry.jar` for the patched loader.
6. Only after that, continue to the Android JVM native-load probe.

Do not modify AndroidJvmLauncher or native/SDL production code as part of that verification.
