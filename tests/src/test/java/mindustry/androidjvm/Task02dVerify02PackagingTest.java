package mindustry.androidjvm;

import org.junit.jupiter.api.Test;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.jar.JarFile;

import static org.junit.jupiter.api.Assertions.*;

public class Task02dVerify02PackagingTest{

    static final String ARC_SHA = "8eb00ffff0126d0576c67df46f99b8f6bccd96fe";
    static final String LOADER = "arc/util/SharedLibraryLoader.class";
    static final String ANDROID_ARC = "arm64-v8a/libarc.so";

    static Path findRoot(){
        Path current = Paths.get(System.getProperty("user.dir")).toAbsolutePath();
        while(current != null){
            if(Files.isRegularFile(current.resolve("gradlew")) && Files.isDirectory(current.resolve("desktop"))){
                return current;
            }
            current = current.getParent();
        }
        throw new IllegalStateException("Mindustry root with gradlew not found from " + System.getProperty("user.dir"));
    }

    static Result run(Path cwd, Path gradleHome, String... command) throws Exception{
        List<String> cmd = new ArrayList<>(List.of(command));
        ProcessBuilder builder = new ProcessBuilder(cmd)
            .directory(cwd.toFile())
            .redirectErrorStream(true);
        builder.environment().put("GRADLE_USER_HOME", gradleHome.toString());

        Process process = builder.start();
        String output;
        try(InputStream input = process.getInputStream()){
            output = new String(input.readAllBytes(), StandardCharsets.UTF_8);
        }
        int exit = process.waitFor();

        System.out.println("===== TASK-02D VERIFY-02 COMMAND =====");
        System.out.println(String.join(" ", cmd));
        System.out.println("EXIT=" + exit);
        System.out.print(output);
        if(!output.endsWith("\n")) System.out.println();

        return new Result(exit, output);
    }

    static void requireZero(Result result, String what){
        assertEquals(0, result.exit, what + " failed. Output:\n" + result.output);
    }

    static void requireEntry(Path jar, String entry) throws Exception{
        try(JarFile file = new JarFile(jar.toFile())){
            assertNotNull(file.getJarEntry(entry), "Missing JAR entry " + entry + " in " + jar);
        }
    }

    static Path findArcCoreJar(Path arcCoreLibs) throws Exception{
        try(var stream = Files.list(arcCoreLibs)){
            return stream
                .filter(Files::isRegularFile)
                .filter(p -> p.getFileName().toString().startsWith("arc-core"))
                .filter(p -> p.getFileName().toString().endsWith(".jar"))
                .filter(p -> !p.getFileName().toString().endsWith("-sources.jar"))
                .filter(p -> !p.getFileName().toString().endsWith("-javadoc.jar"))
                .sorted()
                .findFirst()
                .orElseThrow(() -> new AssertionError("No generated arc-core JAR found in " + arcCoreLibs));
        }
    }

    @Test
    void verifyTask02dPackaging() throws Exception{
        Path root = findRoot();
        Path arc = root.getParent().resolve("Arc");
        Path nestedGradleHome = root.resolve("build/task02d-verify02-gradle-home");
        Path evidence = root.resolve("build/task02d-verify02-evidence");
        Files.createDirectories(nestedGradleHome);
        Files.createDirectories(evidence);

        System.out.println("===== TASK-02D VERIFY-02 ROOT =====");
        System.out.println("Mindustry root = " + root);
        System.out.println("Arc path = " + arc);
        System.out.println("Expected Arc SHA = " + ARC_SHA);

        assertTrue(Files.isDirectory(arc), "Sibling Arc checkout is missing: " + arc);
        assertTrue(Files.isRegularFile(root.resolve("gradle.properties")), "gradle.properties missing");

        String gradleProperties = Files.readString(root.resolve("gradle.properties"));
        assertTrue(gradleProperties.lines().anyMatch(line -> line.startsWith("archash=" + ARC_SHA)),
            "gradle.properties does not pin Arc to " + ARC_SHA);

        String desktopBuild = Files.readString(root.resolve("desktop/build.gradle"));
        assertTrue(desktopBuild.contains("configurations.runtimeClasspath.collect{ it.isDirectory() ? it : zipTree(it) }"),
            "desktop/build.gradle does not use normal runtimeClasspath assembly");
        assertFalse(desktopBuild.contains("exclude("arc/util/SharedLibraryLoader.class")"),
            "SharedLibraryLoader exclusion workaround is still present");
        assertFalse(desktopBuild.contains("from("../Arc/arc-core/build/classes/java/main")"),
            "manual Arc class injection workaround is still present");

        Path patch = root.resolve("ci/android-jvm/task02d-arc-shared-library-loader.patch");

        Result checkout = run(root, nestedGradleHome,
            "git", "-C", arc.toString(), "fetch", "--no-tags", "--depth=1", "origin", ARC_SHA);
        requireZero(checkout, "Arc fetch");

        Result pin = run(root, nestedGradleHome,
            "git", "-C", arc.toString(), "checkout", "--detach", ARC_SHA);
        requireZero(pin, "Arc checkout");

        Result actualSha = run(root, nestedGradleHome,
            "git", "-C", arc.toString(), "rev-parse", "HEAD");
        requireZero(actualSha, "Arc SHA inspection");
        assertEquals(ARC_SHA, actualSha.output.trim(), "Arc checkout SHA mismatch");

        Result diffNames = run(root, nestedGradleHome,
            "git", "-C", arc.toString(), "diff", "--name-only");
        requireZero(diffNames, "Arc diff inspection");
        if(!diffNames.output.lines().anyMatch(line -> line.trim().equals("arc-core/src/arc/util/SharedLibraryLoader.java"))){
            Result applyCheck = run(root, nestedGradleHome,
                "git", "-C", arc.toString(), "apply", "--check", patch.toString());
            requireZero(applyCheck, "Arc loader patch check");

            Result apply = run(root, nestedGradleHome,
                "git", "-C", arc.toString(), "apply", patch.toString());
            requireZero(apply, "Arc loader patch apply");
        }

        Result postSha = run(root, nestedGradleHome,
            "git", "-C", arc.toString(), "rev-parse", "HEAD");
        requireZero(postSha, "post-patch Arc SHA inspection");
        assertEquals(ARC_SHA, postSha.output.trim(), "Arc SHA changed after patch");

        Result classes = run(root, nestedGradleHome,
            "./gradlew", ":Arc:arc-core:classes", "--rerun-tasks", "--stacktrace", "--console=plain");
        requireZero(classes, "Arc arc-core classes");

        Path loaderClass = arc.resolve("arc-core/build/classes/java/main/arc/util/SharedLibraryLoader.class");
        assertTrue(Files.isRegularFile(loaderClass), "Patched SharedLibraryLoader.class was not produced");
        System.out.println("ARC_CLASS_OUTPUT=" + loaderClass + " size=" + Files.size(loaderClass));

        Result loaderJavap = run(root, nestedGradleHome,
            "javap", "-classpath", arc.resolve("arc-core/build/classes/java/main").toString(),
            "-c", "-p", "arc.util.SharedLibraryLoader");
        requireZero(loaderJavap, "Arc loader javap");
        assertTrue(loaderJavap.output.contains("isAndroidRuntime"), "Arc loader bytecode lacks isAndroidRuntime");
        assertTrue(loaderJavap.output.contains("androidResourcePath"), "Arc loader bytecode lacks androidResourcePath");
        assertTrue(loaderJavap.output.contains("System.load"), "Arc loader bytecode lacks System.load");

        Result arcJarBuild = run(root, nestedGradleHome,
            "./gradlew", ":Arc:arc-core:jar", "--rerun-tasks", "--stacktrace", "--console=plain");
        requireZero(arcJarBuild, "Arc arc-core JAR");

        Path arcJar = findArcCoreJar(arc.resolve("arc-core/build/libs"));
        System.out.println("ACTUAL_ARC_CORE_JAR=" + arcJar);
        requireEntry(arcJar, LOADER);

        Result deps = run(root, nestedGradleHome,
            "./gradlew", "-PandroidJvm", ":desktop:dependencies",
            "--configuration", "runtimeClasspath", "--console=plain");
        requireZero(deps, "runtimeClasspath dependency report");
        assertTrue(deps.output.contains("com.github.Anuken:arc-core:8eb00ffff0 -> project :Arc:arc-core"),
            "runtimeClasspath did not show expected composite-build Arc substitution");

        Path initScript = evidence.resolve("runtimeClasspath.init.gradle");
        Files.writeString(initScript, """
allprojects {
    afterEvaluate { p ->
        if (p.path == ':desktop') {
            p.tasks.register('task02dVerifyRuntimeClasspath') {
                doLast {
                    p.configurations.runtimeClasspath.resolve().sort { a, b -> a.absolutePath <=> b.absolutePath }.each {
                        println "RUNTIME_FILE=DLBRACEit.absolutePath}"
                    }
                }
            }
        }
    }
}
""".replace("DLBRACE", "$" + "{"));

        Result runtimeFiles = run(root, nestedGradleHome,
            "./gradlew", "-PandroidJvm", "--init-script", initScript.toString(),
            ":desktop:task02dVerifyRuntimeClasspath", "--console=plain");
        requireZero(runtimeFiles, "physical runtimeClasspath inspection");

        Optional<String> arcRuntime = runtimeFiles.output.lines()
            .filter(line -> line.startsWith("RUNTIME_FILE="))
            .map(line -> line.substring("RUNTIME_FILE=".length()))
            .filter(line -> line.contains("/Arc/arc-core/build/libs/"))
            .findFirst();

        assertTrue(arcRuntime.isPresent(), "No physical runtimeClasspath Arc artifact under ../Arc/arc-core/build/libs/");
        Path arcRuntimeJar = Paths.get(arcRuntime.get());
        assertTrue(Files.isRegularFile(arcRuntimeJar), "Resolved Arc runtime artifact does not exist: " + arcRuntimeJar);
        System.out.println("PHYSICAL_ARC_RUNTIME_ARTIFACT=" + arcRuntimeJar);
        requireEntry(arcRuntimeJar, LOADER);

        Result dist = run(root, nestedGradleHome,
            "./gradlew", "-PandroidJvm", "desktop:dist", "--rerun-tasks", "--stacktrace", "--console=plain");
        requireZero(dist, "Android-JVM desktop:dist");

        Path mindustryJar = root.resolve("desktop/build/libs/Mindustry.jar");
        assertTrue(Files.isRegularFile(mindustryJar), "Mindustry.jar was not produced");
        System.out.println("MINDUSTRY_JAR=" + mindustryJar + " size=" + Files.size(mindustryJar));

        requireEntry(mindustryJar, LOADER);
        requireEntry(mindustryJar, ANDROID_ARC);

        Result packagedJavap = run(root, nestedGradleHome,
            "javap", "-classpath", mindustryJar.toString(), "-c", "-p", "arc.util.SharedLibraryLoader");
        requireZero(packagedJavap, "packaged SharedLibraryLoader javap");
        assertTrue(packagedJavap.output.contains("isAndroidRuntime"), "Packaged loader lacks isAndroidRuntime");
        assertTrue(packagedJavap.output.contains("androidResourcePath"), "Packaged loader lacks androidResourcePath");
        assertTrue(packagedJavap.output.contains("System.load"), "Packaged loader lacks System.load");

        Path nativeOut = evidence.resolve("libarc.so");
        try(JarFile jar = new JarFile(mindustryJar.toFile())){
            var entry = jar.getJarEntry(ANDROID_ARC);
            try(InputStream input = jar.getInputStream(entry)){
                Files.copy(input, nativeOut, StandardCopyOption.REPLACE_EXISTING);
            }
        }

        Result header = run(root, nestedGradleHome,
            "readelf", "-h", nativeOut.toString());
        requireZero(header, "libarc ELF header");
        assertTrue(header.output.contains("Class:                             ELF64"), "libarc is not ELF64");
        assertTrue(header.output.contains("Machine:                           AArch64"), "libarc is not AArch64");

        Result dynamic = run(root, nestedGradleHome,
            "readelf", "-d", nativeOut.toString());
        requireZero(dynamic, "libarc dynamic section");
        for(String forbidden : List.of(
            "libpthread.so.0",
            "libdl.so.2",
            "libm.so.6",
            "libc.so.6",
            "libstdc++.so.6",
            "libgcc_s.so.1",
            "ld-linux-aarch64.so.1",
            "libGL.so.1",
            "libSDL2-2.0.so.0"
        )){
            assertFalse(dynamic.output.contains("[" + forbidden + "]"),
                "Forbidden native dependency present: " + forbidden);
        }

        Result desktop = run(root, nestedGradleHome,
            "./gradlew", "desktop:dist", "--rerun-tasks", "--stacktrace", "--console=plain");
        requireZero(desktop, "desktop regression desktop:dist");
        assertTrue(Files.isRegularFile(mindustryJar), "desktop/build/libs/Mindustry.jar missing after desktop regression build");

        System.out.println("TASK-02D VERIFY-02 RESULT: PASS");
    }

    static final class Result{
        final int exit;
        final String output;

        Result(int exit, String output){
            this.exit = exit;
            this.output = output;
        }
    }
}
