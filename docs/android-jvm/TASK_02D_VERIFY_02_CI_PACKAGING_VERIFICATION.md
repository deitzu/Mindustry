# TASK-02D VERIFY-02 — CI Packaging Verification

## Status

**IN PROGRESS**

This report remains IN PROGRESS until the dedicated verification run on the packaging-fix source state completes and its generated artifacts are directly inspected.

## Branch

**android-jvm**

## Baseline

**64ea7aeecb9f740ab08d7fd7a98583638464e8c6**

## Arc Revision

**8eb00ffff0126d0576c67df46f99b8f6bccd96fe**

## Objective

Prove through actual GitHub Actions execution and direct artifact inspection that the restored normal `runtimeClasspath` packaging path packages the patched Arc:

`arc/util/SharedLibraryLoader.class`

into:

`desktop/build/libs/Mindustry.jar`

while preserving:

`arm64-v8a/libarc.so`

without proceeding into Android runtime loading or changing AndroidJvmLauncher, SDL runtime code, or the native architecture.

## Current Source State

### Confirmed by source

The current `desktop/build.gradle` contains the normal packaging path:

```groovy
from{
    runtimeClasspathContents()
}
```

There is no current `SharedLibraryLoader.class` exclusion and no explicit Arc build-directory injection.

The current branch still contains the historical AndroidJvmLauncher changes from the preceding task history. VERIFY-02 does not modify them.

## Temporary CI Workflow

**Primary temporary workflow path:**

`.github/workflows/android-jvm-task02d-verify.yml`

The standalone temporary workflow was committed, but its push trigger did not produce an executable run through the available GitHub Actions interface. The verifier was subsequently installed as a temporary job in the repository's active `.github/workflows/push.yml` workflow.

**Effective verification job:**

`.github/workflows/push.yml::task02d-verify`

**Trigger:**

push to `android-jvm`

**Purpose:**

Execute the complete TASK-02D packaging evidence chain on an actual Ubuntu GitHub Actions runner.

The temporary verification workflow/job will:

1. verify the branch, Arc pin, and production packaging state;
2. clone Arc into the sibling path used by the project;
3. checkout exactly the pinned Arc SHA;
4. apply the existing deterministic loader patch without committing Arc changes;
5. compile Arc and verify the patched class;
6. build and inspect the generated Arc core JAR;
7. inspect both Gradle dependency resolution and physical runtimeClasspath files;
8. build `-PandroidJvm desktop:dist`;
9. inspect the final Mindustry JAR for the patched loader and ARM64 Arc native resource;
10. inspect patched loader bytecode;
11. inspect `arm64-v8a/libarc.so` ELF metadata and reject forbidden desktop/glibc dependencies;
12. run the established TASK-02C Android-JVM packaging verifier;
13. run the normal `desktop:dist` regression build;
14. upload the resulting verification artifacts.

## Arc Build Evidence

**Pending CI execution.**

Required evidence:

```
../Arc/arc-core/build/classes/java/main/arc/util/SharedLibraryLoader.class
```

must exist after:

```
./gradlew :Arc:arc-core:classes --rerun-tasks --stacktrace --console=plain
```

## Arc JAR Evidence

**Pending CI execution.**

The workflow discovers the actual generated `arc-core*.jar` filename from `../Arc/arc-core/build/libs/`, records it, runs `jar tf`, and requires:

```
arc/util/SharedLibraryLoader.class
```

## RuntimeClasspath Evidence

**Pending CI execution.**

The workflow records:

```
./gradlew -PandroidJvm :desktop:dependencies --configuration runtimeClasspath
./gradlew -PandroidJvm :desktop:dependencyInsight --configuration runtimeClasspath --dependency com.github.Anuken:arc-core
```

and uses a temporary Gradle init script to print every physical resolved runtimeClasspath file.

Expected substitution, to be confirmed by CI:

```
com.github.Anuken:arc-core:8eb00ffff0 -> project :Arc:arc-core
```

The physical resolved Arc artifact path will be recorded rather than inferred.

## Mindustry JAR Evidence

**Pending CI execution.**

Required final artifact:

`desktop/build/libs/Mindustry.jar`

The workflow directly checks its ZIP entries for:

```
arc/util/SharedLibraryLoader.class
arm64-v8a/libarc.so
```

Both checks are hard failures when absent.

## Patched Loader Verification

**Pending CI execution.**

The final JAR is inspected using:

```
javap -classpath desktop/build/libs/Mindustry.jar -c -p arc.util.SharedLibraryLoader
```

The output must contain evidence of the patched implementation:

- `isAndroidRuntime`
- `androidResourcePath`
- `System.load`

## Native Artifact Verification

**Pending CI execution.**

The actual `arm64-v8a/libarc.so` is extracted from the final Mindustry JAR and inspected with the Android NDK LLVM `readelf` where available.

Required artifact facts:

- file exists;
- ELF64;
- AArch64;
- actual SONAME recorded;
- actual DT_NEEDED recorded;
- forbidden desktop/glibc dependencies rejected.

The established TASK-02C packaging verifier is also executed against the exact Android-JVM JAR.

## Desktop Regression

**Pending CI execution.**

The workflow runs:

```
./gradlew desktop:dist --rerun-tasks --stacktrace --console=plain
```

without `-PandroidJvm`.

This regression build is executed after Android-JVM packaging verification so it cannot overwrite the artifact being verified before its inspection.

## Result

**Pending.**

A temporary direct-verification step was added to the existing active CI workflow on an isolated packaging-fix verification branch. The current commit is documentation-only and exists to trigger that already-registered job.

No PASS conclusion is permitted before successful GitHub Actions execution and direct artifact inspection.

## Known Limitations

The current ChatGPT runtime has no guaranteed local Mindustry repository shell, so all execution for this task is delegated to GitHub Actions.

No Android runtime load test is part of VERIFY-02.

## Cleanup

**Pending.**

After a successful verification run, the temporary workflow will be removed in a separate cleanup commit. The verification report will preserve the completed CI run and artifact evidence.

## Next Task

Pending verification result.

On PASS:

**TASK-02D RUNTIME-01 — Android JVM native-load probe.**

On FAIL:

Create or continue the next debugging task at the first actual failing verification boundary.
