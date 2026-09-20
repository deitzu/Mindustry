#!/usr/bin/env bash
set -euo pipefail

NATIVE_LIB="${1:?usage: $0 <libsdl-arc.so> [output-dir]}"
OUT_DIR="${2:-ci-artifacts/android-jvm-android-jni-glue-load-probe}"

ARC_EXPECTED="8eb00ffff0126d0576c67df46f99b8f6bccd96fe"
SDL_VERSION="2.32.8"
SDL_COMMIT="98d1f3a45aae568ccd6ed5fec179330f47d4d356"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
ARC_DIR="$ROOT/../Arc"
SDL_ROOT="$ROOT/../SDL2-$SDL_VERSION"
SDL_VERSION_HEADER="$SDL_ROOT/include/SDL_version.h"
OUT_JAR="$OUT_DIR/Mindustry-android-jvm-android-jni-glue-load-probe.jar"
RESOURCE_PATH="android-jvm-probe/native/arm64-v8a/libsdl-arc.so"
ANDROID_JAVA_ROOT="$SDL_ROOT/android-project/app/src/main/java"

ACTIVITY_SOURCE="$ANDROID_JAVA_ROOT/org/libsdl/app/SDLActivity.java"
SDL_SOURCE="$ANDROID_JAVA_ROOT/org/libsdl/app/SDL.java"
AUDIO_SOURCE="$ANDROID_JAVA_ROOT/org/libsdl/app/SDLAudioManager.java"
CONTROLLER_SOURCE="$ANDROID_JAVA_ROOT/org/libsdl/app/SDLControllerManager.java"
DIRECT_CLASSES=(SDLActivity SDLInputConnection SDLAudioManager SDLControllerManager)
EXTRA_CLASSES=(SDLJoystickHandler SDLJoystickHandler_API16 SDLJoystickHandler_API19 SDLHapticHandler SDLHapticHandler_API26)
PACKAGE_CLASSES=("${DIRECT_CLASSES[@]}" "${EXTRA_CLASSES[@]}")

[ -f "$NATIVE_LIB" ] || {
  echo "::error::Native library not found: $NATIVE_LIB"
  exit 1
}

[ "$(basename "$NATIVE_LIB")" = "libsdl-arc.so" ] || {
  echo "::error::Unexpected native library filename: $(basename "$NATIVE_LIB")"
  exit 1
}

echo "== DEBUG-14-CI-01: verify authoritative Arc checkout == "
pwd -P
echo "ROOT=$ROOT"
echo "ARC_DIR=$ARC_DIR"
[ -d "$ARC_DIR" ] || {
  echo "::error::Arc directory missing: $ARC_DIR"
  exit 1
}
[ -e "$ARC_DIR/.git" ] || {
  echo "::error::Arc Git metadata missing: $ARC_DIR/.git"
  exit 1
}
for expected in build.gradle gradle.properties settings.gradle; do
  [ -e "$ARC_DIR/$expected" ] || {
    echo "::error::Expected Arc file missing: $ARC_DIR/$expected"
    exit 1
  }
done

if ! actual_arc="$(git -C "$ARC_DIR" rev-parse HEAD)"; then
  echo "::error::Arc HEAD resolution failed at: $ARC_DIR"
  exit 1
fi
[ "$actual_arc" = "$ARC_EXPECTED" ] || {
  echo "::error::Arc revision mismatch: expected $ARC_EXPECTED, got $actual_arc"
  exit 1
}
echo "Arc revision verified by single late-stage Git query: $actual_arc"

if ! git -C "$SDL_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "== TASK 03C-DEBUG-14: obtain authoritative SDL $SDL_VERSION checkout =="
  rm -rf "$SDL_ROOT"
  git clone --no-tags --depth=1 --branch "release-$SDL_VERSION" https://github.com/libsdl-org/SDL "$SDL_ROOT"
fi

actual_sdl_commit="$(git -C "$SDL_ROOT" rev-parse HEAD)"
[ "$actual_sdl_commit" = "$SDL_COMMIT" ] || {
  echo "::error::SDL revision mismatch: expected $SDL_COMMIT, got $actual_sdl_commit"
  exit 1
}

[ -f "$SDL_VERSION_HEADER" ] || {
  echo "::error::SDL headers not found after checkout: $SDL_ROOT"
  exit 1
}

header_version="$(awk '/^#define SDL_MAJOR_VERSION[[:space:]]/ {major=$3} /^#define SDL_MINOR_VERSION[[:space:]]/ {minor=$3} /^#define SDL_PATCHLEVEL[[:space:]]/ {patch=$3} END {if(major == "" || minor == "" || patch == "") exit 1; print major "." minor "." patch}' "$SDL_VERSION_HEADER")"
[ "$header_version" = "$SDL_VERSION" ] || {
  echo "::error::SDL version mismatch: expected $SDL_VERSION, got $header_version"
  exit 1
}

for source in "$ACTIVITY_SOURCE" "$SDL_SOURCE" "$AUDIO_SOURCE" "$CONTROLLER_SOURCE"; do
  [ -f "$source" ] || {
    echo "::error::Required SDL Android Java source not found: $source"
    exit 1
  }
done

grep -Eq "^[[:space:]]*class[[:space:]]+SDLJoystickHandler[[:space:]]*[{]" "$CONTROLLER_SOURCE" || {
  echo "::error::Expected SDLJoystickHandler class declaration not found: $CONTROLLER_SOURCE"
  exit 1
}

grep -Eq "^[[:space:]]*class[[:space:]]+SDLJoystickHandler_API16[[:space:]]+extends[[:space:]]+SDLJoystickHandler[[:space:]]*[{]" "$CONTROLLER_SOURCE" || {
  echo "::error::Expected SDLJoystickHandler_API16 extends SDLJoystickHandler declaration not found: $CONTROLLER_SOURCE"
  exit 1
}

grep -Eq "^[[:space:]]*class[[:space:]]+SDLJoystickHandler_API19[[:space:]]+extends[[:space:]]+SDLJoystickHandler_API16[[:space:]]*[{]" "$CONTROLLER_SOURCE" || {
  echo "::error::Expected SDLJoystickHandler_API19 extends SDLJoystickHandler_API16 declaration not found: $CONTROLLER_SOURCE"
  exit 1
}

grep -Eq "^[[:space:]]*class[[:space:]]+SDLHapticHandler[[:space:]]*[{]" "$CONTROLLER_SOURCE" || {
  echo "::error::Expected SDLHapticHandler class declaration not found: $CONTROLLER_SOURCE"
  exit 1
}

grep -Eq "^[[:space:]]*class[[:space:]]+SDLHapticHandler_API26[[:space:]]+extends[[:space:]]+SDLHapticHandler[[:space:]]*[{]" "$CONTROLLER_SOURCE" || {
  echo "::error::Expected SDLHapticHandler_API26 extends SDLHapticHandler declaration not found: $CONTROLLER_SOURCE"
  exit 1
}

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


    private static String classLoaderName(ClassLoader loader){
        return loader == null ? "<null>" : loader.getClass().getName();
    }

    private static void printClassVisibility(String label, String className, String resourceName, ClassLoader loader){
        System.out.println(label + "_LOADER_CLASS=" + classLoaderName(loader));

        if(loader == null){
            System.out.println(label + "_VISIBLE=false");
            System.out.println(label + "_ERROR.type=java.lang.IllegalStateException");
            System.out.println(label + "_ERROR.message=ClassLoader is null");
            System.out.println(label + "_RESOURCE=<null-loader>");
            return;
        }

        try{
            Class<?> resolved = Class.forName(className, false, loader);
            System.out.println(label + "_VISIBLE=true");

            ClassLoader resolvedLoader = resolved.getClassLoader();
            System.out.println(label + "_RESOLVED_LOADER_CLASS=" + classLoaderName(resolvedLoader));

            try{
                java.security.ProtectionDomain domain = resolved.getProtectionDomain();
                java.security.CodeSource codeSource = domain == null ? null : domain.getCodeSource();
                System.out.println(label + "_CODE_SOURCE=" +
                    (codeSource == null || codeSource.getLocation() == null ? "<null>" : codeSource.getLocation()));
            }catch(Throwable throwable){
                System.out.println(label + "_CODE_SOURCE=<unavailable>");
            }
        }catch(Throwable throwable){
            System.out.println(label + "_VISIBLE=false");
            System.out.println(label + "_ERROR.type=" + throwable.getClass().getName());
            System.out.println(label + "_ERROR.message=" + throwable.getMessage());
        }

        try{
            java.net.URL resource = loader.getResource(resourceName);
            System.out.println(label + "_RESOURCE=" + (resource == null ? "<null>" : resource.toString()));
        }catch(Throwable throwable){
            System.out.println(label + "_RESOURCE=<error:" + throwable.getClass().getName() + ">");
        }
    }

    private static void printClassLoaderVisibilityDiagnostics(){
        final String joystickClassName = "org.libsdl.app.SDLJoystickHandler";
        final String joystickResourceName = "org/libsdl/app/SDLJoystickHandler.class";
        final String hapticClassName = "org.libsdl.app.SDLHapticHandler";
        final String hapticResourceName = "org/libsdl/app/SDLHapticHandler.class";
        final String hapticApi26ClassName = "org.libsdl.app.SDLHapticHandler_API26";
        final String hapticApi26ResourceName = "org/libsdl/app/SDLHapticHandler_API26.class";

        System.out.println("ANDROID_JNI_CLASS_VISIBILITY_BEGIN");
        System.out.println("ANDROID_JNI_CLASS_JAVA_CLASS_PATH=" + System.getProperty("java.class.path"));

        try{
            java.security.ProtectionDomain domain = AbsolutePathAndroidJniGlueLoadProbe.class.getProtectionDomain();
            java.security.CodeSource codeSource = domain == null ? null : domain.getCodeSource();
            System.out.println("ANDROID_JNI_CLASS_CODE_SOURCE=" +
                (codeSource == null || codeSource.getLocation() == null ? "<null>" : codeSource.getLocation()));
        }catch(Throwable throwable){
            System.out.println("ANDROID_JNI_CLASS_CODE_SOURCE=<unavailable>");
        }

        ClassLoader systemLoader = ClassLoader.getSystemClassLoader();
        printClassVisibility("ANDROID_JNI_CLASS_SYSTEM", joystickClassName, joystickResourceName, systemLoader);
        printClassVisibility("ANDROID_JNI_HAPTIC_BASE_SYSTEM", hapticClassName, hapticResourceName, systemLoader);
        printClassVisibility("ANDROID_JNI_HAPTIC_API26_SYSTEM", hapticApi26ClassName, hapticApi26ResourceName, systemLoader);

        ClassLoader probeLoader = AbsolutePathAndroidJniGlueLoadProbe.class.getClassLoader();
        printClassVisibility("ANDROID_JNI_CLASS_PROBE", joystickClassName, joystickResourceName, probeLoader);
        printClassVisibility("ANDROID_JNI_HAPTIC_BASE_PROBE", hapticClassName, hapticResourceName, probeLoader);
        printClassVisibility("ANDROID_JNI_HAPTIC_API26_PROBE", hapticApi26ClassName, hapticApi26ResourceName, probeLoader);

        ClassLoader contextLoader = Thread.currentThread().getContextClassLoader();
        printClassVisibility("ANDROID_JNI_CLASS_CONTEXT", joystickClassName, joystickResourceName, contextLoader);
        printClassVisibility("ANDROID_JNI_HAPTIC_BASE_CONTEXT", hapticClassName, hapticResourceName, contextLoader);
        printClassVisibility("ANDROID_JNI_HAPTIC_API26_CONTEXT", hapticApi26ClassName, hapticApi26ResourceName, contextLoader);

        System.out.println("ANDROID_JNI_CLASS_RESOURCE_SYSTEM=" +
            (systemLoader == null ? "<null-loader>" :
                String.valueOf(systemLoader.getResource(joystickResourceName))));
        System.out.println("ANDROID_JNI_CLASS_RESOURCE_PROBE=" +
            (probeLoader == null ? "<null-loader>" :
                String.valueOf(probeLoader.getResource(joystickResourceName))));
        System.out.println("ANDROID_JNI_CLASS_RESOURCE_CONTEXT=" +
            (contextLoader == null ? "<null-loader>" :
                String.valueOf(contextLoader.getResource(joystickResourceName))));
        System.out.println("ANDROID_JNI_HAPTIC_BASE_RESOURCE_SYSTEM=" +
            (systemLoader == null ? "<null-loader>" :
                String.valueOf(systemLoader.getResource(hapticResourceName))));
        System.out.println("ANDROID_JNI_HAPTIC_BASE_RESOURCE_PROBE=" +
            (probeLoader == null ? "<null-loader>" :
                String.valueOf(probeLoader.getResource(hapticResourceName))));
        System.out.println("ANDROID_JNI_HAPTIC_BASE_RESOURCE_CONTEXT=" +
            (contextLoader == null ? "<null-loader>" :
                String.valueOf(contextLoader.getResource(hapticResourceName))));
        System.out.println("ANDROID_JNI_HAPTIC_API26_RESOURCE_SYSTEM=" +
            (systemLoader == null ? "<null-loader>" :
                String.valueOf(systemLoader.getResource(hapticApi26ResourceName))));
        System.out.println("ANDROID_JNI_HAPTIC_API26_RESOURCE_PROBE=" +
            (probeLoader == null ? "<null-loader>" :
                String.valueOf(probeLoader.getResource(hapticApi26ResourceName))));
        System.out.println("ANDROID_JNI_HAPTIC_API26_RESOURCE_CONTEXT=" +
            (contextLoader == null ? "<null-loader>" :
                String.valueOf(contextLoader.getResource(hapticApi26ResourceName))));

        System.out.println("ANDROID_JNI_CLASS_VISIBILITY_END");
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

        printClassLoaderVisibilityDiagnostics();

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
  "$SDL_SOURCE" \
  "$AUDIO_SOURCE" \
  "$CONTROLLER_SOURCE" \
  "$PROBE_SRC"

echo "== TASK 03C-DEBUG-18: stage DEBUG-17 classes plus exactly SDLHapticHandler and SDLHapticHandler_API26 =="

for class_name in "${PACKAGE_CLASSES[@]}"; do
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
  'org/libsdl/app/SDLAudioManager.class'
  'org/libsdl/app/SDLControllerManager.class'
  'org/libsdl/app/SDLInputConnection.class'
  'org/libsdl/app/SDLJoystickHandler.class'
  'org/libsdl/app/SDLJoystickHandler_API16.class'
  'org/libsdl/app/SDLJoystickHandler_API19.class'
  'org/libsdl/app/SDLHapticHandler.class'
  'org/libsdl/app/SDLHapticHandler_API26.class'
)

diff -u \
  <(printf '%s\n' "${expected_java_classes[@]}") \
  <(printf '%s\n' "${packaged_java_classes[@]}")

if printf '%s\n' "${packaged_java_classes[@]}" | grep -Fxq 'org/libsdl/app/SDLHapticHandler$SDLHaptic.class'; then
  echo "::error::Speculative nested SDLHapticHandler$SDLHaptic.class was packaged"
  exit 1
fi

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
printf '  %s\n' "$ACTIVITY_SOURCE" "$SDL_SOURCE" "$AUDIO_SOURCE" "$CONTROLLER_SOURCE"
echo "DEBUG-14 direct JNI_OnLoad Java classes:"
printf '  %s\n' "${DIRECT_CLASSES[@]}"
echo "DEBUG-18 additional Java classes:"
printf '  %s\n' "${EXTRA_CLASSES[@]}"
echo "SDLInputConnection source declaration: SDLActivity.java (top-level class)"
echo "SDLJoystickHandler/API16/API19 and SDLHapticHandler/API26 source location: SDLControllerManager.java (top-level package-private classes)"
echo "Native SHA-256: $native_sha"
echo "Embedded native SHA-256: $embedded_sha"
echo "Verified DEBUG-17 seven SDL classes plus exactly SDLHapticHandler and SDLHapticHandler_API26"
echo "Verified real libsdl-arc.so resource"
echo "Android JNI glue absolute-load diagnostic package: PASS"
