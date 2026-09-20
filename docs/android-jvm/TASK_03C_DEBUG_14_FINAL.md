# TASK 03C-DEBUG-14-FINAL — SDL Android Java Glue / JNI_OnLoad Dependency Probe

## Status

PASS — CI packaging and verification completed successfully.

This closes the DEBUG-14 CI/package portion. Real-device four-class runtime verification remains a separate next task.

## Branch

`android-jvm`

## Baseline

`b4433a1dc78bd4910724268645c1c06bf7ac08f1`

## Result

This task is verified by GitHub Actions run:

- Continuous Build: `35505910722`
- Tests: `35505910743`
- Gradle Wrapper validation: `35505910713`

All three workflows completed with conclusion `success` on commit:

`b4433a1dc78bd4910724268645c1c06bf7ac08f1`

The final documentation commit is this report's resulting commit.

## Objective

Determine and package the minimum SDL 2.32.8 Android Java classes directly required by SDL's `JNI_OnLoad` registration, while preserving the real ARM64 native library and avoiding production runtime changes.

## Scope

In scope:

- SDL 2.32.8 source inspection;
- direct JNI_OnLoad Java class identification;
- deterministic diagnostic JAR packaging;
- reuse of the real Android ARM64 `libsdl-arc.so`;
- CI/build verification.

Out of scope:

- production native loader integration;
- Android Activity/lifecycle integration;
- renderer changes;
- fake Java stubs;
- direct modification of pinned upstream Arc source.

## Pinned dependencies

Arc:

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

SDL:

- version: `2.32.8`
- release ref: `release-2.32.8`
- commit: `98d1f3a45aae568ccd6ed5fec179330f47d4d356`

Android CI toolchain:

- NDK: `30.0.16248370`
- API: `36`
- CMake: `3.31.6`

## Source findings

SDL 2.32.8 registers exactly four Java classes from native `JNI_OnLoad`:

1. `org/libsdl/app/SDLActivity`
2. `org/libsdl/app/SDLInputConnection`
3. `org/libsdl/app/SDLAudioManager`
4. `org/libsdl/app/SDLControllerManager`

`SDLInputConnection` is a top-level class declared inside `SDLActivity.java`; there is no standalone `SDLInputConnection.java` file at this SDL revision.

These findings are source-derived and were used to define the diagnostic package.

## Implementation

The diagnostic helper:

`scripts/android-jvm/task-03c-build-controller-glue-load-probe.sh`

now:

- derives the repository root from its own script location;
- validates the authoritative pinned Arc checkout;
- independently obtains SDL 2.32.8 when the sibling tree is not a valid Git checkout;
- validates the exact SDL commit and source version;
- compiles the SDL Android Java sources against Android API 36;
- packages exactly the four direct JNI_OnLoad classes;
- embeds the real `libsdl-arc.so` ARM64 native library;
- verifies package contents deterministically;
- verifies the embedded native SHA-256 against the source native artifact.

No production Mindustry Android loader change was introduced by DEBUG-14.

## CI verification

Final Continuous Build run:

`35505910722`

Job:

`106065580586`

All relevant steps completed successfully:

- checkout triggering commit: PASS
- setup JDK 17: PASS
- Gradle setup: PASS
- clone and pin Arc: PASS
- Android SDK setup: PASS
- Android native toolchain installation: PASS
- native toolchain verification: PASS
- Android ARM64 SDL native probe: PASS
- unit tests: PASS
- desktop JAR build: PASS
- desktop JAR verification: PASS
- real Android JVM native-load probe packaging: PASS
- absolute-path native-load diagnostic packaging: PASS
- SDL Android Java JNI glue diagnostic: PASS
- SDL Android JNI glue artifact upload: PASS
- Android JVM loader-boundary probe: PASS
- Android JVM native-load probe upload: PASS
- desktop JAR upload: PASS

## Final DEBUG-14 artifact evidence

Artifact:

`Android-JVM-android-jni-glue-load-probe-b4433a1dc78bd4910724268645c1c06bf7ac08f1`

Artifact ID:

`10603299911`

Artifact SHA-256:

`9641318b1c58be12e7b153267379937192f73ba4e29bf54b147a1d0853a9c8f7`

The diagnostic package reported:

- SDL source version: `2.32.8`
- SDL source commit: `98d1f3a45aae568ccd6ed5fec179330f47d4d356`
- Android API JAR: Android 36
- exact four direct JNI_OnLoad Java classes present
- real `libsdl-arc.so` resource present
- source native SHA-256:
  `d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7`
- embedded native SHA-256:
  `d98174dd5d9c2b94f595cafbd53b8382cee0f57e4e27dff97ea86cab512dceb7`

Final diagnostic result:

`Android JNI glue absolute-load diagnostic package: PASS`

## Previous failure chain preserved

The intermediate reports remain unchanged as historical records:

- `TASK_03C_DEBUG_14_CI_01.md` — Arc late Git revalidation failure
- `TASK_03C_DEBUG_14_CI_02.md` — SDL checkout validation failure
- `TASK_03C_DEBUG_14_CI_03.md` — Java class-list ordering assertion failure

Those failures were fixed incrementally and re-verified by later CI. No historical report was rewritten.

## Important boundary

The CI workflow's `Probe Android JVM native loader boundary` step runs in the GitHub-hosted Linux environment and reports:

`OS.isAndroid=false`

Therefore its PASS status must not be interpreted as proof of successful Android-device runtime loading.

The real-device evidence remains the earlier DEBUG-13A observation that absolute `System.load(absPath)` reached native JNI initialization and then failed on the missing SDL Java class:

`org/libsdl/app/SDLControllerManager`

DEBUG-14 now provides the source-grounded four-class package required to test that boundary on the actual Android JVM.

## Acceptance criteria

- [x] Exact SDL 2.32.8 source revision identified.
- [x] Four direct JNI_OnLoad Java classes identified from source.
- [x] `SDLInputConnection` source placement verified.
- [x] Diagnostic package compiles in CI.
- [x] Diagnostic package contains exactly the four intended classes.
- [x] Real ARM64 `libsdl-arc.so` is embedded unchanged.
- [x] Embedded native SHA-256 matches source native artifact.
- [x] CI Continuous Build passes.
- [x] Project Tests workflow passes.
- [x] Gradle Wrapper validation passes.
- [x] No production runtime loader change introduced.

Not part of this task:

- [ ] Real Android four-class runtime probe.
- [ ] Complete SDL Activity/window/input/audio runtime integration.

## Known limitations

- CI proves reproducible source selection, compilation, packaging, and artifact integrity.
- CI does not prove full Android runtime compatibility.
- Full SDL Android Java runtime behavior beyond JNI_OnLoad remains unverified.

## Next task

Run the final four-class diagnostic JAR on the real Android JVM and capture the earliest post-JNI boundary:

- success of `System.load(absPath)`, or
- the next concrete Java/linker/runtime failure.

Do not add additional SDL Java classes preemptively. Use the real runtime failure to select the next dependency.

## Handoff

Status:
PASS — DEBUG-14 CI/package task complete

Branch:
`android-jvm`

Baseline:
`b4433a1dc78bd4910724268645c1c06bf7ac08f1`

Commit:
Resulting documentation commit created from this report.

Files changed:
`docs/android-jvm/TASK_03C_DEBUG_14_FINAL.md`

Result:
SDL 2.32.8 direct JNI_OnLoad Java glue was source-verified, compiled, packaged, and integrity-checked successfully in CI. The exact four direct classes are:

`SDLActivity`
`SDLInputConnection`
`SDLAudioManager`
`SDLControllerManager`

CI:
- `35505910722` — Continuous Build: PASS
- `35505910743` — Tests: PASS
- `35505910713` — Gradle Wrapper validation: PASS

Build:
Android ARM64 native probe, unit tests, desktop build, diagnostic packaging, and artifact upload: PASS

Verification:
Four-class package PASS; native SHA-256 source/embedded match PASS

Known limitations:
Real-device four-class runtime remains a separate unverified boundary.

Next task:
Real Android four-class JNI load probe.
