# TASK-04-DEBUG-02 — TASK-02D Probe Package Failure

Status: **PASS**

## Task

Diagnose the exact command causing `scripts/android-jvm/task-02d-build-arc-load-probe.sh` to exit with code 1 after the `TASK 02D: verify Android JVM Arc native load probe package` banner, then apply the smallest verified fix.

## Repository State

- Branch: `android-jvm`
- Baseline: `f325c0ddd03917bf2172b2d28f869f8ccb5ed820`
- Result implementation commit: `10e6d1896f060751d029deeefbe26cf8bf8a41c5`
- Pinned Arc revision: `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

## Scope

Changed only:

- `scripts/android-jvm/task-02d-build-arc-load-probe.sh`

No changes were made to:

- `AndroidJvmLauncher`
- `SharedLibraryLoader.java`
- Arc revision/source
- Arc native source
- backend-sdl native implementation
- `SDLGL`
- GLES/native linker configuration
- Android APK backend
- loader architecture
- valid Android-JVM probes

A temporary diagnostic instrumentation commit was used to isolate the failing verification check and was replaced by the minimal final fix.

## Original Failure

Continuous Build run:

- Run: `35596569354`
- Job: `106322641487`
- Step: `Build Android JVM Arc native load probe package`
- Command:
  `bash scripts/android-jvm/task-02d-build-arc-load-probe.sh desktop/build/libs/Mindustry.jar`

Before instrumentation, the script reached:

```
== TASK 02D: verify Android JVM Arc native load probe package ==
```

and exited with code 1 without identifying the failing assertion.

## Diagnostic Method

Temporary commit:

`dfe4baad3fbe0815a2022ec4008508ae51d6cc06`

The probe-package verification section was instrumented only to:

1. report PASS/FAIL for each package entry;
2. print the packaged `libarc.so` SHA-256 before comparison;
3. print the raw manifest with escaped CR characters;
4. print the manifest after the existing `tr` expression;
5. keep `set -euo pipefail`.

No production loader or native behavior was changed.

## Exact First Failure

Diagnostic Continuous Build:

- Run: `35596569354`
- Job: `106322641487`

Results immediately before the failing check:

```
PASS: arc/util/SharedLibraryLoader.class
PASS: androidjvm/probe/AndroidJvmArcNativeLoadProbe.class
PASS: arm64-v8a/libarc.so
SHA256: arm64-v8a/libarc.so = ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338
PASS: packaged libarc.so SHA256
```

The generated manifest contained:

```
Manifest-Version: 1.0\\r
Main-Class: androidjvm.probe.AndroidJvmArcNativeLoadProbe\\r
Enable-Native-Access: ALL-UNNAMED\\r
Multi-Release: true\\r
Created-By: 17.0.20.1 (Eclipse Adoptium)\\r
```

The existing command:

```
tr -d '\\r'
```

removed the literal character `r` rather than the CR character. The diagnostic output showed the resulting corruption:

```
Manifest-Vesion: 1.0\\r
Main-Class: andoidjvm.pobe.AndoidJvmAcNativeLoadPobe\\r
Enable-Native-Access: ALL-UNNAMED\\r
Multi-Release: tue\\r
Ceated-By: 17.0.20.1 (Eclipse Adoptium)\\r
```

The next command,

```
grep -Fxq 'Main-Class: androidjvm.probe.AndroidJvmArcNativeLoadProbe'
```

therefore returned exit code 1.

This was the first failing sub-check. No later verifier was executed.

## Minimal Fix

Final implementation commit:

`10e6d1896f060751d029deeefbe26cf8bf8a41c5`

Changed only the manifest verification expression from the incorrect form to:

```bash
tr -d '\\r'
```

No other probe logic was redesigned or altered.

## Duplicate Manifest Warnings

During:

```bash
jar ufm "$OUT_JAR" "$MANIFEST"
```

Java emitted:

```
WARNING: Duplicate name in Manifest: Manifest-Version.
WARNING: Duplicate name in Manifest: Main-Class.
```

These warnings were **non-fatal** and were not the cause of the failure.

Evidence:

- the probe-package verifier continued past the warnings;
- the raw final manifest contained the expected effective `Manifest-Version` and `Main-Class` entries;
- the first package entry checks passed;
- the `libarc.so` checksum check passed;
- only the broken `tr` normalization caused the first failing command.

The warnings are therefore recorded as packaging noise/manifest-update warnings, not as the blocker fixed by this task.

## Build Verification

Continuous Build after the fix:

- Run: `35597004218`
- Commit: `10e6d1896f060751d029deeefbe26cf8bf8a41c5`
- Overall result: **success**

Confirmed before and through the probe-package step:

- `core:compileJava`: pass
- `desktop:compileJava`: pass
- `-PandroidJvm desktop:dist --rerun-tasks`: pass
- Android-JVM packaging verification: pass
- TASK-02D probe package verification: pass

The workflow subsequently continued successfully through:

- unit tests
- desktop JAR build and verification
- real Android native load probe packaging
- Android absolute-path native load diagnostic
- SDL Android controller Java glue diagnostic
- Android JVM native loader boundary probe
- artifact uploads

## Probe Package Verification

The corrected verifier passed and produced:

```
androidjvm/probe/AndroidJvmArcNativeLoadProbe.class
arc/util/SharedLibraryLoader.class
arm64-v8a/libarc.so
```

Packaged `libarc.so` SHA-256:

```
ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338
```

Probe package SHA-256 from CI:

```
04fc21813830a35f7ff21f2fbe9d600aa4bb6dba0e12db6ee7c64b6f40063078
```

Final verifier marker:

```
TASK 02D Android JVM Arc native load probe package: PASS
```

## Historical Integrity

The temporary diagnostic instrumentation was not retained. The final task change contains only the corrected manifest CR-removal expression, preserving earlier TASK-02D implementation and DEBUG-01 history.

## Result

The TASK-02D probe package failure was caused by the manifest verification command using:

```
tr -d '\\r'
```

with the wrong escaping. It deleted literal `r` characters from the manifest before the exact Main-Class comparison.

The minimal correction to remove actual CR characters makes the probe-package verifier pass without changing the probe's loader behavior or native artifacts.

## Known Limitations

This task proves the probe package can be constructed and structurally verified. It does not by itself prove a real Android device can execute the probe successfully.

The duplicate manifest warnings remain emitted by the `jar ufm` packaging operation, but they are non-fatal and are outside the minimal fix because they do not fail verification.

## Next Task

Continue with the next scoped Android-JVM investigation from the clean result commit. Do not reopen TASK-02D manifest debugging unless a new regression provides evidence.

