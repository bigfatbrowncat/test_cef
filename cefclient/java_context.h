
#ifndef __cefclient__java_context__
#define __cefclient__java_context__
#pragma once

#include <stdio.h>
#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif
    
extern JavaVM *g_jvm;       /* denotes a Java VM */
extern JNIEnv *g_env;       /* pointer to native method interface */

void StartJVM();

void StopJVM();

void RunEclipse();


#ifdef __cplusplus
}
#endif
        
#endif /* defined(__cefclient__java_context__) */
