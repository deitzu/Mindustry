#!/usr/bin/env bash
set -euo pipefail

NATIVE_LIB="${1:?usage: $0 <libsdl-arc.so> [output-dir]}"
OUT_DIR="${2:-ci-artifacts/android-jvm-android-jni-glue-load-probe}"

ARC_EXPECTED="8eb00ffff0126d0576c67df46f99b8f6bccd96fe"
SDL_VERSION="2.32.8"
SDL_COMMIT="98d1f3a45aae568ccd6ed5fec179330f47d4d356"

ROOT="$(git rev-parse --show-toplevel)"
ARC_DIR="$ROOT/../Arc"
SDL_ROOT="$ROOT/../SDL2-$SDL_VERSION"
OUT_JAR="$OUT_DIR/Mindustry-android-jvm-android-jni-glue-load-probe.jar"
RESOURCE_PATH="android-jvm-probe/native/arm64-v8a/libsdl-arc.so"
ANDROID_JAVA_ROOT="$SDL_ROOT/android-project/app/src/main/java"

ACTIVITY_SOURCE="$ANDROID_JAVA_ROOT/org/libsdl/app/SDLActivity.java"
SDL_SOURCE="$ANDROID_JAVA_ROOT/org/libsdl/app/SDL.java"
AUDIO_SOURCE="$ANDROID_JAVA_ROOT/org/libsdl/app/SDLAudioManager.java"
CONTROLLER_SOURCE="$ANDROID_JAVA_ROOT/org/libsdl/app/SDLControllerManager.java"
INPUT_SOURCE="$ANDROID_JAVA_ROOT/org/libsdl/app/SDLInputConnection.java"
DIRECT_CLASSES=(SDLActivity SDLInputConnection SDLAudioManager SDLControllerManager)

[ -f "$NATIVE_LIB" ] || {
  echo "::error::Native library not found: $NATIVE_LIB"
  exit 1
}

[ "$(basename "$NATIVE_LIB")" = "libsdl-arc.so" ] || {
  echo "::error::Unexpected native library filename: $(basename "$NATIVE_LIB")"
  exit 1
}

actual_arc="$(git -C "$ARC_DIR" rev-parse HEAD)"
[ "$actual_arc" = "$ARC_EXPECTED" ] || {
  echo "::error::Arc revision mismatch: expected $ARC_EXPECTED, got $actual_arc"
  exit 1
}

if [ ! -f "$SDL_ROOT/include/SDL2/SDL_version.h" ]; then
  echo "== TASK 03C-DEBUG-14: obtain SDL $SDL_VERSION independently =="
  rm -rf "$SDL_ROOT"
  git clone --no-tags --depth=1 --branch "$SDL_VERSION" https://github.com/libsdl-org/SDL "$SDL_ROOT"
fi

actual_sdl_commit="$(git -C "$SDL_ROOT" rev-parse HEAD)"
[ "$actual_sdl_commit" = "$SDL_COMMIT" ] || {
  echo "::error::SDL revision mismatch: expected $SDL_COMMIT, got $actual_sdl_commit"
  exit 1
}

[ -f "$SDL_ROOT/include/SDL2/SDL_version.h" ] || {
  echo "::error::SDL headers not found after checkout: $SDL_ROOT"
  exit 1
}

header_version="$(awk '/^#define SDL_MAJOR_VERSION[[:space:]]/ {major=$3} /^#define SDL_MINOR_VERSION[[:space:]]/ {minor=$3} /^#define SDL_PATCHLEVEL[[:space:]]/ {patch=$3} END {if(major == "" || minor == "" || patch == "") exit 1; print major "." minor "." patch}' "$SDL_ROOT/include/SDL2/SDL_version.h")"
[ "$header_version" = "$SDL_VERSION" ] || {
  echo "::error::SDL version mismatch: expected $SDL_VERSION, got $header_version"
  exit 1
}

for source in "$ACTIVITY_SOURCE" "$INPUT_SOURCE" "$SDL_SOURCE" "$AUDIO_SOURCE" "$CONTROLLER_SOURCE"; do
  [ -f "$source" ] || {
    echo "::error::Required SDL Android Java source not found: $source"
    exit 1
  }
done

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[ -n "$SDK_ROOT" ] || {
  echo "::error::Android SDK root is not configured"
  exit 1
}

ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-36}"
ANDROID_JAR="$SDK_ROOT/platforms/android-$ANDROID_API_LEVEL/android.jar"
[ -f "$ANDROID_JAR" ] || {
  echo "::error::Android platform android-$ANDROID_API_LEVEL missing: $ANDROID_JAR"
  exit 1
}

mkdir -p "$OUT_DIR"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PROBE_SRC="$TMP/AbsolutePathAndroidJniGlueLoadProbe.java"
CLS="$TMP/classes"
STAGE="$TMP/stage"
MANIFEST="$TMP/MANIFEST.MF"

mkdir -p "$CLS" "$STAGE/org/libsdl/app" "$STAGE/androidjvm/probe" "$(dirname "$STAGE/$RESOURCE_PATH")"

cat > "$PROBE_SRC" <<'JAVA'
package androidjvm.probe;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.security.MessageDigest;
import java.util.Locale;

public final class AbsolutePathAndroidJniGlueLoadProbe{
    private static void printThrowable(String label, Throwable throwable){
        System.out.println(label + ".type=" + throwable.getClass().getName());
        System.out.println(label + ".message=" + throwable.getMessage());

        int depth = 0;
        Throwable cause = throwable;
        while(cause != null && depth < 8){
            System.out.println(label + ".cause[" + depth + "].type=" + cause.getClass().getName());
            System.out.println(label + ".cause[" + depth + "].message=" + cause.getMessage());
            cause = cause.getCause();
            depth++;
        }

        throwable.printStackTrace(System.out);
    }

    private static String sha256(File file) throws Exception{
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] buffer = new byte[8192];
        try(InputStream input = new FileInputStream(file)){
            int length;
            while((length = input.read(buffer)) != -1){
                digest.update(buffer, 0, length);
            }
        }

        StringBuilder out = new StringBuilder();
        for(byte value : digest.digest()){
            out.append(String.format(Locale.ROOT, "%02x", value));
        }
        return out.toString();
    }

    public static void main(String[] args){
        System.out.println("PROBE_START");
        System.out.println("ANDROID_JNI_GLUE_LOAD_PROBE_BEGIN");

        String resourcePath = "/android-jvm-probe/native/arm64-v8a/libsdl-arc.so";
        System.out.println("ANDROID_JNI_GLUE_NATIVE_RESOURCE=" + resourcePath);
        System.out.println("Runtime.java.io.tmpdir=" + System.getProperty("java.io.tmpdir"));
        System.out.println("Runtime.java.library.path=" + System.getProperty("java.library.path"));
        System.out.println("Runtime.LD_LIBRARY_PATH=" + System.getenv("LD_LIBRARY_PATH"));

        String tmpDirProperty = System.getProperty("java.io.tmpdir");
        if(tmpDirProperty == null || tmpDirProperty.isEmpty()){
            System.out.println("ANDROID_JNI_GLUE_LOAD_FAIL");
            System.out.println("ANDROID_JNI_GLUE_LOAD_ERROR.type=java.lang.IllegalStateException");
            System.out.println("ANDROID_JNI_GLUE_LOAD_ERROR.message=java.io.tmpdir is missing");
            System.exit(47);
            return;
        }

        File extractDir = new File(tmpDirProperty, "mindustry-android-jvm-android-jni-glue-load");
        if(!extractDir.isAbsolute()){
            extractDir = extractDir.getAbsoluteFile();
        }

        try{
            if(!extractDir.exists() && !extractDir.mkdirs()){
                throw new IllegalStateException("Unable to create extraction directory: " + extractDir);
            }
        }catch(Throwable throwable){
            System.out.println("ANDROID_JNI_GLUE_LOAD_FAIL");
            printThrowable("ANDROID_JNI_GLUE_LOAD_ERROR", throwable);
            System.exit(47);
            return;
        }

        File target = new File(extractDir, "libsdl-arc.so").getAbsoluteFile();
        System.out.println("ANDROID_JNI_GLUE_LOAD_PATH=" + target.getAbsolutePath());

        try(InputStream input = AbsolutePathAndroidJniGlueLoadProbe.class.getResourceAsStream(resourcePath)){
            if(input == null){
                throw new IllegalStateException("Embedded native resource not found: " + resourcePath);
            }

            try(FileOutputStream output = new FileOutputStream(target, false)){
                byte[] buffer = new byte[8192];
                int length;
                while((length = input.read(buffer)) != -1){
                    output.write(buffer, 0, length);
                }
            }
        }catch(Throwable throwable){
            System.out.println("ANDROID_JNI_GLUE_LOAD_FAIL");
            printThrowable("ANDROID_JNI_GLUE_LOAD_ERROR", throwable);
            System.exit(47);
            return;
        }

        System.out.println("ANDROID_JNI_GLUE_FILE_EXISTS=" + target.exists());
        System.out.println("ANDROID_JNI_GLUE_FILE_REGULAR=" + target.isFile());
        System.out.println("ANDROID_JNI_GLUE_FILE_READABLE=" + target.canRead());
        System.out.println("ANDROID_JNI_GLUE_FILE_SIZE=" + target.length());

        if(!target.exists() || !target.isFile() || !target.canRead() || target.length() <= 0){
            System.out.println("ANDROID_JNI_GLUE_LOAD_FAIL");
            System.out.println("ANDROID_JNI_GLUE_LOAD_ERROR.type=java.lang.IllegalStateException");
            System.out.println("ANDROID_JNI_GLUE_LOAD_ERROR.message=Extracted native file failed filesystem validation");
            System.exit(47);
            return;
        }

        try{
            System.out.println("ANDROID_JNI_GLUE_SHA256=" + sha256(target));
        }catch(Throwable throwable){
            System.out.println("ANDROID_JNI_GLUE_SHA256=<unavailable>");
            printThrowable("ANDROID_JNI_GLUE_SHA256_ERROR", throwable);
        }

        System.out.println("ANDROID_JNI_GLUE_LOAD_BEGIN");
        try{
            System.load(target.getAbsolutePath());
            System.out.println("ANDROID_JNI_GLUE_LOAD_PASS");
            System.out.println("PROBE_END");
        }catch(Throwable throwable){
            System.out.println("ANDROID_JNI_GLUE_LOAD_FAIL");
            printThrowable("ANDROID_JNI_GLUE_LOAD_ERROR", throwable);
            System.exit(48);
        }
    }
}
JAVA

echo "== TASK 03C-DEBUG-14: compile exact SDL 2.32.8 Android Java JNI glue sources =="

javac -source 8 -target 8 -proc:none \
  -cp "$ANDROID_JAR" \
  -sourcepath "$ANDROID_JAVA_ROOT" \
  -d "$CLS" \
  "$ACTIVITY_SOURCE" \
  "$INPUT_SOURCE" \
  "$SDL_SOURCE" \
  "$AUDIO_SOURCE" \
  "$CONTROLLER_SOURCE" \
  "$PROBE_SRC"

echo "== TASK 03C-DEBUG-14: stage only four direct JNI_OnLoad classes =="

for class_name in "${DIRECT_CLASSES[@]}"; do
  class_file="$CLS/org/libsdl/app/$class_name.class"
  [ -f "$class_file" ] || {
    echo "::error::Expected JNI_OnLoad class missing: $class_file"
    exit 1
  }
  cp "$class_file" "$STAGE/org/libsdl/app/"
done

cp "$CLS/androidjvm/probe/AbsolutePathAndroidJniGlueLoadProbe.class" "$STAGE/androidjvm/probe/"
cp "$NATIVE_LIB" "$STAGE/$RESOURCE_PATH"

cat > "$MANIFEST" <<'EOF'
Manifest-Version: 1.0
Main-Class: androidjvm.probe.AbsolutePathAndroidJniGlueLoadProbe
EOF

jar cfm "$OUT_JAR" "$MANIFEST" \
  -C "$STAGE" androidjvm/probe/AbsolutePathAndroidJniGlueLoadProbe.class \
  -C "$STAGE" org/libsdl/app \
  -C "$STAGE" android-jvm-probe/native/arm64-v8a/libsdl-arc.so

echo "== TASK 03C-DEBUG-14: verify exact diagnostic package =="

jar tf "$OUT_JAR" | grep -Fxq 'androidjvm/probe/AbsolutePathAndroidJniGlueLoadProbe.class'
jar tf "$OUT_JAR" | grep -Fxq "$RESOURCE_PATH"

mapfile -t packaged_java_classes < <(
  jar tf "$OUT_JAR" |
    grep -E '^org/libsdl/app/[^/]+\.class$' |
    sort
)

expected_java_classes=(
  'org/libsdl/app/SDLActivity.class'
  'org/libsdl/app/SDLInputConnection.class'
  'org/libsdl/app/SDLAudioManager.class'
  'org/libsdl/app/SDLControllerManager.class'
)

diff -u \
  <(printf '%s\n' "${expected_java_classes[@]}") \
  <(printf '%s\n' "${packaged_java_classes[@]}")

unzip -p "$OUT_JAR" META-INF/MANIFEST.MF |
  tr -d '\r' |
  grep -Fxq 'Main-Class: androidjvm.probe.AbsolutePathAndroidJniGlueLoadProbe'

native_sha="$(sha256sum "$NATIVE_LIB" | awk '{print $1}')"
embedded_sha="$(unzip -p "$OUT_JAR" "$RESOURCE_PATH" | sha256sum | awk '{print $1}')"

[ "$native_sha" = "$embedded_sha" ] || {
  echo "::error::Embedded native SHA-256 mismatch: source=$native_sha embedded=$embedded_sha"
  exit 1
}

echo "Arc revision: $actual_arc"
echo "SDL source version: $header_version"
echo "SDL source commit: $actual_sdl_commit"
echo "Android API jar: $ANDROID_JAR"
echo "SDL Android Java source files:"
printf '  %s\n' "$ACTIVITY_SOURCE" "$INPUT_SOURCE" "$SDL_SOURCE" "$AUDIO_SOURCE" "$CONTROLLER_SOURCE"
echo "Direct JNI_OnLoad Java classes:"
printf '  %s\n' "${DIRECT_CLASSES[@]}"
echo "SDLInputConnection source declaration: SDLActivity.java (top-level class)"
echo "Native SHA-256: $native_sha"
echo "Embedded native SHA-256: $embedded_sha"
echo "Verified exact four direct JNI_OnLoad classes only"
echo "Verified real libsdl-arc.so resource"
echo "Android JNI glue absolute-load diagnostic package: PASS"
