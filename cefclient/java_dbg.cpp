// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "cefclient/java_dbg.h"
#include "include/cef_browser.h"
#include "java_context.h"

#include <string>

# define NELEM(x) ((int) (sizeof(x) / sizeof((x)[0])))
# define NATIVE_METHOD(className, functionName, signature) \
{ (char*)#functionName, (char*)signature, reinterpret_cast<void*>(className ## _ ## functionName) }

extern "C" void Debugger_updateJS(JNIEnv* env, jclass clazz);

namespace java_dbg {

const char kDebuggerName[] = "com/intel/Main";
const char kDebuggerRunMessageName[] = "Debugger.Run";
const char kDebuggerPauseMessageName[] = "Debugger.Pause";
const char kDebuggerStopMessageName[] = "Debugger.Stop";

namespace {

// Handle messages in the browser process.
class Handler : public CefMessageRouterBrowserSide::Handler {

    jobject dbg = NULL;
    
public:
    static CefRefPtr<CefFrame> _frame;
    
 public:
  Handler() {}

    // Called due to cefQuery execution in dialogs.html.
    virtual bool OnQuery(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         int64 query_id,
                         const CefString& request,
                         bool persistent,
                         CefRefPtr<Callback> callback) OVERRIDE {

        /******** Save CEF params **********/

        _frame = browser->GetMainFrame();
        
        if (!dbg)
        {
            jclass cls = g_env->FindClass(kDebuggerName);
            
            /******** Register native Java methods ********/
            static JNINativeMethod gMethods[] = {
                NATIVE_METHOD(Debugger, updateJS, "()V"),
            };
            g_env->RegisterNatives(cls, gMethods, NELEM(gMethods));

            /******** Create one java instance ********/
            jmethodID constructor = g_env->GetMethodID(cls, "<init>", "()V");
            dbg = g_env->NewObject(cls, constructor);
        }

        const std::string& message_name = request;
        if (message_name == kDebuggerRunMessageName) {

            jclass cls = g_env->FindClass(kDebuggerName);
            jmethodID mid = g_env->GetMethodID(cls, "run", "()V");
            
            g_env->CallVoidMethod(dbg, mid);
        } else if (message_name == kDebuggerStopMessageName) {
            
            jclass cls = g_env->FindClass(kDebuggerName);
            jmethodID mid = g_env->GetMethodID(cls, "stop", "()V");
            
            g_env->CallVoidMethod(dbg, mid);
        }else if (message_name == kDebuggerPauseMessageName) {
            
            jclass cls = g_env->FindClass(kDebuggerName);
            jmethodID mid = g_env->GetMethodID(cls, "stop", "()V");
            
            g_env->CallVoidMethod(dbg, mid);
        }

        callback->Success("All is OK!");
        return true;
    }
};

}  // namespace

void CreateMessageHandlers(ClientHandler::MessageHandlerSet& handlers) {
    handlers.insert(new Handler());
}
    
CefRefPtr<CefFrame> Handler::_frame;

}  // namespace java_dbg

extern "C" {
    
    JNIEXPORT void JNICALL
    Debugger_updateJS(JNIEnv* env, jclass clazz)
    {
        CefRefPtr<CefFrame> &frame = java_dbg::Handler::_frame;
        frame->ExecuteJavaScript("change_btn_color();",
                                         frame->GetURL(), 0);
    }
    
}
