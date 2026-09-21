# TASK-04-CLEANUP-01 — Remove stale TASK-02D packaging verifier

## Status

**PARTIAL / BLOCKED BY STALE CI VERIFIER**

The requested TASK-02D VERIFY-02 diagnostic block was removed from `desktop/build.gradle`.

The cleanup itself is isolated and buildable, but the current Continuous Build remains blocked by a separate TASK-02D verifier still embedded in `.github/workflows/ci.yml`. That CI-side verifier is outside this task's requested file scope and was not modified.

## Branch

`android-jvm`

## Baseline

`2741f2d9d8a253072fff53b828b451f1d065d4f8`

## Implementation Commit

`929f74ba2d6ae758148bc3b861dca8f6c7f2bffe`

Message:

`chore(android-jvm): remove stale TASK-02D packaging verifier`

## Report Commit

`54455bdf7c7a163b48826d354f231da717a9ff99`

## Arc Revision

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

Confirmed by Continuous Build checkout. The Arc revision remained pinned to the required SHA.

## Objective

Remove only the obsolete TASK-02D VERIFY-02 temporary packaging diagnostic block from `desktop/build.gradle`.

## Scope

### Changed

- `desktop/build.gradle`: removed the obsolete TASK-02D VERIFY-02 diagnostic/verifier block.

### Documentation

- `docs/android-jvm/TASK_04_CLEANUP_01_TASK02D_VERIFIER.md`

### Explicitly not changed

- `AndroidJvmLauncher`
- `SharedLibraryLoader` implementation
- Arc overlay
- `backend-sdl`
- `SDLGL`
- GLES
- native build
- launcher behavior
- `.github/workflows/ci.yml`

## Source Verification

Confirmed by source/diff inspection:

- The cleanup commit changes only `desktop/build.gradle`.
- The diff contains **0 additions / 120 deletions** in that file.
- The deleted region is the exact TASK-02D VERIFY-02 temporary diagnostic block.
- The surrounding `dist` task and following sprite-packing logic remain intact.
- No `TASK-02D VERIFY-02` marker remains in `desktop/build.gradle`.
- The `mainClassName` selection and manifest definition remain unchanged.
- `gradle.properties` still carries the pinned Arc revision via `archash=8eb00ffff0126d0576c67df46f99b8f6bccd96fe`.

## Continuous Build

Workflow:

`.github/workflows/ci.yml`

Workflow name:

`Continuous Build`

Final relevant run before report update:

`35583552079`

Job:

`106281603056` — `Test and build`

Second job:

`106281603280` — `Arc Android ARM64 native probe`

### Result

- Arc Android ARM64 native probe: **PASS**
- Main `Test and build`: **FAIL**
- Failing step: `Package Android-JVM Arc native artifact`

### Important build evidence

The Continuous Build successfully executed:

`./gradlew -PandroidJvm desktop:dist --rerun-tasks --stacktrace`

and Gradle reported:

`BUILD SUCCESSFUL in 1m 19s`

The same build sequence also reached successful:

- `:core:compileJava`
- `:desktop:compileJava`

with no compile failure.

The job failed **after** `:desktop:dist` completed, when the workflow's separate TASK-02D verifier ran:

`javap -classpath desktop/build/libs/Mindustry.jar -c -p arc.util.SharedLibraryLoader`

followed by a check for the patched loader markers.

The exact failure was:

`Packaged Mindustry.jar does not contain patched SharedLibraryLoader`

This is a CI-side verifier failure, not a Gradle packaging failure caused by the requested cleanup.

## Acceptance Matrix

| Acceptance | Result | Evidence |
|---|---|---|
| `:core:compileJava` passes | **PASS** | Successful within the Continuous Build's composite build sequence |
| `:desktop:compileJava` passes | **PASS** | Successful within the Continuous Build's composite build sequence |
| `-PandroidJvm desktop:dist` passes | **PASS** | Exact command completed with `BUILD SUCCESSFUL in 1m 19s` |
| `desktop:dist` normal passes | **NOT REACHED** | Continuous Build stopped before its later normal desktop JAR step |
| Android-JVM JAR Main-Class = `mindustry.androidjvm.AndroidJvmLauncher` | **NOT FRESHLY VERIFIED** | Previously artifact-verified on parent commit `2741f2d`; cleanup does not modify the manifest selector, but current run stopped before a fresh manifest check |
| Normal desktop JAR Main-Class = `mindustry.desktop.DesktopLauncher` | **NOT FRESHLY VERIFIED** | Previously artifact-verified on parent commit `2741f2d`; current run stopped before the normal desktop JAR verification step |
| Arc SHA = `8eb00ffff0126d0576c67df46f99b8f6bccd96fe` | **PASS** | Continuous Build cloned/checked out the exact pinned revision |

## Result

**Cleanup implementation: PASS. Full acceptance: BLOCKED.**

The requested production cleanup is complete and isolated.

The remaining red CI condition is caused by stale verification logic in `.github/workflows/ci.yml`, which still expects the patched `SharedLibraryLoader` to appear in the Mindustry JAR and therefore aborts immediately after the successful Android-JVM `desktop:dist`.

No change was made to that workflow because doing so would exceed the requested scope of this cleanup task.

## Known Limitations

- No Android runtime testing was performed.
- The current Continuous Build is red because of the unrelated/still-stale CI-side TASK-02D packaging verifier.
- A fresh normal desktop JAR manifest check could not be reached in this Continuous Build run.
- The Android-JVM and normal desktop Main-Class values were previously artifact-verified on parent commit `2741f2d9d8a253072fff53b828b451f1d065d4f8`; this cleanup does not alter the relevant Gradle manifest logic, but that is not a substitute for a fresh artifact check.

## Next Task

**TASK-04-CLEANUP-02 — Remove/retire the remaining TASK-02D verifier logic from `.github/workflows/ci.yml`**, then rerun Continuous Build so the normal desktop build and final manifest checks can execute.
