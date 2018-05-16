// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef APPS_DART_RUNNER_EMBEDDER_BUILTIN_H_
#define APPS_DART_RUNNER_EMBEDDER_BUILTIN_H_

#include <memory>
#include <string>

#include <fdio/namespace.h>

#include "lib/app/cpp/application_context.h"
#include <component/cpp/fidl.h>

namespace dart_runner {

void InitBuiltinLibrariesForIsolate(
    const std::string& script_uri, fdio_ns_t* namespc, int stdoutfd,
    int stderrfd, std::unique_ptr<component::ApplicationContext> context,
    fidl::InterfaceRequest<component::ServiceProvider> outgoing_services,
    bool service_isolate);

}  // namespace dart_runner

#endif  // APPS_DART_RUNNER_EMBEDDER_BUILTIN_H_
