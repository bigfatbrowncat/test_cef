// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_JAVA_DBG_H_
#define CEF_JAVA_DBG_H_
#pragma once

#include "cefclient/client_handler.h"

namespace java_dbg {

/// Handler creation. Called from ClientHandler.
void CreateMessageHandlers(ClientHandler::MessageHandlerSet& handlers);

}  // namespace java_dbg

#endif  // CEF_JAVA_DBG_H_
