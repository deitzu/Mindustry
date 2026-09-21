#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
JAR="$1"
OUT="$ROOT/ci-artifacts/task02c"
ARC_EXPECTED="8eb00ffff0126d0576c67df46f99b8f6bccd96fe"
PINNED_ARC_ANDROID_ARM64_SHA256="ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338"

[ -n "$JAR" ] || { echo "usage: $0 <android-jvm-mindustry-jar>"; exit 2; }
mkdir -p "$OUT"
exec > >(tee "$OUT/packaging-verification.log") 2>&1

echo "== TASK 02C: Android-JVM packaging verification =="
echo "Mindustry branch: $(git branch --show-current)"
echo "Mindustry HEAD: $(git rev-parse HEAD)"
git status --short || true

[ -f "$JAR" ] || { echo "::error::Android-JVM artifact missing: $JAR"; exit 1; }

ARC_DIR="$ROOT/../Arc"
if [ -d "$ARC_DIR/.git" ]; then
    ARC_HEAD="$(git -C "$ARC_DIR" rev-parse HEAD)"
    echo "Arc HEAD: $ARC_HEAD"
    [ "$ARC_HEAD" = "$ARC_EXPECTED" ] || { echo "::error::Arc SHA mismatch: $ARC_HEAD"; exit 1; }
fi

SDL_NATIVE_JAR="$ARC_DIR/backends/backend-sdl/libs/sdl-arc-natives-arm64-v8a.jar"
[ -d "$ARC_DIR/.git" ] || {
    echo "::error::Pinned Arc checkout is required for Android-JVM SDL packaging verification: $ARC_DIR"
    exit 1
}
[ -f "$SDL_NATIVE_JAR" ] || {
    echo "::error::Expected pinned Android ARM64 SDL native package is missing: $SDL_NATIVE_JAR"
    exit 1
}
jar tf "$SDL_NATIVE_JAR" | grep -Fxq "libsdl-arc.so" || {
    echo "::error::Pinned Android ARM64 SDL native package does not contain libsdl-arc.so: $SDL_NATIVE_JAR"
    exit 1
}
unzip -p "$SDL_NATIVE_JAR" "libsdl-arc.so" > "$OUT/source-libsdl-arc.so"
test -s "$OUT/source-libsdl-arc.so"
SDL_SOURCE_SHA="$(sha256sum "$OUT/source-libsdl-arc.so" | awk '{print $1}')"
echo "Pinned Android ARM64 SDL package libsdl-arc.so SHA256: $SDL_SOURCE_SHA" | tee "$OUT/sdl-source-sha256.txt"

sha256sum "$JAR" | tee "$OUT/jar-sha256.txt"
stat -c 'size=%s' "$JAR" | tee "$OUT/jar-size.txt"

echo "== Packaged Arc resource entries =="
unzip -Z1 "$JAR" | grep -E '(^|/)(arm64-v8a|armeabi-v7a|x86|x86_64)/libarc\.so$' | sort -u | tee "$OUT/arc-resource-entries.txt" || true
grep -Fxq 'arm64-v8a/libarc.so' "$OUT/arc-resource-entries.txt" || {
    echo "::error::Expected Android ARM64 resource arm64-v8a/libarc.so is missing"
    exit 1
}
if grep -Evx 'arm64-v8a/libarc\.so' "$OUT/arc-resource-entries.txt" | grep -q .; then
    echo "::error::Android-JVM artifact contains a non-ARM64 Arc native entry"
    exit 1
fi
if unzip -Z1 "$JAR" | grep -Eq '(^|/)libarcarm64\.so$'; then
    echo "::error::Desktop Linux libarcarm64.so was packaged into the Android-JVM artifact"
    exit 1
fi
echo "Desktop libarcarm64.so: absent"

echo "== Packaged Android SDL resource entries =="
unzip -Z1 "$JAR" | grep -E "(^|/)(arm64-v8a|armeabi-v7a|x86|x86_64)/libsdl-arc\.so$" | sort -u | tee "$OUT/sdl-resource-entries.txt" || true
grep -Fxq "arm64-v8a/libsdl-arc.so" "$OUT/sdl-resource-entries.txt" || {
    echo "::error::Expected Android ARM64 resource arm64-v8a/libsdl-arc.so is missing"
    exit 1
}
if grep -Evx "arm64-v8a/libsdl-arc\.so" "$OUT/sdl-resource-entries.txt" | grep -q .; then
    echo "::error::Android-JVM artifact contains a non-ARM64 SDL native entry"
    exit 1
fi
if unzip -Z1 "$JAR" | grep -Eq "(^|/)(libsdl-arcarm64\.so|libSDL2-2\.0\.so\.0)$"; then
    echo "::error::Desktop Linux SDL native library was packaged into the Android-JVM artifact"
    exit 1
fi
echo "Desktop SDL native variants: absent"

unzip -p "$JAR" 'arm64-v8a/libarc.so' > "$OUT/libarc.so"
test -s "$OUT/libarc.so"

unzip -p "$JAR" "arm64-v8a/libsdl-arc.so" > "$OUT/libsdl-arc.so"
test -s "$OUT/libsdl-arc.so"
PACKAGED_SDL_SHA="$(sha256sum "$OUT/libsdl-arc.so" | awk '{print $1}')"
echo "Packaged libsdl-arc.so SHA256: $PACKAGED_SDL_SHA" | tee "$OUT/sdl-packaged-sha256.txt"
[ "$PACKAGED_SDL_SHA" = "$SDL_SOURCE_SHA" ] || {
    echo "::error::Packaged libsdl-arc.so does not match the pinned Arc Android ARM64 SDL native package"
    exit 1
}
echo "Packaged libsdl-arc.so matches the pinned Arc Android ARM64 SDL package"

READELF="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf"
if [ ! -x "$READELF" ]; then
    READELF="$(command -v llvm-readelf || command -v readelf || true)"
fi
[ -n "$READELF" ] && [ -x "$READELF" ] || { echo "::error::No usable readelf/llvm-readelf found"; exit 1; }

"$READELF" -h "$OUT/libarc.so" | tee "$OUT/readelf-header.txt"
"$READELF" -l "$OUT/libarc.so" | tee "$OUT/readelf-program-headers.txt"
"$READELF" -d "$OUT/libarc.so" | tee "$OUT/readelf-dynamic.txt"
"$READELF" -Ws "$OUT/libarc.so" | tee "$OUT/readelf-symbols.txt"
"$READELF" -V "$OUT/libarc.so" | tee "$OUT/readelf-version.txt"

CLASS="$("$READELF" -h "$OUT/libarc.so" | awk -F: '/Class:/{gsub(/^ +/,"",$2); print $2}')"
MACHINE="$("$READELF" -h "$OUT/libarc.so" | awk -F: '/Machine:/{gsub(/^ +/,"",$2); print $2}')"
TYPE="$("$READELF" -h "$OUT/libarc.so" | awk -F: '/Type:/{gsub(/^ +/,"",$2); print $2}')"
SONAME="$("$READELF" -d "$OUT/libarc.so" | sed -n 's/.*SONAME.*\[\(.*\)\].*/\1/p' | head -n1 || true)"
"$READELF" -d "$OUT/libarc.so" | sed -n 's/.*NEEDED.*\[\(.*\)\].*/\1/p' | tee "$OUT/dt-needed.txt"

[ "$CLASS" = "ELF64" ] || { echo "::error::Unexpected ELF class: $CLASS"; exit 1; }
printf '%s' "$MACHINE" | grep -q 'AArch64' || { echo "::error::Unexpected ELF machine: $MACHINE"; exit 1; }
printf '%s' "$TYPE" | grep -q 'DYN' || { echo "::error::Unexpected ELF type: $TYPE"; exit 1; }
[ "$SONAME" = "libarc.so" ] || { echo "::error::Unexpected SONAME: $SONAME"; exit 1; }

for forbidden in libpthread.so.0 libdl.so.2 libm.so.6 libc.so.6 libstdc++.so.6 libgcc_s.so.1 ld-linux-aarch64.so.1; do
    ! grep -Fxq "$forbidden" "$OUT/dt-needed.txt" || {
        echo "::error::Forbidden desktop dependency: $forbidden"
        exit 1
    }
done

! grep -Eq 'GLIBC_[0-9]|GLIBCXX_|CXXABI_|GCC_[0-9]' "$OUT/readelf-symbols.txt" "$OUT/readelf-version.txt" || {
    echo "::error::Desktop GNU ABI version requirement detected"
    exit 1
}

JNI_COUNT="$("$READELF" -Ws "$OUT/libarc.so" | awk '$0 ~ /Java_/ && $5 == "GLOBAL" && $6 == "DEFAULT" && $7 != "UND" {c++} END{print c+0}')"
echo "JNI exported Java_* symbols: $JNI_COUNT" | tee "$OUT/jni-summary.txt"
[ "$JNI_COUNT" -gt 0 ] || { echo "::error::No exported Java_* JNI symbols found"; exit 1; }

PACKAGED_SHA="$(sha256sum "$OUT/libarc.so" | awk '{print $1}')"
echo "Packaged libarc.so SHA256: $PACKAGED_SHA"
[ "$PACKAGED_SHA" = "$PINNED_ARC_ANDROID_ARM64_SHA256" ] || {
    echo "::error::Packaged libarc.so does not match pinned Arc natives-android arm64-v8a artifact"
    exit 1
}

BUILD_ID="$("$READELF" -n "$OUT/libarc.so" | sed -n 's/.*Build ID: \([0-9a-fA-F]*\).*/\1/p' | head -n1 || true)"

cat > "$OUT/TASK_02C_ARTIFACT_RESULT.md" <<EOF
# TASK 02C — Android-JVM packaged Arc artifact verification

JAR: $JAR
JAR SHA256: $(cut -d' ' -f1 "$OUT/jar-sha256.txt")
Packaged resource: arm64-v8a/libarc.so
libarc.so SHA256: $PACKAGED_SHA
libsdl-arc.so SHA256: $PACKAGED_SDL_SHA
Pinned Arc Android ARM64 SDL package: $SDL_NATIVE_JAR
Pinned Arc Android ARM64 SDL package libsdl-arc.so SHA256: $SDL_SOURCE_SHA
Pinned Arc SHA: $ARC_EXPECTED
Pinned Arc natives-android arm64-v8a SHA256: $PINNED_ARC_ANDROID_ARM64_SHA256
Build ID: $BUILD_ID
ELF class: $CLASS
Machine: $MACHINE
Type: $TYPE
SONAME: $SONAME
JNI exported Java_* symbols: $JNI_COUNT

Direct DT_NEEDED:
$(cat "$OUT/dt-needed.txt")

Desktop libarcarm64.so: absent
Desktop/glibc dependencies: absent
GNU desktop ABI version requirements: absent
EOF

echo "TASK 02C Android-JVM packaging artifact verification: PASS"
