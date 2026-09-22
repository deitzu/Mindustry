package mindustry.androidjvm;

import arc.*;
import arc.Files.*;
import arc.struct.*;
import arc.backend.sdl.*;
import arc.files.*;
import arc.util.*;
import arc.util.Log.*;
import mindustry.*;
import mindustry.core.*;
import mindustry.desktop.ErrorDialog;
import mindustry.game.EventType.*;
import mindustry.gen.*;
import mindustry.net.*;
import mindustry.net.Net.*;
import mindustry.mod.Mods.*;
import mindustry.type.*;
import mindustry.ui.*;
import mindustry.ui.dialogs.*;
import mindustry.ui.FileChooser.*;

import java.io.*;

import static mindustry.Vars.*;

public class AndroidJvmLauncher extends ClientLauncher{
    public static void main(String[] arg){
        try{
            Core.files = new SdlFiles();
            Version.init();
            Vars.loadLogger();
            Vars.loadFileLogger(new Fi(OS.getAppDataDirectoryString(appName)).child("last_log.txt"));

            checkJavaVersion();

            new SdlApplication(new AndroidJvmLauncher(arg), new SdlConfig(){{
                title = "Mindustry";
                maximized = true;
                coreProfile = true;
                width = 900;
                height = 700;

                if(OS.isLinux){
                    glVersions = new int[][]{{3, 2}, {3, 1}, {3, 0}, {2, 1}, {2, 0}};
                }else{
                    glVersions = new int[][]{{4, 6}, {4, 5}, {4, 4}, {4, 1}, {3, 3}, {3, 2}, {3, 1}, {2, 1}, {2, 0}};
                }

                for(int i = 0; i < arg.length; i++){
                    if(arg[i].charAt(0) == '-'){
                        String name = arg[i].substring(1);
                        switch(name){
                            case "width" -> width = Strings.parseInt(arg[i + 1], width);
                            case "height" -> height = Strings.parseInt(arg[i + 1], height);
                            case "gl" -> {
                                String str = arg[i + 1];
                                if(str.contains(".")){
                                    String[] split = str.split("\\.");
                                    if(split.length == 2 && Strings.canParsePositiveInt(split[0]) && Strings.canParsePositiveInt(split[1])){
                                        glVersions = new int[][]{{Strings.parseInt(split[0]), Strings.parseInt(split[1])}};
                                        allowGl30 = true;
                                        break;
                                    }
                                }
                                Log.err("Invalid GL version format string: '@'. GL version must be of the form <major>.<minor>", str);
                            }
                            case "coreGl" -> coreProfile = true;
                            case "compatibilityGl" -> coreProfile = false;
                            case "antialias" -> samples = 16;
                            case "debug" -> Log.level = LogLevel.debug;
                            case "maximized" -> maximized = Boolean.parseBoolean(arg[i + 1]);
                            case "testMobile" -> testMobile = true;
                        }
                    }
                }
                setWindowIcon(FileType.internal, "icons/icon_64.png");
            }});
        }catch(Throwable e){
            handleCrash(e);
        }
    }

    static void checkJavaVersion(){
        if(OS.javaVersionNumber < 17){
            ErrorDialog.show("Java 25 is required to run Mindustry. Your version: " + OS.javaVersionNumber + "\n" +
            "\n" +
            "Please uninstall your current Java version, and download Java 25.\n" +
            "\n" +
            "It is recommended to download Java from adoptium.net.\n" +
            "Do not download from java.com, as that will give you Java 8 by default.");
        }
    }

    public final String[] args;

    public AndroidJvmLauncher(String[] args){
        this.args = args;
    }

    @Override
    public void showFileChooser(FileChooserParams params){
        Threads.daemon(() -> {
            try{
                FileChooser.showFallbackFileChooser(params);
            }catch(Throwable error){
                Log.err("Failed to execute file chooser", error);
                Core.app.post(() -> FileChooser.showFallbackFileChooser(params));
            }
        });
    }

    @Override
    public Seq<Fi> getWorkshopContent(Class<? extends Publishable> type){
        return super.getWorkshopContent(type);
    }

    @Override
    public void viewListing(Publishable pub){
    }

    @Override
    public void viewListingID(String id){
    }

    @Override
    public NetProvider getNet(){
        return new ArcNetProvider();
    }

    @Override
    public void openWorkshop(){
    }

    @Override
    public void publish(Publishable pub){
    }

    @Override
    public void inviteFriends(){
    }

    @Override
    public void updateLobby(){
    }

    @Override
    public void updateRPC(){
    }

    @Override
    public String getUUID(){
        return super.getUUID();
    }

    static void handleCrash(Throwable e){
        boolean badGPU = false;
        String finalMessage = Strings.getFinalMessage(e);
        String total = Strings.getCauses(e).toString();

        if(total.contains("Couldn't create window") || total.contains("OpenGL 2.0 or higher") || total.toLowerCase().contains("pixel format") || total.contains("GLEW")|| total.contains("unsupported combination of formats")){

            message(
                total.contains("Couldn't create window") ? "A graphics initialization error has occured! Try to update your graphics drivers:\n" + finalMessage :
                            "Your graphics card does not support the right OpenGL features.\n" +
                                    "Try to update your graphics drivers. If this doesn't work, your computer may not support Mindustry.\n\n" +
                                    "Full message: " + finalMessage);
            badGPU = true;
        }

        boolean fbgp = badGPU;

        LoadedMod cause = CrashHandler.getModCause(e);
        String causeString = cause == null ? (Structs.contains(e.getStackTrace(), st -> st.getClassName().contains("rhino.gen.")) ? "A mod or script has caused Mindustry to crash.\nConsider disabling your mods if the issue persists.\n" : "Mindustry has crashed.") :
            "'" + cause.meta.displayName + "' (" + cause.name + ") has caused Mindustry to crash.\nConsider disabling this mod if issues persist.\n";

        CrashHandler.handle(e, file -> {
            Throwable fc = Strings.getFinalCause(e);
            if(!fbgp){
                String firstStackTraces = "";

                try{
                    var s = Seq.with(fc.getStackTrace());
                    s.removeAll(st -> st.getClassName().contains("MethodAccessor") || st.getClassName().substring(st.getClassName().lastIndexOf(".") + 1).equals("Method"));
                    s.truncate(3);
                    firstStackTraces = "\n" + s.toString("\n", st -> {
                        String className = st.getClassName();
                        return className.substring(className.lastIndexOf(".") + 1) + "." + st.getMethodName() + ": " + st.getLineNumber();
                    });
                }catch(Throwable ignored){
                }

                message(causeString + "\nThe logs have been saved in:\n" + file.getAbsolutePath() + "\n" + fc.getClass().getSimpleName().replace("Exception", "") + (fc.getMessage() == null ? "" : ":\n" + fc.getMessage()) + firstStackTraces);
            }
        });
    }

    private static void message(String message){
        Log.err(message);
    }
}