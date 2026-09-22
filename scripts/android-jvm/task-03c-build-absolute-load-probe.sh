#!/usr/bin/env bash
set -euo pipefail

NATIVE_LIB="${1:?usage: $0 <libsdl-arc.so> [output-dir]}"
OUT_DIR="${2:-ci-artifacts/android-jvm-absolute-load-probe}"

[ -f "$NATIVE_LIB" ] || {
  echo "::error::Native library not found: $NATIVE_LIB"
  exit 1
}

[ "$(basename "$NATIVE_LIB")" = "libsdl-arc.so" ] || {
  echo "::error::Unexpected native library filename: $(basename "$NATIVE_LIB")"
  exit 1
}

ROOT="$(git rev-parse --show-toplevel)"
mkdir -p "$OUT_DIR"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SRC="$TMP/AbsolutePathNativeLoadProbe.java"
CLS="$TMP/classes"
RESOURCE_ROOT="$TMP/resources"
MANIFEST="$TMP/MANIFEST.MF"
OUT_JAR="$OUT_DIR/Mindustry-android-jvm-absolute-load-probe.jar"
RESOURCE_PATH="android-jvm-probe/native/arm64-v8a/libsdl-arc.so"

mkdir -p "$CLS" "$RESOURCE_ROOT/android-jvm-probe/native/arm64-v8a"

cat > "$SRC" <<'JAVA'
package androidjvm.probe;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.security.MessageDigest;
import java.util.Locale;

public final class AbsolutePathNativeLoadProbe{
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
        System.out.println("ABSOLUTE_LOAD_PROBE_BEGIN");

        String resourcePath = "/android-jvm-probe/native/arm64-v8a/libsdl-arc.so";
        System.out.println("ABSOLUTE_LOAD_RESOURCE=" + resourcePath);

        String tmpDirProperty = System.getProperty("java.io.tmpdir");
        System.out.println("Runtime.java.io.tmpdir=" + tmpDirProperty);
        System.out.println("Runtime.java.library.path=" + System.getProperty("java.library.path"));
        System.out.println("Runtime.LD_LIBRARY_PATH=" + System.getenv("LD_LIBRARY_PATH"));

        if(tmpDirProperty == null || tmpDirProperty.isEmpty()){
            System.out.println("ABSOLUTE_LOAD_FAIL");
            System.out.println("ABSOLUTE_LOAD_ERROR.type=java.lang.IllegalStateException");
            System.out.println("ABSOLUTE_LOAD_ERROR.message=java.io.tmpdir is missing");
            System.exit(47);
            return;
        }

        File tmpDir = new File(tmpDirProperty);
        if(!tmpDir.isAbsolute()){
            tmpDir = tmpDir.getAbsoluteFile();
        }

        File extractDir;
        try{
            extractDir = new File(tmpDir, "mindustry-android-jvm-absolute-load");
            if(!extractDir.exists() && !extractDir.mkdirs()){
                throw new IllegalStateException("Unable to create extraction directory: " + extractDir);
            }
        }catch(Throwable throwable){
            System.out.println("ABSOLUTE_LOAD_FAIL");
            printThrowable("ABSOLUTE_LOAD_ERROR", throwable);
            System.exit(47);
            return;
        }

        File target = new File(extractDir, "libsdl-arc.so").getAbsoluteFile();
        System.out.println("ABSOLUTE_LOAD_PATH=" + target.getAbsolutePath());

        try(InputStream input = AbsolutePathNativeLoadProbe.class.getResourceAsStream(resourcePath)){
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
            System.out.println("ABSOLUTE_LOAD_FAIL");
            printThrowable("ABSOLUTE_LOAD_ERROR", throwable);
            System.exit(47);
            return;
        }

        System.out.println("ABSOLUTE_LOAD_FILE_EXISTS=" + target.exists());
        System.out.println("ABSOLUTE_LOAD_FILE_REGULAR=" + target.isFile());
        System.out.println("ABSOLUTE_LOAD_FILE_READABLE=" + target.canRead());
        System.out.println("ABSOLUTE_LOAD_FILE_SIZE=" + target.length());

        if(!target.exists() || !target.isFile() || !target.canRead() || target.length() <= 0){
            System.out.println("ABSOLUTE_LOAD_FAIL");
            System.out.println("ABSOLUTE_LOAD_ERROR.type=java.lang.IllegalStateException");
            System.out.println("ABSOLUTE_LOAD_ERROR.message=Extracted native file failed filesystem validation");
            System.exit(47);
            return;
        }

        try{
            System.out.println("ABSOLUTE_LOAD_SHA256=" + sha256(target));
        }catch(Throwable throwable){
            System.out.println("ABSOLUTE_LOAD_SHA256=<unavailable>");
            printThrowable("ABSOLUTE_LOAD_SHA256_ERROR", throwable);
        }

        System.out.println("ABSOLUTE_LOAD_BEGIN");
        try{
            System.load(target.getAbsolutePath());
            System.out.println("ABSOLUTE_LOAD_PASS");
            System.out.println("PROBE_END");
        }catch(Throwable throwable){
            System.out.println("ABSOLUTE_LOAD_FAIL");
            printThrowable("ABSOLUTE_LOAD_ERROR", throwable);
            System.exit(48);
        }
    }
}
JAVA

javac -d "$CLS" "$SRC"

cat > "$MANIFEST" <<'EOF'
Manifest-Version: 1.0
Main-Class: androidjvm.probe.AbsolutePathNativeLoadProbe
EOF

OUT_NATIVE="$RESOURCE_ROOT/$RESOURCE_PATH"
cp "$NATIVE_LIB" "$OUT_NATIVE"

jar cfm "$OUT_JAR" "$MANIFEST"   -C "$CLS" androidjvm/probe/AbsolutePathNativeLoadProbe.class   -C "$RESOURCE_ROOT" "$RESOURCE_PATH"

echo "== TASK 03C-DEBUG-13A: verify absolute-load probe package =="
echo "Native library: $NATIVE_LIB"
echo "Output JAR: $OUT_JAR"

jar tf "$OUT_JAR" | grep -Fxq 'androidjvm/probe/AbsolutePathNativeLoadProbe.class'
jar tf "$OUT_JAR" | grep -Fxq "$RESOURCE_PATH"
unzip -p "$OUT_JAR" META-INF/MANIFEST.MF | tr -d '\r' | grep -Fxq 'Main-Class: androidjvm.probe.AbsolutePathNativeLoadProbe'

native_sha="$(sha256sum "$NATIVE_LIB" | awk '{print $1}')"
embedded_sha="$(unzip -p "$OUT_JAR" "$RESOURCE_PATH" | sha256sum | awk '{print $1}')"
[ "$native_sha" = "$embedded_sha" ] || {
  echo "::error::Embedded native SHA-256 mismatch: source=$native_sha embedded=$embedded_sha"
  exit 1
}

echo "Native SHA-256: $native_sha"
echo "Embedded native SHA-256: $embedded_sha"
echo "Verified probe class entry"
echo "Verified native resource entry"
echo "Verified probe Main-Class"
echo "Absolute-load probe package: PASS"
