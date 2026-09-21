#!/usr/bin/env bash
set -euo pipefail

MINDUSTRY_JAR="${1:?usage: $0 <Mindustry-android-jvm.jar> [output-dir]}"
OUT_DIR="${2:-ci-artifacts/task02d}"
EXPECTED_ARC_SHA256="ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338"

[ -f "$MINDUSTRY_JAR" ] || {
    echo "::error::Mindustry Android-JVM JAR not found: $MINDUSTRY_JAR"
    exit 1
}

mkdir -p "$OUT_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PROBE_SRC="$TMP/AndroidJvmArcNativeLoadProbe.java"
PROBE_CLASSES="$TMP/classes"
MANIFEST="$TMP/MANIFEST.MF"
OUT_JAR="$OUT_DIR/Mindustry-android-jvm-arc-native-load-probe.jar"
mkdir -p "$PROBE_CLASSES"

unzip -p "$MINDUSTRY_JAR" arc/util/SharedLibraryLoader.class | strings | grep -Fq 'arm64-v8a/lib' || {
    echo "::error::Patched SharedLibraryLoader.class does not contain Android arm64 resource path logic"
    exit 1
}
unzip -p "$MINDUSTRY_JAR" arc/util/SharedLibraryLoader.class | strings | grep -Fq 'arc.native.loader.debug' || {
    echo "::error::Patched SharedLibraryLoader.class does not contain loader debug instrumentation"
    exit 1
}

cat > "$PROBE_SRC" <<'JAVA'
package androidjvm.probe;

import arc.util.SharedLibraryLoader;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.PrintStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class AndroidJvmArcNativeLoadProbe{
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

    public static void main(String[] args) throws Exception{
        System.out.println("PROBE_START");
        System.out.println("Runtime.java.runtime.name=" + System.getProperty("java.runtime.name"));
        System.out.println("Runtime.java.vm.vendor=" + System.getProperty("java.vm.vendor"));
        System.out.println("Runtime.os.name=" + System.getProperty("os.name"));
        System.out.println("Runtime.os.arch=" + System.getProperty("os.arch"));
        System.out.println("Runtime.sun.arch.data.model=" + System.getProperty("sun.arch.data.model"));

        String resourcePath = "/arm64-v8a/libarc.so";
        URL resource = AndroidJvmArcNativeLoadProbe.class.getResource(resourcePath);
        System.out.println("RESOURCE_PATH=" + resourcePath);
        System.out.println("RESOURCE_FOUND=" + (resource != null ? "YES" : "NO"));
        System.out.println("MAPPED_NAME=" + new SharedLibraryLoader().mapLibraryName("arc"));

        if(resource == null){
            System.out.println("SYSTEM_LOAD=FAIL");
            System.out.println("FAILURE_LAYER=resource");
            System.exit(41);
            return;
        }

        System.setProperty("arc.native.loader.debug", "true");

        ByteArrayOutputStream capture = new ByteArrayOutputStream();
        PrintStream originalOut = System.out;
        try(PrintStream capturedOut = new PrintStream(capture, true, StandardCharsets.UTF_8)){
            System.setOut(capturedOut);
            new SharedLibraryLoader().load("arc");
        }catch(Throwable throwable){
            System.setOut(originalOut);
            System.out.println("LOADER_DEBUG_BEGIN");
            System.out.print(capture.toString(StandardCharsets.UTF_8));
            System.out.println("LOADER_DEBUG_END");
            System.out.println("SYSTEM_LOAD=FAIL");
            System.out.println("FAILURE_LAYER=system_load");
            printThrowable("SYSTEM_LOAD_ERROR", throwable);
            System.exit(42);
            return;
        }finally{
            System.setOut(originalOut);
        }

        String debug = capture.toString(StandardCharsets.UTF_8);
        System.out.println("LOADER_DEBUG_BEGIN");
        System.out.print(debug);
        System.out.println("LOADER_DEBUG_END");
        System.out.println("LOADED_LIBRARY=" + SharedLibraryLoader.isLoaded("arc"));

        Matcher pathMatcher = Pattern.compile("Arc Android native extracted = (.+)").matcher(debug);
        if(!pathMatcher.find()){
            System.out.println("SYSTEM_LOAD=FAIL");
            System.out.println("FAILURE_LAYER=extraction_path");
            System.exit(43);
            return;
        }

        File extracted = new File(pathMatcher.group(1).trim()).getAbsoluteFile();
        System.out.println("EXTRACTED_PATH=" + extracted.getAbsolutePath());
        System.out.println("EXTRACTED_EXISTS=" + extracted.exists());
        System.out.println("EXTRACTED_REGULAR=" + extracted.isFile());
        System.out.println("EXTRACTED_READABLE=" + extracted.canRead());
        System.out.println("EXTRACTED_EXECUTABLE=" + extracted.canExecute());
        System.out.println("EXTRACTED_SIZE=" + extracted.length());

        if(!extracted.isFile() || !extracted.canRead() || extracted.length() <= 0){
            System.out.println("SYSTEM_LOAD=FAIL");
            System.out.println("FAILURE_LAYER=extraction");
            System.exit(44);
            return;
        }

        String sha = sha256(extracted);
        System.out.println("EXTRACTED_SHA256=" + sha);
        if(!sha.equals("ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338")){
            System.out.println("SYSTEM_LOAD=FAIL");
            System.out.println("FAILURE_LAYER=artifact_identity");
            System.exit(45);
            return;
        }

        System.out.println("SYSTEM_LOAD=PASS");
        System.out.println("FAILURE_LAYER=none");
        System.out.println("PROBE_END");
    }
}
JAVA

javac -cp "$MINDUSTRY_JAR" -d "$PROBE_CLASSES" "$PROBE_SRC"

cat > "$MANIFEST" <<'EOF'
Manifest-Version: 1.0
Main-Class: androidjvm.probe.AndroidJvmArcNativeLoadProbe
EOF

cp "$MINDUSTRY_JAR" "$OUT_JAR"
jar ufm "$OUT_JAR" "$MANIFEST"
jar uf "$OUT_JAR" -C "$PROBE_CLASSES" androidjvm/probe/AndroidJvmArcNativeLoadProbe.class

echo "== TASK 02D: verify Android JVM Arc native load probe package =="
jar tf "$OUT_JAR" | grep -Fxq 'arc/util/SharedLibraryLoader.class'
jar tf "$OUT_JAR" | grep -Fxq 'androidjvm/probe/AndroidJvmArcNativeLoadProbe.class'
jar tf "$OUT_JAR" | grep -Fxq 'arm64-v8a/libarc.so'
unzip -p "$OUT_JAR" 'arm64-v8a/libarc.so' | sha256sum | grep -Fxq "$EXPECTED_ARC_SHA256  -"
unzip -p "$OUT_JAR" 'META-INF/MANIFEST.MF' | tr -d '\\r' | grep -Fxq 'Main-Class: androidjvm.probe.AndroidJvmArcNativeLoadProbe'
sha256sum "$OUT_JAR" | tee "$OUT_DIR/probe-jar-sha256.txt"
jar tf "$OUT_JAR" | grep -E '^(arc/util/SharedLibraryLoader.class|androidjvm/probe/AndroidJvmArcNativeLoadProbe.class|arm64-v8a/libarc.so)$' | sort | tee "$OUT_DIR/probe-entries.txt"

cat > "$OUT_DIR/README-MOJO.txt" <<'TXT'
TASK 02D — Android JVM Arc native load probe

Run this JAR through the real Android JVM / Mojo Launcher "Execute a JAR" path.

Do NOT add -Dos.name, -Dos.arch, -Djava.runtime.name, or other Android-simulation overrides.

Expected target:
  Android ARM64 / arm64-v8a / AArch64

The probe calls:
  new SharedLibraryLoader().load("arc")

The patched loader should:
  1. recognize the Android JVM runtime,
  2. resolve /arm64-v8a/libarc.so from the JAR,
  3. extract it to a writable native path,
  4. call System.load(absolutePath).

Required markers:
  RESOURCE_FOUND=YES
  SYSTEM_LOAD=PASS
  EXTRACTED_SHA256=ad3b718db318332446deaf4db79462edd1954612ce88e5515c949ba62bbc4338
  PROBE_END

Capture stdout/stderr and Android logcat for the run.

A successful SYSTEM_LOAD=PASS proves only:
  packaged resource lookup
  + native extraction
  + Android linker acceptance of libarc.so

It does NOT prove:
  JNI method execution
  SDL initialization
  GLES
  full Mindustry startup
TXT

echo "TASK 02D Android JVM Arc native load probe package: PASS"
