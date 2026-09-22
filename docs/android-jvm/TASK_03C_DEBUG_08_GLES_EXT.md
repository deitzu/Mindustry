# TASK 03C-DEBUG-08 — Android GLES EXT Compatibility

## Status

**Complete.** The five targeted Android GLES/EXT compiler failures are fixed. The Android ARM64 native build passed C++ compilation of `SDLGL.cpp` and reached the shared-library linker. Per task stop condition, work stopped at the first new linker-layer failure.

## Branch

`ci/task-ci-01`

## Baseline

`ba36266cd443abd852852f2f9e7929d53e58a74c`

Pinned Arc revision:

`8eb00ffff0126d0576c67df46f99b8f6bccd96fe`

SDL: 2.32.8  
jnigen: 3.1.2  
Android ABI: arm64-v8a  
Android minimum API target: 21

## Result Commit

Implementation:

`42cea81b673a394e2d26adb22b361036fcc42846`

The deterministic Arc overlay remains the only project-side implementation mechanism. No upstream Arc files were modified.

## Exact Original Compiler Failure

The previous native compilation stopped in generated `SDLGL.cpp` on these undeclared Android identifiers:

- `glFramebufferRenderbufferEXT`
- `glFramebufferTexture2DEXT`
- `glGenerateMipmapEXT`
- `glGenFramebuffersEXT`
- `glGenRenderbuffersEXT`

## Symbol Mappings

| Android-specific desktop EXT fallback | Android direct GLES call |
|---|---|
| `glFramebufferRenderbufferEXT` | `glFramebufferRenderbuffer` |
| `glFramebufferTexture2DEXT` | `glFramebufferTexture2D` |
| `glGenerateMipmapEXT` | `glGenerateMipmap` |
| `glGenFramebuffersEXT` | `glGenFramebuffers` |
| `glGenRenderbuffersEXT` | `glGenRenderbuffers` |

## Implementation

The five JNI native methods in `SDLGL.java` now use:

```cpp
#ifdef __ANDROID__
    // direct GLES function
#else
    // existing desktop core/EXT fallback
#endif
```

The desktop branches retain their existing core-function detection and EXT fallback calls. No global OpenGL-to-GLES replacement was performed.

The overlay patch was regenerated from the exact pinned Arc source for this change. The five-function hunk is a generated unified diff with verified hunk counts, not a hand-edited hunk-count adjustment.

## Files Changed

- `ci/android-jvm/task03c-backend-sdl.patch`

The patch modifies the existing scoped Arc targets:

- `backends/backend-sdl/build.gradle`
- `backends/backend-sdl/src/arc/backend/sdl/jni/SDLGL.java`

No SDL source, jnigen source, generated C++, generated Android.mk, Java GL wrapper, launcher/runtime, or Arc revision was changed.

## CI

GitHub Actions Continuous Build run:

`35461891071`

The workflow verified:

- Arc checkout at `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`
- Arc revision remained unchanged after overlay application
- overlay modified exactly the intended two Arc files
- SDL source version 2.32.8
- Android NDK 30.0.16248370
- Android ARM64 native build entered `SDLGL.cpp`

## Build Result

**Confirmed by CI/build:** the previous five EXT GLES compiler errors are gone.

The log reached:

```
[arm64-v8a] Compile++      : sdl-arc <= arc_backend_sdl_jni_SDLGL.cpp
[arm64-v8a] SharedLibrary  : libsdl-arc.so
```

This proves the C++ compilation stage passed for `SDLGL.cpp`.

The build then failed at the linker with new undefined Android GLES symbols, beginning with:

```
ld.lld: error: undefined symbol: glReadBuffer
ld.lld: error: undefined symbol: glDrawRangeElements
ld.lld: error: undefined symbol: glTexImage3D
```

Additional linker errors followed, including `glDrawBuffers` and several matrix-uniform functions.

## Verification

### Confirmed by source

- Android branches use the direct GLES equivalents for all five targeted functions.
- Desktop branches retain the existing EXT fallback code.
- No global EXT-to-core replacement was made.

### Confirmed by CI/build

- The deterministic overlay applied to pinned Arc.
- Arc SHA remained `8eb00ffff0126d0576c67df46f99b8f6bccd96fe`.
- `SDLGL.cpp` compiled past the five original EXT identifier failures.
- Native build reached the shared-library link stage.

### Confirmed by generated artifact

The CI log references the generated target:

`Arc/backends/backend-sdl/build/jnigen/target/android32/arc_backend_sdl_jni_SDLGL.cpp`

and shows its object file being linked into `libsdl-arc.so`.

### Inference

The next failure layer is Android GLES linkage rather than C++ symbol declaration. The exact root cause of the new undefined symbols is not determined by this task.

### Unknown

- Whether all remaining OpenGL 3.x methods can be supported directly through the current Android GLES2/GLES3 linkage.
- Whether the correct next fix is GLES3 linkage, conditional unsupported methods, or another scoped compatibility boundary.

## Known Limitations

- The native shared library does not link yet.
- The new linker failures are intentionally not fixed in DEBUG-08.
- Desktop build regression is not independently proven by this CI run because the native probe failed before the later desktop-build stage.

## Next Task

**TASK 03C-DEBUG-09 — Android GLES Linkage Compatibility**

Investigate the first linker failure, starting with `glReadBuffer`. Do not modify unrelated GLES methods until the linkage boundary is established.
