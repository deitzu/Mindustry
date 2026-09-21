#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
OUT_DIR="${1:-$ROOT/ci-artifacts/android-jvm-framework-visibility-probe}"
OUT_JAR="$OUT_DIR/Mindustry-android-jvm-framework-visibility-probe.jar"

command -v javac >/dev/null 2>&1 || { echo "::error::javac not found"; exit 1; }
command -v jar >/dev/null 2>&1 || { echo "::error::jar not found"; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "::error::sha256sum not found"; exit 1; }

mkdir -p "$OUT_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SRC="$TMP/AndroidFrameworkVisibilityProbe.java"
CLS="$TMP/classes"
mkdir -p "$CLS"

cat > "$SRC" <<'JAVA'
package androidjvm.probe;

import java.io.File;
import java.net.URL;
import java.security.CodeSource;
import java.security.ProtectionDomain;

public final class AndroidFrameworkVisibilityProbe{
    private static final String[] CLASSES = {
        "android.media.AudioDeviceCallback",
        "android.media.AudioDeviceInfo",
        "android.media.AudioManager",
        "android.content.Context",
        "android.app.Activity",
        "android.os.Build",
        "android.os.Environment",
        "android.view.View",
        "android.content.res.AssetManager"
    };

    private static String value(String property){
        try{
            return String.valueOf(System.getProperty(property));
        }catch(Throwable throwable){
            return "<error:" + throwable.getClass().getName() + ">";
        }
    }

    private static String loaderClass(ClassLoader loader){
        return loader == null ? "<bootstrap/null>" : loader.getClass().getName();
    }

    private static String loaderText(ClassLoader loader){
        return loader == null ? "<bootstrap/null>" : String.valueOf(loader);
    }

    private static void printHierarchy(String label, ClassLoader loader){
        System.out.println("LOADER_HIERARCHY_BEGIN=" + label);
        ClassLoader current = loader;
        int depth = 0;
        while(current != null){
            System.out.println("LOADER_HIERARCHY[" + depth + "].label=" + label);
            System.out.println("LOADER_HIERARCHY[" + depth + "].class=" + loaderClass(current));
            System.out.println("LOADER_HIERARCHY[" + depth + "].value=" + loaderText(current));
            try{
                current = current.getParent();
            }catch(Throwable throwable){
                System.out.println("LOADER_HIERARCHY[" + depth + "].parent_error=" + throwable.getClass().getName());
                current = null;
            }
            depth++;
            if(depth >= 16){
                System.out.println("LOADER_HIERARCHY_TRUNCATED=true");
                break;
            }
        }
        if(depth == 0){
            System.out.println("LOADER_HIERARCHY[0].class=<bootstrap/null>");
            System.out.println("LOADER_HIERARCHY[0].value=<bootstrap/null>");
        }
        System.out.println("LOADER_HIERARCHY_END=" + label);
    }

    private static String codeSource(Class<?> type){
        try{
            ProtectionDomain domain = type.getProtectionDomain();
            if(domain == null){
                return "<null>";
            }
            CodeSource source = domain.getCodeSource();
            if(source == null || source.getLocation() == null){
                return "<null>";
            }
            return source.getLocation().toString();
        }catch(Throwable throwable){
            return "<error:" + throwable.getClass().getName() + ">";
        }
    }

    private static String classResource(Class<?> type){
        try{
            String resourceName = "/" + type.getName().replace('.', '/') + ".class";
            URL resource = type.getResource(resourceName);
            return resource == null ? "<null>" : resource.toString();
        }catch(Throwable throwable){
            return "<error:" + throwable.getClass().getName() + ">";
        }
    }

    private static String loaderResource(ClassLoader loader, String className){
        try{
            if(loader == null){
                return "<bootstrap/null>";
            }
            String resourceName = className.replace('.', '/') + ".class";
            URL resource = loader.getResource(resourceName);
            return resource == null ? "<null>" : resource.toString();
        }catch(Throwable throwable){
            return "<error:" + throwable.getClass().getName() + ">";
        }
    }

    private static void probe(String label, ClassLoader loader, String className){
        String key = label + "." + className;
        System.out.println("PROBE=" + key);
        System.out.println("PROBE_ATTEMPT_LOADER_CLASS=" + loaderClass(loader));
        System.out.println("PROBE_ATTEMPT_LOADER=" + loaderText(loader));

        try{
            Class<?> type = Class.forName(className, false, loader);
            System.out.println("PROBE_RESULT=SUCCESS");
            System.out.println("PROBE_RESOLVED_CLASS=" + type.getName());
            System.out.println("PROBE_RESOLVED_LOADER_CLASS=" + loaderClass(type.getClassLoader()));
            System.out.println("PROBE_RESOLVED_LOADER=" + loaderText(type.getClassLoader()));
            System.out.println("PROBE_CODE_SOURCE=" + codeSource(type));
            System.out.println("PROBE_CLASS_RESOURCE=" + classResource(type));
        }catch(ClassNotFoundException e){
            System.out.println("PROBE_RESULT=NOT_FOUND");
            System.out.println("PROBE_ERROR_TYPE=" + e.getClass().getName());
            System.out.println("PROBE_ERROR_MESSAGE=" + e.getMessage());
        }catch(Throwable throwable){
            System.out.println("PROBE_RESULT=ERROR");
            System.out.println("PROBE_ERROR_TYPE=" + throwable.getClass().getName());
            System.out.println("PROBE_ERROR_MESSAGE=" + throwable.getMessage());
        }

        System.out.println("PROBE_LOADER_RESOURCE=" + loaderResource(loader, className));
        System.out.println("PROBE_END=" + key);
    }

    private static void printSystemProperties(){
        System.out.println("JVM_PROPERTIES_BEGIN");
        String[] properties = {
            "java.version",
            "java.runtime.name",
            "java.vm.vendor",
            "java.vm.name",
            "os.name",
            "os.arch",
            "sun.arch.data.model",
            "java.class.path",
            "java.boot.class.path",
            "java.library.path",
            "java.io.tmpdir",
            "user.dir"
        };
        for(String property : properties){
            System.out.println(property + "=" + value(property));
        }
        System.out.println("JVM_PROPERTIES_END");
    }

    public static void main(String[] args){
        System.out.println("ANDROID_FRAMEWORK_VISIBILITY_PROBE_BEGIN");
        printSystemProperties();

        ClassLoader systemLoader = ClassLoader.getSystemClassLoader();
        ClassLoader contextLoader = Thread.currentThread().getContextClassLoader();
        ClassLoader probeLoader = AndroidFrameworkVisibilityProbe.class.getClassLoader();

        System.out.println("LOADER_SYSTEM_CLASS=" + loaderClass(systemLoader));
        System.out.println("LOADER_CONTEXT_CLASS=" + loaderClass(contextLoader));
        System.out.println("LOADER_PROBE_CLASS=" + loaderClass(probeLoader));

        printHierarchy("system", systemLoader);
        printHierarchy("context", contextLoader);
        printHierarchy("probe", probeLoader);

        ClassLoader[] loaders = {systemLoader, contextLoader, null};
        String[] labels = {"SYSTEM", "CONTEXT", "BOOTSTRAP"};

        for(int i = 0; i < loaders.length; i++){
            System.out.println("CLASSLOADER_PROBE_SET_BEGIN=" + labels[i]);
            System.out.println("CLASSLOADER_PROBE_SET_LOADER=" + loaderClass(loaders[i]));
            for(String className : CLASSES){
                probe(labels[i], loaders[i], className);
            }
            System.out.println("CLASSLOADER_PROBE_SET_END=" + labels[i]);
        }

        ProtectionDomain probeDomain = AndroidFrameworkVisibilityProbe.class.getProtectionDomain();
        CodeSource probeSource = probeDomain == null ? null : probeDomain.getCodeSource();
        System.out.println("PROBE_ARTIFACT_CLASSLOADER_CLASS=" + loaderClass(probeLoader));
        System.out.println("PROBE_ARTIFACT_CODE_SOURCE=" +
            (probeSource == null || probeSource.getLocation() == null ? "<null>" : probeSource.getLocation()));
        if(probeSource != null && probeSource.getLocation() != null){
            System.out.println("PROBE_ARTIFACT_JAR_PATH=" + new File(probeSource.getLocation().getPath()).getAbsolutePath());
        }
        System.out.println("ANDROID_FRAMEWORK_VISIBILITY_PROBE_END");
    }
}
JAVA

echo "== ANDROID-JVM FRAMEWORK VISIBILITY PROBE: compile =="
javac -source 8 -target 8 -proc:none -encoding UTF-8 -d "$CLS" "$SRC"

echo "== ANDROID-JVM FRAMEWORK VISIBILITY PROBE: package =="
jar cfe "$OUT_JAR" androidjvm.probe.AndroidFrameworkVisibilityProbe -C "$CLS" androidjvm/probe/AndroidFrameworkVisibilityProbe.class

jar tf "$OUT_JAR" | grep -Fxq 'androidjvm/probe/AndroidFrameworkVisibilityProbe.class'
jar tf "$OUT_JAR" | grep -Fxq 'META-INF/MANIFEST.MF'
if jar tf "$OUT_JAR" | grep -Eq '^(android|java|javax)/'; then
    echo "::error::Probe JAR unexpectedly contains framework/JDK package classes"
    exit 1
fi

SHA="$(sha256sum "$OUT_JAR" | awk '{print $1}')"
SIZE="$(wc -c < "$OUT_JAR")"

echo "Probe JAR: $OUT_JAR"
echo "Probe JAR size: $SIZE bytes"
echo "Probe JAR SHA-256: $SHA"
echo "Package verification: PASS"
echo
printf '%s\n' 'Run on the Android JVM with the same Mojo Java runtime:'
printf '  java -jar %q\n' "$OUT_JAR"
echo "Do not add android.jar to the runtime classpath."
