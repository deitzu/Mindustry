#!/usr/bin/env bash
set -euo pipefail

JAR="$1"
OUT_DIR="ci-artifacts/runtime-boundary"
mkdir -p "$OUT_DIR"

[ -f "$JAR" ] || {
  echo "::error::Mindustry JAR not found: $JAR"
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SRC="$TMP/AndroidJvmNativeLoadProbe.java"
CLS="$TMP/classes"
mkdir -p "$CLS"

cat > "$SRC" <<'JAVA'
import arc.util.OS;
import arc.util.SharedLibraryLoader;

import java.io.File;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public final class AndroidJvmNativeLoadProbe{
    public static void main(String[] args) throws Exception{
        File jar = new File(args[0]).getAbsoluteFile();

        System.out.println("Runtime java.runtime.name=" + System.getProperty("java.runtime.name"));
        System.out.println("Runtime java.vm.vendor=" + System.getProperty("java.vm.vendor"));
        System.out.println("Runtime os.name=" + System.getProperty("os.name"));
        System.out.println("Runtime os.arch=" + System.getProperty("os.arch"));
        System.out.println("Runtime sun.arch.data.model=" + System.getProperty("sun.arch.data.model"));

        System.out.println("OS.isAndroid=" + OS.isAndroid);
        System.out.println("OS.isLinux=" + OS.isLinux);
        System.out.println("OS.isARM=" + OS.isARM);
        System.out.println("OS.is64Bit=" + OS.is64Bit);

        SharedLibraryLoader loader = new SharedLibraryLoader();
        String arcName = loader.mapLibraryName("arc");
        String sdlName = loader.mapLibraryName("sdl-arc");

        System.out.println("Mapped arc=" + arcName);
        System.out.println("Mapped sdl-arc=" + sdlName);

        try(ZipFile zip = new ZipFile(jar)){
            String[] entries = {
                "libarcarm64.so",
                "libarc.so",
                "libsdl-arcarm64.so",
                "libsdl-arc.so"
            };
            for(String entryName : entries){
                ZipEntry entry = zip.getEntry(entryName);
                System.out.println("JAR " + entryName + "=" + (entry != null ? "PRESENT" : "ABSENT"));
            }

            System.out.println("Loader resource for arc=" + (zip.getEntry(arcName) != null ? "PRESENT" : "ABSENT"));
            System.out.println("Loader resource for sdl-arc=" + (zip.getEntry(sdlName) != null ? "PRESENT" : "ABSENT"));
        }
    }
}
JAVA

javac -cp "$JAR" -d "$CLS" "$SRC"

echo "== TASK 03C-DEBUG-11: Android JVM loader-boundary probe =="
java   -Dos.name=Linux   -Dos.arch=aarch64   -Dsun.arch.data.model=64   -cp "$JAR:$CLS"   AndroidJvmNativeLoadProbe "$JAR" | tee "$OUT_DIR/loader-boundary.txt"

grep -Fxq "OS.isAndroid=false" "$OUT_DIR/loader-boundary.txt"
grep -Fxq "OS.isLinux=true" "$OUT_DIR/loader-boundary.txt"
grep -Fxq "OS.isARM=true" "$OUT_DIR/loader-boundary.txt"
grep -Fxq "OS.is64Bit=true" "$OUT_DIR/loader-boundary.txt"
grep -Fxq "Mapped arc=libarcarm64.so" "$OUT_DIR/loader-boundary.txt"
grep -Fxq "Mapped sdl-arc=libsdl-arcarm64.so" "$OUT_DIR/loader-boundary.txt"
grep -Fxq "JAR libarcarm64.so=PRESENT" "$OUT_DIR/loader-boundary.txt"
grep -Fxq "JAR libsdl-arcarm64.so=ABSENT" "$OUT_DIR/loader-boundary.txt"
grep -Fxq "Loader resource for arc=PRESENT" "$OUT_DIR/loader-boundary.txt"
grep -Fxq "Loader resource for sdl-arc=ABSENT" "$OUT_DIR/loader-boundary.txt"

echo "Loader boundary probe: PASS"
