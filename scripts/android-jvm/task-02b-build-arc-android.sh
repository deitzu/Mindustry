#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
ARC_DIR="$ROOT/../Arc"
OUT="$ROOT/ci-artifacts/task02b"
ARC_EXPECTED="8eb00ffff0126d0576c67df46f99b8f6bccd96fe"
NDK_EXPECTED="30.0.16248370"
ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-36}"

mkdir -p "$OUT"

echo "== TASK 02B: Git/source state =="
echo "Mindustry branch: $(git branch --show-current)"
echo "Mindustry HEAD: $(git rev-parse HEAD)"
git status --short
[ -d "$ARC_DIR" ] || { echo "::error::Arc checkout missing: $ARC_DIR"; exit 1; }
ARC_HEAD="$(git -C "$ARC_DIR" rev-parse HEAD)"
echo "Arc HEAD: $ARC_HEAD"
[ "$ARC_HEAD" = "$ARC_EXPECTED" ] || { echo "::error::Arc SHA mismatch"; exit 1; }

NDK_DIR="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
[ -n "$NDK_DIR" ] && [ -d "$NDK_DIR" ] || { echo "::error::Android NDK unavailable"; exit 1; }
NDK_REV="$(sed -n 's/^Pkg.Revision = //p' "$NDK_DIR/source.properties" | tr -d '[:space:]')"
[ "$NDK_REV" = "$NDK_EXPECTED" ] || { echo "::error::NDK mismatch: $NDK_REV"; exit 1; }

TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
CLANG="$TOOLCHAIN/bin/clang++"
READELF="$TOOLCHAIN/bin/llvm-readelf"
[ -x "$CLANG" ] && [ -x "$READELF" ] || { echo "::error::Required NDK LLVM tools missing"; exit 1; }
COMPILER_TARGET="$("$CLANG" --target=aarch64-linux-android21 -dumpmachine)"
printf '%s\n' "Android SDK: ${ANDROID_SDK_ROOT:-${ANDROID_HOME:-<unset>}}" "Android API: $ANDROID_API_LEVEL" "NDK: $NDK_DIR" "NDK version: $NDK_REV" "Compiler: $CLANG" "Compiler target: $COMPILER_TARGET" | tee "$OUT/toolchain.txt"
printf '%s' "$COMPILER_TARGET" | grep -Eq '^aarch64.*linux-android' || { echo "::error::Compiler target is not Android AArch64"; exit 1; }

ARC_BUILD="$ARC_DIR/arc-core/build.gradle"
grep -nE 'sharedLibName|libsDir|addAndroid|OpenSLES|APP_STL|preJni|getTasksByName' "$ARC_BUILD" | tee "$OUT/arc-build-relevant.txt"

echo "== TASK 02B: Gradle discovery =="
pushd "$ARC_DIR" >/dev/null
GRADLE_VERSION="$(./gradlew --version | sed -n 's/^Gradle \([0-9][^ ]*\).*/\1/p' | head -n1)"
echo "Gradle version: $GRADLE_VERSION" | tee "$OUT/gradle-version.txt"
./gradlew :arc-core:tasks --all --console=plain | tee "$OUT/arc-core-tasks.txt"
popd >/dev/null

mapfile -t DISCOVERED < <(sed -n 's/^[[:space:]]*\(jnigen[^[:space:]]*\)[[:space:]]*-.*/\1/p' "$OUT/arc-core-tasks.txt" | grep -Ei '^jnigen.*Android.*(arm64-v8a|aarch64)|^jnigen.*(arm64-v8a|aarch64).*Android' | sort -u)
printf '%s\n' "${DISCOVERED[@]}" | tee "$OUT/android-jni-tasks.txt"

BUILD_TASK="$(printf '%s\n' "${DISCOVERED[@]}" | grep -Fx 'jnigenBuildAndroid_arm64-v8a' | head -n1 || true)"
PACKAGE_TASK="$(printf '%s\n' "${DISCOVERED[@]}" | grep -Fx 'jnigenPackageAndroid_arm64-v8a' | head -n1 || true)"
[ -n "$BUILD_TASK" ] || { echo "::error::Gradle did not report jnigenBuildAndroid_arm64-v8a"; exit 1; }
printf 'Build task=:arc-core:%s\nPackage task=:arc-core:%s\n' "$BUILD_TASK" "${PACKAGE_TASK:-<none>}" | tee "$OUT/task-selection.txt"

pushd "$ARC_DIR" >/dev/null
./gradlew ":arc-core:$BUILD_TASK" --dry-run --console=plain | tee "$OUT/task-dry-run.txt"
echo "== TASK 02B: real Android native build =="
./gradlew ":arc-core:$BUILD_TASK" --info --stacktrace --console=plain | tee "$OUT/build.log"
popd >/dev/null

echo "== TASK 02B: generated artifact discovery =="
mapfile -t GENERATED < <(find "$ARC_DIR/arc-core/build" -type f -name libarc.so -print | sort)
printf '%s\n' "${GENERATED[@]}" | tee "$OUT/generated-candidates.txt"
[ "${#GENERATED[@]}" -gt 0 ] || { echo "::error::No libarc.so generated"; exit 1; }

CANDIDATE=""
for f in "${GENERATED[@]}"; do
  if "$READELF" -h "$f" 2>/dev/null | grep -q 'Machine:.*AArch64' && printf '%s' "$f" | grep -Eq 'android|arm64-v8a|arm64|aarch64'; then
    CANDIDATE="$f"; break
  fi
done
[ -n "$CANDIDATE" ] || { echo "::error::No Android/AArch64 libarc.so candidate found"; exit 1; }
cp "$CANDIDATE" "$OUT/libarc.so"
sha256sum "$OUT/libarc.so" | tee "$OUT/sha256.txt"
stat -c 'size=%s' "$OUT/libarc.so" | tee "$OUT/size.txt"

echo "== TASK 02B: ELF inspection =="
"$READELF" -h "$OUT/libarc.so" | tee "$OUT/readelf-header.txt"
"$READELF" -l "$OUT/libarc.so" | tee "$OUT/readelf-program-headers.txt"
"$READELF" -d "$OUT/libarc.so" | tee "$OUT/readelf-dynamic.txt"
"$READELF" -Ws "$OUT/libarc.so" | tee "$OUT/readelf-symbols.txt"
"$READELF" -V "$OUT/libarc.so" | tee "$OUT/readelf-version.txt"

CLASS="$("$READELF" -h "$OUT/libarc.so" | awk -F: '/Class:/{gsub(/^ +/,"",$2); print $2}')"
MACHINE="$("$READELF" -h "$OUT/libarc.so" | awk -F: '/Machine:/{gsub(/^ +/,"",$2); print $2}')"
TYPE="$("$READELF" -h "$OUT/libarc.so" | awk -F: '/Type:/{gsub(/^ +/,"",$2); print $2}')"
OSABI="$("$READELF" -h "$OUT/libarc.so" | awk -F: '/OS\/ABI:/{gsub(/^ +/,"",$2); print $2}')"
SONAME="$("$READELF" -d "$OUT/libarc.so" | sed -n 's/.*SONAME.*\[\(.*\)\].*/\1/p' | head -n1 || true)"
"$READELF" -d "$OUT/libarc.so" | sed -n 's/.*NEEDED.*\[\(.*\)\].*/\1/p' | tee "$OUT/dt-needed.txt"

for forbidden in libpthread.so.0 libdl.so.2 libm.so.6 libc.so.6 ld-linux-aarch64.so.1 libstdc++.so.6 libgcc_s.so.1; do
  ! grep -Fxq "$forbidden" "$OUT/dt-needed.txt" || { echo "::error::Forbidden desktop dependency: $forbidden"; exit 1; }
done
! grep -Eq 'GLIBC_[0-9]|GLIBCXX_|CXXABI_|GCC_[0-9]' "$OUT/readelf-symbols.txt" "$OUT/readelf-version.txt" || { echo "::error::Desktop GNU ABI version requirement detected"; exit 1; }

JNI_COUNT="$(grep -Ec ' [TW] +Java_' "$OUT/readelf-symbols.txt" || true)"
echo "JNI symbol count: $JNI_COUNT" | tee "$OUT/jni-summary.txt"

echo "== TASK 02B: existing Arc Android prebuilt =="
mapfile -t PREBUILT < <(find "$ARC_DIR/natives/natives-android" -type f -name libarc.so -print 2>/dev/null | sort)
printf '%s\n' "${PREBUILT[@]}" | tee "$OUT/prebuilt-candidates.txt"
if [ "${#PREBUILT[@]}" -gt 0 ]; then
  for f in "${PREBUILT[@]}"; do
    d="$OUT/prebuilt-$(basename "$(dirname "$f")")"
    mkdir -p "$d"
    cp "$f" "$d/libarc.so"
    sha256sum "$f" | tee "$d/sha256.txt"
    "$READELF" -h "$f" | tee "$d/readelf-header.txt"
    "$READELF" -d "$f" | tee "$d/readelf-dynamic.txt"
    "$READELF" -Ws "$f" | tee "$d/readelf-symbols.txt"
    "$READELF" -V "$f" | tee "$d/readelf-version.txt"
  done
else
  echo "No prebuilt Android libarc.so found" | tee "$OUT/prebuilt-summary.txt"
fi

BUILD_ID="$("$READELF" -n "$OUT/libarc.so" | sed -n 's/.*Build ID: \([0-9a-fA-F]*\).*/\1/p' | head -n1 || true)"
SHA256="$(cut -d' ' -f1 "$OUT/sha256.txt")"
SIZE="$(stat -c '%s' "$OUT/libarc.so")"

cat > "$OUT/TASK_02B_RESULT.md" <<EOF
# TASK 02B — CI Proof of Android ARM64 Arc libarc.so

Status: PASS

Mindustry HEAD: $(git rev-parse HEAD)
Arc revision: $ARC_HEAD
Gradle wrapper: Arc ./gradlew
Gradle version: $GRADLE_VERSION
Build task: :arc-core:$BUILD_TASK
Artifact: $CANDIDATE
SHA256: $SHA256
Size: $SIZE
Build ID: ${BUILD_ID:-<absent>}
ELF class: $CLASS
Machine: $MACHINE
OS/ABI: $OSABI
Type: $TYPE
SONAME: ${SONAME:-<absent>}
JNI symbols: $JNI_COUNT

DT_NEEDED:
$("$READELF" -d "$OUT/libarc.so" | sed -n 's/.*NEEDED.*\[\(.*\)\].*/\1/p')
EOF

echo "TASK 02B native Android libarc build probe: PASS"
