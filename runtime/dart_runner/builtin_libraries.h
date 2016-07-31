// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_CONTENT_HANDLER_EMBEDDER_BUILTIN_H_
#define APPS_DART_CONTENT_HANDLER_EMBEDDER_BUILTIN_H_

#include <string>

#include "mojo/public/cpp/system/handle.h"

namespace dart_content_handler {

void SetHandleWatcherProducerHandle(MojoHandle handle);
void InitBuiltinLibrariesForIsolate(const std::string& base_uri,
                                    const std::string& script_uri);

}  // namespace dart_content_handler

#endif  // APPS_DART_CONTENT_HANDLER_EMBEDDER_BUILTIN_H_
