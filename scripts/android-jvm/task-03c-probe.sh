#!/usr/bin/env bash
set -euo pipefail

ARC_EXPECTED="8eb00ffff0126d0576c67df46f99b8f6bccd96fe"
SDL_VERSION="2.32.8"
SDL_URL="https://github.com/libsdl-org/SDL/releases/download/release-2.32.8/SDL2-2.32.8.tar.gz"

ROOT="$(git rev-parse --show-toplevel)"
ARC_DIR="$ROOT/../Arc"
PATCH_FILE="$ROOT/ci/android-jvm/task03c-backend-sdl.patch"
SDL_ROOT="$ROOT/../SDL2-2.32.8"
SDL_BUILD="$SDL_ROOT/build"
OUT="$ROOT/ci-artifacts/task03c"
mkdir -p "$OUT"

echo "== TASK 03C: verify Arc before patch =="
actual_arc="$(git -C "$ARC_DIR" rev-parse HEAD)"
[ "$actual_arc" = "$ARC_EXPECTED" ] || {
  echo "::error::Arc revision mismatch before patch: expected $ARC_EXPECTED, got $actual_arc"
  exit 1
}
echo "Arc revision before patch: $actual_arc"

echo "== TASK 03C: apply deterministic Arc overlay =="
git -C "$ARC_DIR" diff --exit-code
git -C "$ARC_DIR" apply --check "$PATCH_FILE"
git -C "$ARC_DIR" apply "$PATCH_FILE"

post_arc="$(git -C "$ARC_DIR" rev-parse HEAD)"
[ "$post_arc" = "$ARC_EXPECTED" ] || {
  echo "::error::Arc revision changed unexpectedly after patch: $post_arc"
  exit 1
}
git -C "$ARC_DIR" diff --check
echo "Arc revision after patch: $post_arc"
git -C "$ARC_DIR" status --short

export SDL2_ANDROID_ROOT="$SDL_ROOT"

echo "== TASK 03C: obtain SDL $SDL_VERSION =="
if [ ! -d "$SDL_ROOT" ]; then
  archive="$ROOT/../SDL2-$SDL_VERSION.tar.gz"
  curl -fsSL --retry 3 --retry-all-errors "$SDL_URL" -o "$archive"
  tar -xzf "$archive" -C "$ROOT/.."
fi

[ -f "$SDL_ROOT/CMakeLists.txt" ] || {
  echo "::error::SDL source directory is missing: $SDL_ROOT"
  exit 1
}
header_version="$(awk '/^#define SDL_MAJOR_VERSION[[:space:]]/ {major=$3} /^#define SDL_MINOR_VERSION[[:space:]]/ {minor=$3} /^#define SDL_PATCHLEVEL[[:space:]]/ {patch=$3} END {if(major == "" || minor == "" || patch == "") exit 1; print major "." minor "." patch}' "$SDL_ROOT/include/SDL_version.h")"
[ "$header_version" = "$SDL_VERSION" ] || {
  echo "::error::SDL version mismatch: expected $SDL_VERSION, got $header_version"
  exit 1
}
echo "SDL source version: $header_version"

CMAKE_BIN="$ANDROID_SDK_ROOT/cmake/3.31.6/bin/cmake"
[ -x "$CMAKE_BIN" ] || { echo "::error::CMake 3.31.6 not found"; exit 1; }

echo "== TASK 03C: configure SDL2 static Android arm64-v8a =="
"$CMAKE_BIN" \
  -S "$SDL_ROOT" \
  -B "$SDL_BUILD" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-21 \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DSDL_STATIC_PIC=ON \
  -DSDL_SHARED=OFF \
  -DSDL_STATIC=ON \
  -DSDL_TEST=OFF \
  -DSDL_OPENGL=OFF \
  -DSDL_OPENGLES=ON \
  -DSDL_AUDIO=OFF \
  -DSDL_HAPTIC=ON \
  -DSDL_HIDAPI=OFF \
  -DSDL_JOYSTICK=ON \
  -DSDL_SENSOR=OFF \
  -DSDL_VULKAN=OFF \
  -DSDL_MISC=OFF \
  -DSDL_FILESYSTEM=OFF \
  -DSDL_LOCALE=OFF \
  -DSDL_POWER=OFF

echo "== TASK 03C: build SDL2-static =="
"$CMAKE_BIN" --build "$SDL_BUILD" --target SDL2-static --parallel 2
SDL_STATIC="$SDL_BUILD/libSDL2.a"
[ -f "$SDL_STATIC" ] || { echo "::error::Expected SDL static archive not found: $SDL_STATIC"; exit 1; }
echo "SDL static archive: $SDL_STATIC"
"$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar" t "$SDL_STATIC" | head -n 10

echo "== TASK 03C: inspect Gradle task graph =="
TASKS_FILE="$OUT/backend-sdl-tasks.txt"
( cd "$ARC_DIR" && ./gradlew :backends:backend-sdl:tasks --all ) | tee "$TASKS_FILE"
ANDROID_TASK="$(awk '$1 ~ /^jnigenBuild/ && /Android/ {print $1; exit}' "$TASKS_FILE")"
ANDROID_PACKAGE_TASK="$(awk '$1 ~ /^jnigenPackageAndroid_/ && /arm64-v8a/ {print $1; exit}' "$TASKS_FILE")"
if [ -z "$ANDROID_PACKAGE_TASK" ]; then
  ANDROID_PACKAGE_TASK="$(awk '$1 ~ /^jnigenPackageAllAndroid$/ {print $1; exit}' "$TASKS_FILE")"
fi
if [ -z "$ANDROID_TASK" ] || [ -z "$ANDROID_PACKAGE_TASK" ]; then
  echo "---- candidate jnigen Android tasks ----"
  grep -Ei 'jnigen|android' "$TASKS_FILE" || true
  echo "::error::Could not discover both Android native compilation and packaging tasks"
  exit 1
fi
echo "Discovered Android native task: :backends:backend-sdl:$ANDROID_TASK"
echo "Discovered Android packaging task: :backends:backend-sdl:$ANDROID_PACKAGE_TASK"

echo "== TASK 03C: generate jnigen sources =="
( cd "$ARC_DIR" && ./gradlew :backends:backend-sdl:jnigen --stacktrace )

echo "== DEBUG-07: compile Android backend-sdl and retain first native failure =="
set +e
( cd "$ARC_DIR" && ./gradlew ":backends:backend-sdl:$ANDROID_TASK" --stacktrace )
native_status=$?
set -e

echo "== DEBUG-07: inspect generated Android.mk after native task starts =="
ANDROID_MK="$ARC_DIR/backends/backend-sdl/build/jnigen/target/android32/Android.mk"
if [ -f "$ANDROID_MK" ]; then
  echo "Android.mk: $ANDROID_MK"
  grep -nE "LOCAL_C_INCLUDES|LOCAL_CFLAGS|LOCAL_CPPFLAGS|SDL2|SDL" "$ANDROID_MK" || true
else
  echo "::error::Android.mk was not generated at expected path: $ANDROID_MK"
  find "$ARC_DIR/backends/backend-sdl/build/jnigen" -type f -name Android.mk -print || true
fi

[ "$native_status" -eq 0 ] || {
  echo "::error::Android native task failed with status $native_status"
  exit "$native_status"
}

echo "== TASK 03C: package Android ARM64 JNI library =="
( cd "$ARC_DIR" && ./gradlew ":backends:backend-sdl:$ANDROID_PACKAGE_TASK" --stacktrace )

echo "== TASK 03C: locate Android native package =="
PACKAGE_JAR=""
PACKAGE_ENTRY=""
EXPECTED_PACKAGE_NAME="sdl-arc-natives-arm64-v8a.jar"

while IFS= read -r candidate; do
  [ -f "$candidate" ] || continue
  [ "$(basename "$candidate")" = "$EXPECTED_PACKAGE_NAME" ] || continue

  if jar tf "$candidate" 2>/dev/null | grep -Fxq 'libsdl-arc.so'; then
    PACKAGE_JAR="$candidate"
    PACKAGE_ENTRY="libsdl-arc.so"
    break
  fi
done < <(find "$ARC_DIR/backends/backend-sdl" -type f -name '*.jar' -print)

[ -n "$PACKAGE_JAR" ] || {
  echo "::error::No Android ARM64 native JAR '$EXPECTED_PACKAGE_NAME' containing libsdl-arc.so was found"
  find "$ARC_DIR/backends/backend-sdl" -type f -name '*.jar' -print || true
  exit 1
}
echo "Android ARM64 native package: $PACKAGE_JAR"
echo "Android ARM64 package entry: $PACKAGE_ENTRY"
cp "$PACKAGE_JAR" "$OUT/$(basename "$PACKAGE_JAR")"
printf 'Package task=%s\nPackage path=%s\nPackage entry=%s\n' "$ANDROID_PACKAGE_TASK" "$PACKAGE_JAR" "$PACKAGE_ENTRY" | tee "$OUT/package-summary.txt"

echo "== TASK 03C: locate Android ARM64 JNI library =="
mapfile -t candidates < <(find "$ARC_DIR/backends/backend-sdl" -type f -name '*.so' -print)
probe=""
for candidate in "${candidates[@]}"; do
  if "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf" -h "$candidate" 2>/dev/null | grep -q 'Machine:.*AArch64'; then
    probe="$candidate"
    break
  fi
done
[ -n "$probe" ] || {
  echo "::error::No AArch64 backend-sdl JNI .so was found"
  printf '%s\n' "${candidates[@]}"
  exit 1
}
echo "Android ARM64 JNI library: $probe"
cp "$probe" "$OUT/$(basename "$probe")"

READELF="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf"
[ -x "$READELF" ] || { echo "::error::NDK llvm-readelf not found"; exit 1; }
HEADER="$OUT/readelf-header.txt"
PROGRAM="$OUT/readelf-program-headers.txt"
DYNAMIC="$OUT/readelf-dynamic.txt"
SYMBOLS="$OUT/readelf-symbols.txt"
"$READELF" -h "$probe" | tee "$HEADER"
"$READELF" -l "$probe" | tee "$PROGRAM"
"$READELF" -d "$probe" | tee "$DYNAMIC"
"$READELF" -Ws "$probe" | tee "$SYMBOLS"

machine="$($READELF -h "$probe" | awk -F: '/Machine:/{gsub(/^ +/,"",$2); print $2}')"
class="$($READELF -h "$probe" | awk -F: '/Class:/{gsub(/^ +/,"",$2); print $2}')"
soname="$($READELF -d "$probe" | sed -n 's/.*SONAME.*\[\(.*\)\].*/\1/p' | head -n 1 || true)"
[ "$class" = "ELF64" ] || { echo "::error::Unexpected ELF class: $class"; exit 1; }
[ "$machine" = "AArch64" ] || { echo "::error::Unexpected ELF machine: $machine"; exit 1; }
[ "$soname" = "libsdl-arc.so" ] || { echo "::error::Unexpected SONAME: $soname"; exit 1; }
printf 'TASK_03C\nArc revision=%s\nSDL version=%s\nSDL ABI=arm64-v8a\nNative task=%s\nPackaging task=%s\nOutput path=%s\nELF class=%s\nELF machine=%s\nSONAME=%s\nPackage path=%s\nPackage entry=%s\n' "$post_arc" "$header_version" "$ANDROID_TASK" "$ANDROID_PACKAGE_TASK" "$probe" "$class" "$machine" "$soname" "$PACKAGE_JAR" "$PACKAGE_ENTRY" | tee "$OUT/verification-summary.txt"
"$READELF" -d "$probe" | sed -n 's/.*NEEDED.*\[\(.*\)\].*/\1/p' | tee "$OUT/dt-needed.txt"
grep -Fxq 'libGLESv3.so' "$OUT/dt-needed.txt" || { echo "::error::libGLESv3.so missing from DT_NEEDED"; exit 1; }
grep -Fxq 'libGLESv1_CM.so' "$OUT/dt-needed.txt" || { echo "::error::libGLESv1_CM.so missing from DT_NEEDED"; exit 1; }

forbidden_patterns=('libGL.so.1' 'libSDL2-2.0.so.0' 'libc.so.6' 'ld-linux-aarch64.so.1' 'GLEW')
for forbidden in "${forbidden_patterns[@]}"; do
  if grep -Fqi "$forbidden" "$DYNAMIC" "$OUT/dt-needed.txt" "$SYMBOLS"; then
    echo "::error::Forbidden dependency/symbol detected: $forbidden"
    exit 1
  fi
done

jni_count="$(grep -c 'Java_arc_backend_sdl_jni_' "$SYMBOLS" || true)"
jni_sdl_count="$(grep -c 'Java_arc_backend_sdl_jni_SDL_' "$SYMBOLS" || true)"
jni_sdlgl_count="$(grep -c 'Java_arc_backend_sdl_jni_SDLGL_' "$SYMBOLS" || true)"
[ "$jni_count" -gt 0 ] || { echo "::error::No generated Arc SDL JNI symbols found"; exit 1; }
[ "$jni_sdl_count" -gt 0 ] || { echo "::error::Generated SDL JNI symbols are missing"; exit 1; }
[ "$jni_sdlgl_count" -gt 0 ] || { echo "::error::Generated SDLGL JNI symbols are missing"; exit 1; }
echo "JNI symbol count: $jni_count" | tee -a "$OUT/verification-summary.txt"
echo "SDL JNI symbol count: $jni_sdl_count" | tee -a "$OUT/verification-summary.txt"
echo "SDLGL JNI symbol count: $jni_sdlgl_count" | tee -a "$OUT/verification-summary.txt"
echo "Forbidden dependency scan: PASS" | tee -a "$OUT/verification-summary.txt"
echo "JNI symbol surface: PASS" | tee -a "$OUT/verification-summary.txt"
echo "Android native probe: PASS" | tee -a "$OUT/verification-summary.txt"
