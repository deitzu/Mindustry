# TASK 03C-DEBUG-14-CI-03 — Fix Java class verification ordering

## Status

INCOMPLETE — fix applied; CI verification pending.

## Branch

`android-jvm`

## Baseline

`5d1fba0fb5e9b3e78c30980805396b5d18e2efd6`

Pinned Arc revision:

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

SDL:

`2.32.8`

SDL source commit:

`98d1f3a45aae568ccd6ed5fec179330f47d4d356`

## Result

`6d736ea6ec82fd26d51888afff0c0598a3cacee3`

Commit message:

`Fix DEBUG-14 Java class verification order`

## Files changed

- `scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh`
- this report

No production Android loader, Arc upstream checkout, SDL source, `OS.java`, `SharedLibraryLoader`, or `SDLGL.java` files were modified.

## Failure

Continuous Build run:

`35505341157`

Job:

`106064072483`

Failing step:

`Build SDL Android controller Java glue diagnostic`

The SDL checkout itself succeeded. The script cloned SDL at the required commit, compiled the four direct JNI classes, staged them, and reached package verification.

The failure was the `diff -u` check. The script sorted the actual packaged class list but the expected array was not in the same sorted order.

Actual sorted order:

- `org/libsdl/app/SDLActivity.class`
- `org/libsdl/app/SDLAudioManager.class`
- `org/libsdl/app/SDLControllerManager.class`
- `org/libsdl/app/SDLInputConnection.class`

Expected array before the fix placed `SDLInputConnection.class` before the two audio/controller classes.

This caused exit code 1 despite the package containing the correct four classes.

## Root Cause

The verification logic compared:

1. a lexicographically sorted actual class list, against
2. an unsorted expected class list.

The package contents were therefore correct, but the verification assertion was internally inconsistent.

## Fix

Reordered the expected class array to match the existing deterministic `sort` operation:

```
SDLActivity
SDLAudioManager
SDLControllerManager
SDLInputConnection
```

No packaging behavior changed. This modifies only the verification assertion.

## CI

### Continuous Build

- Run `35505341157` — failed at class-list verification.
- New verification run is triggered by commit `6d736ea6...`; final result pending.

### Tests workflow

Run:

`35505341162`

Job:

`106064072703`

This workflow independently failed during `tests:test --rerun`.

The terminal dependency failure was:

```
Could not HEAD 'https://repo.maven.apache.org/maven2/de/undercouch/download/de.undercouch.download.gradle.plugin/5.0.1/de.undercouch.download.gradle.plugin-5.0.1.pom'.
Received status code 429 from server: Too Many Requests
```

This is an external Maven Central HTTP 429 response, not a Java/compiler/test assertion failure demonstrated by the log.

The same Tests workflow for the preceding commit `b437e1ab...` passed, so there is no current evidence that the DEBUG-14 patch caused the Tests failure.

No workflow change was made for the 429.

## Build

For Continuous Build run `35505341157`, confirmed green before the verification failure:

- Arc exact pin: PASS
- Android SDK/NDK setup: PASS
- Android native toolchain: PASS
- Android ARM64 SDL native build: PASS
- unit tests: PASS
- `desktop:dist`: PASS
- desktop JAR verification: PASS
- real Android JVM native-load probe packaging: PASS
- absolute-path native-load diagnostic packaging: PASS
- SDL 2.32.8 checkout: PASS
- SDL Android Java compilation: PASS
- four direct JNI classes staged: PASS

DEBUG-14 final package verification failed only on ordering.

## Verification

### Confirmed by source

- SDL 2.32.8 is checked out independently when the sibling tree is not a valid Git checkout.
- The exact SDL version header path is `include/SDL_version.h`.
- The diagnostic is intended to package exactly four direct JNI_OnLoad classes.

### Confirmed by CI/build

- SDL clone at the pinned commit succeeded.
- Java compilation succeeded.
- All four expected class files were generated.
- Failure happened only at the final class-list `diff`.

### Confirmed by artifact inspection

- The package reached verification, but artifact upload was skipped after the verification command failed.
- Therefore final artifact availability for this run is not established.

### Confirmed by previous CI

- The independent Tests workflow succeeded on `b437e1ab...`, while the later `5d1fba0...` run encountered Maven Central HTTP 429.

### Inference

- The class-verification failure is purely an assertion-order bug in the diagnostic script.

### Unknown

- Whether the next CI run will reveal another DEBUG-14 issue after the ordering assertion is fixed.

## Known limitations

- Final DEBUG-14 packaging is still unverified after the ordering fix.
- Tests workflow health is temporarily affected by an external Maven Central 429 in the observed run.
- Full Android runtime behavior remains untested.

## Next task

Verify the CI run triggered by `6d736ea6...`.

If Continuous Build passes the package step, inspect the produced DEBUG-14 artifact and verify its exact entries and embedded native SHA-256. If another failure occurs, create a new debug report from that exact failure.

## Handoff

Status:
INCOMPLETE — CI verification pending

Branch:
`android-jvm`

Baseline:
`5d1fba0fb5e9b3e78c30980805396b5d18e2efd6`

Commit:
`6d736ea6ec82fd26d51888afff0c0598a3cacee3`

Files changed:
`scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh`
`docs/android-jvm/TASK_03C_DEBUG_14_CI_03.md`

Result:
Fixed the deterministic class-list verification mismatch by ordering expected entries consistently with the sorted actual package listing.

CI:
- `35505341157` — DEBUG-14 assertion-order failure.
- `35505341162` — Tests workflow failed on external Maven Central HTTP 429.
- New Continuous Build verification triggered by `6d736ea6...`.

Build:
All required pre-verification stages were green in the failing Continuous Build run.

Verification:
SDL clone, Java compilation, and class staging all passed; only the list-order assertion failed.

Known limitations:
Final DEBUG-14 package verification remains pending.

Next task:
Verify the new Continuous Build and inspect the artifact if it passes.
