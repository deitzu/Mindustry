#!/usr/bin/env bash
set -euo pipefail

ARC_EXPECTED="8eb00ffff0126d0576c67df46f99b8f6bccd96fe"
SDL_VERSION="2.32.8"
SDL_URL="https://github.com/libsdl-org/SDL/releases/download/release-2.32.8/SDL2-2.32.8.tar.gz"

ROOT="${git rev-parse --show-toplevel}"
ARC_DIR="$ROOT/../Arc"
PATCH_FILE="$ROOT/ci/android-jvm/task03c-backend-sdl.patch"
SDL_ROOT="$ROOT/../SDL2-2.32.8"
SDL_BUILD="$SDL_ROOT/build"
OUT="$ROOT/ci-artifacts/task03c"
mkdir -p "$OUT"

echo "== TASK 03C: verify Arc before patch =="
actual_arc="${git -C "$ARC_DIR" rev-parse HEAD}"
[ "$actual_arc" = "$ARC_EXPECTED" ] || {
  echo "::error::Arc revision mismatch before patch: expected $ARC_EXPECTED, got $actual_arc"
  exit 1
}
echo "Arc revision before patch: $actual_arc"

echo "== TASK 03C: apply deterministic Arc overlay =="
git -C "$ARC_DIR" diff --exit-code
git -C "$ARC_DIR" apply --check "$PATCH_FILE"
git -C "$ARC_DIR" apply "$PATCH_FILE"

post_arc="${git -C "$ARC_DIR" rev-parse HEAD}"
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
header_version="${awk -F" |[()]" '/^#define SDL_MAJOR_VERSION/{major=$4} /^#define SDL_MINOR_VERSION/{minor=$4} /^#define SDL_PATCHLEVEL/{patch=$4} END{print major "." minor "." patch}' "$SDL_ROOT/include/SDL_version.h"}"
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
  -DSDL_HAPTIC=OFF \
  -DSDL_HIDAPI=OFF \
  -DSDL_JOYSTICK=OFF \
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
ANDROID_TASK="${awk '$1 ~ /^jnigenBuild/ && /Android/ {print $1; exit}' "$TASKS_FILE"}"
if [ -z "$ANDROID_TASK" ]; then
  echo "---- candidate jnigen Android tasks ----"
  grep -Ei 'jnigen|android' "$TASKS_FILE" || true
  echo "::error::No Android jnigen compilation task discovered"
  exit 1
fi
echo "Discovered Android native task: :backends:backend-sdl:$ANDROID_TASK"

echo "== TASK 03C: generate jnigen sources =="
( cd "$ARC_DIR" && ./gradlew :backends:backend-sdl:jnigen --stacktrace )

echo "== TASK 03C: compile Android backend-sdl =="
( cd "$ARC_DIR" && ./gradlew ":backends:backend-sdl:$ANDROID_TASK" --stacktrace )

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

machine="${$READELF -h "$probe" | awk -F: '/Machine:/{gsub(/^ +/,"",$2); print $2}'}"
class="${$READELF -h "$probe" | awk -F: '/Class:/{gsub(/^ +/,"",$2); print $2}'}"
soname="${$READELF -d "$probe" | sed -n 's/.*SONAME.*\[\(.*\)\].*/\1/p' | head -n 1 || true}"
printf 'TASK_03C\nArc revision=%s\nSDL version=%s\nSDL ABI=arm64-v8a\nNative task=%s\nOutput path=%s\nELF class=%s\nELF machine=%s\nSONAME=%s\n' "$post_arc" "$header_version" "$ANDROID_TASK" "$probe" "$class" "$machine" "${soname:-<none>}" | tee "$OUT/verification-summary.txt"
"$READELF" -d "$probe" | sed -n 's/.*NEEDED.*\[\(.*\)\].*/\1/p' | tee "$OUT/dt-needed.txt"

forbidden_patterns=('libGL.so.1' 'libSDL2-2.0.so.0' 'libc.so.6' 'ld-linux-aarch64.so.1' 'GLEW')
for forbidden in "${forbidden_patterns[@]}"; do
  if grep -Fqi "$forbidden" "$DYNAMIC" "$OUT/dt-needed.txt" "$SYMBOLS"; then
    echo "::error::Forbidden dependency/symbol detected: $forbidden"
    exit 1
  fi
done

jni_count="${grep -c 'Java_arc_backend_sdl_jni_' "$SYMBOLS" || true}"
[ "$jni_count" -gt 0 ] || { echo "::error::No generated Arc SDL JNI symbols found"; exit 1; }
echo "JNI symbol count: $jni_count" | tee -a "$OUT/verification-summary.txt"
echo "Forbidden dependency scan: PASS" | tee -a "$OUT/verification-summary.txt"
echo "Android native probe: PASS" | tee -a "$OUT/verification-summary.txt"
