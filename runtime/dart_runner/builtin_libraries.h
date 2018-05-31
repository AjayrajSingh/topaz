// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_DART_RUNNER_BUILTIN_LIBRARIES_H_
#define TOPAZ_RUNTIME_DART_RUNNER_BUILTIN_LIBRARIES_H_

#include <memory>
#include <string>

#include <fdio/namespace.h>

#include <component/cpp/fidl.h>
#include "lib/app/cpp/startup_context.h"

namespace dart_runner {

void InitBuiltinLibrariesForIsolate(
    const std::string& script_uri, fdio_ns_t* namespc, int stdoutfd,
    int stderrfd, std::unique_ptr<component::StartupContext> context,
    fidl::InterfaceRequest<component::ServiceProvider> outgoing_services,
    bool service_isolate);

}  // namespace dart_runner

#endif  // TOPAZ_RUNTIME_DART_RUNNER_BUILTIN_LIBRARIES_H_
