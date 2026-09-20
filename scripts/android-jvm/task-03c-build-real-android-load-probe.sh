#!/usr/bin/env bash
set -euo pipefail

MINDUSTRY_JAR="${1:?usage: $0 <Mindustry.jar> <libsdl-arc.so> [output-dir]}"
NATIVE_LIB="${2:?usage: $0 <Mindustry.jar> <libsdl-arc.so> [output-dir]}"
OUT_DIR="${3:-ci-artifacts/android-jvm-load-probe}"

[ -f "$MINDUSTRY_JAR" ] || {
  echo "::error::Mindustry JAR not found: $MINDUSTRY_JAR"
  exit 1
}

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

SRC="$TMP/RealAndroidNativeLoadProbe.java"
CLS="$TMP/classes"
RESOURCE_ROOT="$TMP/resources"
MANIFEST="$TMP/MANIFEST.MF"
OUT_JAR="$OUT_DIR/Mindustry-android-jvm-load-probe.jar"

mkdir -p "$CLS" "$RESOURCE_ROOT/android-jvm-probe/native/arm64-v8a"

cat > "$SRC" <<'JAVA'
package androidjvm.probe;

import arc.util.OS;
import arc.util.SharedLibraryLoader;
import arc.backend.sdl.jni.SDL;

import java.io.File;
import java.net.URL;
import java.util.Arrays;

public final class RealAndroidNativeLoadProbe{
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

    private static void printNativeSearchState(){
        String libraryPath = System.getProperty("java.library.path", "");
        String ldLibraryPath = System.getenv("LD_LIBRARY_PATH");

        System.out.println("Runtime.java.runtime.name=" + System.getProperty("java.runtime.name"));
        System.out.println("Runtime.java.vm.vendor=" + System.getProperty("java.vm.vendor"));
        System.out.println("Runtime.java.version=" + System.getProperty("java.version"));
        System.out.println("Runtime.os.name=" + System.getProperty("os.name"));
        System.out.println("Runtime.os.arch=" + System.getProperty("os.arch"));
        System.out.println("Runtime.sun.arch.data.model=" + System.getProperty("sun.arch.data.model"));
        System.out.println("Runtime.java.library.path=" + libraryPath);
        System.out.println("Runtime.LD_LIBRARY_PATH=" + ldLibraryPath);
        System.out.println("Runtime.user.dir=" + System.getProperty("user.dir"));

        System.out.println("Runtime.OS.isAndroid=" + OS.isAndroid);
        System.out.println("Runtime.OS.isLinux=" + OS.isLinux);
        System.out.println("Runtime.OS.isARM=" + OS.isARM);
        System.out.println("Runtime.OS.is64Bit=" + OS.is64Bit);

        String[] pathEntries = libraryPath.isEmpty() ? new String[0] : libraryPath.split(File.pathSeparator);
        for(int i = 0; i < pathEntries.length; i++){
            File path = new File(pathEntries[i]);
            System.out.println("Runtime.java.library.path[" + i + "]=" + path.getAbsolutePath()
                    + " exists=" + path.exists()
                    + " directory=" + path.isDirectory()
                    + " readable=" + path.canRead());
        }

        try{
            File probeJar = new File(RealAndroidNativeLoadProbe.class
                    .getProtectionDomain()
                    .getCodeSource()
                    .getLocation()
                    .toURI());
            System.out.println("Probe.codeSource=" + probeJar.getAbsolutePath());
        }catch(Throwable ignored){
            System.out.println("Probe.codeSource=<unavailable>");
        }

        URL nativeResource = RealAndroidNativeLoadProbe.class.getResource(
                "/android-jvm-probe/native/arm64-v8a/libsdl-arc.so");
        System.out.println("Probe.embeddedNativeResource=" + (nativeResource != null ? nativeResource : "<absent>"));
    }

    public static void main(String[] args){
        System.out.println("PROBE_START");
        printNativeSearchState();

        SharedLibraryLoader loader = new SharedLibraryLoader();
        String mappedName = loader.mapLibraryName("sdl-arc");
        System.out.println("LIBRARY_REQUEST=sdl-arc");
        System.out.println("LIBRARY_MAPPED_NAME=" + mappedName);

        System.out.println("LIBRARY_LOAD_BEGIN");
        try{
            loader.load("sdl-arc");
            System.out.println("LIBRARY_LOAD_PASS");
        }catch(Throwable throwable){
            System.out.println("LIBRARY_LOAD_FAIL");
            printThrowable("LIBRARY_LOAD_ERROR", throwable);
            System.exit(43);
            return;
        }

        System.out.println("JNI_CALL_BEGIN");
        try{
            String error = SDL.SDL_GetError();
            System.out.println("JNI_CALL_PASS");
            System.out.println("JNI_SDL_GET_ERROR=" + String.valueOf(error));
        }catch(Throwable throwable){
            System.out.println("JNI_CALL_FAIL");
            printThrowable("JNI_CALL_ERROR", throwable);
            System.exit(44);
            return;
        }

        System.out.println("SDL_INIT_BEGIN");
        int initFlags = SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS;
        try{
            int result = SDL.SDL_Init(initFlags);
            String error = SDL.SDL_GetError();
            System.out.println("SDL_INIT_RESULT=" + result);
            System.out.println("SDL_INIT_ERROR=" + String.valueOf(error));

            if(result != 0){
                System.out.println("SDL_INIT_FAIL");
                System.exit(45);
                return;
            }

            System.out.println("SDL_INIT_PASS");
            try{
                SDL.SDL_Quit();
                System.out.println("SDL_QUIT_PASS");
            }catch(Throwable throwable){
                System.out.println("SDL_QUIT_FAIL");
                printThrowable("SDL_QUIT_ERROR", throwable);
                System.exit(46);
                return;
            }
        }catch(Throwable throwable){
            System.out.println("SDL_INIT_FAIL");
            printThrowable("SDL_INIT_ERROR", throwable);
            System.exit(45);
            return;
        }

        System.out.println("PROBE_END");
        System.out.println("TASK_03C_DEBUG_12_RESULT=PASS");
    }
}
JAVA

javac -cp "$MINDUSTRY_JAR" -d "$CLS" "$SRC"

cp "$MINDUSTRY_JAR" "$OUT_JAR"
cp "$NATIVE_LIB" "$RESOURCE_ROOT/android-jvm-probe/native/arm64-v8a/libsdl-arc.so"

if unzip -p "$OUT_JAR" META-INF/MANIFEST.MF > "$MANIFEST" 2>/dev/null; then
  :
else
  printf 'Manifest-Version: 1.0\n' > "$MANIFEST"
fi

python3 - "$MANIFEST" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")
lines = text.splitlines()
out = []
found = False

for line in lines:
    if line.startswith("Main-Class:"):
        out.append("Main-Class: androidjvm.probe.RealAndroidNativeLoadProbe")
        found = True
    else:
        out.append(line)

if not found:
    if out and out[-1] != "":
        out.append("")
    out.append("Main-Class: androidjvm.probe.RealAndroidNativeLoadProbe")

path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY

# Replace the original manifest instead of adding a second META-INF/MANIFEST.MF.
# Java's jar tool otherwise preserves the old attributes and emits duplicate-name warnings.
if jar tf "$OUT_JAR" | grep -Fxq 'META-INF/MANIFEST.MF'; then
  jar --delete --file "$OUT_JAR" META-INF/MANIFEST.MF
fi
jar ufm "$OUT_JAR" "$MANIFEST"
jar uf "$OUT_JAR" -C "$CLS" androidjvm/probe/RealAndroidNativeLoadProbe.class
jar uf "$OUT_JAR" -C "$RESOURCE_ROOT" android-jvm-probe/native/arm64-v8a/libsdl-arc.so

echo "== TASK 03C-DEBUG-12: verify runtime probe package =="
echo "Mindustry JAR: $MINDUSTRY_JAR"
echo "Native library: $NATIVE_LIB"
echo "Output JAR: $OUT_JAR"

jar tf "$OUT_JAR" | grep -Fxq 'androidjvm/probe/RealAndroidNativeLoadProbe.class'
echo "Verified probe class entry"
jar tf "$OUT_JAR" | grep -Fxq 'android-jvm-probe/native/arm64-v8a/libsdl-arc.so'
echo "Verified native resource entry"
unzip -p "$OUT_JAR" META-INF/MANIFEST.MF | tr -d '\r' | grep -Fxq 'Main-Class: androidjvm.probe.RealAndroidNativeLoadProbe'
echo "Verified probe Main-Class"

sha256sum "$OUT_JAR" | tee "$OUT_DIR/Mindustry-android-jvm-load-probe.sha256"
jar tf "$OUT_JAR" | grep -E '^(androidjvm/probe/RealAndroidNativeLoadProbe.class|android-jvm-probe/native/arm64-v8a/libsdl-arc.so)$' | tee "$OUT_DIR/package-entries.txt"

cat > "$OUT_DIR/README-MOJO.txt" <<'TXT'
TASK 03C-DEBUG-12 — Real Android JVM Native Load Probe

Purpose:
  Exercise the real Android/JVM native boundary for logical library "sdl-arc".

Baseline launch:
  Run this JAR through Mojo Launcher's JAR execution path.
  Do not add -Dos.name, -Dos.arch, or other host-simulation overrides.
  Do not modify SharedLibraryLoader or the Mindustry JAR.

The probe intentionally embeds the actual arm64-v8a libsdl-arc.so as a JAR resource.
The baseline test does not extract that resource itself. This exposes the real native
library discovery behavior of the existing runtime.

Capture:
  - complete probe stdout/stderr
  - process exit status
  - relevant Android logcat from the same launch
  - Android version/API level
  - device ABI
  - Mojo Launcher version/build
  - selected JVM/runtime version

Milestones:
  PROBE_START
  LIBRARY_LOAD_BEGIN
  LIBRARY_LOAD_PASS or LIBRARY_LOAD_FAIL
  JNI_CALL_BEGIN
  JNI_CALL_PASS or JNI_CALL_FAIL
  SDL_INIT_BEGIN
  SDL_INIT_PASS or SDL_INIT_FAIL
  PROBE_END
  TASK_03C_DEBUG_12_RESULT=PASS

Stop at the earliest failure. Do not treat a later crash or timeout as proof that an
earlier boundary passed.
TXT

echo "Runtime probe package: PASS"
