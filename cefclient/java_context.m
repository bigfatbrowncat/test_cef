#include "java_context.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>

#include <dlfcn.h>
#include <limits.h>



JavaVM *g_jvm = 0;       /* denotes a Java VM */
JNIEnv *g_env = 0;       /* pointer to native method interface */

NSString* classPathFromDir(const char* dir)
{
    NSString *parantDir = [NSString stringWithUTF8String:dir];
    NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:parantDir
                                                                        error:NULL];
    
    NSMutableString *cp = [NSMutableString stringWithString:@"-Djava.class.path="];
    
    [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *filename = (NSString *)obj;
//        NSString *extension = [[filename pathExtension] lowercaseString];
        [cp appendFormat:@"%@/%@:",parantDir,filename];
    }];
    
    [cp deleteCharactersInRange:NSMakeRange([cp length]-1, 1)];

    return cp;
}

void StartJVM()
{
    
    const char* java_home = getenv("JAVA_HOME");
    if (!java_home) {
        printf("JAVA_HOME variable isn't setted.\n");
        return;
    }
    
    char fullJVMPath[PATH_MAX] = "";
    strcat(fullJVMPath, java_home);
    strcat(fullJVMPath, "/jre/lib/jli/libjli.dylib");
    
    void * jvmdll = dlopen(fullJVMPath, RTLD_LAZY);
    
    if (!jvmdll) {
        printf("JVM dynamic library was not loaded.\n");
        return;
    }

    typedef jint (JNICALL *CreateJVMFunc)(JavaVM **pvm, void **penv, void *args);
    CreateJVMFunc createJVMFunc = dlsym(jvmdll, "JNI_CreateJavaVM");
    
    if (!createJVMFunc) {
        printf("JNI_CreateJavaVM symbol was not found.\n");
        return;
    }

    void * chechhdl = dlopen("/Users/apeskov/Documents/xcode/uiloop/_build/uiloop/Build/Products/Debug/libuiloop.dylib", RTLD_LAZY);

    void * selfhdl = dlopen(0, RTLD_LAZY);
    void*  checfunc = dlsym(selfhdl, "Java_org_eclipse_ui_application_WorkbenchAdvisor_processNativeUIMessages");
    
    

    JavaVMInitArgs vm_args; /* JDK 1.1 VM initialization arguments */
    JavaVMOption args[1024];
    int nargs = 0;
    
    /* Set a classpath with local jars */
    CFURLRef jarUrl = CFBundleCopyResourceURL(CFBundleGetMainBundle(), CFSTR("cefclient"), CFSTR("jar"), nil);
    CFStringRef jarPath = CFURLCopyFileSystemPath(jarUrl, kCFURLPOSIXPathStyle);
    CFStringRef cpParam = CFStringCreateWithFormat(NULL, NULL, CFSTR("-Djava.class.path=%@"), jarPath);
    
    NSString *cp = classPathFromDir("/Users/apeskov/Desktop/macosx/cocoa/x86_64/Eclipse.app/Contents/Eclipse/plugins");
    
    char cpstr[1024];
    CFStringGetCString(cpParam, cpstr, 1024, kCFStringEncodingUTF8);
//    args[nargs++].optionString = cpstr;
//    args[nargs++].optionString = "-Djava.class.path=/Users/apeskov/Desktop/macosx/cocoa/x86_64/Eclipse.app/Contents/Eclipse/plugins/org.eclipse.equinox.launcher_1.3.100.v20150511-1540.jar";
    
    args[nargs++].optionString = [cp UTF8String];

    /** Debug keys */
//    args[nargs++].optionString = "-Xdebug";
//    args[nargs++].optionString = "-Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=1044";

    /** Eclipse keys */
    args[nargs++].optionString = "-Xms256m";
    args[nargs++].optionString = "-Xmx1024m";
    args[nargs++].optionString = "-Xdock:icon=/Users/apeskov/Desktop/macosx/cocoa/x86_64/Eclipse.app/Contents/Resources/Eclipse.icns";
    args[nargs++].optionString = "-XstartOnFirstThread";
    args[nargs++].optionString = "-Dorg.eclipse.swt.internal.carbon.smallFonts";

    
    vm_args.version  = JNI_VERSION_1_4;
    vm_args.options  = args;
    vm_args.nOptions = nargs;
    vm_args.ignoreUnrecognized = JNI_TRUE;
    
    CFRelease(jarUrl);
    
    /* load and initialize a Java VM, return a JNI interface
     * pointer in env */
    jint ret = createJVMFunc(&g_jvm, (void**)&g_env, &vm_args);
    if (ret) {
        printf("JVM was not created (ret = %d).\n", ret);
        return;
    }

}

void StopJVM()
{
    (*g_jvm)->DestroyJavaVM(g_jvm);
}

static jclass string_class = NULL;

static jstring newJavaString(JNIEnv *env, const char * str)
{
    jstring newString = NULL;
    newString = (*env)->NewStringUTF(env, str);

    if(newString == NULL) {
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    return newString;
}

static jobjectArray createRunArgs( JNIEnv *env, const char * args[] ) {
    int index = 0, length = -1;
    jobjectArray stringArray = NULL;
    jstring string;
    
    /*count the number of elements first*/
    while(args[++length] != NULL);
    
    if (string_class == NULL)
        string_class = (*env)->FindClass(env, "java/lang/String");
    if(string_class != NULL) {
        stringArray = (*env)->NewObjectArray(env, length, string_class, 0);
        if(stringArray != NULL) {
            for( index = 0; index < length; index++) {
                string = newJavaString(env, args[index]);
                if(string != NULL) {
                    (*env)->SetObjectArrayElement(env, stringArray, index, string);
                    (*env)->DeleteLocalRef(env, string);
                } else {
                    (*env)->DeleteLocalRef(env, stringArray);
                    (*env)->ExceptionDescribe(env);
                    (*env)->ExceptionClear(env);
                    return NULL;
                }
            }
        }
    } 
    if(stringArray == NULL) {
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    return stringArray;
}

# define NELEM(x) ((int) (sizeof(x) / sizeof((x)[0])))
# define NATIVE_METHOD(className, functionName, signature) \
{ (char*)#functionName, (char*)signature, (void*)(className ## _ ## functionName) }

JNIEXPORT void JNICALL
WorkbenchAdvisor_processNativeUIMessages(JNIEnv* env, jobject obj)
{
    printf("[ Hello loop ]\n");
}

void RunEclipse()
{
    jint retval;
    
    //egister JNI methods
//    {
//        const char* workbenchAdv = "org/eclipse/ui/application/WorkbenchAdvisor";
//        jclass cls = (*g_env)->FindClass(g_env, workbenchAdv);
//        
//        jthrowable exc = (*g_env)->ExceptionOccurred(g_env);
//        if (exc) {
//            cls = (*g_env)->GetObjectClass(g_env, exc);
//
//            jmethodID mid = (*g_env)->GetMethodID(g_env, cls, "printStackTrace", "()V");
//            (*g_env)->CallVoidMethod(g_env, exc, mid); 
//            
//            (*g_env)->ExceptionDescribe(g_env);
//            (*g_env)->ExceptionClear(g_env);
//        }
//        
//        /******** Register native Java methods ********/
//        static JNINativeMethod gMethods[] = {
//            NATIVE_METHOD(WorkbenchAdvisor, processNativeUIMessages, "()V"),
//        };
//        jint ret = (*g_env)->RegisterNatives(g_env, cls, gMethods, NELEM(gMethods));
//        NSLog (@"After register %d", ret);
//        
//        
//    }

    
    const char *progArgs[] = {
        "-os",
        "macosx",
        "-ws",
        "cocoa",
        "-arch",
        "x86_64",
        "-showsplash",
        "-launcher",
//        "/Users/apeskov/Desktop/macosx/cocoa/x86_64/Eclipse.app/Contents/MacOS/eclipse",
        "/Users/apeskov/Downloads/test_cef/xcodebuild/Debug/cefclient.app/Contents/MacOS/cefclient",
        "-name",
        "Eclipse",
        "--launcher.library",
        "/Users/apeskov/Desktop/macosx/cocoa/x86_64/Eclipse.app/Contents/Eclipse/plugins/org.eclipse.equinox.launcher.cocoa.macosx.x86_64_1.1.300.v20150602-1417/eclipse_1611.so",
        "-startup",
        "/Users/apeskov/Desktop/macosx/cocoa/x86_64/Eclipse.app/Contents/Eclipse/plugins/org.eclipse.equinox.launcher_1.3.100.v20150511-1540.jar",
        "--launcher.appendVmargs",
//        "-keyring",
//        "/Users/sokolovmikhail/.eclipse_keyring",
        "-vm",
        "/Library/Java/JavaVirtualMachines/jdk1.8.0_31.jdk/Contents/Home/jre/lib/server/libjvm.dylib",
        "-vmargs",
        "-Xms256m",
        "-Xmx1024m",
        "-Xdock:icon=/Users/apeskov/Desktop/macosx/cocoa/x86_64/Eclipse.app/Contents/Resources/Eclipse.icns",
        "-XstartOnFirstThread",
        "-Dorg.eclipse.swt.internal.carbon.smallFonts",
        "-Djava.class.path=/Users/apeskov/Desktop/macosx/cocoa/x86_64/Eclipse.app/Contents/Eclipse/plugins/org.eclipse.equinox.launcher_1.3.100.v20150511-1540.jar",
        NULL
    };
    
    const char *mainClassName = "org/eclipse/equinox/launcher/Main";
    jclass mainClass = NULL;
    mainClass = (*g_env)->FindClass(g_env, mainClassName);
    
    if(mainClass != NULL) {
        jmethodID mainConstructor = (*g_env)->GetMethodID(g_env, mainClass, "<init>", "()V");
        if(mainConstructor != NULL) {
            jobject mainObject = (*g_env)->NewObject(g_env, mainClass, mainConstructor);
            if(mainObject != NULL) {
                jmethodID runMethod = (*g_env)->GetMethodID(g_env, mainClass, "run", "([Ljava/lang/String;)I");
                if(runMethod != NULL) {
                    jobject methodArgs = createRunArgs(g_env, progArgs);
                    if(methodArgs != NULL) {
                        retval = (*g_env)->CallIntMethod(g_env, mainObject, runMethod, methodArgs);
                        (*g_env)->DeleteLocalRef(g_env, methodArgs);
                    }
                }
                (*g_env)->DeleteLocalRef(g_env, mainObject);
            }
        }
    }
    
    if((*g_env)->ExceptionOccurred(g_env)){
        (*g_env)->ExceptionDescribe(g_env);
        (*g_env)->ExceptionClear(g_env);
    }
        
//    cls = (*g_env)->FindClass(g_env, "org/eclipse/equinox/launcher/Main");

    /******** Create one java instance ********/
//    jmethodID constructor = (*g_env)->GetMethodID(g_env, cls, "<init>", "()V");
//    jobject main_ins = (*g_env)->NewObject(g_env, cls, constructor);
//    (*g_env)->CallVoidMethod(g_env, main_ins, constructor);
    
//    jmethodID main_mid = (*g_env)->GetMethodID(g_env, cls, "run", "([Ljava/lang/String;)I");
//    (*g_env)->CallStaticVoidMethod(g_env, cls, main_mid, NULL);
    
}


//org.eclipse.ui.application.WorkbenchAdvisor.processNativeUIMessages()V


