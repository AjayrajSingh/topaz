// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_CONTENT_HANDLER_EMBEDDER_BUILTIN_H_
#define APPS_DART_CONTENT_HANDLER_EMBEDDER_BUILTIN_H_

#include <string>
#include <mx/channel.h>

#include "apps/modular/services/application/application_environment.fidl.h"

namespace dart_content_handler {

void InitBuiltinLibrariesForIsolate(
    const std::string& base_uri,
    const std::string& script_uri,
    fidl::InterfaceHandle<modular::ApplicationEnvironment> environment,
    fidl::InterfaceRequest<modular::ServiceProvider> outgoing_services);

}  // namespace dart_content_handler

#endif  // APPS_DART_CONTENT_HANDLER_EMBEDDER_BUILTIN_H_
